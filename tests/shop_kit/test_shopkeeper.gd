extends "res://tests/shop_kit/sk_test_case.gd"
## SKShopkeeper2D: a shop on an NPC (interaction zone, open, close), and the demos.

var db: IKItemDatabase
var window: SKShopWindow
var player: CharacterBody2D


func _npc(vendor: SKVendor = null) -> SKShopkeeper2D:
	if db == null:
		db = make_db()
	if window == null:
		window = SKShopWindow.new()
		window.bag = make_bag(db, 6, 100)
		window.visible = false
		add_to_tree(window)
	if player == null:
		player = CharacterBody2D.new()
		player.add_to_group(&"player")
		add_to_tree(player)
	var keeper := SKShopkeeper2D.new()
	keeper.vendor = vendor if vendor != null else make_vendor(db)
	keeper.add_child(keeper.vendor)
	keeper.window = window
	var prompt := Label.new()
	keeper.add_child(prompt)
	keeper.prompt = prompt
	add_to_tree(keeper)
	return keeper


func _interact(keeper: SKShopkeeper2D) -> void:
	var event := InputEventAction.new()
	event.action = SKShopkeeper2D.INTERACT
	event.pressed = true
	keeper._unhandled_input(event)


func test_interact_action_is_registered() -> void:
	SKShopkeeper2D.ensure_actions()
	assert_true(InputMap.has_action(SKShopkeeper2D.INTERACT))
	assert_true(InputMap.action_get_events(SKShopkeeper2D.INTERACT).size() >= 2, "key and gamepad")


func test_only_the_player_counts() -> void:
	var keeper := _npc()
	var stranger := CharacterBody2D.new()
	add_to_tree(stranger)
	keeper._on_body_entered(stranger)
	assert_false(keeper.is_player_near())
	assert_false(keeper.prompt.visible)
	var entered := []
	keeper.player_entered.connect(func(body: Node2D) -> void: entered.append(body))
	keeper._on_body_entered(player)
	assert_true(keeper.is_player_near())
	assert_true(keeper.prompt.visible, "prompt shown")
	assert_eq(entered, [player])


func test_interact_opens_and_walking_away_closes() -> void:
	var keeper := _npc()
	var events := []
	keeper.shop_opened.connect(func() -> void: events.append("open"))
	keeper.shop_closed.connect(func() -> void: events.append("close"))
	_interact(keeper)
	assert_false(window.visible, "nothing happens far from the NPC")
	keeper._on_body_entered(player)
	_interact(keeper)
	assert_true(window.visible)
	assert_true(keeper.is_open())
	assert_eq(window.vendor, keeper.vendor)
	assert_eq(window.current_tab, SKShopWindow.Tab.BUY)
	assert_false(keeper.prompt.visible, "prompt hidden while trading")
	keeper._on_body_exited(player)
	assert_false(window.visible)
	assert_eq(events, ["open", "close"])


func test_cancel_closes_and_the_prompt_comes_back() -> void:
	var keeper := _npc()
	keeper._on_body_entered(player)
	assert_true(keeper.open_shop())
	window.close_requested.emit()
	assert_false(keeper.is_open())
	assert_true(keeper.prompt.visible, "still next to the NPC")


func test_options_open_on_enter_and_stay_open() -> void:
	var keeper := _npc()
	keeper.open_on_enter = true
	keeper.close_on_exit = false
	keeper._on_body_entered(player)
	assert_true(keeper.is_open())
	keeper._on_body_exited(player)
	assert_true(keeper.is_open(), "close_on_exit off")
	keeper.close_shop()
	assert_false(window.visible)


func test_two_npcs_share_one_window() -> void:
	var first := _npc()
	var second := _npc()
	first._on_body_entered(player)
	first.open_shop()
	second._on_body_entered(player)
	second.open_shop()
	assert_eq(window.vendor, second.vendor)
	assert_false(first.is_open(), "the window now shows the other vendor")
	first._on_body_exited(player)
	assert_true(window.visible, "leaving the first NPC does not close the second shop")
	window.close_requested.emit()
	assert_false(window.visible)


func test_screen_is_shown_instead_of_the_window() -> void:
	var keeper := _npc()
	var screen := Control.new()
	screen.visible = false
	add_to_tree(screen)
	keeper.screen = screen
	keeper._on_body_entered(player)
	keeper.open_shop()
	assert_true(screen.visible)
	assert_true(keeper.is_open())
	keeper.close_shop()
	assert_false(screen.visible)


func test_missing_vendor_does_not_open() -> void:
	var keeper := _npc()
	keeper.vendor = null
	keeper._on_body_entered(player)
	assert_false(keeper.open_shop())
	assert_false(window.visible)


func test_npc_demo_runs() -> void:
	var demo: Node = add_to_tree(load("res://demo/shop/npc_demo.tscn").instantiate())
	await wait_frames(3)
	assert_eq(demo.shopkeepers.size(), 2)
	var keeper: SKShopkeeper2D = demo.shopkeepers[1]
	keeper._on_body_entered(demo.player)
	_interact(keeper)
	assert_true(demo.screen.visible, "the shop screen opens")
	assert_eq(demo.window.vendor.shop.shop_id, &"hunter")
	var bag: IKContainer = demo.bag.container
	var arrows_line := -1
	for offer in demo.window.vendor.get_offers():
		if offer.item_id == &"arrows":
			arrows_line = offer.index
	var bones := bag.count(&"bone")
	assert_true(demo.window.vendor.buy(arrows_line, 4, bag).ok, "arrows for bones")
	assert_eq(bag.count(&"bone"), bones - 4)
	demo.window.close_requested.emit()
	assert_false(demo.screen.visible)


func test_market_demo_has_the_hunter() -> void:
	var demo: Node = add_to_tree(load("res://demo/shop/shop_demo.tscn").instantiate())
	await wait_frames(3)
	assert_eq(demo.vendors.size(), 4)
	var hunter: SKVendor = demo.vendors[3]
	var bag: IKContainer = demo.bag.container
	assert_eq(hunter.get_offer(0).unit_costs, {&"gold_coins": 60, &"ruby": 1})
	var gold := bag.count(&"gold_coins")
	assert_true(hunter.buy(0, 1, bag).ok, "a bow for gold and a ruby")
	assert_eq(bag.count(&"ruby"), 0)
	assert_eq(bag.count(&"gold_coins"), gold - 60)
	assert_eq(hunter.get_reputation(), 6, "+1 per 10 gold")
	assert_true(hunter.get_offers().any(func(offer: SKOffer) -> bool: return offer.locked))
