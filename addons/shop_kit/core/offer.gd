class_name SKOffer
extends RefCounted
## A read-only snapshot of one line of a vendor's wares, for UIs.
## Changing it never changes the vendor: call [method SKVendor.buy].

## Line index, to pass to [method SKVendor.buy].
var index: int = -1
var item_id: StringName
var definition: IKItemDefinition
## Items left. -1 = unlimited.
var stock: int = -1
## Unit price in the main [member currency], vendor modifiers and reputation included
## (0 for lines paid only in other currencies or items).
var unit_price: int = 0
var currency: StringName
## True for wares rolled from the shop's random table.
var random: bool = false
## Unit price in every currency of the line, modifiers included: currency -> amount.
## Usually just {currency: unit_price}.
var unit_costs: Dictionary = {}
## Items handed over per unit (barter): item id -> amount.
var barter: Dictionary = {}
## True while the vendor's reputation is below [member min_reputation].
var locked: bool = false
## Reputation needed ([constant SKShopEntry.ANY_REPUTATION] = none).
var min_reputation: int = SKShopEntry.ANY_REPUTATION


func is_unlimited() -> bool:
	return stock < 0


func is_sold_out() -> bool:
	return stock == 0


## True if the line asks for items (barter) instead of, or on top of, money.
func is_barter() -> bool:
	return not barter.is_empty()


## True if the line costs anything other than the main currency.
func has_extra_costs() -> bool:
	return is_barter() or unit_costs.keys().any(func(key: Variant) -> bool: return key != currency)


## Most the player can take in one purchase: stock, then the item's stack size.
func max_amount() -> int:
	var stack := definition.get_effective_max_stack() if definition != null else 1
	return stack if stock < 0 else mini(stock, stack)


## Everything [param amount] units cost: currencies and barter items, id -> total.
func total_costs(amount: int = 1) -> Dictionary:
	var totals := {}
	for key in unit_costs:
		if unit_costs[key] > 0:
			totals[key] = totals.get(key, 0) + unit_costs[key] * amount
	for key in barter:
		if barter[key] > 0:
			totals[key] = totals.get(key, 0) + barter[key] * amount
	return totals
