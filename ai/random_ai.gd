class_name RandomAI
extends AIPlayer
## "Easy" opponent: plays a capturing card whenever it has one, otherwise a
## random card. It always announces.

## When false it plays a completely random card.
var prefer_captures: bool = true


func _init() -> void:
	display_name = "Easy"


func choose_move(state: RoundState, rng: RandomNumberGenerator) -> Move:
	var moves := state.legal_moves()
	var announce := find_announce(moves)
	if announce != null:
		return announce   # announcing is worth points

	var plays := play_moves(moves)
	if prefer_captures:
		var capturing: Array[Move] = []
		for move in plays:
			if not RondaRules.find_capture(move.card, state.table).is_empty():
				capturing.append(move)
		if not capturing.is_empty():
			return capturing[rng.randi_range(0, capturing.size() - 1)]
	return plays[rng.randi_range(0, plays.size() - 1)]
