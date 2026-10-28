# Shop & Vendor Kit for Godot 4

Merchants for your RPG, survival game or roguelite: **buy, sell and buy back**, stock and restocks, price rules, random wares, vendor money, saves, and a **ready-to-use shop window** that works with the mouse, the keyboard and a gamepad.

**Pay what you want, from $0.** Code under MIT. A tip on itch.io keeps new kits coming. Official page, downloads and playable web demo: https://banc-essai.site-testeurs.workers.dev/shop-kit/
More free kits, and our game prototypes waiting for testers: https://banc-essai.site-testeurs.workers.dev/

- Built on **Inventory Kit** (included in the download): money is an item, so every trade is one atomic transaction. The gold and the items move together or not at all: no gold is taken for items that do not fit, no item is given without payment, nothing is ever duplicated.
- Prices from each item's `value`, buy and sell multipliers, per-category factors, per-item overrides, reputation or sale modifiers. Selling never pays more than buying: buy-and-resell loops can never create money.
- **Several currencies** per price (gold + gems) and **barter**: pay with items (1 bone per arrow, 2 hides for leather), in the same atomic transaction.
- **Reputation per merchant**, saved: levels (Stranger, Regular, Friend...) change prices and unlock wares; it grows as the player spends.
- **Shops on NPCs**: `SKShopkeeper2D` opens the shop when the player walks up and presses Interact, closes it when they walk away.
- Stock per line (limited or unlimited), restock per "day" (refill or +N), **random wares** rolled from a loot table, vendor **funds**.
- What a vendor buys: categories, refused tags (quest items), worthless items refused.
- **Buyback** of the last sold items, for the price the player got. Unique items come back with their uid and data (durability, enchantments).
- **Loot tables** (`SKLootTable`): weighted picks, amounts, no-repeat option, "nothing" chance, reproducible seeds, atomic `roll_into()` for chests and drops.
- Save / load each vendor (`to_data()` / `load_data()`, JSON-friendly).
- `SKShopWindow`: Buy / Sell / Buy back tabs, item grid, details with stat comparison against the equipped item, amount, total, money. Styled by Inventory Kit skins, so it matches your inventory in any of the 4 art styles.
- Every player text is translatable (`translations/shop_kit.csv`). 67 automated tests.

## Install

1. Copy `addons/inventory_kit/` and `addons/shop_kit/` into your project's `addons/` folder (skip Inventory Kit if you already have it).
2. Open `demo/shop/shop_demo.tscn` to see a market with four vendors, or `demo/shop/npc_demo.tscn` to walk up to merchants.

## Five-minute setup

```gdscript
# A shop is a resource: save it as .tres and share it between vendors.
var shop := SKShop.new()
shop.display_name = "Brann's Forge"
shop.currency = &"gold_coins"                     # an item of your database
shop.entries = [SKShopEntry.make(&"sword", 2), SKShopEntry.make(&"arrows")]  # stock 2, unlimited
shop.buys_categories = [&"weapon", &"armor"]

var vendor := SKVendor.new()
vendor.shop = shop
vendor.database = preload("res://addons/inventory_kit/art/painted/painted_items.tres")
add_child(vendor)

var result := vendor.buy(0, 1, bag.container)   # offer 0, amount 1
if not result.ok:
	status.text = SKText.result_message(result)  # "Not enough money.", "Sold out."…

vendor.sell(bag.container, slot)                 # whole stack; vendor.sell(bag, slot, 3) for 3
vendor.buy_back(0, bag.container)
vendor.restock()                                 # call it when your game's day changes
```

Ready-made UI:

```gdscript
var window := SKShopWindow.new()
window.vendor = vendor
window.bag = bag.container
window.equipment = equipment.container           # optional: stat comparison
window.skin = preload("res://addons/inventory_kit/art/painted/painted_skin.tres")
window.theme = preload("res://addons/inventory_kit/art/painted/painted_theme.tres")
add_child(window)
window.close_requested.connect(window.hide)
```

Saving next to your inventory:

```gdscript
var data := {"blacksmith": blacksmith.to_data()}
FileAccess.open("user://vendors.json", FileAccess.WRITE).store_string(JSON.stringify(data))
# later
blacksmith.load_data(JSON.parse_string(FileAccess.get_file_as_string("user://vendors.json")).blacksmith)
```

The saved state includes stock, buyback, funds, day and the vendor's reputation. Saves made with 1.0 load unchanged (reputation starts from `SKShop.start_reputation`).

## Recipes

[docs/recipes.md](docs/recipes.md): a shop on an NPC (interaction zone, opening and closing, 2D and 3D), prices in several currencies, barter, reputation per merchant.

## Classes

| Class | Role |
|---|---|
| `SKShop` | Resource: name, currency, wares, pricing, random wares, what the vendor buys, funds, buyback size |
| `SKShopEntry` | One line of wares: item, stock, max stock, restock amount, fixed price, `prices` in several currencies, `barter` items, `min_reputation` |
| `SKReputationTier` | A reputation level: name, from which value, buy / sell multipliers |
| `SKShopkeeper2D` | Area2D on an NPC: prompt, Interact (`sk_interact`: F / gamepad Y) opens the shop, leaving or Cancel closes it |
| `SKPricing` | Value property, buy / sell multipliers, category factors, overrides, minimum price |
| `SKVendor` | Node with the runtime state: `buy()`, `sell()`, `buy_back()`, `restock()`, `get_offers()`, `get_currencies()`, reputation (`add_reputation()`, `get_reputation_tier()`), `to_data()`; signals `purchased`, `sold`, `bought_back`, `restocked`, `reputation_changed`, `changed` |
| `SKOffer` | Read-only snapshot of one line, for your own UI |
| `SKLootTable`, `SKLootEntry` | Weighted random picks, `roll()` and atomic `roll_into()` |
| `SKResult`, `SKText` | Outcome codes (`OUT_OF_STOCK`, `NOT_ENOUGH_MONEY`, `NOT_ENOUGH_ITEMS`, `NO_ROOM`, `LOCKED`, `VENDOR_REFUSES`, `VENDOR_NO_FUNDS`), `result.costs`, player texts |
| `SKShopWindow`, `SKItemButton` | The shop screen |

Controls of the shop window: click or Enter / A to pick an item, the arrows / d-pad move between items, Q / E or LB / RB switch tabs, Escape / B emits `close_requested`. Add actions named `sk_previous_tab` / `sk_next_tab` in your Input Map to rebind the tabs.

## Running the tests

```bash
godot --headless --path <project> --import
godot --headless --path <project> -s res://tests/shop_kit/run_tests.gd
```

## Licenses

- Source code: MIT (`LICENSE.txt`).
- The item art in `addons/inventory_kit/art/` is covered by Inventory Kit's `LICENSE_ART.txt`: free to use in your games, please do not re-upload it; link to the official page instead.
- Found a bug or want a feature? Tell us: https://banc-essai.site-testeurs.workers.dev/
