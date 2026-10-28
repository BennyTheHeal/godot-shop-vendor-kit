extends "res://tests/shop_kit/sk_test_case.gd"
## Several currencies per price (gold + gems) and barter (paying with items):
## everything is paid in the same transaction as the items received.


## make_db() plus gem (a second currency) and pelt (a barter good, value 8).
func _db() -> IKItemDatabase:
	var db := make_db()
	db.add_item(make_item(&"gem", 99, 0, &"currency"))
	db.add_item(make_item(&"pelt", 20, 8, &"material"))
	return db


func _shop(entries: Array[SKShopEntry]) -> SKShop:
	var shop := make_shop()
	shop.entries = entries
	return shop


func _priced(item_id: StringName, prices: Dictionary, stock: int = -1) -> SKShopEntry:
	var entry := SKShopEntry.make(item_id, stock)
	for key in prices:
		entry.prices[key] = prices[key]
	return entry


func _bag(db: IKItemDatabase, gold: int, gems: int = 0, pelts: int = 0, slots: int = 6) -> IKContainer:
	var bag := make_bag(db, slots, gold)
	if gems > 0:
		bag.add(&"gem", gems)
	if pelts > 0:
		bag.add(&"pelt", pelts)
	return bag


func test_price_in_two_currencies() -> void:
	var db := _db()
	var vendor := make_vendor(db, _shop([_priced(&"sword", {&"gold": 50, &"gem": 2})]))
	var bag := _bag(db, 100, 3)
	var offer := vendor.get_offer(0)
	assert_eq(offer.unit_price, 50, "main currency part")
	assert_eq(offer.unit_costs, {&"gold": 50, &"gem": 2})
	assert_true(offer.has_extra_costs())
	assert_false(offer.is_barter())
	assert_eq(vendor.get_currencies(), [&"gold", &"gem"] as Array[StringName])
	var result := vendor.buy(0, 1, bag)
	assert_true(result.ok, str(result))
	assert_eq(bag.count(&"gold"), 50)
	assert_eq(bag.count(&"gem"), 1)
	assert_eq(bag.count(&"sword"), 1)
	assert_eq(result.price, 50)
	assert_eq(result.costs, {&"gold": 50, &"gem": 2})
	vendor.free()


func test_missing_second_currency_changes_nothing() -> void:
	var db := _db()
	var vendor := make_vendor(db, _shop([_priced(&"sword", {&"gold": 50, &"gem": 2})]))
	var bag := _bag(db, 100, 1)
	assert_shop(vendor.buy(0, 1, bag), SKResult.Code.NOT_ENOUGH_MONEY)
	assert_eq(bag.count(&"gold"), 100)
	assert_eq(bag.count(&"gem"), 1)
	assert_eq(bag.count(&"sword"), 0)
	vendor.free()


func test_price_only_in_another_currency() -> void:
	var db := _db()
	var shop := _shop([_priced(&"potion", {&"gem": 3}, 5)])
	shop.funds = 100
	var vendor := make_vendor(db, shop)
	var bag := _bag(db, 10, 9)
	assert_eq(vendor.get_offer(0).unit_price, 0, "no gold asked")
	var result := vendor.buy(0, 2, bag)
	assert_true(result.ok, str(result))
	assert_eq(bag.count(&"gem"), 3)
	assert_eq(bag.count(&"gold"), 10)
	assert_eq(result.costs, {&"gem": 6})
	assert_eq(vendor.get_funds(), 100, "funds count the main currency only")
	vendor.free()


func test_modifiers_apply_to_every_currency() -> void:
	var db := _db()
	var vendor := make_vendor(db, _shop([_priced(&"sword", {&"gold": 50, &"gem": 3})]))
	vendor.buy_modifier = 0.5
	assert_eq(vendor.get_offer(0).unit_costs, {&"gold": 25, &"gem": 2}, "rounded up")
	vendor.buy_modifier = 0.01
	assert_eq(vendor.get_offer(0).unit_costs, {&"gold": 1, &"gem": 1}, "never free")
	vendor.free()


func test_barter_only_line() -> void:
	var db := _db()
	var vendor := make_vendor(db, _shop([SKShopEntry.trade(&"potion", {&"pelt": 2})]))
	var bag := _bag(db, 40, 0, 7)
	var offer := vendor.get_offer(0)
	assert_true(offer.is_barter())
	assert_eq(offer.unit_price, 0)
	assert_eq(offer.unit_costs, {})
	assert_eq(offer.total_costs(3), {&"pelt": 6})
	var result := vendor.buy(0, 3, bag)
	assert_true(result.ok, str(result))
	assert_eq(bag.count(&"potion"), 3)
	assert_eq(bag.count(&"pelt"), 1)
	assert_eq(bag.count(&"gold"), 40, "no money involved")
	assert_eq(result.costs, {&"pelt": 6})
	vendor.free()


func test_barter_without_the_goods_is_refused() -> void:
	var db := _db()
	var vendor := make_vendor(db, _shop([SKShopEntry.trade(&"potion", {&"pelt": 2})]))
	var bag := _bag(db, 40, 0, 3)
	var result := vendor.buy(0, 2, bag)
	assert_shop(result, SKResult.Code.NOT_ENOUGH_ITEMS)
	assert_eq(SKText.result_message(result), "You don't have what this trade asks for.")
	assert_eq(bag.count(&"pelt"), 3)
	assert_eq(bag.count(&"potion"), 0)
	vendor.free()


func test_barter_plus_money_and_modifiers_do_not_touch_goods() -> void:
	var db := _db()
	var entry := SKShopEntry.trade(&"wood", {&"pelt": 1})
	entry.price = 4
	var vendor := make_vendor(db, _shop([entry]))
	vendor.buy_modifier = 2.0
	var bag := _bag(db, 100, 0, 5)
	assert_eq(vendor.get_offer(0).total_costs(2), {&"gold": 16, &"pelt": 2})
	assert_true(vendor.buy(0, 2, bag).ok)
	assert_eq(bag.count(&"gold"), 84)
	assert_eq(bag.count(&"pelt"), 3)
	vendor.free()


func test_barter_is_atomic_when_the_bag_is_full() -> void:
	var db := _db()
	var vendor := make_vendor(db, _shop([SKShopEntry.trade(&"potion", {&"pelt": 2})]))
	var bag := _bag(db, 10, 0, 5, 2)  # slot 0 gold, slot 1 pelts: no free slot after paying
	var result := vendor.buy(0, 1, bag)
	assert_shop(result, SKResult.Code.NO_ROOM)
	assert_eq(bag.count(&"pelt"), 5, "nothing handed over for items that do not fit")
	assert_eq(bag.count(&"gold"), 10)
	var exact := _bag(db, 10, 0, 2, 2)
	assert_true(vendor.buy(0, 1, exact).ok, "paying with the last pelts frees their slot")
	assert_eq(exact.count(&"potion"), 1)
	vendor.free()


func test_wallet_pays_money_bag_pays_barter() -> void:
	var db := _db()
	var entry := SKShopEntry.trade(&"potion", {&"pelt": 1})
	entry.prices[&"gold"] = 10
	var vendor := make_vendor(db, _shop([entry]))
	var bag := _bag(db, 0, 0, 4)
	var wallet := IKContainer.new(&"wallet", 1, db)
	wallet.add(&"gold", 30)
	assert_true(vendor.buy(0, 2, bag, wallet).ok)
	assert_eq(wallet.count(&"gold"), 10)
	assert_eq(bag.count(&"pelt"), 2)
	assert_shop(vendor.buy(0, 1, IKContainer.new(&"empty", 3, db), wallet), SKResult.Code.NOT_ENOUGH_ITEMS)
	vendor.free()


func test_save_keeps_currencies_and_barter() -> void:
	var db := _db()
	var gem_line := _priced(&"sword", {&"gold": 50, &"gem": 2}, 2)
	var vendor := make_vendor(db, _shop([gem_line, SKShopEntry.trade(&"potion", {&"pelt": 2})]))
	var data: Dictionary = JSON.parse_string(JSON.stringify(vendor.to_data()))
	var other_shop := _shop([SKShopEntry.make(&"sword", 2), SKShopEntry.make(&"potion")])
	var copy := make_vendor(db, other_shop)
	assert_true(copy.load_data(data))
	assert_eq(copy.get_offer(0).unit_costs, {&"gold": 50, &"gem": 2}, "saved with the line")
	assert_eq(copy.get_offer(1).barter, {&"pelt": 2})
	vendor.free()
	copy.free()


func test_data_from_1_0_takes_prices_from_the_shop() -> void:
	var db := _db()
	var shop := _shop([_priced(&"sword", {&"gold": 50, &"gem": 2}, 2), SKShopEntry.trade(&"potion", {&"pelt": 2})])
	var vendor := make_vendor(db, shop)
	var old := {"version": 1, "shop": "test", "day": 3, "funds": -1, "buyback": [], "lines": [
		{"id": "sword", "stock": 1, "max": 2, "restock": 0, "price": -1, "random": false},
		{"id": "potion", "stock": -1, "max": -1, "restock": 0, "price": -1, "random": false},
	]}
	assert_true(vendor.load_data(old))
	assert_eq(vendor.day, 3)
	assert_eq(vendor.get_offer(0).stock, 1)
	assert_eq(vendor.get_offer(0).unit_costs, {&"gold": 50, &"gem": 2})
	assert_eq(vendor.get_offer(1).barter, {&"pelt": 2})
	assert_eq(vendor.get_reputation(), 0, "no reputation in 1.0 data: the shop's start value")
	vendor.free()


func test_cost_texts() -> void:
	var db := _db()
	assert_eq(SKText.cost_text({&"gold": 80, &"gem": 1}, db), "80 Gold + 1 Gem")
	assert_eq(SKText.cost_text({}, db), "Free")
	assert_eq(SKText.short_cost({&"gold": 80, &"pelt": 2}, &"gold", db), "80+2 Pel")
	assert_eq(SKText.short_cost({&"gem": 3}, &"gold", db), "3 Gem")


func test_window_shows_and_trades_barter_lines() -> void:
	var db := _db()
	var entry := SKShopEntry.trade(&"potion", {&"pelt": 2})
	var vendor: SKVendor = add_to_tree(make_vendor(db, _shop([_priced(&"sword", {&"gold": 50, &"gem": 2}), entry])))
	var bag := _bag(db, 100, 2, 5)
	var window := SKShopWindow.new()
	window.vendor = vendor
	window.bag = bag
	add_to_tree(window)
	await wait_frames(2)
	var entries := window._entries()
	assert_eq(entries[0].price_text, "50+2 Gem")
	assert_eq(entries[1].price_text, "2 Pel")
	assert_true(window._money.text.contains("100 Gold") and window._money.text.contains("2 Gem"), window._money.text)
	window._select(1)
	assert_eq(window._action.text, "Trade")
	assert_true(window._detail_text.text.contains("In exchange for"), window._detail_text.text)
	window._amount.max_value = 5
	window._amount.value = 2
	assert_eq(window._total.text, "4 Pelt")
	window._on_action()
	await wait_frames(2)
	assert_eq(bag.count(&"potion"), 2)
	assert_eq(bag.count(&"pelt"), 1)
	window._select(0)
	assert_true(window._detail_text.text.contains("Price: 50 Gold + 2 Gem"), window._detail_text.text)


func test_trading_with_two_currencies_never_creates_money() -> void:
	var db := _db()
	var vendor := make_vendor(db, _shop([_priced(&"wood", {&"gold": 6, &"gem": 1}), SKShopEntry.trade(&"potion", {&"pelt": 3})]))
	var bag := _bag(db, 200, 20, 20, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var gold_before := bag.count(&"gold")
		var gems_before := bag.count(&"gem")
		match rng.randi_range(0, 2):
			0:
				vendor.buy(0, rng.randi_range(1, 3), bag)
			1:
				vendor.buy(1, 1, bag)
			2:
				var slots := bag.find_slots(&"wood")
				if not slots.is_empty():
					vendor.sell(bag, slots[0], 1)
		assert_true(bag.count(&"gem") <= gems_before, "gems are only ever spent")
		# A sale pays for wood bought with 6 gold + a gem: always less than the gold part.
		assert_true(bag.count(&"gold") - gold_before < 6, "no sale pays what the wood cost")
	assert_eq(IKAudit.validate([bag]).size(), 0)
	vendor.free()
