@tool
class_name SKShopEntry
extends Resource
## One line of a vendor's wares.

## [member min_reputation] value meaning "no reputation needed" (the default).
const ANY_REPUTATION := -1000000

## Item id from the Inventory Kit database.
@export var item_id: StringName
## Stock when the vendor opens. -1 = unlimited.
@export var stock: int = -1
## Stock a restock refills to. -1 = same as [member stock].
@export var max_stock: int = -1
## Items added per restock, up to [member max_stock]. 0 = refill completely.
@export var restock_amount: int = 0
## Unit buy price before vendor modifiers. -1 = from [SKPricing].
@export var price: int = -1

@export_group("Currencies and barter")
## Unit price in one or several currencies, all paid together, e.g.
## {&"gold_coins": 80, &"ruby": 1}. Replaces [member price] and the pricing rules;
## vendor modifiers and reputation still apply. Empty = [member price] in the shop's currency.
@export var prices: Dictionary[StringName, int] = {}
## Items the player hands over per unit bought (barter), e.g. {&"wolf_pelt": 3}.
## Taken from the bag, never changed by modifiers. A line with barter items and no
## [member price] / [member prices] costs only those items.
@export var barter: Dictionary[StringName, int] = {}

@export_group("Reputation")
## Reputation with the vendor needed to buy this line (see [member SKShop.reputation_tiers]).
## Until then the line is shown locked (or hidden, see [member SKShop.show_locked_wares]).
## Default: always available.
@export var min_reputation: int = ANY_REPUTATION


static func make(p_item_id: StringName, p_stock: int = -1, p_price: int = -1) -> SKShopEntry:
	var entry := SKShopEntry.new()
	entry.item_id = p_item_id
	entry.stock = p_stock
	entry.price = p_price
	return entry


## A line paid with items only, e.g. [code]SKShopEntry.trade(&"leather", {&"rawhide": 2})[/code].
static func trade(p_item_id: StringName, p_barter: Dictionary, p_stock: int = -1) -> SKShopEntry:
	var entry := make(p_item_id, p_stock)
	for key in p_barter:
		entry.barter[StringName(key)] = int(p_barter[key])
	return entry


func get_max_stock() -> int:
	return max_stock if max_stock >= 0 else stock


func requires_reputation() -> bool:
	return min_reputation != ANY_REPUTATION
