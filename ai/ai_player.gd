class_name AIPlayer
extends RefCounted
## Base class of every computer opponent. GameController only relies on
## choose_move(), so any subclass can be dropped in.
##
## choose_move() is called on the AI's turn with the REAL RoundState, which also
## contains the other players' hands. An AI must play fair and never read
## another seat's cards: use AIKnowledge, which exposes only what a player
## could know (own hand, table, captured piles, and how many cards the others hold).
##
## choose_move() is called again after an ANNOUNCE move (announcing does not use
## up the turn) and must then return a card to play.

## Short name for menus and logs.
var display_name: String = "AI"


func choose_move(_state: RoundState, _rng: RandomNumberGenerator) -> Move:
	push_error("AIPlayer.choose_move() must be overridden")
	return null


## The ANNOUNCE move in `moves`, or null if there is none.
static func find_announce(moves: Array[Move]) -> Move:
	for move in moves:
		if move.type == Move.Type.ANNOUNCE:
			return move
	return null


## Only the PLAY moves of `moves`.
static func play_moves(moves: Array[Move]) -> Array[Move]:
	var plays: Array[Move] = []
	for move in moves:
		if move.type == Move.Type.PLAY:
			plays.append(move)
	return plays
