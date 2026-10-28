@tool
class_name SKLootTable
extends Resource
## Weighted random picks: random vendor wares, chest contents, enemy drops.
##
## Rolls are reproducible: pass your own [RandomNumberGenerator] with a fixed seed.
## [codeblock]
## var drops := table.roll(3, rng)                  # [{item_id, amount}, ...]
## var result := table.roll_into(chest.container, 3, rng)  # atomic: all drops or none
## [/codeblock]

@export var entries: Array[SKLootEntry] = []
## Chance that a roll gives nothing at all (0 to 1), for "empty" results.
@export_range(0.0, 1.0, 0.01) var nothing_chance: float = 0.0


func total_weight() -> float:
	var total := 0.0
	for entry in entries:
		if entry != null and entry.weight > 0.0:
			total += entry.weight
	return total


## [param count] picks. With [param repeats] false, an entry is picked at most once
## (fewer results when the table is smaller). Same item picked twice: amounts add up.
func roll(count: int, rng: RandomNumberGenerator, repeats: bool = true) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	var pool: Array[SKLootEntry] = []
	for entry in entries:
		if entry != null and entry.weight > 0.0 and not entry.item_id.is_empty():
			pool.append(entry)
	for i in count:
		if pool.is_empty():
			break
		if nothing_chance > 0.0 and rng.randf() < nothing_chance:
			continue
		var entry := _pick(pool, rng)
		if not repeats:
			pool.erase(entry)
		var amount := rng.randi_range(entry.min_amount, maxi(entry.min_amount, entry.max_amount))
		var merged := false
		for drop in picked:
			if drop.item_id == entry.item_id:
				drop.amount += amount
				merged = true
				break
		if not merged:
			picked.append({"item_id": entry.item_id, "amount": amount})
	return picked


## Rolls and adds the drops to [param container] in one transaction: if they do not
## all fit, nothing is added (check [code]result.ok[/code]).
func roll_into(container: IKContainer, count: int, rng: RandomNumberGenerator, repeats: bool = true) -> IKResult:
	var transaction := IKTransaction.new()
	for drop in roll(count, rng, repeats):
		transaction.add(container, drop.item_id, drop.amount)
	return transaction.commit()


func _pick(pool: Array[SKLootEntry], rng: RandomNumberGenerator) -> SKLootEntry:
	var total := 0.0
	for entry in pool:
		total += entry.weight
	var target := rng.randf() * total
	for entry in pool:
		target -= entry.weight
		if target < 0.0:
			return entry
	return pool.back()
