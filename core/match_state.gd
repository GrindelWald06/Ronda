class_name MatchState
extends RefCounted
## A whole game (partie): a series of rounds until a side reaches the target
## score (41 points). It owns the running scores and the dealer, and creates
## each new RoundState.
##
## Scores are indexed by SIDE (see RoundState). The target is checked at the
## end of a round, once that round's points have been added. If several sides
## reach it in the same round the highest total wins, and an exact tie at the
## top simply means another round is played.

var player_count: int
var target_score: int = RondaRules.WIN_SCORE
## Total points per side, NOT including the round in progress until
## finish_round() is called.
var scores: Array[int] = []
var round_number: int = 0
## The dealer of the current (or next) round. The seat after the dealer plays
## first, and the role moves to the next seat after every round.
var dealer: int = 0
var current_round: RoundState
## True once the current round's points have been added to `scores`.
var round_counted: bool = false


func _init(p_player_count: int = 2, p_first_dealer: int = 0) -> void:
	player_count = p_player_count
	dealer = p_first_dealer % p_player_count
	for _side in (2 if p_player_count == 4 else p_player_count):
		scores.append(0)


## Deals and returns the next round.
func start_round(rng: RandomNumberGenerator = null) -> RoundState:
	round_number += 1
	round_counted = false
	current_round = RoundState.new_round(player_count, dealer, rng)
	return current_round


## Adds the finished round's points to the scores and passes the deal on.
## Does nothing if the round is not finished or was already counted.
func finish_round() -> void:
	if current_round == null or not current_round.finished or round_counted:
		return
	for side in scores.size():
		scores[side] += current_round.round_points[side]
	round_counted = true
	dealer = (dealer + 1) % player_count


func is_over() -> bool:
	return winning_side() != -1


## The side that has won the match, or -1 if nobody has yet (including an
## exact tie at the top).
func winning_side() -> int:
	var best := -1
	var best_score := target_score - 1
	var tied := false
	for side in scores.size():
		if scores[side] > best_score:
			best = side
			best_score = scores[side]
			tied = false
		elif scores[side] == best_score and best != -1:
			tied = true
	return -1 if tied else best
