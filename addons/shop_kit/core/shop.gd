@tool
class_name SKShop
extends Resource
## What a vendor sells and buys, as a resource you can share between vendors.
## The runtime state (stock left, buyback, funds, reputation) lives in [SKVendor], never here.

@export var shop_id: StringName
@export var display_name: String = ""
## Main currency: the item used as money for prices from [member pricing], sales,
## buyback and funds. It must exist in the database (the library has gold_coins).
## Lines can also cost other currencies or items ([member SKShopEntry.prices],
## [member SKShopEntry.barter]).
@export var currency: StringName = &"gold_coins"
@export var pricing: SKPricing
## Fixed wares.
@export var entries: Array[SKShopEntry] = []

@export_group("Random wares")
## Extra wares rolled at every restock (replaced each time).
@export var random_wares: SKLootTable
@export_range(0, 64) var random_ware_count: int = 0
## Stock of each random ware: the rolled amount.

@export_group("Buying from the player")
## Categories this vendor buys. Empty = buys every category.
@export var buys_categories: Array[StringName] = []
## Items with any of these tags are never bought (quest items...).
@export var refuses_tags: Array[StringName] = [&"quest"]
## Categories never bought, even when [member buys_categories] is empty.
@export var refuses_categories: Array[StringName] = [&"quest", &"currency"]
## Money the vendor has to pay the player, reset at each restock. -1 = unlimited.
@export var funds: int = -1
## Sold items the player can buy back for the price they got (latest first).
@export_range(0, 64) var buyback_size: int = 8
@export var clear_buyback_on_restock: bool = true

@export_group("Reputation")
## Levels of reputation with this vendor and their prices, in any order
## (the highest one reached applies). Empty = reputation changes no price.
@export var reputation_tiers: Array[SKReputationTier] = []
## Reputation when the vendor opens (before any save is loaded).
@export var start_reputation: int = 0
@export var min_reputation: int = -100
@export var max_reputation: int = 100
## +1 reputation for every this much main currency the player spends on wares
## (buyback excluded). 0 = reputation only changes through [method SKVendor.add_reputation].
@export_range(0, 100000) var currency_per_reputation: int = 0
## Wares waiting for more reputation are listed (locked) instead of hidden.
@export var show_locked_wares: bool = true


func get_pricing() -> SKPricing:
	if pricing == null:
		pricing = SKPricing.new()
	return pricing


## Whether this vendor buys items of this kind at all (price aside).
func accepts(definition: IKItemDefinition) -> bool:
	if definition == null or definition.id == currency:
		return false
	if refuses_categories.has(definition.category):
		return false
	for tag in refuses_tags:
		if definition.has_tag(tag):
			return false
	return buys_categories.is_empty() or buys_categories.has(definition.category)


## The reputation level reached at [param reputation], or null (no level / none reached).
func tier_for(reputation: int) -> SKReputationTier:
	var best: SKReputationTier = null
	for tier in reputation_tiers:
		if tier != null and reputation >= tier.min_reputation \
				and (best == null or tier.min_reputation > best.min_reputation):
			best = tier
	return best


## The next level above [param reputation], or null at the top.
func next_tier_for(reputation: int) -> SKReputationTier:
	var best: SKReputationTier = null
	for tier in reputation_tiers:
		if tier != null and tier.min_reputation > reputation \
				and (best == null or tier.min_reputation < best.min_reputation):
			best = tier
	return best
