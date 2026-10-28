extends IKInventoryUI
## Shop & Vendor Kit demo: a small market with three vendors (fixed and random wares,
## different prices, funds and tastes), the player's bag and equipment (Inventory Kit),
## "Next day" restocks, save / load, and a live art direction picker.

const ART := "res://addons/inventory_kit/art/"
const DIRECTIONS := {"painted": "Hand-painted", "realistic": "Realistic", "cartoon": "Cartoon", "flat": "Flat"}
const SHOPS := preload("res://demo/shop/demo_shops.gd")
const SAVE_DIR := "user://shop_demo/"
const SITE := "https://banc-essai.site-testeurs.workers.dev/?src=shop-demo"
const NPC_DEMO := "res://demo/shop/npc_demo.tscn"
const EQUIPMENT_SLOTS: Array[StringName] = [&"head", &"body", &"hands", &"feet", &"weapon", &"offhand"]

var bag: IKInventory
var equipment: IKEquipment
var vendors: Array[SKVendor] = []
var shop_window: SKShopWindow
var art_direction := ""
var _picker: OptionButton
var _vendor_buttons: Array[Button] = []
var _day: Label
var _status: Label
var _save := IKSaveFile.new(SAVE_DIR + "inventory.json")


static func available_directions() -> Array[String]:
	var result: Array[String] = []
	for da in DIRECTIONS:
		if ResourceLoader.exists(ART + "%s/%s_items.tres" % [da, da]):
			result.append(da)
	return result


func _ready() -> void:
	var directions := available_directions()
	var database: IKItemDatabase = load(ART + "%s/%s_items.tres" % [directions[0], directions[0]])
	bag = IKInventory.new()
	_setup(bag, &"bag", 18, database, {&"gold_coins": 250, &"wood_log": 12, &"iron_ore": 6, &"ruby": 1,
		&"sword": 1, &"cloth_chest": 1, &"health_potion": 1, &"apple": 3, &"key": 1, &"bone": 8, &"rawhide": 4})
	equipment = IKEquipment.new()
	equipment.slot_types = EQUIPMENT_SLOTS
	_setup(equipment, &"equipment", 0, database, {&"cloth_helmet": 1, &"dagger": 1, &"boots": 1})
	var seed := 1
	for shop in [SHOPS.blacksmith(), SHOPS.alchemist(), SHOPS.trader(), SHOPS.hunter()]:
		var vendor := SKVendor.new()
		vendor.name = String(shop.shop_id).capitalize()
		vendor.shop = shop
		vendor.database = database
		vendor.rng_seed = seed
		seed += 1
		add_child(vendor)
		vendors.append(vendor)
	_build_layout(directions)
	super._ready()
	shop_window.bag = bag.container
	shop_window.equipment = equipment.container
	shop_window.traded.connect(func(result: SKResult) -> void: _set_status(""))
	for vendor in vendors:
		vendor.reputation_changed.connect(func(reputation: int, tier: SKReputationTier) -> void:
			_set_status("%s: reputation %d%s." % [vendor.shop.display_name, reputation,
				" (%s)" % tier.display_name if tier != null else ""]))
	interaction_failed.connect(func(result: IKResult) -> void: _set_status(IKText.result_message(result), true))
	apply_art_direction(directions[0])
	open_vendor(0)


## Icons, slot skin and window theme change; item ids, prices and stock do not.
func apply_art_direction(da: String) -> void:
	art_direction = da
	var database: IKItemDatabase = load(ART + "%s/%s_items.tres" % [da, da])
	for node: IKInventory in [bag, equipment]:
		node.container.database = database
	cursor.container.database = database
	for vendor in vendors:
		vendor.database = database
	theme = load(ART + "%s/%s_theme.tres" % [da, da])
	skin = load(ART + "%s/%s_skin.tres" % [da, da])
	shop_window.skin = skin
	_refresh_vendor_buttons()
	var index := available_directions().find(da)
	if _picker != null and index >= 0 and _picker.selected != index:
		_picker.select(index)


func open_vendor(index: int) -> void:
	shop_window.vendor = vendors[index]
	shop_window.show_tab(SKShopWindow.Tab.BUY)
	for i in _vendor_buttons.size():
		_vendor_buttons[i].button_pressed = i == index


func next_day() -> void:
	for vendor in vendors:
		vendor.restock()
	_day.text = "Day %d" % (vendors[0].day + 1)
	_set_status("A new day: the vendors restocked, random wares changed, buyback was cleared.")


func _setup(node: IKInventory, id: StringName, slots: int, database: IKItemDatabase, items: Dictionary) -> void:
	node.name = String(id).capitalize()
	node.container_id = id
	if not node is IKEquipment:
		node.size = slots
	node.database = database
	node.initial_items.assign(items)
	add_child(node)


func _build_layout(directions: Array[String]) -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.10)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 12)
	column.add_child(header)
	var title := Label.new()
	title.text = "Shop & Vendor Kit — free demo"
	title.add_theme_font_size_override(&"font_size", 22)
	header.add_child(title)
	_picker = OptionButton.new()
	for da in directions:
		_picker.add_item(DIRECTIONS[da])
	_picker.item_selected.connect(func(index: int) -> void: apply_art_direction(directions[index]))
	_picker.focus_mode = FOCUS_NONE
	header.add_child(_picker)
	_button(header, "Next day", next_day)
	_day = Label.new()
	_day.text = "Day 1"
	header.add_child(_day)
	_button(header, "Save", _on_save)
	_button(header, "Load", _on_load)
	if ResourceLoader.exists(NPC_DEMO):
		_button(header, "Walk-up merchants", func() -> void: get_tree().change_scene_to_file(NPC_DEMO))
	var site := LinkButton.new()
	site.text = "More free kits & our games »"
	site.uri = SITE
	site.size_flags_horizontal = SIZE_EXPAND_FILL
	site.size_flags_vertical = SIZE_SHRINK_CENTER
	header.add_child(site)

	var market := HBoxContainer.new()
	market.add_theme_constant_override(&"separation", 8)
	column.add_child(market)
	var market_label := Label.new()
	market_label.text = "Market:"
	market.add_child(market_label)
	var group := ButtonGroup.new()
	for i in vendors.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.text = vendors[i].shop.display_name
		button.custom_minimum_size = Vector2(0, 40)
		button.add_theme_constant_override(&"icon_max_width", 28)
		button.focus_mode = FOCUS_NONE
		var index := i
		button.pressed.connect(func() -> void: open_vendor(index))
		market.add_child(button)
		_vendor_buttons.append(button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 14)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 8)
	body.add_child(left)

	var bag_box := _panel(left, "Your bag (drag to equip)")
	_view(bag_box, bag, 6)
	var equipment_box := _panel(left, "Equipped: the shop compares with these")
	var equipment_view := _view(equipment_box, equipment, 6)
	var outlines: Array[Texture2D] = []
	for slot_type in EQUIPMENT_SLOTS:
		outlines.append(load(ART + "shared/silhouettes/%s.png" % slot_type))
	equipment_view.empty_icons = outlines
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(360, 0)
	_status.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_child(_status)

	shop_window = SKShopWindow.new()
	shop_window.name = "ShopWindow"
	shop_window.size_flags_horizontal = SIZE_EXPAND_FILL
	shop_window.size_flags_vertical = SIZE_EXPAND_FILL
	shop_window.columns = 5
	shop_window.item_size = Vector2(60, 60)
	shop_window.close_requested.connect(func() -> void: _set_status("Cancel in the shop: a game would close the window here."))
	body.add_child(shop_window)


func _refresh_vendor_buttons() -> void:
	var icons := [&"sword", &"health_potion", &"gold_coins", &"bow"]
	for i in _vendor_buttons.size():
		var definition := bag.container.database.get_item(icons[i])
		_vendor_buttons[i].icon = definition.icon if definition != null else null


func _panel(parent: Control, title: String) -> VBoxContainer:
	var frame := PanelContainer.new()
	parent.add_child(frame)
	var box := VBoxContainer.new()
	frame.add_child(box)
	var label := Label.new()
	label.text = title
	box.add_child(label)
	return box


func _view(parent: Control, inventory: IKInventory, columns: int) -> IKContainerView:
	var view := IKContainerView.new()
	view.name = String(inventory.container_id).capitalize() + "View"
	view.columns = columns
	view.inventory = inventory
	parent.add_child(view)
	return view


func _button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)


func _on_save() -> void:
	return_held()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var error := _save.save([bag.container, equipment.container])
	var data := {}
	for vendor in vendors:
		data[String(vendor.shop.shop_id)] = vendor.to_data()
	var file := FileAccess.open(SAVE_DIR + "vendors.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
	_set_status("Saved: bag, equipment and every vendor's stock." if error == OK and file != null
		else "Save failed: %s" % error_string(error if error != OK else FileAccess.get_open_error()), error != OK or file == null)


func _on_load() -> void:
	return_held()
	var report := _save.load_into([bag.container, equipment.container])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_DIR + "vendors.json"))
	if not report.ok or typeof(parsed) != TYPE_DICTIONARY:
		_set_status("Nothing to load yet: press Save first." if not FileAccess.file_exists(SAVE_DIR + "vendors.json") else report.error, true)
		return
	for vendor in vendors:
		var saved: Variant = parsed.get(String(vendor.shop.shop_id))
		if typeof(saved) == TYPE_DICTIONARY:
			vendor.load_data(saved)
	_day.text = "Day %d" % (vendors[0].day + 1)
	_set_status("Loaded.")


func _set_status(text: String, warning: bool = false) -> void:
	_status.text = text
	_status.modulate = Color(1, 0.6, 0.5) if warning else Color(0.7, 1, 0.7)
