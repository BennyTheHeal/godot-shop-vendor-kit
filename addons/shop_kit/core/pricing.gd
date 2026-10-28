@tool
class_name SKPricing
extends Resource
## How a vendor turns an item's value into buy and sell prices.
##
## The base value is read from the item definition's [member IKItemDefinition.properties]
## ([member value_property], "value" by default, as in the Inventory Kit library).
## Guarantee: for any modifiers, a vendor never pays more for an item than it asks
## for it, so buying and reselling can never create money.

## Property of [member IKItemDefinition.properties] holding the base value.
@export var value_property: StringName = &"value"
## Base value of items without that property.
@export var default_value: int = 0
## Price the player pays = value × buy_multiplier × category multiplier × modifiers.
@export var buy_multiplier: float = 1.0
## Price the player receives = value × sell_multiplier × category multiplier × modifiers.
@export var sell_multiplier: float = 0.4
## Per-category factor, e.g. {&"weapon": 1.5} for a pricey weapon smith.
@export var category_multipliers: Dictionary[StringName, float] = {}
## Per-item price override (buy price before modifiers), e.g. {&"health_potion": 25}.
@export var price_overrides: Dictionary[StringName, int] = {}
## Lowest buy price of an item that has a value.
@export var minimum_price: int = 1


func base_value(definition: IKItemDefinition) -> int:
	if definition == null:
		return 0
	var value: Variant = definition.properties.get(value_property, default_value)
	return maxi(0, int(value)) if value is int or value is float else default_value


## Unit price the player pays. [param modifier] stacks reputation, sales, haggling...
func buy_price(definition: IKItemDefinition, modifier: float = 1.0) -> int:
	if definition == null:
		return 0
	var raw: float
	if price_overrides.has(definition.id):
		raw = price_overrides[definition.id] * modifier
	else:
		var value := base_value(definition)
		if value <= 0:
			return 0
		raw = value * buy_multiplier * _category_factor(definition) * modifier
	return maxi(minimum_price, ceili(raw - 0.0001))


## Unit price the player receives. Never above [code]buy_price(definition, buy_modifier) - 1[/code].
func sell_price(definition: IKItemDefinition, modifier: float = 1.0, buy_modifier: float = 1.0) -> int:
	if definition == null:
		return 0
	var value := base_value(definition)
	if price_overrides.has(definition.id):
		value = price_overrides[definition.id]
	if value <= 0:
		return 0
	var price := floori(value * sell_multiplier * _category_factor(definition) * modifier + 0.0001)
	var ceiling := buy_price(definition, buy_modifier) - 1
	return clampi(price, 0, maxi(0, ceiling))


func _category_factor(definition: IKItemDefinition) -> float:
	return category_multipliers.get(definition.category, 1.0)
