extends "res://tests/shop_kit/sk_test_case.gd"
## Prices: value property, multipliers, overrides, rounding, and the no-free-money rule.


func test_buy_and_sell_prices_from_value() -> void:
	var db := make_db()
	var pricing := SKPricing.new()
	assert_eq(pricing.buy_price(db.get_item(&"potion")), 20)
	assert_eq(pricing.sell_price(db.get_item(&"potion")), 8, "40 % of 20")
	assert_eq(pricing.buy_price(db.get_item(&"rock")), 0, "no value: not for sale")
	assert_eq(pricing.sell_price(db.get_item(&"rock")), 0)


func test_category_multiplier_and_override() -> void:
	var db := make_db()
	var pricing := SKPricing.new()
	pricing.category_multipliers = {&"weapon": 1.5}
	pricing.price_overrides = {&"wood": 9}
	assert_eq(pricing.buy_price(db.get_item(&"sword")), 150)
	assert_eq(pricing.buy_price(db.get_item(&"wood")), 9)
	assert_eq(pricing.buy_price(db.get_item(&"wood"), 0.5), 5, "buy prices round up")


func test_selling_never_pays_more_than_buying() -> void:
	var db := make_db()
	var pricing := SKPricing.new()
	pricing.sell_multiplier = 3.0  # a careless setting
	for id in [&"wood", &"potion", &"sword", &"gold"]:
		var definition := db.get_item(id)
		for modifiers in [[1.0, 1.0], [2.0, 0.5], [1.0, 0.1], [5.0, 1.0]]:
			var sell := pricing.sell_price(definition, modifiers[0], modifiers[1])
			var buy := pricing.buy_price(definition, modifiers[1])
			assert_true(sell < buy, "%s sell %d < buy %d at %s" % [id, sell, buy, modifiers])


func test_minimum_price() -> void:
	var db := make_db()
	var pricing := SKPricing.new()
	pricing.minimum_price = 3
	assert_eq(pricing.buy_price(db.get_item(&"gold")), 3)
