class_name SKText
extends RefCounted
## Every text Shop & Vendor Kit shows to players goes through here, so it can be
## translated or reworded with Godot's translation system (template:
## [code]addons/shop_kit/translations/shop_kit.csv[/code]), like Inventory Kit's IKText.

## Player text for each refusal. Replace entries to reword them in code, e.g.
## [code]SKText.result_texts[SKResult.Code.NOT_ENOUGH_MONEY] = "You can't afford that."[/code]
static var result_texts := {
	SKResult.Code.INVALID_ARGUMENT: "That did not work.",
	SKResult.Code.OUT_OF_STOCK: "Sold out.",
	SKResult.Code.NOT_ENOUGH_MONEY: "Not enough money.",
	SKResult.Code.NO_ROOM: "Not enough room in your bag.",
	SKResult.Code.VENDOR_REFUSES: "This merchant doesn't buy that.",
	SKResult.Code.VENDOR_NO_FUNDS: "The merchant can't afford that today.",
	SKResult.Code.INVENTORY_ERROR: "That did not work.",
	SKResult.Code.NOT_ENOUGH_ITEMS: "You don't have what this trade asks for.",
	SKResult.Code.LOCKED: "This merchant doesn't trust you enough yet.",
}


static func t(text: String) -> String:
	if text.is_empty():
		return text
	return String(TranslationServer.translate(text))


## What to tell the player about a refused purchase or sale.
static func result_message(result: SKResult) -> String:
	if result == null or result.ok:
		return ""
	if result.code == SKResult.Code.NO_ROOM and result.inventory_result != null \
			and not result.inventory_result.player_text.is_empty():
		return IKText.result_message(result.inventory_result)  # "Too heavy." from a weight rule
	if result.code == SKResult.Code.INVENTORY_ERROR and result.inventory_result != null:
		return IKText.result_message(result.inventory_result)
	return t(result_texts.get(result.code, "That did not work."))


## "12 Gold Coins", using the currency item's name from [param database].
static func price_text(amount: int, currency: StringName, database: IKItemDatabase) -> String:
	var definition := database.get_item(currency) if database != null else null
	var name := IKText.item_name(definition) if definition != null else String(currency)
	return "%d %s" % [amount, name]


## "80 Gold Coins + 1 Ruby + 4 Bone" for a cost (item id -> amount); "Free" when empty.
static func cost_text(costs: Dictionary, database: IKItemDatabase) -> String:
	var parts := PackedStringArray()
	for key in costs:
		if int(costs[key]) > 0:
			parts.append(price_text(int(costs[key]), StringName(key), database))
	return " + ".join(parts) if not parts.is_empty() else t("Free")


## Short price for an item button: "80" in the main currency, other parts with a
## short name ("80+1 Rub"), barter lines included.
static func short_cost(costs: Dictionary, main_currency: StringName, database: IKItemDatabase) -> String:
	var parts := PackedStringArray()
	if int(costs.get(main_currency, 0)) > 0:
		parts.append(str(int(costs[main_currency])))
	for key in costs:
		if StringName(key) == main_currency or int(costs[key]) <= 0:
			continue
		var definition := database.get_item(StringName(key)) if database != null else null
		var name := IKText.item_name(definition) if definition != null else String(key)
		parts.append("%d %s" % [int(costs[key]), name.substr(0, 3)])
	return "+".join(parts) if not parts.is_empty() else t("Free")


## "Friend (55)", or just the number when the vendor has no reputation levels.
static func reputation_text(vendor: SKVendor) -> String:
	if vendor == null:
		return ""
	var tier := vendor.get_reputation_tier()
	if tier == null or tier.display_name.is_empty():
		return "%s %d" % [t("Reputation"), vendor.get_reputation()]
	return "%s (%d)" % [t(tier.display_name), vendor.get_reputation()]
