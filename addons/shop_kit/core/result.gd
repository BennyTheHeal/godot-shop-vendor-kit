class_name SKResult
extends RefCounted
## Outcome of a purchase, sale or buyback.
##
## Like Inventory Kit, the shop never fails silently and never pushes engine errors
## for expected refusals (not enough gold, bag full...). Check [member ok] and
## [member code]; show [method SKText.result_message] to players.

enum Code {
	OK,
	## Bad index, amount or container: a bug in the calling code.
	INVALID_ARGUMENT,
	## The vendor has fewer items left than asked.
	OUT_OF_STOCK,
	## The wallet does not hold enough of a currency.
	NOT_ENOUGH_MONEY,
	## The bag cannot take the items (space, weight or slot rules).
	NO_ROOM,
	## This vendor does not buy this item (category, tag, currency, worthless).
	VENDOR_REFUSES,
	## The vendor's own money (funds) is too low to pay for the sale.
	VENDOR_NO_FUNDS,
	## The inventory refused for another reason: see [member inventory_result].
	INVENTORY_ERROR,
	## The bag does not hold the items this barter line asks for.
	NOT_ENOUGH_ITEMS,
	## The line needs more reputation with this vendor.
	LOCKED,
}

var code: Code = Code.OK
## Technical detail for developers and logs (English, not translated).
var message: String = ""
## The inventory transaction result, when the inventory refused.
var inventory_result: IKResult
var item_id: StringName
var amount: int = 0
## Total price paid or received, in [member currency] (the vendor's main currency).
var price: int = 0
var currency: StringName
## What changed hands, item id -> amount: for a purchase everything paid, other
## currencies and barter items included (e.g. {&"gold_coins": 80, &"ruby": 1, &"bone": 4});
## for a sale or a buyback, the main currency.
var costs: Dictionary = {}

var ok: bool:
	get:
		return code == Code.OK


static func success(p_item_id: StringName, p_amount: int, p_price: int, p_currency: StringName) -> SKResult:
	var result := SKResult.new()
	result.item_id = p_item_id
	result.amount = p_amount
	result.price = p_price
	result.currency = p_currency
	if p_price > 0:
		result.costs = {p_currency: p_price}
	return result


static func failure(error_code: Code, error_message: String = "", inventory: IKResult = null) -> SKResult:
	var result := SKResult.new()
	result.code = error_code
	result.message = error_message
	result.inventory_result = inventory
	return result


func code_name() -> String:
	return Code.keys()[code]


func _to_string() -> String:
	if ok:
		return "SKResult(OK, %s x%d for %d %s)" % [item_id, amount, price, currency]
	return "SKResult(%s: %s)" % [code_name(), message]
