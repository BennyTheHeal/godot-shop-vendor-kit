@tool
class_name SKReputationTier
extends Resource
## One reputation level with a vendor ("Stranger", "Regular", "Friend"...): from
## [member min_reputation] up, prices change. Lines of wares can also wait for a
## level ([member SKShopEntry.min_reputation]).

## Reputation needed for this level (the highest level reached applies).
@export var min_reputation: int = 0
## Shown to players (translatable).
@export var display_name: String = ""
## Multiplies the prices the player pays: 0.9 = 10 % off.
@export var buy_multiplier: float = 1.0
## Multiplies what the vendor pays for the player's items: 1.1 = 10 % more.
## Selling still never pays more than buying.
@export var sell_multiplier: float = 1.0


static func make(p_min_reputation: int, p_display_name: String, p_buy: float = 1.0, p_sell: float = 1.0) -> SKReputationTier:
	var tier := SKReputationTier.new()
	tier.min_reputation = p_min_reputation
	tier.display_name = p_display_name
	tier.buy_multiplier = p_buy
	tier.sell_multiplier = p_sell
	return tier
