class_name MonteCarloAI
extends AIPlayer
## "Hard" opponent: determinized Monte Carlo.
##
## The AI can't see the other hands or the talon, but it knows exactly which
## cards those must be (see AIKnowledge). So it repeatedly:
##   1. deals the unseen cards at random into "possible worlds",
##   2. tries each of its candidate cards in every world,
##   3. plays the rest of the current deal out with a fast, simple policy,
##   4. scores the outcome (points + cards won, me minus the others).
## The card with the best average score over all the worlds is played.
## All candidates are tried in the same worlds and with the same random numbers
## so they are compared fairly.
##
## It thinks for about `think_time_ms` milliseconds per move, on the main thread,
## so the window freezes briefly. Lower the time (or max_samples) if that bothers
## you.
##
## Not used yet: an opponent's announcement (they hold a pair or three of a kind
## somewhere in their hand) is ignored when dealing the possible worlds.

## Time budget per decision.
var think_time_ms: int = 350
## Always run at least this many worlds, however long that takes.
var min_samples: int = 12
var max_samples: int = 800
## Value of one captured card compared to one point. Cards beyond the threshold
## score at the end of the round, so a card lead is worth something even while
## the round is still in progress.
var card_weight: float = 0.5
## false: look only until the current deal is played out. true: until the round
## ends (slower, and noisier for the same time budget).
var play_full_round: bool = false


func _init() -> void:
	display_name = "Hard"


func choose_move(state: RoundState, rng: RandomNumberGenerator) -> Move:
	var moves := state.legal_moves()
	var announce := find_announce(moves)
	if announce != null:
		return announce
	var plays := play_moves(moves)
	if plays.size() == 1:
		return plays[0]

	var seat := state.current_player
	var knowledge := AIKnowledge.new(state, seat)
	var totals: Array[float] = []
	for _i in plays.size():
		totals.append(0.0)

	var samples := 0
	var deadline := Time.get_ticks_msec() + think_time_ms
	while samples < max_samples and (samples < min_samples or Time.get_ticks_msec() < deadline):
		var world := _sample_world(state, knowledge, rng)
		var rollout_seed := rng.randi()
		for i in plays.size():
			var simulation := world.clone()
			simulation.apply_move(plays[i])
			totals[i] += _rollout(simulation, seat, rollout_seed)
		samples += 1

	var best_index := 0
	for i in plays.size():
		if totals[i] > totals[best_index]:
			best_index = i
	return plays[best_index]


## One possible world: a copy of the state in which the other hands and the talon
## are replaced by a random deal of the unseen cards.
func _sample_world(
	state: RoundState, knowledge: AIKnowledge, rng: RandomNumberGenerator
) -> RoundState:
	var world := state.clone()

	var pool := Card.copy_array(knowledge.unseen)
	for i in range(pool.size() - 1, 0, -1):   # Fisher-Yates shuffle
		var j := rng.randi_range(0, i)
		var swap := pool[i]
		pool[i] = pool[j]
		pool[j] = swap

	var next := 0
	for other in world.player_count:
		if other == knowledge.seat:
			continue
		var hand: Array[Card] = []
		for _n in knowledge.opponent_hand_sizes[other]:
			hand.append(pool[next])
			next += 1
		world.hands[other] = hand

	var rest: Array[Card] = []
	while next < pool.size():
		rest.append(pool[next])
		next += 1
	world.talon.cards = rest
	return world


## Plays `simulation` forward with the fast policy and returns its score for `seat`.
func _rollout(simulation: RoundState, seat: int, rollout_seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = rollout_seed
	var start_talon := simulation.talon_size()
	var guard := 300
	while not simulation.finished and guard > 0:
		# A smaller talon means a new deal has started: stop there.
		if not play_full_round and simulation.talon_size() != start_talon:
			break
		guard -= 1
		simulation.apply_move(_fast_policy(simulation, rng))
	return _evaluate(simulation, seat)


## Cheap stand-in for a player during simulations: announce, else take the
## biggest capture, else throw a random card.
func _fast_policy(simulation: RoundState, rng: RandomNumberGenerator) -> Move:
	var moves := simulation.legal_moves()
	var best: Move = null
	var best_taken := 0
	for move in moves:
		if move.type == Move.Type.ANNOUNCE:
			return move
		var taken := RondaRules.find_capture(move.card, simulation.table).size()
		if taken > best_taken:
			best_taken = taken
			best = move
	if best != null:
		return best
	return moves[rng.randi_range(0, moves.size() - 1)]


## My side's points and cards minus the average of the other sides'.
func _evaluate(simulation: RoundState, seat: int) -> float:
	var my_side := simulation.side_of(seat)
	var mine := float(simulation.round_points[my_side]) \
		+ card_weight * float(simulation.cards_won(my_side))
	var others := 0.0
	var other_sides := 0
	for side in simulation.side_count():
		if side == my_side:
			continue
		others += float(simulation.round_points[side]) \
			+ card_weight * float(simulation.cards_won(side))
		other_sides += 1
	return mine - others / float(other_sides)
