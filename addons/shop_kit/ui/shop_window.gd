class_name SKShopWindow
extends PanelContainer
## A ready-to-use shop screen: Buy, Sell and Buy back tabs, item grid, details with
## comparison to the equipped item, quantity, price and the player's money.
##
## Works with the mouse, the keyboard and a gamepad (focus navigation; Q/E or LB/RB
## switch tabs). Set [member vendor] and [member bag], optionally [member wallet],
## [member equipment] and [member skin] (an Inventory Kit [IKSkin], so the shop
## matches the inventory). Restyle the rest with a Godot [Theme].

## Emitted after every refused action, with the text for the player.
signal refused(result: SKResult, text: String)
## Emitted after every successful purchase, sale or buyback.
signal traded(result: SKResult)
## The player pressed Cancel (Escape / B) in the window.
signal close_requested

enum Tab { BUY, SELL, BUYBACK }

const TAB_PREVIOUS := &"sk_previous_tab"
const TAB_NEXT := &"sk_next_tab"

@export var vendor: SKVendor:
	set(value):
		_disconnect()
		vendor = value
		_connect()
		refresh()
## The player's bag (where bought items go, and what can be sold).
var bag: IKContainer:
	set(value):
		_disconnect()
		bag = value
		_connect()
		refresh()
## Where the money is taken from and paid to. Defaults to [member bag].
var wallet: IKContainer:
	set(value):
		_disconnect()
		wallet = value
		_connect()
		refresh()
## Optional: equipped items, to compare stats in the details.
var equipment: IKContainer
@export var skin: IKSkin:
	set(value):
		skin = value
		refresh()
## Item properties listed in the details (and compared with the equipped item).
@export var shown_properties: Array[StringName] = [&"damage", &"armor", &"heal", &"mana", &"stamina", &"fire_resist", &"tier"]
@export var columns: int = 6
@export var item_size := Vector2(72, 72)

var current_tab: Tab = Tab.BUY
var _title := Label.new()
var _money := Label.new()
var _reputation := Label.new()
var _tabs: Array[Button] = []
var _grid := GridContainer.new()
var _empty := Label.new()
var _detail_icon := TextureRect.new()
var _detail_name := Label.new()
var _detail_text := RichTextLabel.new()
var _amount := SpinBox.new()
var _total := Label.new()
var _action := Button.new()
var _status := Label.new()
var _selected := -1  # offer index, bag slot or buyback index depending on the tab
var _connected: Array[Object] = []
var _fallback_skin: IKSkin
var _refresh_queued := false


func _init() -> void:
	_build()


func _ready() -> void:
	_ensure_actions()
	refresh()


func _exit_tree() -> void:
	_disconnect()


## Opens a tab and selects its first item.
func show_tab(tab: Tab) -> void:
	current_tab = tab
	_selected = -1
	refresh()
	_focus_first()


## Rebuilds the grid and the details from the vendor and the bag.
func refresh() -> void:
	if not is_node_ready() and get_child_count() == 0:
		return
	for i in _tabs.size():
		_tabs[i].button_pressed = i == current_tab
		_tabs[i].modulate = Color.WHITE if i == current_tab else Color(1, 1, 1, 0.55)
	_title.text = SKText.t(vendor.shop.display_name) if vendor != null and vendor.shop != null else ""
	_refresh_money()
	_reputation.visible = vendor != null and vendor.shop != null \
		and (not vendor.shop.reputation_tiers.is_empty() or vendor.shop.currency_per_reputation > 0)
	_reputation.text = SKText.reputation_text(vendor) if _reputation.visible else ""
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var had_focus := focused != null and _grid.is_ancestor_of(focused)
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_grid.columns = columns
	var entries := _entries()
	for entry in entries:
		var button := SKItemButton.new()
		button.setup(entry.definition, entry.amount_text, entry.price_text, _skin(), item_size)
		button.disabled = entry.dimmed
		var key: int = entry.key
		button.pressed.connect(func() -> void: _select(key))
		button.focus_entered.connect(func() -> void: _select(key, false))
		button.set_selected(key == _selected)
		_grid.add_child(button)
	_empty.visible = entries.is_empty()
	_empty.text = [SKText.t("Nothing for sale."), SKText.t("Nothing this merchant buys."), SKText.t("Nothing to buy back.")][current_tab]
	if not entries.any(func(e: Dictionary) -> bool: return e.key == _selected):
		_selected = entries[0].key if not entries.is_empty() else -1
	_refresh_details()
	if had_focus:
		_focus_first.call_deferred()


# --- Building ----------------------------------------------------------------

func _build() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_title.add_theme_font_size_override(&"font_size", 24)
	_title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(_title)
	_reputation.add_theme_color_override(&"font_color", Color(0.65, 0.85, 1.0))
	_reputation.size_flags_vertical = SIZE_SHRINK_CENTER
	header.add_child(_reputation)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(16, 0)
	header.add_child(spacer)
	_money.add_theme_font_size_override(&"font_size", 20)
	_money.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.35))
	header.add_child(_money)

	var tab_row := HBoxContainer.new()
	column.add_child(tab_row)
	var group := ButtonGroup.new()
	for label in ["Buy", "Sell", "Buy back"]:
		var tab := Button.new()
		tab.text = SKText.t(label)
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = FOCUS_NONE
		var index := _tabs.size()
		tab.pressed.connect(func() -> void: show_tab(index as Tab))
		tab_row.add_child(tab)
		_tabs.append(tab)
	var hint := Label.new()
	hint.text = SKText.t("Q / E · LB / RB")
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.size_flags_horizontal = SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tab_row.add_child(hint)

	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 14)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 260)
	body.add_child(scroll)
	var grid_box := VBoxContainer.new()
	grid_box.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(grid_box)
	_grid.add_theme_constant_override(&"h_separation", 6)
	_grid.add_theme_constant_override(&"v_separation", 6)
	grid_box.add_child(_grid)
	_empty.modulate = Color(1, 1, 1, 0.6)
	grid_box.add_child(_empty)

	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(280, 0)
	details.add_theme_constant_override(&"separation", 8)
	body.add_child(details)
	var name_row := HBoxContainer.new()
	details.add_child(name_row)
	_detail_icon.custom_minimum_size = Vector2(56, 56)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_row.add_child(_detail_icon)
	_detail_name.add_theme_font_size_override(&"font_size", 19)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_name.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(_detail_name)
	_detail_text.bbcode_enabled = true
	_detail_text.fit_content = true
	_detail_text.scroll_active = false
	_detail_text.size_flags_vertical = SIZE_EXPAND_FILL
	details.add_child(_detail_text)
	var amount_row := HBoxContainer.new()
	details.add_child(amount_row)
	var amount_label := Label.new()
	amount_label.text = SKText.t("Amount")
	amount_row.add_child(amount_label)
	_amount.min_value = 1
	_amount.max_value = 1
	_amount.value_changed.connect(func(_v: float) -> void: _refresh_total())
	amount_row.add_child(_amount)
	_total.size_flags_horizontal = SIZE_EXPAND_FILL
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_row.add_child(_total)
	_action.custom_minimum_size = Vector2(0, 44)
	_action.pressed.connect(_on_action)
	details.add_child(_action)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_status)


# --- Content -----------------------------------------------------------------

func _entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if vendor == null:
		return entries
	match current_tab:
		Tab.BUY:
			for offer in vendor.get_offers():
				if offer.definition == null or (offer.locked and not vendor.shop.show_locked_wares):
					continue
				var stock_text := "" if offer.is_unlimited() else ("×%d" % offer.stock if offer.stock > 0 else SKText.t("Sold out"))
				if offer.locked:
					stock_text = SKText.t("Locked")
				var price_text := str(offer.unit_price)
				if offer.has_extra_costs():
					price_text = SKText.short_cost(offer.total_costs(1), offer.currency, vendor.database)
				entries.append({"key": offer.index, "definition": offer.definition, "amount_text": stock_text,
					"price_text": price_text, "dimmed": offer.is_sold_out() or offer.locked})
		Tab.SELL:
			if bag != null:
				for slot in bag.size():
					var definition := bag.get_definition(slot)
					if definition == null or definition.id == vendor.get_currency():
						continue
					var unit := vendor.sell_price(definition.id)
					var amount := bag.get_stack(slot).amount
					entries.append({"key": slot, "definition": definition, "amount_text": str(amount) if amount > 1 else "",
						"price_text": str(unit) if unit > 0 else "—", "dimmed": unit <= 0})
		Tab.BUYBACK:
			var list := vendor.get_buyback()
			for i in list.size():
				var stack: IKItemStack = list[i].stack
				var definition := vendor.database.get_item(stack.item_id) if vendor.database != null else null
				if definition == null:
					continue
				entries.append({"key": i, "definition": definition, "amount_text": str(stack.amount) if stack.amount > 1 else "",
					"price_text": str(list[i].price), "dimmed": false})
	return entries


func _select(key: int, grab: bool = true) -> void:
	_selected = key
	for child in _grid.get_children():
		if child is SKItemButton:
			child.set_selected(false)
	var index := _entries().map(func(e: Dictionary) -> int: return e.key).find(key)
	if index >= 0 and index < _grid.get_child_count():
		var button: SKItemButton = _grid.get_child(index)
		button.set_selected(true)
		if grab and not button.has_focus():
			button.grab_focus()
	_refresh_details()


func _refresh_details() -> void:
	var definition: IKItemDefinition = null
	var max_amount := 1
	var can_act := false
	match current_tab:
		Tab.BUY:
			var offer := vendor.get_offer(_selected) if vendor != null else null
			if offer != null:
				definition = offer.definition
				max_amount = maxi(1, offer.max_amount())
				can_act = not offer.is_sold_out() and not offer.locked
			_action.text = SKText.t("Trade") if offer != null and offer.is_barter() else SKText.t("Buy")
		Tab.SELL:
			if bag != null and bag.is_valid_slot(_selected) and not bag.is_slot_empty(_selected):
				definition = bag.get_definition(_selected)
				max_amount = bag.get_stack(_selected).amount
				can_act = vendor.will_buy(definition.id)
			_action.text = SKText.t("Sell")
		Tab.BUYBACK:
			var list: Array = vendor.get_buyback() if vendor != null else []
			if _selected >= 0 and _selected < list.size():
				definition = vendor.database.get_item(list[_selected].stack.item_id)
				can_act = true
			_action.text = SKText.t("Buy back")
	_detail_icon.texture = definition.icon if definition != null else null
	_detail_name.text = IKText.item_name(definition)
	_detail_text.text = _describe(definition)
	_amount.max_value = max_amount
	_amount.value = clampf(_amount.value, 1, max_amount)
	_amount.editable = current_tab != Tab.BUYBACK and max_amount > 1
	_action.disabled = not can_act
	_refresh_total()


func _describe(definition: IKItemDefinition) -> String:
	if definition == null:
		return ""
	var lines := PackedStringArray()
	var description := IKText.item_description(definition)
	if not description.is_empty():
		lines.append("[i]%s[/i]" % description)
	var worn := _equipped_like(definition)
	for property in shown_properties:
		var value: Variant = definition.properties.get(property)
		if value == null:
			continue
		var line := "%s: %s" % [IKText.label(property), value]
		if worn != null and worn != definition and (value is int or value is float):
			var diff: float = float(value) - float(worn.properties.get(property, 0))
			if diff != 0:
				line += " [color=%s](%s%s)[/color]" % ["#7ee08a" if diff > 0 else "#ff7a6b", "+" if diff > 0 else "", str(int(diff)) if is_equal_approx(diff, roundf(diff)) else "%.1f" % diff]
		lines.append(line)
	if worn != null and worn != definition:
		lines.append("[color=#aab1bf]%s %s[/color]" % [SKText.t("Compared with"), IKText.item_name(worn)])
	if current_tab == Tab.SELL and definition != null and vendor != null and not vendor.will_buy(definition.id):
		lines.append("[color=#ff7a6b]%s[/color]" % SKText.t("This merchant doesn't buy that."))
	if current_tab == Tab.BUY and vendor != null:
		lines.append_array(_offer_lines(vendor.get_offer(_selected)))
	return "\n".join(lines)


## Price, barter and reputation lines of an offer, for the details.
func _offer_lines(offer: SKOffer) -> PackedStringArray:
	var lines := PackedStringArray()
	if offer == null:
		return lines
	if offer.has_extra_costs():
		var money := {}
		for key in offer.unit_costs:
			money[key] = offer.unit_costs[key]
		if not money.is_empty():
			lines.append("%s: %s" % [SKText.t("Price"), SKText.cost_text(money, vendor.database)])
		if offer.is_barter():
			var parts := PackedStringArray()
			for key in offer.barter:
				var held := bag.count(StringName(key)) if bag != null else 0
				var part := "%s (%s %d)" % [SKText.price_text(offer.barter[key], StringName(key), vendor.database),
					SKText.t("you have"), held]
				parts.append(("[color=#ff7a6b]%s[/color]" % part) if held < int(offer.barter[key]) else part)
			lines.append("%s: %s" % [SKText.t("In exchange for"), ", ".join(parts)])
	if offer.locked:
		var tier := vendor.shop.tier_for(offer.min_reputation)
		var needed := "%s %d" % [SKText.t("Reputation"), offer.min_reputation]
		if tier != null and not tier.display_name.is_empty():
			needed += " (%s)" % SKText.t(tier.display_name)
		lines.append("[color=#ff7a6b]%s %s[/color]" % [SKText.t("Needs"), needed])
	return lines


func _equipped_like(definition: IKItemDefinition) -> IKItemDefinition:
	if equipment == null or definition.equip_slot.is_empty():
		return null
	for slot in equipment.size():
		var worn := equipment.get_definition(slot)
		if worn != null and worn.equip_slot == definition.equip_slot:
			return worn
	return null


func _unit_price() -> int:
	match current_tab:
		Tab.BUY:
			var offer := vendor.get_offer(_selected) if vendor != null else null
			return offer.unit_price if offer != null else 0
		Tab.SELL:
			if bag != null and bag.is_valid_slot(_selected) and not bag.is_slot_empty(_selected):
				return vendor.sell_price(bag.get_stack(_selected).item_id)
		Tab.BUYBACK:
			var list: Array = vendor.get_buyback() if vendor != null else []
			return list[_selected].price if _selected >= 0 and _selected < list.size() else 0
	return 0


func _refresh_total() -> void:
	var amount := 1 if current_tab == Tab.BUYBACK else int(_amount.value)
	if vendor != null and current_tab == Tab.BUY:
		var offer := vendor.get_offer(_selected)
		if offer != null and offer.has_extra_costs():
			_total.text = SKText.cost_text(offer.total_costs(amount), vendor.database)
			return
	var total := _unit_price() * amount
	_total.text = SKText.price_text(total, vendor.get_currency(), vendor.database) if vendor != null else ""


func _refresh_money() -> void:
	var purse := wallet if wallet != null else bag
	if vendor == null or purse == null:
		_money.text = ""
		return
	var parts := PackedStringArray()
	for currency in vendor.get_currencies():
		parts.append(SKText.price_text(purse.count(currency), currency, vendor.database))
	_money.text = " · ".join(parts)


func _on_action() -> void:
	if vendor == null or bag == null or _selected < 0:
		return
	var result: SKResult
	match current_tab:
		Tab.BUY:
			result = vendor.buy(_selected, int(_amount.value), bag, wallet)
		Tab.SELL:
			result = vendor.sell(bag, _selected, int(_amount.value), wallet)
		Tab.BUYBACK:
			result = vendor.buy_back(_selected, bag, wallet)
	if result.ok:
		var verb: String = [SKText.t("Bought"), SKText.t("Sold"), SKText.t("Bought back")][current_tab]
		var definition := vendor.database.get_item(result.item_id) if vendor.database != null else null
		var paid := SKText.cost_text(result.costs, vendor.database) if not result.costs.is_empty() \
			else SKText.price_text(result.price, result.currency, vendor.database)
		_set_status("%s %d × %s (%s)." % [verb, result.amount, IKText.item_name(definition), paid], false)
		traded.emit(result)
	else:
		var text := SKText.result_message(result)
		_set_status(text, true)
		refused.emit(result, text)
	_queue_refresh()


func _set_status(text: String, warning: bool) -> void:
	_status.text = text
	_status.modulate = Color(1, 0.62, 0.52) if warning else Color(0.6, 1, 0.65)


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(TAB_PREVIOUS):
		show_tab(((current_tab + 2) % 3) as Tab)
		accept_event()
	elif event.is_action_pressed(TAB_NEXT):
		show_tab(((current_tab + 1) % 3) as Tab)
		accept_event()
	elif event.is_action_pressed(&"ui_cancel"):
		close_requested.emit()
		accept_event()


func _focus_first() -> void:
	if not is_inside_tree():
		return
	for child in _grid.get_children():
		if child is SKItemButton and not child.is_queued_for_deletion():
			var index := _entries().map(func(e: Dictionary) -> int: return e.key).find(_selected)
			var target: Control = _grid.get_child(index) if index >= 0 and index < _grid.get_child_count() else child
			target.grab_focus()
			return
	_action.grab_focus()


func _ensure_actions() -> void:
	var defaults := {
		TAB_PREVIOUS: [_key(KEY_Q), _joy(JOY_BUTTON_LEFT_SHOULDER)],
		TAB_NEXT: [_key(KEY_E), _joy(JOY_BUTTON_RIGHT_SHOULDER)],
	}
	for action: StringName in defaults:
		if InputMap.has_action(action):
			continue  # the game's own bindings win
		InputMap.add_action(action)
		for event: InputEvent in defaults[action]:
			InputMap.action_add_event(action, event)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _skin() -> IKSkin:
	if skin != null:
		return skin
	if _fallback_skin == null:
		_fallback_skin = IKSkin.create_default()
	return _fallback_skin


## Several signals fire for one trade (vendor, bag, wallet): rebuild once, next frame.
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_deferred_refresh.call_deferred()


func _deferred_refresh() -> void:
	_refresh_queued = false
	refresh()


func _connect() -> void:
	for object: Object in [vendor, bag, wallet]:
		if object == null or _connected.has(object):
			continue
		if object is SKVendor or object is IKContainer:
			object.changed.connect(_queue_refresh)
		_connected.append(object)


func _disconnect() -> void:
	for object in _connected:
		if is_instance_valid(object) and object.is_connected(&"changed", _queue_refresh):
			object.disconnect(&"changed", _queue_refresh)
	_connected.clear()
