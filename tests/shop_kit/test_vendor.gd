extends "res://tests/shop_kit/sk_test_case.gd"
## Buying, selling, buyback, stock, funds and restocks: payments and items always
## move together.


func test_buy_pays_and_gives() -> void:
	var db := make_db()
	var vendor := make_vendor(db)
	var bag := make_bag(db)
	var signals := []
	vendor.purchased.connect(func(id: StringName, n: int, price: int) -> void: signals.append([id, n, price]))
	var result := vendor.buy(1, 2, bag)
	assert_true(result.ok, str(result))
	assert_eq(bag.count(&"potion"), 2)
	assert_eq(bag.count(&"gold"), 60)
	assert_eq(result.price, 40)
	assert_eq(vendor.get_offer(1).stock, 1, "stock went down")
	assert_eq(signals, [[&"potion", 2, 40]])
	vendor.free()


func test_not_enough_money_changes_nothing() -> void:
	var db := make_db()
	var vendor := make_vendor(db)
	var bag := make_bag(db, 6, 50)
	assert_shop(vendor.buy(2, 1, bag), SKResult.Code.NOT_ENOUGH_MONEY)
	assert_eq(bag.count(&"gold"), 50)
	assert_eq(bag.count(&"sword"), 0)
	assert_eq(vendor.get_offer(2).stock, 1)
	vendor.free()


func test_full_bag_keeps_the_money() -> void:
	var db := make_db()
	var vendor := make_vendor(db)
	var bag := make_bag(db, 2, 100)  # slot 0: gold, slot 1: wood
	bag.add(&"wood", 20)
	var result := vendor.buy(1, 1, bag)
	assert_shop(result, SKResult.Code.NO_ROOM)
	assert_eq(bag.count(&"gold"), 100, "no gold taken for items that do not fit")
	assert_eq(vendor.get_offer(1).stock, 3)
	assert_false(SKText.result_message(result).is_empty())
	vendor.free()


func test_paying_can_free_the_slot_it_needs() -> void:
	var db := make_db()
	var vendor := make_vendor(db)
	var bag := make_bag(db, 2, 120)  # all the gold goes in the payment
	bag.add(&"wood", 20)
	assert_true(vendor.buy(2, 1, bag).ok, "the gold slot empties and takes the sword")
	assert_eq(bag.count(&"sword"), 1)
	assert_eq(bag.count(&"gold"), 0)
	vendor.free()


func test_out_of_stock() -> void:
	var db := make_db()
	var vendor := make_vendor(db)
	var bag := make_bag(db, 6, 500)
	assert_shop(vendor.buy(1, 4, bag), SKResult.Code.OUT_OF_STOCK)
	assert_true(vendor.buy(1, 3, bag).ok)
	assert_true(vendor.get_offer(1).is_sold_out())
	assert_shop(vendor.buy(1, 1, bag), SKResult.Code.OUT_OF_STOCK)
	assert_true(vendor.buy(0, 15, bag).ok, "unlimited stock")
	assert_true(vendor.get_offer(0).is_unlimited())
	vendor.free()


func test_separate_wallet() -> void:
	var db := make_db()
	var vendor := make_vendor(db)
	var bag := make_bag(db, 4, 0)
	var purse := make_bag(db, 1, 100)
	assert_true(vendor.buy(0, 4, bag, purse).ok)
	assert_eq(purse.count(&"gold"), 80)
	assert_eq(bag.count(&"wood"), 4)
	vendor.free()


func test_sell_and_refusals() -> void:
	var db := make_db()
	var vendor := make_vendor(db)
	var bag := make_bag(db, 6, 0)
	bag.add(&"wood", 10)
	bag.add(&"letter", 1)
	bag.add(&"rock", 3)
	var result := vendor.sell(bag, bag.find_slots(&"wood")[0], 4)
	assert_true(result.ok, str(result))
	assert_eq(result.price, 8, "4 x 2 gold")
	assert_eq(bag.count(&"wood"), 6)
	assert_eq(bag.count(&"gold"), 8)
	assert_shop(vendor.sell(bag, bag.find_slots(&"letter")[0]), SKResult.Code.VENDOR_REFUSES, "quest item")
	assert_shop(vendor.sell(bag, bag.find_slots(&"rock")[0]), SKResult.Code.VENDOR_REFUSES, "worthless")
	assert_shop(vendor.sell(bag, bag.find_slots(&"gold")[0]), SKResult.Code.VENDOR_REFUSES, "the currency itself")
	assert_shop(vendor.sell(bag, 5), SKResult.Code.INVALID_ARGUMENT, "empty slot")
	vendor.free()


func test_vendor_categories() -> void:
	var db := make_db()
	var shop := make_shop()
	shop.buys_categories = [&"consumable"]
	var vendor := make_vendor(db, shop)
	assert_true(vendor.will_buy(&"potion"))
	assert_false(vendor.will_buy(&"wood"))
	vendor.free()


func test_vendor_funds() -> void:
	var db := make_db()
	var shop := make_shop()
	shop.funds = 30
	var vendor := make_vendor(db, shop)
	var bag := make_bag(db, 6, 0)
	bag.add(&"sword", 1)
	assert_shop(vendor.sell(bag, bag.find_slots(&"sword")[0]), SKResult.Code.VENDOR_NO_FUNDS, "sword pays 40")
	assert_eq(bag.count(&"sword"), 1)
	bag.add(&"potion", 3)
	assert_true(vendor.sell(bag, bag.find_slots(&"potion")[0]).ok)
	assert_eq(vendor.get_funds(), 6, "30 - 3 x 8")
	vendor.restock()
	assert_eq(vendor.get_funds(), 30, "funds reset at restock")
	vendor.free()


func test_buyback_returns_the_same_unique_item() -> void:
	var db := make_db()
	var vendor := make_vendor(db)
	var bag := make_bag(db, 6, 0)
	bag.add(&"sword", 1, false, {"durability": 37})
	var slot := bag.find_slots(&"sword")[0]
	var uid := bag.get_stack(slot).uid
	assert_true(vendor.sell(bag, slot).ok)
	assert_eq(bag.count(&"gold"), 40)
	assert_eq(vendor.get_buyback().size(), 1)
	var result := vendor.buy_back(0, bag)
	assert_true(result.ok, str(result))
	var back := bag.get_stack(bag.find_slots(&"sword")[0])
	assert_eq(back.uid, uid, "same copy")
	assert_eq(back.data.get("durability"), 37)
	assert_eq(bag.count(&"gold"), 0, "bought back for what the player got")
	assert_true(vendor.get_buyback().is_empty())
	vendor.free()


func test_buyback_size_and_restock_clear() -> void:
	var db := make_db()
	var shop := make_shop()
	shop.buyback_size = 2
	var vendor := make_vendor(db, shop)
	var bag := make_bag(db, 6, 0)
	bag.add(&"wood", 20)
	for i in 3:
		assert_true(vendor.sell(bag, bag.find_slots(&"wood")[0], 1).ok)
	assert_eq(vendor.get_buyback().size(), 2)
	vendor.restock()
	assert_true(vendor.get_buyback().is_empty())
	vendor.free()


func test_restock_refills() -> void:
	var db := make_db()
	var shop := make_shop()
	shop.entries[1].restock_amount = 1
	var vendor := make_vendor(db, shop)
	var bag := make_bag(db, 6, 500)
	assert_true(vendor.buy(1, 3, bag).ok)
	assert_true(vendor.buy(2, 1, bag).ok)
	vendor.restock()
	assert_eq(vendor.get_offer(1).stock, 1, "potions: +1 per restock")
	assert_eq(vendor.get_offer(2).stock, 1, "sword: refilled")
	vendor.restock()
	vendor.restock()
	vendor.restock()
	assert_eq(vendor.get_offer(1).stock, 3, "never above max")
	assert_eq(vendor.day, 4)
	vendor.free()


func test_modifiers() -> void:
	var db := make_db()
	var vendor := make_vendor(db)
	vendor.buy_modifier = 0.5
	assert_eq(vendor.get_offer(1).unit_price, 10)
	assert_eq(vendor.get_offer(2).unit_price, 60, "fixed price lines are discounted too")
	assert_true(vendor.sell_price(&"potion") < vendor.buy_price(&"potion"))
	vendor.free()


func test_random_wares_are_reproducible() -> void:
	var db := make_db()
	var shop := make_shop()
	shop.random_wares = SKLootTable.new()
	shop.random_wares.entries = [SKLootEntry.make(&"wood", 1, 2, 5), SKLootEntry.make(&"potion", 1, 1, 2), SKLootEntry.make(&"sword", 1)]
	shop.random_ware_count = 2
	var a := make_vendor(db, shop)
	var b := make_vendor(db, shop)
	assert_eq(a.get_offers().size(), 5)
	assert_eq(_lines(a), _lines(b), "same seed, same wares")
	a.restock()
	b.restock()
	assert_eq(_lines(a), _lines(b))
	assert_eq(a.get_offers().size(), 5, "random wares replaced, not piled up")
	a.free()
	b.free()


func test_save_and_load() -> void:
	var db := make_db()
	var vendor := make_vendor(db)
	var bag := make_bag(db, 6, 500)
	vendor.buy(1, 2, bag)
	bag.add(&"sword", 1, false, {"durability": 5})
	vendor.sell(bag, bag.find_slots(&"sword")[0])
	vendor.restock()
	vendor.sell(bag, bag.find_slots(&"potion")[0], 1)
	var data: Dictionary = JSON.parse_string(JSON.stringify(vendor.to_data()))  # through a real save file format
	var copy := make_vendor(db)
	assert_true(copy.load_data(data))
	assert_eq(_lines(copy), _lines(vendor))
	assert_eq(copy.day, 1)
	assert_eq(copy.get_buyback().size(), 1)
	assert_eq(copy.get_buyback()[0].stack.item_id, &"potion")
	assert_false(copy.load_data({"nope": true}), "unreadable data is refused")
	assert_eq(_lines(copy), _lines(vendor), "and the state is kept")
	vendor.free()
	copy.free()


func test_trading_never_creates_gold() -> void:
	# Buy and sell at random for a while: the gold the player holds plus the
	# vendor's takings always add up, and nothing is ever free.
	var db := make_db()
	var shop := make_shop()
	shop.buyback_size = 4
	var vendor := make_vendor(db, shop)
	var bag := make_bag(db, 8, 300)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var vendor_gold := 0
	for step in 400:
		var before := bag.count(&"gold")
		var result: SKResult
		match rng.randi_range(0, 3):
			0, 1:
				result = vendor.buy(rng.randi_range(0, 2), rng.randi_range(1, 3), bag)
				if result.ok:
					vendor_gold += result.price
					assert_eq(bag.count(&"gold"), before - result.price)
			2:
				var slot := rng.randi_range(0, 7)
				result = vendor.sell(bag, slot, rng.randi_range(1, 4)) if not bag.is_slot_empty(slot) else null
				if result != null and result.ok:
					vendor_gold -= result.price
					assert_eq(bag.count(&"gold"), before + result.price)
			3:
				if not vendor.get_buyback().is_empty():
					result = vendor.buy_back(0, bag)
					if result.ok:
						vendor_gold += result.price
		if step % 50 == 49:
			vendor.restock()
		assert_eq(bag.count(&"gold") + vendor_gold, 300, "step %d" % step)
	assert_true(vendor_gold >= 0, "the player can never make money out of nothing")
	vendor.free()


func _lines(vendor: SKVendor) -> Array:
	var lines := []
	for offer in vendor.get_offers():
		lines.append([offer.item_id, offer.stock, offer.unit_price, offer.random])
	return lines
