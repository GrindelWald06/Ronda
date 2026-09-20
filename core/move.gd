class_name Move
extends RefCounted
## A player's choice of action.
##
##  - PLAY: play a card from hand. Whether it captures is decided by the rules
##    (a card that pairs with a table card always captures, otherwise it is
##    thrown onto the table).
##  - ANNOUNCE: declare the ronda or tringla you hold. It does not use up the
##    turn: the same player still has to play a card afterwards. Only possible
##    before your first card of a deal.
##
## Later phases (tapping, passing on a tap) can add more types.

enum Type { PLAY, ANNOUNCE }

var type: int = Type.PLAY
var player: int = -1
var card: Card   # only used by PLAY moves


static func play(p_player: int, p_card: Card) -> Move:
	var move := Move.new()
	move.type = Type.PLAY
	move.player = p_player
	move.card = p_card
	return move


## The engine works out which announcement (ronda or tringla, and of which
## rank) the player's hand allows, so there is nothing more to specify.
static func announce(p_player: int) -> Move:
	var move := Move.new()
	move.type = Type.ANNOUNCE
	move.player = p_player
	return move


func _to_string() -> String:
	if type == Type.ANNOUNCE:
		return "Player %d announces" % player
	return "Player %d plays %s" % [player, card]
