extends Node2D
## Walk-up merchants: shops wired to NPCs with SKShopkeeper2D. Walk to a merchant
## (arrows / WASD / d-pad), press F or gamepad Y to trade, Escape / B or walk away to close.
## Both merchants share one shop screen (the window plus the player's bag).

const ART := "res://addons/inventory_kit/art/"
const SHOPS := preload("res://demo/shop/demo_shops.gd")
const MARKET_DEMO := "res://demo/shop/shop_demo.tscn"
const SPEED := 240.0


class Walker extends CharacterBody2D:
	var frozen: Callable  # () -> bool: true while a shop is open

	func _ready() -> void:
		add_to_group(&"player")
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 16.0
		shape.shape = circle
		add_child(shape)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 16.0, Color(0.35, 0.7, 1.0))
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color.WHITE, 2.0)

	func _physics_process(_delta: float) -> void:
		if frozen.is_valid() and frozen.call():
			velocity = Vector2.ZERO
			return
		var direction := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
		if direction == Vector2.ZERO:
			direction = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
				float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
		velocity = direction * SPEED
		move_and_slide()


class Npc extends Node2D:
	var color := Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 70.0, Color(color, 0.12))
		draw_arc(Vector2.ZERO, 70.0, 0.0, TAU, 48, Color(color, 0.5), 2.0)
		draw_circle(Vector2.ZERO, 20.0, color)


var player: Walker
var bag: IKInventory
var screen: IKInventoryUI
var window: SKShopWindow
var shopkeepers: Array[SKShopkeeper2D] = []
var _status: Label


func _ready() -> void:
	var database: IKItemDatabase = _database()
	var background := ColorRect.new()
	background.color = Color(0.13, 0.16, 0.12)
	background.size = Vector2(1280, 720)
	add_child(background)

	player = Walker.new()
	player.name = "Player"
	player.position = Vector2(640, 520)
	player.frozen = func() -> bool: return screen != null and screen.visible
	add_child(player)

	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)
	_build_screen(ui_layer, database)
	var hud := VBoxContainer.new()
	hud.position = Vector2(16, 12)
	ui_layer.add_child(hud)
	var help := Label.new()
	help.text = "Walk: arrows / WASD / d-pad  ·  Trade: F or gamepad Y near a merchant  ·  Close: Escape / B or walk away"
	hud.add_child(help)
	_status = Label.new()
	_status.modulate = Color(0.7, 1, 0.7)
	hud.add_child(_status)
	var back := Button.new()
	back.text = "Back to the market demo"
	back.focus_mode = Control.FOCUS_NONE
	back.position = Vector2(1040, 12)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MARKET_DEMO))
	ui_layer.add_child(back)

	var seed := 1
	for setup in [[SHOPS.blacksmith(), Vector2(330, 300), Color(1.0, 0.6, 0.3)],
			[SHOPS.hunter(), Vector2(950, 300), Color(0.5, 0.9, 0.5)]]:
		var vendor := SKVendor.new()
		vendor.name = String((setup[0] as SKShop).shop_id).capitalize()
		vendor.shop = setup[0]
		vendor.database = database
		vendor.rng_seed = seed
		seed += 1
		add_child(vendor)
		shopkeepers.append(_add_npc(vendor, setup[1], setup[2]))


static func _database() -> IKItemDatabase:
	for da in ["painted", "realistic", "cartoon", "flat"]:
		var path := ART + "%s/%s_items.tres" % [da, da]
		if ResourceLoader.exists(path):
			return load(path)
	return IKItemDatabase.new()


func _build_screen(parent: Node, database: IKItemDatabase) -> void:
	screen = IKInventoryUI.new()
	screen.name = "ShopScreen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for da in ["painted", "realistic", "cartoon", "flat"]:
		if ResourceLoader.exists(ART + "%s/%s_skin.tres" % [da, da]):
			screen.skin = load(ART + "%s/%s_skin.tres" % [da, da])
			screen.theme = load(ART + "%s/%s_theme.tres" % [da, da])
			break
	screen.visible = false
	parent.add_child(screen)
	bag = IKInventory.new()
	bag.name = "Bag"
	bag.container_id = &"bag"
	bag.size = 18
	bag.database = database
	bag.initial_items.assign({&"gold_coins": 300, &"bone": 12, &"rawhide": 6, &"ruby": 2, &"iron_ore": 8})
	screen.add_child(bag)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	center.add_child(row)
	var bag_frame := PanelContainer.new()
	row.add_child(bag_frame)
	var bag_box := VBoxContainer.new()
	bag_frame.add_child(bag_box)
	var bag_label := Label.new()
	bag_label.text = "Your bag"
	bag_box.add_child(bag_label)
	var bag_view := IKContainerView.new()
	bag_view.columns = 3
	bag_view.inventory = bag
	bag_box.add_child(bag_view)
	window = SKShopWindow.new()
	window.name = "ShopWindow"
	window.columns = 4
	window.item_size = Vector2(60, 60)
	window.custom_minimum_size = Vector2(700, 460)
	window.skin = screen.skin
	row.add_child(window)
	window.bag = bag.container
	window.traded.connect(func(result: SKResult) -> void: _status.text = "")


func _add_npc(vendor: SKVendor, at: Vector2, color: Color) -> SKShopkeeper2D:
	var npc := Npc.new()
	npc.name = vendor.name + "Npc"
	npc.position = at
	npc.color = color
	add_child(npc)
	var label := Label.new()
	label.text = vendor.shop.display_name
	label.position = Vector2(-80, -64)
	npc.add_child(label)
	var prompt := Label.new()
	prompt.text = "F / Y: trade"
	prompt.position = Vector2(-40, 30)
	npc.add_child(prompt)
	var area := SKShopkeeper2D.new()
	area.name = "Shopkeeper"
	area.vendor = vendor
	area.window = window
	area.screen = screen
	area.prompt = prompt
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 70.0
	shape.shape = circle
	area.add_child(shape)
	npc.add_child(area)
	area.shop_opened.connect(func() -> void: _status.text = "Trading with %s." % vendor.shop.display_name)
	area.shop_closed.connect(func() -> void: _status.text = "See you, traveller.")
	return area
