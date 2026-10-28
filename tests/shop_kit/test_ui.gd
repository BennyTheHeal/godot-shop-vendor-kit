extends "res://tests/shop_kit/sk_test_case.gd"
## The shop window and the demo scene: build, trade through the UI, tabs, save / load.


func _window() -> Dictionary:
	var db := make_db()
	var vendor: SKVendor = add_to_tree(make_vendor(db))
	var bag := make_bag(db, 6, 100)
	var window := SKShopWindow.new()
	window.vendor = vendor
	window.bag = bag
	add_to_tree(window)
	return {"window": window, "vendor": vendor, "bag": bag}


func test_window_lists_the_wares() -> void:
	var w := _window()
	await wait_frames(2)
	var window: SKShopWindow = w.window
	assert_eq(window._entries().size(), 3)
	assert_eq(window._grid.get_child_count(), 3)


func test_buy_through_the_window() -> void:
	var w := _window()
	await wait_frames(2)
	var window: SKShopWindow = w.window
	var traded := []
	window.traded.connect(func(result: SKResult) -> void: traded.append(result.item_id))
	window._select(1)
	window._amount.value = 2
	window._on_action()
	await wait_frames(2)
	assert_eq(w.bag.count(&"potion"), 2)
	assert_eq(traded, [&"potion"])
	assert_true(window._money.text.begins_with("60"), window._money.text)


func test_refusal_is_reported() -> void:
	var w := _window()
	await wait_frames(2)
	var window: SKShopWindow = w.window
	var texts := []
	window.refused.connect(func(_result: SKResult, text: String) -> void: texts.append(text))
	window._select(2)  # the sword costs 120, the bag holds 100
	window._on_action()
	assert_eq(texts, ["Not enough money."])


func test_sell_and_buyback_tabs() -> void:
	var w := _window()
	var bag: IKContainer = w.bag
	bag.add(&"wood", 5)
	await wait_frames(2)
	var window: SKShopWindow = w.window
	window.show_tab(SKShopWindow.Tab.SELL)
	await wait_frames(1)
	assert_eq(window._entries().size(), 1, "gold is not listed for sale")
	window._select(bag.find_slots(&"wood")[0])
	window._amount.value = 5
	window._on_action()
	await wait_frames(2)
	assert_eq(bag.count(&"wood"), 0)
	window.show_tab(SKShopWindow.Tab.BUYBACK)
	await wait_frames(1)
	assert_eq(window._entries().size(), 1)
	window._on_action()
	await wait_frames(2)
	assert_eq(bag.count(&"wood"), 5)


func test_tab_shortcuts() -> void:
	var w := _window()
	await wait_frames(2)
	var window: SKShopWindow = w.window
	assert_true(InputMap.has_action(SKShopWindow.TAB_NEXT))
	var event := InputEventAction.new()
	event.action = SKShopWindow.TAB_NEXT
	event.pressed = true
	window._unhandled_input(event)
	assert_eq(window.current_tab, SKShopWindow.Tab.SELL)
	event.action = SKShopWindow.TAB_PREVIOUS
	window._unhandled_input(event)
	window._unhandled_input(event)
	assert_eq(window.current_tab, SKShopWindow.Tab.BUYBACK, "wraps around")


func test_demo_runs_in_every_art_direction() -> void:
	var demo: Node = add_to_tree(load("res://demo/shop/shop_demo.tscn").instantiate())
	await wait_frames(3)
	for da in demo.available_directions():
		demo.apply_art_direction(da)
		for i in demo.vendors.size():
			demo.open_vendor(i)
			await wait_frames(1)
			assert_true(demo.shop_window._grid.get_child_count() > 0, "%s vendor %d has wares" % [da, i])
	var bag: IKContainer = demo.bag.container
	var gold := bag.count(&"gold_coins")
	demo.open_vendor(1)
	assert_true(demo.vendors[1].buy(0, 1, bag).ok)
	assert_true(bag.count(&"gold_coins") < gold)
	demo.next_day()
	demo._on_save()
	var stock: int = demo.vendors[1].get_offer(0).stock
	demo.vendors[1].buy(0, 1, bag)
	demo._on_load()
	assert_eq(demo.vendors[1].get_offer(0).stock, stock, "vendor stock restored by Load")
