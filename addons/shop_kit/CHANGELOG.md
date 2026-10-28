# Changelog

All notable changes to Shop & Vendor Kit are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-10-28

### Added
- Several currencies per price: `SKShopEntry.prices` (e.g. 60 gold + 1 ruby, or gems only), `SKOffer.unit_costs`, `total_costs()`, `has_extra_costs()`, `SKVendor.get_currencies()`; the window shows every currency the player holds.
- Barter: `SKShopEntry.barter` and `SKShopEntry.trade()` (pay with items, alone or on top of money), taken from the bag in the same atomic transaction; `SKResult.Code.NOT_ENOUGH_ITEMS`; `SKResult.costs` lists everything paid.
- Reputation per vendor: `SKReputationTier` (levels with buy / sell multipliers), `SKShop.reputation_tiers`, `start_reputation`, `min_reputation` / `max_reputation`, `currency_per_reputation` (grows with spending), `show_locked_wares`; `SKShopEntry.min_reputation` unlocks wares (`SKResult.Code.LOCKED`); `SKVendor.get_reputation()`, `set_reputation()`, `add_reputation()`, `get_reputation_tier()`, `get_next_reputation_tier()`, `get_buy_modifier()`, `get_sell_modifier()`, `is_locked()`, signal `reputation_changed`. Saved by `to_data()`.
- `SKShopkeeper2D`: a shop on an NPC (interaction zone, prompt, `sk_interact` action F / gamepad Y, closes on leaving or Cancel, several NPCs per window).
- `docs/recipes.md`: shop on an NPC (2D and 3D), several currencies, barter, reputation.
- Demo: a fourth vendor (Kesh's Hunting Lodge: gold + gems, barter, reputation levels and locked wares) and a walk-up merchants scene (`demo/shop/npc_demo.tscn`).
- `SKText.cost_text()`, `short_cost()`, `reputation_text()`; 10 new player texts in the translation template.
- 35 new tests (67 in total).

### Changed
- Vendor data saved by 1.0 loads unchanged: line prices, barter and requirements come from the shop, reputation from `start_reputation`.
- `SKVendor.sell()` refuses a slot without a stack (a covered cell of an Inventory Kit 1.2 grid bag) instead of failing.

## [1.0.0] - 2026-10-26

### Added
- `SKVendor`: buy, sell and buy back through Inventory Kit transactions (payment and items move together or not at all), stock and restocks, random wares, vendor funds, buy / sell modifiers, signals, save / load (`to_data()`, `load_data()`).
- `SKShop`, `SKShopEntry`, `SKPricing`: wares, what a vendor buys, prices from item values with multipliers, category factors, overrides and the "selling never pays more than buying" rule.
- `SKLootTable`, `SKLootEntry`: weighted picks, amounts, no-repeat option, nothing chance, atomic `roll_into()`.
- `SKShopWindow`: Buy / Sell / Buy back tabs, stat comparison with the equipped item, mouse, keyboard and gamepad, Inventory Kit skins.
- Market demo with three vendors and the four Inventory Kit art styles; 32 automated tests; translation template.
