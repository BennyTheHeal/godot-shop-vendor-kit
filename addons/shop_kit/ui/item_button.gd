class_name SKItemButton
extends Button
## One item in the shop window: icon, amount (or stock) and price, styled with the
## Inventory Kit skin so it matches the inventory. Focusable: works with a gamepad.

var item_id: StringName
var _amount_label := Label.new()
var _price_label := Label.new()
var _skin: IKSkin


func _init() -> void:
	focus_mode = FOCUS_ALL
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clip_contents = true
	for label in [_amount_label, _price_label]:
		label.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(label)
	_amount_label.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_amount_label.grow_horizontal = GROW_DIRECTION_BEGIN
	_amount_label.grow_vertical = GROW_DIRECTION_BEGIN
	_price_label.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)


func setup(definition: IKItemDefinition, amount_text: String, price_text: String, skin: IKSkin, size_px: Vector2) -> void:
	item_id = definition.id if definition != null else &""
	icon = definition.icon if definition != null else null
	tooltip_text = IKText.item_name(definition)
	custom_minimum_size = size_px
	_skin = skin
	_amount_label.text = amount_text
	_price_label.text = price_text
	if skin != null:
		skin.apply_amount_label(_amount_label)
		skin.apply_amount_label(_price_label)
		_price_label.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.35))
		add_theme_stylebox_override(&"normal", skin.get_slot_style(IKSlotView.State.NORMAL))
		add_theme_stylebox_override(&"hover", skin.get_slot_style(IKSlotView.State.HOVER))
		add_theme_stylebox_override(&"pressed", skin.get_slot_style(IKSlotView.State.MARKED))
		add_theme_stylebox_override(&"focus", skin.get_slot_style(IKSlotView.State.FOCUS))
		add_theme_stylebox_override(&"disabled", skin.get_slot_style(IKSlotView.State.REJECTED))
		add_theme_constant_override(&"icon_max_width", int(size_px.x - skin.icon_margin * 2))
	_amount_label.offset_right = -4
	_amount_label.offset_bottom = -1
	_price_label.offset_left = 4
	_price_label.offset_top = 1


func set_selected(selected: bool) -> void:
	if _skin == null:
		return
	var state := IKSlotView.State.MARKED if selected else IKSlotView.State.NORMAL
	add_theme_stylebox_override(&"normal", _skin.get_slot_style(state))
