extends "res://tests/shop_kit/sk_test_case.gd"
## Reputation per vendor: levels change prices, unlock wares, grow with spending, are saved.


## Stranger from 0, Regular from 10 (-10 % / +25 %), Hated from -100 (+50 % / -50 %).
func _shop() -> SKShop:
	var shop := make_shop()
	shop.reputation_tiers = [
		SKReputationTier.make(10, "Regular", 0.9, 1.25),
		SKReputationTier.make(-100, "Hated", 1.5, 0.5),
		SKReputationTier.make(0, "Stranger"),
	]
	return shop


func test_vendor_without_levels_is_unchanged() -> void:
	var db := make_db()
	var vendor := make_vendor(db)
	assert_eq(vendor.get_reputation(), 0)
	assert_eq(vendor.get_reputation_tier(), null)
	assert_eq(vendor.get_buy_modifier(), 1.0)
	assert_eq(vendor.buy_price(&"potion"), 20)
	vendor.add_reputation(50)
	assert_eq(vendor.buy_price(&"potion"), 20, "no levels: reputation changes no price")
	vendor.free()


func test_levels_change_buy_and_sell_prices() -> void:
	var db := make_db()
	var vendor := make_vendor(db, _shop())
	assert_eq(vendor.get_reputation_tier().display_name, "Stranger")
	assert_eq(vendor.buy_price(&"potion"), 20)
	assert_eq(vendor.sell_price(&"potion"), 8)
	vendor.set_reputation(12)
	assert_eq(vendor.get_reputation_tier().display_name, "Regular")
	assert_eq(vendor.buy_price(&"potion"), 18)
	assert_eq(vendor.sell_price(&"potion"), 10)
	assert_eq(vendor.get_offer(1).unit_price, 18, "offers follow")
	assert_eq(vendor.get_offer(2).unit_price, 108, "fixed prices too (120 x 0.9)")
	vendor.set_reputation(-50)
	assert_eq(vendor.get_reputation_tier().display_name, "Hated")
	assert_eq(vendor.buy_price(&"potion"), 30)
	assert_eq(vendor.sell_price(&"potion"), 4)
	vendor.free()


func test_selling_never_pays_more_than_buying_at_any_level() -> void:
	var db := make_db()
	var shop := make_shop()
	shop.reputation_tiers = [SKReputationTier.make(0, "Best friend", 0.1, 10.0)]
	var vendor := make_vendor(db, shop)
	assert_eq(vendor.buy_price(&"potion"), 2)
	assert_true(vendor.sell_price(&"potion") < vendor.buy_price(&"potion"))
	vendor.free()


func test_locked_wares_unlock_with_reputation() -> void:
	var db := make_db()
	var shop := _shop()
	shop.entries[2].min_reputation = 10  # the sword
	var vendor := make_vendor(db, shop)
	var bag := make_bag(db, 6, 500)
	assert_true(vendor.is_locked(2))
	assert_true(vendor.get_offer(2).locked)
	assert_false(vendor.get_offer(0).locked, "lines without a requirement are always open")
	var result := vendor.buy(2, 1, bag)
	assert_shop(result, SKResult.Code.LOCKED)
	assert_eq(SKText.result_message(result), "This merchant doesn't trust you enough yet.")
	assert_eq(bag.count(&"gold"), 500)
	vendor.add_reputation(10)
	assert_false(vendor.is_locked(2))
	assert_true(vendor.buy(2, 1, bag).ok)
	vendor.set_reputation(-20)
	assert_false(vendor.get_offer(0).locked, "even when hated, unrestricted lines stay open")
	vendor.free()


func test_spending_raises_reputation() -> void:
	var db := make_db()
	var shop := _shop()
	shop.currency_per_reputation = 20
	shop.buyback_size = 4
	var vendor := make_vendor(db, shop)
	var bag := make_bag(db, 6, 500)
	var events := []
	vendor.reputation_changed.connect(func(value: int, tier: SKReputationTier) -> void:
		events.append([value, tier.display_name if tier != null else ""]))
	assert_true(vendor.buy(1, 3, bag).ok)  # 60 gold
	assert_eq(vendor.get_reputation(), 3)
	assert_true(vendor.buy(0, 3, bag).ok)  # 15 gold: not enough for a point yet
	assert_eq(vendor.get_reputation(), 3)
	assert_true(vendor.buy(0, 1, bag).ok)  # 5 more: 20
	assert_eq(vendor.get_reputation(), 4)
	var slot := bag.find_slots(&"wood")[0]
	assert_true(vendor.sell(bag, slot, 2).ok)
	assert_true(vendor.buy_back(0, bag).ok)
	assert_eq(vendor.get_reputation(), 4, "selling and buying back never earn reputation")
	assert_eq(events, [[3, "Stranger"], [4, "Stranger"]])
	vendor.free()


func test_reputation_is_clamped_and_signals_only_changes() -> void:
	var db := make_db()
	var shop := _shop()
	shop.min_reputation = -10
	shop.max_reputation = 20
	var vendor := make_vendor(db, shop)
	var count := [0]
	vendor.reputation_changed.connect(func(_v: int, _t: SKReputationTier) -> void: count[0] += 1)
	assert_eq(vendor.add_reputation(100), 20)
	assert_eq(vendor.add_reputation(5), 20)
	assert_eq(vendor.add_reputation(-500), -10)
	vendor.set_reputation(-10)
	assert_eq(count[0], 2, "no signal when nothing changes")
	vendor.free()


func test_reputation_is_saved_and_survives_restocks() -> void:
	var db := make_db()
	var shop := _shop()
	shop.currency_per_reputation = 50
	var vendor := make_vendor(db, shop)
	var bag := make_bag(db, 6, 500)
	vendor.add_reputation(11)
	vendor.buy(1, 2, bag)  # 40 gold at Regular prices (36): progress 36
	vendor.restock()
	assert_eq(vendor.get_reputation(), 11, "a new day keeps the reputation")
	var data: Dictionary = JSON.parse_string(JSON.stringify(vendor.to_data()))
	assert_eq(int(data.reputation), 11)
	assert_eq(int(data.rep_progress), 36)
	var copy := make_vendor(db, _shop())
	copy.shop.currency_per_reputation = 50
	assert_true(copy.load_data(data))
	assert_eq(copy.get_reputation(), 11)
	assert_eq(copy.get_reputation_tier().display_name, "Regular")
	copy.buy(1, 1, bag)  # 18 more: 54
	assert_eq(copy.get_reputation(), 12, "the progress was saved too")
	vendor.open()
	assert_eq(vendor.get_reputation(), 0, "open() starts over from the shop")
	vendor.free()
	copy.free()


func test_loading_bad_or_missing_reputation() -> void:
	var db := make_db()
	var shop := _shop()
	shop.start_reputation = 5
	shop.max_reputation = 50
	var vendor := make_vendor(db, shop)
	assert_eq(vendor.get_reputation(), 5, "start value")
	var data := vendor.to_data()
	data.erase("reputation")
	data.erase("rep_progress")
	vendor.set_reputation(30)
	assert_true(vendor.load_data(data))
	assert_eq(vendor.get_reputation(), 5, "old saves: the shop's start value")
	data["reputation"] = 9999
	assert_true(vendor.load_data(data))
	assert_eq(vendor.get_reputation(), 50, "clamped")
	vendor.free()


func test_tier_lookup_ignores_order() -> void:
	var shop := _shop()
	assert_eq(shop.tier_for(-5).display_name, "Hated")
	assert_eq(shop.tier_for(0).display_name, "Stranger")
	assert_eq(shop.tier_for(99).display_name, "Regular")
	assert_eq(shop.tier_for(-500), null)
	assert_eq(shop.next_tier_for(3).display_name, "Regular")
	assert_eq(shop.next_tier_for(10), null)


func test_window_shows_reputation_and_locked_wares() -> void:
	var db := make_db()
	var shop := _shop()
	shop.entries[2].min_reputation = 10
	var vendor: SKVendor = add_to_tree(make_vendor(db, shop))
	var window := SKShopWindow.new()
	window.vendor = vendor
	window.bag = make_bag(db, 6, 500)
	add_to_tree(window)
	await wait_frames(2)
	assert_true(window._reputation.visible)
	assert_eq(window._reputation.text, "Stranger (0)")
	var entries := window._entries()
	assert_eq(entries.size(), 3)
	assert_eq(entries[2].amount_text, "Locked")
	assert_true(entries[2].dimmed)
	window._select(2)
	assert_true(window._action.disabled)
	assert_true(window._detail_text.text.contains("Needs Reputation 10 (Regular)"), window._detail_text.text)
	shop.show_locked_wares = false
	assert_eq(window._entries().size(), 2, "hidden when show_locked_wares is off")
	vendor.add_reputation(10)
	await wait_frames(2)
	assert_eq(window._reputation.text, "Regular (10)")
	assert_eq(window._entries().size(), 3)


func test_window_hides_reputation_for_plain_vendors() -> void:
	var db := make_db()
	var vendor: SKVendor = add_to_tree(make_vendor(db))
	var window := SKShopWindow.new()
	window.vendor = vendor
	add_to_tree(window)
	await wait_frames(1)
	assert_false(window._reputation.visible)
