@tool
class_name SKLootEntry
extends Resource
## One possible drop of a [SKLootTable].

@export var item_id: StringName
## Relative chance: an entry of weight 2 is picked twice as often as one of weight 1.
@export_range(0.0, 1000.0, 0.01) var weight: float = 1.0
@export_range(1, 9999) var min_amount: int = 1
@export_range(1, 9999) var max_amount: int = 1


static func make(p_item_id: StringName, p_weight: float = 1.0, p_min: int = 1, p_max: int = -1) -> SKLootEntry:
	var entry := SKLootEntry.new()
	entry.item_id = p_item_id
	entry.weight = p_weight
	entry.min_amount = p_min
	entry.max_amount = p_max if p_max >= p_min else p_min
	return entry
