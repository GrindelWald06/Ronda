class_name RandomAI
extends RefCounted
## First, very simple opponent. Any future AI only has to provide the same
## method, choose_move(state, rng) -> Move, to be a drop-in replacement in
## GameController.

## When true the AI plays a capturing card whenever it has one (picked at
## random among them). When false it plays a completely random card.
var prefer_captures: bool = true


func choose_move(state: RoundState, rng: RandomNumberGenerator) -> Move:
	var moves := state.legal_moves()
	if prefer_captures:
		var capturing: Array[Move] = []
		for move in moves:
			if not RondaRules.find_capture(move.card, state.table).is_empty():
				capturing.append(move)
		if not capturing.is_empty():
			return capturing[rng.randi_range(0, capturing.size() - 1)]
	return moves[rng.randi_range(0, moves.size() - 1)]
