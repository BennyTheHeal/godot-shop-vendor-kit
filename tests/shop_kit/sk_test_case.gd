extends RefCounted
## Base class for Shop & Vendor Kit tests: assertions and shared fixtures.

var _failures := PackedStringArray()
var _nodes: Array[Node] = []


func get_failures() -> PackedStringArray:
	return _failures


func get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Adds [param node] to the scene root; it is freed after the test.
func add_to_tree(node: Node) -> Node:
	get_tree().root.add_child(node)
	_nodes.append(node)
	return node


func wait_frames(count: int = 1) -> void:
	for i in count:
		await get_tree().process_frame


## Called by the runner after each test.
func cleanup() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	await get_tree().process_frame


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%sexpected <%s> but got <%s>" % [message + ": " if message else "", expected, actual])


func assert_ok(result: IKResult, message: String = "") -> void:
	if result == null or not result.ok:
		fail("%sexpected OK, got %s" % [message + ": " if message else "", result])


func assert_code(result: IKResult, code: IKResult.Code, message: String = "") -> void:
	if result == null or result.code != code:
		fail("%sexpected %s, got %s" % [message + ": " if message else "", IKResult.Code.keys()[code], result])


## Disconnects every signal of [param objects]. Call at the end of tests whose
## lambdas capture the emitter, otherwise the reference cycle leaks.
func disconnect_all(objects: Array) -> void:
	for object: Object in objects:
		for info in object.get_signal_list():
			for connection in object.get_signal_connection_list(info.name):
				object.disconnect(info.name, connection.callable)


# --- Fixtures ----------------------------------------------------------------

func assert_shop(result: SKResult, code: SKResult.Code, message: String = "") -> void:
	if result == null or result.code != code:
		fail("%sexpected %s, got %s" % [message + ": " if message else "", SKResult.Code.keys()[code], result])


func make_item(id: StringName, max_stack: int = 1, value: int = 0, category: StringName = &"",
		unique: bool = false, tags: Array[StringName] = []) -> IKItemDefinition:
	var item := IKItemDefinition.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.max_stack = max_stack
	item.unique = unique
	item.category = category
	item.tags = tags
	if value > 0:
		item.properties = {"value": value}
	return item


## gold (999, currency), wood (20, value 5), potion (5, value 20, consumable),
## sword (unique weapon, value 100), letter (quest, value 50), rock (no value).
func make_db() -> IKItemDatabase:
	var db := IKItemDatabase.new()
	db.add_item(make_item(&"gold", 999, 1, &"currency"))
	db.add_item(make_item(&"wood", 20, 5, &"material"))
	db.add_item(make_item(&"potion", 5, 20, &"consumable"))
	db.add_item(make_item(&"sword", 1, 100, &"weapon", true))
	db.add_item(make_item(&"letter", 1, 50, &"quest", false, [&"quest"]))
	db.add_item(make_item(&"rock", 10, 0, &"material"))
	return db


## Sells wood (unlimited), potions (stock 3, refill to 3) and a sword (stock 1, 120 gold).
func make_shop() -> SKShop:
	var shop := SKShop.new()
	shop.shop_id = &"test"
	shop.currency = &"gold"
	shop.pricing = SKPricing.new()
	shop.entries = [SKShopEntry.make(&"wood"), SKShopEntry.make(&"potion", 3), SKShopEntry.make(&"sword", 1, 120)]
	return shop


func make_vendor(db: IKItemDatabase, shop: SKShop = null) -> SKVendor:
	var vendor := SKVendor.new()
	vendor.shop = shop if shop != null else make_shop()
	vendor.database = db
	vendor.rng_seed = 42
	vendor.open()
	return vendor


func make_bag(db: IKItemDatabase, slots: int = 6, gold: int = 100) -> IKContainer:
	var bag := IKContainer.new(&"bag", slots, db)
	if gold > 0:
		bag.add(&"gold", gold)
	return bag
