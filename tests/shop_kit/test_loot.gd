extends "res://tests/shop_kit/sk_test_case.gd"
## Loot tables: weights, amounts, no-repeat picks, reproducibility, atomic drops.


func _table() -> SKLootTable:
	var table := SKLootTable.new()
	table.entries = [SKLootEntry.make(&"wood", 8, 1, 3), SKLootEntry.make(&"potion", 2), SKLootEntry.make(&"sword", 0)]
	return table


func test_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var counts := {}
	for i in 2000:
		for drop in _table().roll(1, rng):
			counts[drop.item_id] = counts.get(drop.item_id, 0) + 1
	assert_false(counts.has(&"sword"), "weight 0 never drops")
	var ratio: float = float(counts[&"wood"]) / counts[&"potion"]
	assert_true(ratio > 3.0 and ratio < 5.5, "about 4:1, got %.2f" % ratio)


func test_amounts_and_merging() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var table := SKLootTable.new()
	table.entries = [SKLootEntry.make(&"wood", 1, 2, 4)]
	var drops := table.roll(5, rng)
	assert_eq(drops.size(), 1, "same item merged")
	assert_true(drops[0].amount >= 10 and drops[0].amount <= 20)


func test_no_repeats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var drops := _table().roll(10, rng, false)
	assert_eq(drops.size(), 2, "only two entries can drop")


func test_reproducible() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	assert_eq(_table().roll(6, a), _table().roll(6, b))


func test_nothing_chance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var table := _table()
	table.nothing_chance = 1.0
	assert_true(table.roll(10, rng).is_empty())


func test_roll_into_is_all_or_nothing() -> void:
	var db := make_db()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var chest := IKContainer.new(&"chest", 1, db)
	var table := SKLootTable.new()
	table.entries = [SKLootEntry.make(&"wood", 1, 30, 30)]  # 30 wood never fit in one 20-slot stack
	var result := table.roll_into(chest, 1, rng)
	assert_false(result.ok)
	assert_eq(chest.count(&"wood"), 0)
	table.entries = [SKLootEntry.make(&"wood", 1, 5, 5)]
	assert_true(table.roll_into(chest, 1, rng).ok)
	assert_eq(chest.count(&"wood"), 5)
