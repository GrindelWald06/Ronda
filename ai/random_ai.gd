class_name RandomAI
extends RefCounted
## First, very simple opponent. Any future AI only has to provide the same
## method, choose_move(state, rng) -> Move, to be a drop-in replacement in
## GameController.
##
## Keep in mind that choose_move() is called again after an ANNOUNCE move (the
## announcement does not use up the turn), and must then return a card to play.

## When true the AI plays a capturing card whenever it has one (picked at
## random among them). When false it plays a completely random card.
var prefer_captures: bool = true


func choose_move(state: RoundState, rng: RandomNumberGenerator) -> Move:
	var plays: Array[Move] = []
	for move in state.legal_moves():
		if move.type == Move.Type.ANNOUNCE:
			return move   # always announce: it is worth points
		plays.append(move)

	if prefer_captures:
		var capturing: Array[Move] = []
		for move in plays:
			if not RondaRules.find_capture(move.card, state.table).is_empty():
				capturing.append(move)
		if not capturing.is_empty():
			return capturing[rng.randi_range(0, capturing.size() - 1)]
	return plays[rng.randi_range(0, plays.size() - 1)]
