class_name SKVendor
extends Node
## A merchant: sells its wares, buys from the player, lets the player buy back
## what they sold, and restocks.
##
## Money is an Inventory Kit item ([member SKShop.currency], gold_coins by default),
## so every purchase, sale and buyback is one [IKTransaction]: the payment and the
## items move together or not at all. No gold is taken for items that do not fit,
## and no item is given without payment. Lines can also cost several currencies
## (gold + gems) or items (barter): they are paid in the same transaction.
##
## Each vendor keeps its own reputation (saved by [method to_data]): reputation
## levels change prices and unlock wares (see [member SKShop.reputation_tiers]).
## [codeblock]
## var result := vendor.buy(offer.index, 3, bag.container)
## if not result.ok:
##     status.text = SKText.result_message(result)
## [/codeblock]

signal purchased(item_id: StringName, amount: int, price: int)
signal sold(item_id: StringName, amount: int, price: int)
signal bought_back(item_id: StringName, amount: int, price: int)
signal restocked
## Reputation changed (trades or [method add_reputation]); [param tier] is the level now reached (or null).
signal reputation_changed(reputation: int, tier: SKReputationTier)
## Stock, buyback, funds or reputation changed: refresh the UI.
signal changed

const DATA_VERSION := 1

@export var shop: SKShop
## Item definitions, for prices and names. Defaults to the bag's database.
@export var database: IKItemDatabase
## Multiplies buy prices (sales, haggling...): 0.8 = 20 % off. Reputation levels multiply it.
@export var buy_modifier: float = 1.0
## Multiplies what the vendor pays for the player's items.
@export var sell_modifier: float = 1.0
## Seed of the random wares. 0 = different every run.
@export var rng_seed: int = 0

## Restocks since the vendor opened (your "days").
var day: int = 0

# {item_id, stock, max_stock, restock_amount, price, random, prices, barter, min_reputation}
var _lines: Array[Dictionary] = []
var _buyback: Array[Dictionary] = []  # {stack: IKItemStack, price: int}
var _funds: int = -1
var _reputation: int = 0
var _reputation_progress: int = 0  # main currency spent towards the next point
var _rng := RandomNumberGenerator.new()
var _opened := false


func _ready() -> void:
	if not _opened:
		open()


## (Re)opens the vendor from its [member shop]: full stock, new random wares, funds reset,
## empty buyback, starting reputation. Called automatically when the node enters the tree.
func open() -> void:
	if shop == null:
		push_warning("SKVendor %s has no shop." % name)
		shop = SKShop.new()
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_lines.clear()
	for entry in shop.entries:
		if entry == null or entry.item_id.is_empty():
			continue
		_lines.append(_line_from_entry(entry))
	_roll_random_wares()
	_funds = shop.funds
	_buyback.clear()
	day = 0
	_reputation = _clamp_reputation(shop.start_reputation)
	_reputation_progress = 0
	_opened = true
	changed.emit()


# --- Reading ---------------------------------------------------------------

func get_currency() -> StringName:
	return shop.currency if shop != null else &"gold_coins"


## Main currency first, then every other currency a line is priced in.
func get_currencies() -> Array[StringName]:
	var result: Array[StringName] = [get_currency()]
	for line in _lines:
		for key in line.prices:
			if not result.has(StringName(key)):
				result.append(StringName(key))
	return result


## Money the vendor can still pay out. -1 = unlimited.
func get_funds() -> int:
	return _funds


func get_offers() -> Array[SKOffer]:
	var offers: Array[SKOffer] = []
	for i in _lines.size():
		offers.append(_offer(i))
	return offers


func get_offer(index: int) -> SKOffer:
	return _offer(index) if index >= 0 and index < _lines.size() else null


## Sold items the player can take back, latest first: [{stack: IKItemStack (copy), price: int}].
func get_buyback() -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for entry in _buyback:
		copies.append({"stack": entry.stack.copy(), "price": entry.price})
	return copies


## Unit price the player pays for [param item_id] at this vendor (main currency, from the pricing rules).
func buy_price(item_id: StringName) -> int:
	return shop.get_pricing().buy_price(_definition(item_id), get_buy_modifier())


## Unit price this vendor pays for [param item_id] (0 = refuses it).
func sell_price(item_id: StringName) -> int:
	var definition := _definition(item_id)
	if not shop.accepts(definition):
		return 0
	return shop.get_pricing().sell_price(definition, get_sell_modifier(), get_buy_modifier())


func will_buy(item_id: StringName) -> bool:
	return sell_price(item_id) > 0


# --- Reputation ------------------------------------------------------------

func get_reputation() -> int:
	return _reputation


## The reputation level reached, or null (no levels, or none reached).
func get_reputation_tier() -> SKReputationTier:
	return shop.tier_for(_reputation) if shop != null else null


## The next level to reach, or null at the top.
func get_next_reputation_tier() -> SKReputationTier:
	return shop.next_tier_for(_reputation) if shop != null else null


## Sets the reputation, kept between [member SKShop.min_reputation] and [member SKShop.max_reputation].
func set_reputation(value: int) -> void:
	var clamped := _clamp_reputation(value)
	if clamped == _reputation:
		return
	_reputation = clamped
	reputation_changed.emit(_reputation, get_reputation_tier())
	changed.emit()


## Adds [param amount] (negative to lose some: theft, a failed quest...). Returns the new value.
func add_reputation(amount: int) -> int:
	set_reputation(_reputation + amount)
	return _reputation


## [member buy_modifier] times the multiplier of the reputation level.
func get_buy_modifier() -> float:
	var tier := get_reputation_tier()
	return buy_modifier * (tier.buy_multiplier if tier != null else 1.0)


## [member sell_modifier] times the multiplier of the reputation level.
func get_sell_modifier() -> float:
	var tier := get_reputation_tier()
	return sell_modifier * (tier.sell_multiplier if tier != null else 1.0)


## True if line [param index] needs more reputation.
func is_locked(index: int) -> bool:
	return index >= 0 and index < _lines.size() and _reputation < int(_lines[index].min_reputation)


# --- Trading ---------------------------------------------------------------

## Buys [param amount] of offer [param index] into [param bag], paying from
## [param wallet] (the bag itself by default). Barter items are taken from the bag.
func buy(index: int, amount: int, bag: IKContainer, wallet: IKContainer = null) -> SKResult:
	if index < 0 or index >= _lines.size() or amount <= 0 or bag == null:
		return SKResult.failure(SKResult.Code.INVALID_ARGUMENT, "buy(%d, %d): bad index, amount or bag" % [index, amount])
	wallet = wallet if wallet != null else bag
	_adopt_database(bag)
	var line := _lines[index]
	if is_locked(index):
		return SKResult.failure(SKResult.Code.LOCKED, "%s needs reputation %d, vendor has %d" % [
			line.item_id, line.min_reputation, _reputation])
	if line.stock >= 0 and line.stock < amount:
		return SKResult.failure(SKResult.Code.OUT_OF_STOCK, "%s: %d left, %d asked" % [line.item_id, line.stock, amount])
	var offer := _offer(index)
	var money := {}
	for key in offer.unit_costs:
		if offer.unit_costs[key] > 0:
			money[key] = offer.unit_costs[key] * amount
	var items := {}
	for key in offer.barter:
		if offer.barter[key] > 0:
			items[key] = offer.barter[key] * amount
	for key in money:
		if wallet.count(key) < money[key]:
			return SKResult.failure(SKResult.Code.NOT_ENOUGH_MONEY, "%d %s needed, %d held" % [money[key], key, wallet.count(key)])
	for key in items:
		if bag.count(key) < items[key]:
			return SKResult.failure(SKResult.Code.NOT_ENOUGH_ITEMS, "%d %s needed, %d held" % [items[key], key, bag.count(key)])
	var transaction := IKTransaction.new()
	if not money.is_empty():
		transaction.consume(wallet, money)
	if not items.is_empty():
		transaction.consume(bag, items)
	var result := transaction.add(bag, line.item_id, amount).commit()
	if not result.ok:
		return _inventory_failure(result)
	var currency := get_currency()
	var total: int = money.get(currency, 0)
	if line.stock >= 0:
		line.stock -= amount
	if _funds >= 0:
		_funds += total
	_gain_reputation(total)
	purchased.emit(line.item_id, amount, total)
	changed.emit()
	var success := SKResult.success(line.item_id, amount, total, currency)
	success.costs = offer.total_costs(amount)
	return success


## Sells [param amount] items of [param slot] in [param bag] (-1 = the whole stack);
## the money goes to [param wallet] (the bag itself by default).
func sell(bag: IKContainer, slot: int, amount: int = -1, wallet: IKContainer = null) -> SKResult:
	if bag == null or not bag.is_valid_slot(slot) or bag.is_slot_empty(slot) or amount == 0:
		return SKResult.failure(SKResult.Code.INVALID_ARGUMENT, "sell: empty or invalid slot %d" % slot)
	var stack := bag.get_stack(slot)
	if stack == null:
		return SKResult.failure(SKResult.Code.INVALID_ARGUMENT, "sell: no stack at slot %d" % slot)
	wallet = wallet if wallet != null else bag
	_adopt_database(bag)
	amount = stack.amount if amount < 0 else mini(amount, stack.amount)
	var unit := sell_price(stack.item_id)
	if unit <= 0:
		return SKResult.failure(SKResult.Code.VENDOR_REFUSES, "%s is not bought here" % stack.item_id)
	var total := unit * amount
	if _funds >= 0 and _funds < total:
		return SKResult.failure(SKResult.Code.VENDOR_NO_FUNDS, "vendor has %d, sale is %d" % [_funds, total])
	var result := IKTransaction.new() \
		.remove_at(bag, slot, amount) \
		.add(wallet, get_currency(), total) \
		.commit()
	if not result.ok:
		return _inventory_failure(result)
	if _funds >= 0:
		_funds -= total
	if shop.buyback_size > 0:
		var kept := stack.copy()
		kept.amount = amount
		_buyback.push_front({"stack": kept, "price": total})
		if _buyback.size() > shop.buyback_size:
			_buyback.resize(shop.buyback_size)
	sold.emit(stack.item_id, amount, total)
	changed.emit()
	return SKResult.success(stack.item_id, amount, total, get_currency())


## Buys back entry [param index] of [method get_buyback] for the price the player got.
## Unique items come back with their uid and data (durability, enchantments...).
func buy_back(index: int, bag: IKContainer, wallet: IKContainer = null) -> SKResult:
	if index < 0 or index >= _buyback.size() or bag == null:
		return SKResult.failure(SKResult.Code.INVALID_ARGUMENT, "buy_back(%d): bad index or bag" % index)
	wallet = wallet if wallet != null else bag
	_adopt_database(bag)
	var entry := _buyback[index]
	var currency := get_currency()
	if wallet.count(currency) < entry.price:
		return SKResult.failure(SKResult.Code.NOT_ENOUGH_MONEY, "%d %s needed" % [entry.price, currency])
	var transaction := IKTransaction.new()
	if entry.price > 0:
		transaction.consume(wallet, {currency: entry.price})
	var result := transaction.add_stack(bag, entry.stack.copy()).commit()
	if not result.ok:
		return _inventory_failure(result)
	_buyback.remove_at(index)
	if _funds >= 0:
		_funds += entry.price
	bought_back.emit(entry.stack.item_id, entry.stack.amount, entry.price)
	changed.emit()
	return SKResult.success(entry.stack.item_id, entry.stack.amount, entry.price, currency)


## A new day: fixed wares refill, random wares are rolled again, funds reset,
## buyback cleared (see [member SKShop.clear_buyback_on_restock]). Reputation stays.
func restock() -> void:
	day += 1
	var kept: Array[Dictionary] = []
	for line in _lines:
		if line.random:
			continue
		if line.stock >= 0 and line.max_stock >= 0:
			var gain: int = line.restock_amount if line.restock_amount > 0 else line.max_stock
			line.stock = mini(line.max_stock, line.stock + gain)
		kept.append(line)
	_lines = kept
	_roll_random_wares()
	_funds = shop.funds
	if shop.clear_buyback_on_restock:
		_buyback.clear()
	restocked.emit()
	changed.emit()


# --- Saving ----------------------------------------------------------------

## The vendor's state as JSON-friendly data. Save it next to your inventory save.
func to_data() -> Dictionary:
	var lines := []
	for line in _lines:
		var saved_line := {"id": String(line.item_id), "stock": line.stock, "max": line.max_stock,
			"restock": line.restock_amount, "price": line.price, "random": line.random}
		if not line.prices.is_empty():
			saved_line["prices"] = _to_json_amounts(line.prices)
		if not line.barter.is_empty():
			saved_line["barter"] = _to_json_amounts(line.barter)
		if line.min_reputation != SKShopEntry.ANY_REPUTATION:
			saved_line["min_rep"] = line.min_reputation
		lines.append(saved_line)
	var buyback := []
	for entry in _buyback:
		var stack: IKItemStack = entry.stack
		var saved := {"id": String(stack.item_id), "n": stack.amount, "price": entry.price}
		if stack.has_uid():
			saved["uid"] = stack.uid
		if not stack.data.is_empty():
			saved["data"] = stack.data.duplicate(true)
		buyback.append(saved)
	return {"version": DATA_VERSION, "shop": String(shop.shop_id), "day": day, "funds": _funds,
		"lines": lines, "buyback": buyback, "rng_state": str(_rng.state),
		"reputation": _reputation, "rep_progress": _reputation_progress}


## Restores [method to_data]. Lines of items missing from the database are dropped.
## Returns false (and keeps the current state) when the data is unreadable.
## Data saved by 1.0 (no prices, barter or reputation) loads: those come from the shop.
func load_data(data: Dictionary) -> bool:
	if typeof(data.get("lines")) != TYPE_ARRAY or typeof(data.get("buyback", [])) != TYPE_ARRAY:
		return false
	var lines: Array[Dictionary] = []
	for raw: Variant in data.lines:
		if typeof(raw) != TYPE_DICTIONARY or not _known(StringName(str(raw.get("id", "")))):
			continue
		var item_id := StringName(str(raw.id))
		var random := bool(raw.get("random", false))
		var line := {"item_id": item_id, "stock": int(raw.get("stock", -1)),
			"max_stock": int(raw.get("max", -1)), "restock_amount": int(raw.get("restock", 0)),
			"price": int(raw.get("price", -1)), "random": random,
			"prices": {}, "barter": {}, "min_reputation": SKShopEntry.ANY_REPUTATION}
		var entry := _entry_for(item_id) if not random else null
		if raw.has("prices") or raw.has("barter") or raw.has("min_rep") or entry == null:
			line.prices = _from_json_amounts(raw.get("prices", {}))
			line.barter = _from_json_amounts(raw.get("barter", {}))
			line.min_reputation = int(raw.get("min_rep", SKShopEntry.ANY_REPUTATION))
		else:  # 1.0 data: take them from the shop
			line.prices = _amounts(entry.prices)
			line.barter = _amounts(entry.barter)
			line.min_reputation = entry.min_reputation
		lines.append(line)
	var buyback: Array[Dictionary] = []
	for raw: Variant in data.get("buyback", []):
		if typeof(raw) != TYPE_DICTIONARY or not _known(StringName(str(raw.get("id", "")))) or int(raw.get("n", 0)) <= 0:
			continue
		var stack := IKItemStack.new(StringName(str(raw.id)), int(raw.n), str(raw.get("uid", "")),
			raw.get("data", {}) if typeof(raw.get("data", {})) == TYPE_DICTIONARY else {})
		buyback.append({"stack": stack, "price": maxi(0, int(raw.get("price", 0)))})
	_lines = lines
	_buyback = buyback
	day = int(data.get("day", 0))
	_funds = int(data.get("funds", shop.funds))
	if data.has("rng_state"):
		_rng.state = int(str(data.rng_state))
	var before := _reputation
	_reputation = _clamp_reputation(int(data.get("reputation", shop.start_reputation)))
	_reputation_progress = maxi(0, int(data.get("rep_progress", 0)))
	_opened = true
	if _reputation != before:
		reputation_changed.emit(_reputation, get_reputation_tier())
	changed.emit()
	return true


# --- Internals -------------------------------------------------------------

func _line_from_entry(entry: SKShopEntry) -> Dictionary:
	return {"item_id": entry.item_id, "stock": entry.stock, "max_stock": entry.get_max_stock(),
		"restock_amount": entry.restock_amount, "price": entry.price, "random": false,
		"prices": _amounts(entry.prices), "barter": _amounts(entry.barter), "min_reputation": entry.min_reputation}


func _offer(index: int) -> SKOffer:
	var line := _lines[index]
	var offer := SKOffer.new()
	offer.index = index
	offer.item_id = line.item_id
	offer.definition = _definition(line.item_id)
	offer.stock = line.stock
	offer.currency = get_currency()
	offer.random = line.random
	offer.min_reputation = line.min_reputation
	offer.locked = _reputation < int(line.min_reputation)
	offer.barter = (line.barter as Dictionary).duplicate()
	var modifier := get_buy_modifier()
	if not line.prices.is_empty():
		for key in line.prices:
			var base: int = line.prices[key]
			offer.unit_costs[StringName(key)] = maxi(1, ceili(base * modifier - 0.0001)) if base > 0 else 0
	elif line.price >= 0:
		offer.unit_costs[offer.currency] = maxi(0, ceili(line.price * modifier - 0.0001))
	elif line.barter.is_empty():
		offer.unit_costs[offer.currency] = buy_price(line.item_id)
	offer.unit_price = offer.unit_costs.get(offer.currency, 0)
	return offer


func _gain_reputation(spent: int) -> void:
	if shop.currency_per_reputation <= 0 or spent <= 0:
		return
	_reputation_progress += spent
	var points := _reputation_progress / shop.currency_per_reputation
	_reputation_progress %= shop.currency_per_reputation
	if points > 0:
		set_reputation(_reputation + points)


func _clamp_reputation(value: int) -> int:
	if shop == null:
		return value
	return clampi(value, mini(shop.min_reputation, shop.max_reputation), maxi(shop.min_reputation, shop.max_reputation))


func _entry_for(item_id: StringName) -> SKShopEntry:
	for entry in shop.entries:
		if entry != null and entry.item_id == item_id:
			return entry
	return null


func _roll_random_wares() -> void:
	if shop.random_wares == null or shop.random_ware_count <= 0:
		return
	for drop in shop.random_wares.roll(shop.random_ware_count, _rng, false):
		if not _known(drop.item_id):
			continue
		_lines.append({"item_id": drop.item_id, "stock": drop.amount, "max_stock": drop.amount,
			"restock_amount": 0, "price": -1, "random": true, "prices": {}, "barter": {},
			"min_reputation": SKShopEntry.ANY_REPUTATION})


## Plain {StringName: int} copy, positive amounts only.
static func _amounts(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		var value := int(source[key])
		if value > 0 and not str(key).is_empty():
			result[StringName(str(key))] = value
	return result


static func _to_json_amounts(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		result[String(key)] = int(source[key])
	return result


static func _from_json_amounts(raw: Variant) -> Dictionary:
	return _amounts(raw) if typeof(raw) == TYPE_DICTIONARY else {}


func _adopt_database(bag: IKContainer) -> void:
	if database == null:
		database = bag.database


func _definition(item_id: StringName) -> IKItemDefinition:
	return database.get_item(item_id) if database != null else null


func _known(item_id: StringName) -> bool:
	return not item_id.is_empty() and (database == null or database.has_item(item_id))


func _inventory_failure(result: IKResult) -> SKResult:
	match result.code:
		IKResult.Code.CONTAINER_FULL, IKResult.Code.RULE_REJECTED, IKResult.Code.SLOT_FULL:
			return SKResult.failure(SKResult.Code.NO_ROOM, result.message, result)
		IKResult.Code.NOT_ENOUGH_ITEMS:
			return SKResult.failure(SKResult.Code.NOT_ENOUGH_MONEY, result.message, result)
	return SKResult.failure(SKResult.Code.INVENTORY_ERROR, result.message, result)
