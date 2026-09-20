class_name Move
extends RefCounted
## A player's choice of action. For now the only action is playing a card
## from hand: whether it captures is decided automatically by the rules
## (a card that pairs with a table card always captures, otherwise it is thrown).
##
## Later phases (announcements, tapping, passing on a tap) can add a `type`
## field and more constructors without touching the code that only plays cards.

var player: int = -1
var card: Card


static func play(p_player: int, p_card: Card) -> Move:
	var move := Move.new()
	move.player = p_player
	move.card = p_card
	return move


func _to_string() -> String:
	return "Player %d plays %s" % [player, card]
