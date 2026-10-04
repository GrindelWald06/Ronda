class_name Move
extends RefCounted
## A player's choice of action.
##
##  - PLAY: play a card from hand. Whether it captures is decided by the rules
##    (a card that pairs with a table card always captures, otherwise it is
##    thrown onto the table). Only possible when no tap is waiting for an answer.
##  - ANNOUNCE: declare the ronda or tringla you hold. It does not use up the
##    turn: the same player still has to play a card afterwards. Only possible
##    before your first card of a deal.
##  - TAP ("Bount"): pair the card the previous player has just THROWN, but
##    instead of collecting the pair at once, stack the two cards and let the
##    following players answer. See RoundState.can_tap().
##  - COUNTER ("Khamsa" / "Aachra"): while a tap is waiting for an answer, add a
##    card of the same rank on top of the stack.
##  - DECLINE: while a tap is waiting for an answer, let it go. The stack is
##    settled and the player then carries on with a normal turn.

enum Type { PLAY, ANNOUNCE, TAP, COUNTER, DECLINE }

var type: int = Type.PLAY
var player: int = -1
var card: Card   # PLAY, TAP and COUNTER moves only


static func play(p_player: int, p_card: Card) -> Move:
	return _make(Type.PLAY, p_player, p_card)


## The engine works out which announcement (ronda or tringla, and of which
## rank) the player's hand allows, so there is nothing more to specify.
static func announce(p_player: int) -> Move:
	return _make(Type.ANNOUNCE, p_player, null)


static func tap(p_player: int, p_card: Card) -> Move:
	return _make(Type.TAP, p_player, p_card)


static func counter(p_player: int, p_card: Card) -> Move:
	return _make(Type.COUNTER, p_player, p_card)


static func decline(p_player: int) -> Move:
	return _make(Type.DECLINE, p_player, null)


static func _make(p_type: int, p_player: int, p_card: Card) -> Move:
	var move := Move.new()
	move.type = p_type
	move.player = p_player
	move.card = p_card
	return move


func _to_string() -> String:
	match type:
		Type.ANNOUNCE:
			return "Player %d announces" % player
		Type.TAP:
			return "Player %d taps with %s" % [player, card]
		Type.COUNTER:
			return "Player %d answers with %s" % [player, card]
		Type.DECLINE:
			return "Player %d lets the tap go" % player
	return "Player %d plays %s" % [player, card]
