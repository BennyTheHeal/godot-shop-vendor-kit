class_name SKShopkeeper2D
extends Area2D
## Puts a shop on an NPC: when the player stands in this area and presses Interact
## (F, gamepad Y: action [code]sk_interact[/code]), the shop window opens on this
## NPC's vendor; walking away or Cancel (Escape / B) closes it.
##
## Add it as a child of your NPC with a CollisionShape2D (the interaction zone),
## put your player in the [member player_group] group, and point [member vendor]
## and [member window] (or [member screen]) at your nodes. Several NPCs can share
## one window. For 3D, see docs/recipes.md: the same few lines on an Area3D.

signal player_entered(body: Node2D)
signal player_exited(body: Node2D)
signal shop_opened
signal shop_closed

const INTERACT := &"sk_interact"

@export var vendor: SKVendor
## The shop window to open (it is given this NPC's vendor).
@export var window: SKShopWindow
## Shown and hidden instead of the window itself, e.g. a screen holding the window
## and the player's bag. Optional.
@export var screen: CanvasItem
## Bodies of this group can trade (add your player node to it).
@export var player_group: StringName = &"player"
## Open as soon as the player walks in, without pressing Interact.
@export var open_on_enter := false
## Close the shop when the player leaves the area.
@export var close_on_exit := true
## Close the shop when the window asks to (Cancel: Escape / B).
@export var close_on_cancel := true
## Shown while the player can interact ("F: Trade"). Optional.
@export var prompt: CanvasItem

var _player: Node2D


func _ready() -> void:
	ensure_actions()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if window != null and not window.close_requested.is_connected(_on_close_requested):
		window.close_requested.connect(_on_close_requested)
	if prompt != null:
		prompt.visible = false


## Adds [code]sk_interact[/code] (F, gamepad Y) unless the game already defines it.
static func ensure_actions() -> void:
	if InputMap.has_action(INTERACT):
		return
	InputMap.add_action(INTERACT)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	InputMap.action_add_event(INTERACT, key)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_Y
	button.device = -1
	InputMap.action_add_event(INTERACT, button)


func is_player_near() -> bool:
	return _player != null and is_instance_valid(_player)


## True while the window shows this NPC's vendor.
func is_open() -> bool:
	var shown := _shown_node()
	return shown != null and shown.visible and window != null and window.vendor == vendor


## Opens the window on this vendor. Returns false if the vendor or the window is missing.
func open_shop() -> bool:
	var shown := _shown_node()
	if vendor == null or window == null or shown == null:
		return false
	if window.vendor != vendor:
		window.vendor = vendor
	shown.show()
	window.show()
	window.show_tab(SKShopWindow.Tab.BUY)
	if prompt != null:
		prompt.visible = false
	shop_opened.emit()
	return true


func close_shop() -> void:
	if not is_open():
		return
	_shown_node().hide()
	if prompt != null:
		prompt.visible = is_player_near()
	shop_closed.emit()


func _shown_node() -> CanvasItem:
	return screen if screen != null else window


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(INTERACT) and is_player_near() and not is_open():
		if open_shop():
			get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(player_group):
		return
	_player = body
	if prompt != null:
		prompt.visible = not is_open()
	player_entered.emit(body)
	if open_on_enter:
		open_shop()


func _on_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	_player = null
	if prompt != null:
		prompt.visible = false
	player_exited.emit(body)
	if close_on_exit:
		close_shop()


func _on_close_requested() -> void:
	if close_on_cancel and is_open():
		close_shop()
