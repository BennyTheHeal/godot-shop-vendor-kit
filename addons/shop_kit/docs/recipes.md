# Shop & Vendor Kit — Recipes

Short, complete answers. Copy, rename, done.

## Put a shop on an NPC (interaction zone, open, close)

The player walks up to a merchant, a prompt appears, Interact opens the shop, walking away or Cancel closes it. `SKShopkeeper2D` does all of it.

Scene (2D):

```
Level
├── Player (CharacterBody2D, in the group "player")
├── Blacksmith (your NPC: sprite, animations...)
│   ├── SKVendor              shop = res://shops/blacksmith.tres
│   ├── Prompt (Label)        "F: Trade"
│   └── SKShopkeeper2D        vendor = ../SKVendor, window = /ShopScreen/ShopWindow,
│       └── CollisionShape2D  screen = /ShopScreen, prompt = ../Prompt  (the interaction zone)
└── CanvasLayer
    └── ShopScreen (IKInventoryUI, hidden)
        ├── Bag (IKInventory) + IKContainerView
        └── ShopWindow (SKShopWindow)
```

```gdscript
# once, when the level starts
$CanvasLayer/ShopScreen/ShopWindow.bag = PlayerData.bag   # where purchases go
$Player.add_to_group(&"player")
```

That is all:

- Interact is the action `sk_interact` (F, gamepad Y). Define an action with that name in *Project Settings > Input Map* to rebind it.
- `close_on_exit` (on by default) closes the shop when the player leaves the zone; `close_on_cancel` closes it on Escape / B (the window's `close_requested`); `open_on_enter` opens it without a key press.
- Several NPCs can share one window: each opens it on its own vendor.
- Signals `player_entered`, `player_exited`, `shop_opened`, `shop_closed`: freeze the player, play a greeting, pause the game...

```gdscript
func _ready() -> void:
	$Blacksmith/SKShopkeeper2D.shop_opened.connect(func() -> void: $Player.set_physics_process(false))
	$Blacksmith/SKShopkeeper2D.shop_closed.connect(func() -> void: $Player.set_physics_process(true))
```

Hiding an `IKInventoryUI` puts the item held with the mouse back in the bag, so closing the shop never loses anything.

**3D**: the same few lines on an `Area3D` (`SKShopkeeper2D` is only a convenience):

```gdscript
extends Area3D
@export var vendor: SKVendor
@export var window: SKShopWindow
var _near := false

func _ready() -> void:
	SKShopkeeper2D.ensure_actions()  # registers sk_interact
	body_entered.connect(func(body: Node3D) -> void: _near = _near or body.is_in_group(&"player"))
	body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group(&"player"):
			_near = false
			window.hide())
	window.close_requested.connect(window.hide)

func _unhandled_input(event: InputEvent) -> void:
	if _near and not window.visible and event.is_action_pressed(SKShopkeeper2D.INTERACT):
		window.vendor = vendor
		window.show()
		window.show_tab(SKShopWindow.Tab.BUY)
		get_viewport().set_input_as_handled()
```

Try it: `demo/shop/npc_demo.tscn` (also reachable from the market demo, "Walk-up merchants").

## Prices in several currencies (gold + gems)

The shop's `currency` stays the main one (prices from item values, sales, buyback, funds). A line can ask for other currencies too; all are paid together, in the same transaction as the item received:

```gdscript
var bow := SKShopEntry.make(&"bow", 2)
bow.prices = {&"gold_coins": 60, &"ruby": 1}   # 60 gold AND 1 ruby
var relic := SKShopEntry.make(&"amulet", 1)
relic.prices = {&"gems": 5}                    # gems only
```

Any item of your database can be a currency. The window shows the player's amount of every currency the vendor uses. Vendor modifiers and reputation apply to every currency (rounded up, never free).

## Barter (paying with items)

```gdscript
var arrows := SKShopEntry.trade(&"arrows", {&"bone": 1})          # 1 bone per arrow
var leather := SKShopEntry.trade(&"leather", {&"rawhide": 2}, 10)  # stock 10
var saddle := SKShopEntry.trade(&"saddle", {&"leather": 4})
saddle.price = 30                                                  # 4 leather + 30 gold
```

Barter items are taken from the bag (money from the wallet), are never changed by modifiers, and the trade is all or nothing: no hide is taken for an item that does not fit. Missing goods give `SKResult.Code.NOT_ENOUGH_ITEMS` ("You don't have what this trade asks for."). `result.costs` lists everything that was paid.

## Reputation per merchant

```gdscript
shop.reputation_tiers = [
	SKReputationTier.make(-100, "Distrusted", 1.25, 0.8),  # pays 25 % more, gets 20 % less
	SKReputationTier.make(0, "Stranger"),
	SKReputationTier.make(10, "Regular", 0.95, 1.05),
	SKReputationTier.make(30, "Friend", 0.85, 1.15),
]
shop.currency_per_reputation = 10     # +1 per 10 gold spent on wares (0 = only by code)
var boots := SKShopEntry.make(&"dragon_boots", 1)
boots.min_reputation = 30             # listed locked until "Friend"
```

```gdscript
vendor.add_reputation(5)              # a quest done for them
vendor.add_reputation(-20)            # caught stealing
vendor.get_reputation_tier().display_name
vendor.reputation_changed.connect(func(value: int, tier: SKReputationTier) -> void: ...)
```

- Each vendor has its own reputation, saved by `to_data()` with the rest of its state (and kept by restocks).
- The highest level reached multiplies `buy_modifier` / `sell_modifier`; selling still never pays more than buying.
- Locked lines are shown with "Locked" and the level they need (`show_locked_wares = false` hides them) and refuse purchases with `SKResult.Code.LOCKED`.
- Selling and buying back never earn reputation, so it cannot be farmed for free.
