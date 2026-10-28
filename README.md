# Shop & Vendor Kit for Godot 4

Merchants for your Godot 4 RPG, survival game or roguelite: buy, sell and buy back, stock and restocks, price rules, random wares, vendor money, saves and a ready-to-use shop window.

**Free and open source (MIT).** Made by Benny, with AI tools.

- Official page, playable web demo and the download with the full art: https://banc-essai.site-testeurs.workers.dev/shop-kit/
- itch.io: https://elliottfhotmailfr.itch.io/shop-vendor-kit-godot
- More kits, and our game prototypes waiting for testers: https://banc-essai.site-testeurs.workers.dev/

![Shop & Vendor Kit screenshot](https://banc-essai.site-testeurs.workers.dev/img/sk-1.jpg)

*Screenshot with the full art from the official page. This repository ships placeholder art, see below.*

## Install

- **From the Asset Library** (inside the Godot editor, *AssetLib* tab): search for "Shop & Vendor Kit", download, install. Only the `addons/` folder is installed.
- **By hand**: copy `addons/shop_kit/` and `addons/inventory_kit/` into your project's `addons/` folder.

Requires **Inventory Kit** ([repository](https://github.com/BennyTheHeal/godot-inventory-kit)), **included here** in `addons/inventory_kit/`. If your project already has it, keep the newest copy.

Documentation: [`addons/shop_kit/README.md`](addons/shop_kit/README.md).

## Demo and tests

This repository is a ready-to-open Godot 4.5+ project.

- Open it in Godot and run `demo/shop/shop_demo.tscn`.
- Tests: `godot --headless --path . --import` then `godot --headless --path . -s res://tests/shop_kit/run_tests.gd`

## About the art

The item icons and UI frames in `addons/inventory_kit/art/` are **placeholders** (coloured shapes with the item initials, drawn by a script, MIT). Same file names and sizes as the real art, so everything works with them. The hand-made art (120 items in 4 art directions with matching UI skins) is free, pay what you want from $0, on the [official page](https://banc-essai.site-testeurs.workers.dev/inventory-kit/): drop its `addons/inventory_kit/art/` folder over this one.

## License

MIT, see [LICENSE](LICENSE).
