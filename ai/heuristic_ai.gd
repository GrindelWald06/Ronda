class_name HeuristicAI
extends AIPlayer
## "Medium" opponent. Scores every card it could play as
##
##     what I win now  -  what the opponent probably wins next
##                     +  a discounted bonus for what I can win on my next turn
##
## and plays the best one. It keeps track of the cards already seen, so it knows
## which ranks the opponent can still hold. A rank whose other cards are all
## on the table or in captured piles is completely safe to leave out.
##
## Values are counted in "cards moved to a pile"; a missa is worth a bit more.

const MISSA_BONUS := 1.5
## How much a capture I could make next turn is worth compared to one now: the
## opponent may well spoil it before I get there.
const FOLLOW_UP_WEIGHT := 0.4


func _init() -> void:
	display_name = "Medium"


func choose_move(state: RoundState, rng: RandomNumberGenerator) -> Move:
	var moves := state.legal_moves()
	var announce := find_announce(moves)
	if announce != null:
		return announce

	var knowledge := AIKnowledge.new(state, state.current_player)
	var best: Move = null
	var best_score := -INF
	for move in play_moves(moves):
		# The tiny random term only breaks ties, so play isn't fully predictable.
		var score := _score_play(state, knowledge, move.card) + rng.randf() * 0.01
		if score > best_score:
			best_score = score
			best = move
	return best


func _score_play(state: RoundState, knowledge: AIKnowledge, card: Card) -> float:
	var table := state.table
	var taken := RondaRules.find_capture(card, table)
	var new_table: Array[Card] = []
	var gain := 0.0

	if taken.is_empty():
		# No pair: the card is thrown onto the table.
		new_table = Card.copy_array(table)
		new_table.append(card)
	else:
		var taken_ids := {}
		for c in taken:
			taken_ids[c.id()] = true
		for c in table:
			if not taken_ids.has(c.id()):
				new_table.append(c)
		gain = 1.0 + float(taken.size())   # my card plus the cards I take
		if new_table.is_empty() and not state.is_last_hand:
			gain += MISSA_BONUS

	var risk := _expected_opponent_gain(new_table, knowledge, state.is_last_hand)
	var follow_up := _follow_up_value(state, card, new_table)
	return gain - risk + FOLLOW_UP_WEIGHT * follow_up


## What the opponent is expected to capture next turn from `table`.
## For every card on the table there is one capture, made with a card of the
## same rank: its value is the length of the run it takes, and its probability
## is the chance the opponent holds that rank. The opponent plays only one card,
## so we take the expected value of the BEST capture available: options are
## sorted by value and each is only reachable if none of the better ones was.
func _expected_opponent_gain(
	table: Array[Card], knowledge: AIKnowledge, is_last_hand: bool
) -> float:
	var by_order := {}
	for c in table:
		by_order[c.order_index()] = c

	var options: Array = []   # each entry: [value, probability]
	for c in table:
		var run := 0
		var order := c.order_index()
		while by_order.has(order):
			run += 1
			order += 1
		var value := 1.0 + float(run)
		if run == table.size() and not is_last_hand:
			value += MISSA_BONUS
		options.append([value, knowledge.probability_opponents_hold(c.rank)])
	options.sort_custom(func(a, b): return a[0] > b[0])

	var expected := 0.0
	var nothing_better := 1.0
	for option in options:
		expected += option[0] * option[1] * nothing_better
		nothing_better *= 1.0 - option[1]
	return expected


## The best capture one of my REMAINING cards could make on `new_table`.
func _follow_up_value(state: RoundState, played: Card, new_table: Array[Card]) -> float:
	var best := 0.0
	for c in state.hand_of(state.current_player):
		if c.id() == played.id():
			continue
		var run := RondaRules.find_capture(c, new_table).size()
		if run > 0:
			best = maxf(best, 1.0 + float(run))
	return best
