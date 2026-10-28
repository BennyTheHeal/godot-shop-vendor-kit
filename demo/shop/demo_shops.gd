extends RefCounted
## The three market vendors of the demo, built in code so every setting is visible
## in one place. In a game you would save these as .tres files (SKShop resources)
## and assign them to SKVendor nodes in the inspector.


static func blacksmith() -> SKShop:
	var shop := _shop(&"blacksmith", "Brann's Forge")
	shop.pricing.category_multipliers = {&"weapon": 1.2, &"armor": 1.1}
	shop.entries = [
		_line(&"sword", 2), _line(&"axe", 2), _line(&"mace", 1), _line(&"spear", 1), _line(&"shield", 2),
		_line(&"iron_helmet", 1), _line(&"iron_chest", 1), _line(&"iron_gloves", 1), _line(&"iron_boots", 1),
		_line(&"steel_helmet", 1), _line(&"steel_chest", 1),
		_line(&"iron_ingot", 20, 2), _line(&"coal"), _line(&"arrows"),
	]
	shop.buys_categories = [&"weapon", &"armor", &"resource", &"material", &"ammo", &"tool"]
	shop.funds = 600
	return shop


static func alchemist() -> SKShop:
	var shop := _shop(&"alchemist", "Mira's Remedies")
	shop.pricing.price_overrides = {&"health_potion": 18}
	shop.entries = [
		_line(&"health_potion", 10, 2), _line(&"mana_potion", 6, 2), _line(&"stamina_potion", 6, 2),
		_line(&"antidote", 4, 1), _line(&"bread"), _line(&"apple"), _line(&"cheese"), _line(&"roast_meat", 8, 4),
	]
	var herbs := SKLootTable.new()
	herbs.entries = [
		SKLootEntry.make(&"herb", 6, 3, 8), SKLootEntry.make(&"magic_essence", 1), SKLootEntry.make(&"crystal", 2, 1, 2),
		SKLootEntry.make(&"rough_amethyst", 2, 1, 3), SKLootEntry.make(&"silk", 1, 1, 2), SKLootEntry.make(&"feather", 4, 4, 10),
	]
	shop.random_wares = herbs
	shop.random_ware_count = 3
	shop.buys_categories = [&"consumable", &"gem", &"material"]
	shop.funds = 400
	return shop


static func trader() -> SKShop:
	var shop := _shop(&"trader", "Tobin's Bazaar")
	shop.pricing.sell_multiplier = 0.3  # buys anything, pays less
	shop.entries = [_line(&"torch"), _line(&"map", 1), _line(&"ring", 1), _line(&"amulet", 1), _line(&"cloak", 1)]
	var junk := SKLootTable.new()
	for id: StringName in [&"oak_planks", &"pine_log", &"granite", &"clay", &"copper_ore", &"silver_ore", &"wool",
			&"linen_thread", &"hardened_leather", &"bone", &"resin", &"ruby", &"sapphire", &"topaz", &"emerald",
			&"gold_nugget", &"bronze_ingot", &"steel_ingot", &"ebony_log", &"diamond"]:
		var rare := id in [&"emerald", &"diamond", &"ebony_log", &"steel_ingot"]
		junk.entries.append(SKLootEntry.make(id, 1.0 if rare else 4.0, 1, 1 if rare else 6))
	shop.random_wares = junk
	shop.random_ware_count = 7
	shop.funds = 300
	return shop


## Multiple currencies, barter and reputation: the hunter wants gold and gems,
## trades for bones and hides, and keeps her best wares for regular customers.
static func hunter() -> SKShop:
	var shop := _shop(&"hunter", "Kesh's Hunting Lodge")
	var bow := _line(&"bow", 2)
	bow.prices = {&"gold_coins": 60, &"ruby": 1}              # gold + a gem
	var arrows := SKShopEntry.trade(&"arrows", {&"bone": 1})   # 1 bone per arrow
	var leather := SKShopEntry.trade(&"leather", {&"rawhide": 2}, 10)
	var cloak := _line(&"cloak", 1)
	cloak.min_reputation = 10                                  # "Regular" and up
	var boots := _line(&"dragon_boots", 1)
	boots.prices = {&"gold_coins": 150, &"diamond": 1}
	boots.min_reputation = 30                                  # "Friend" only
	shop.entries = [bow, arrows, leather, _line(&"dagger", 2), _line(&"roast_meat", 6, 3), cloak, boots]
	shop.reputation_tiers = [
		SKReputationTier.make(-100, "Distrusted", 1.25, 0.8),
		SKReputationTier.make(0, "Stranger"),
		SKReputationTier.make(10, "Regular", 0.95, 1.05),
		SKReputationTier.make(30, "Friend", 0.85, 1.15),
	]
	shop.currency_per_reputation = 10                          # +1 per 10 gold spent
	shop.buys_categories = [&"resource", &"material", &"weapon", &"consumable"]
	shop.funds = 300
	return shop


static func _shop(id: StringName, display_name: String) -> SKShop:
	var shop := SKShop.new()
	shop.shop_id = id
	shop.display_name = display_name
	shop.currency = &"gold_coins"
	shop.pricing = SKPricing.new()
	return shop


static func _line(item_id: StringName, stock: int = -1, restock: int = 0) -> SKShopEntry:
	var entry := SKShopEntry.make(item_id, stock)
	entry.restock_amount = restock
	return entry
