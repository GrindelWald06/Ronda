class_name RondaRules
extends RefCounted
## Stateless rule helpers for Ronda. Nothing here stores state, so every
## function can be called freely from the engine, the UI or the AI.

const WIN_SCORE := 41
const MIN_PLAYERS := 2
const MAX_PLAYERS := 4

const HAND_SIZE := 3                   # cards per player per deal
const FOUR_PLAYER_OPENING_HAND := 4    # 4 players: first deal only
const TABLE_CARDS_AT_DEAL := 4         # 2 and 3 players only

## The opening table must not contain a pair, nor a "suite" (sequence).
## The Wikipedia page doesn't say how long a sequence has to be to count, so
## this is a house-rule constant: 3 consecutive ranks (in RANK_ORDER, so
## 6-7-10 counts) make the table invalid. Set to 2 for a stricter deal.
const INVALID_TABLE_RUN_LENGTH := 3


# ---------------------------------------------------------------------------
# Capturing
# ---------------------------------------------------------------------------

## Returns the TABLE cards captured when `played` is laid on `table`.
## The played card itself is not included.
##
## The played card must pair with a table card of the same rank. Then the
## capture continues UPWARD through the sequence for as long as the next
## rank is on the table (1 2 3 4 5 6 7 10 11 12, no wrap from 12 to 1).
##
## Example: play a 5 on a table of 5, 6, 7, 10, 12 -> captures 5, 6, 7, 10.
## Returns an empty array when there is no pair (the card must be thrown).
##
## Relies on the table never holding two cards of the same rank, which the
## opening deal and the throw/capture rules guarantee.
static func find_capture(played: Card, table: Array[Card]) -> Array[Card]:
	var taken: Array[Card] = []
	var by_order := {}
	for c in table:
		by_order[c.order_index()] = c
	var o := played.order_index()
	while by_order.has(o):
		taken.append(by_order[o])
		o += 1
	return taken


# ---------------------------------------------------------------------------
# Opening deal
# ---------------------------------------------------------------------------

## Indices (into `cards`) of every card that makes the table invalid: cards
## sharing a rank with another card, or belonging to a run of consecutive
## ranks of length INVALID_TABLE_RUN_LENGTH or more.
static func problem_card_indices(cards: Array[Card]) -> Array[int]:
	var result: Array[int] = []
	var present := {}  # order index -> how many cards have it
	for c in cards:
		var key := c.order_index()
		present[key] = present.get(key, 0) + 1
	for i in cards.size():
		var o := cards[i].order_index()
		var is_problem := false
		if present[o] > 1:
			is_problem = true
		else:
			var run := 1
			var k := o - 1
			while present.has(k):
				run += 1
				k -= 1
			k = o + 1
			while present.has(k):
				run += 1
				k += 1
			is_problem = run >= INVALID_TABLE_RUN_LENGTH
		if is_problem:
			result.append(i)
	return result


static func is_valid_table(cards: Array[Card]) -> bool:
	return problem_card_indices(cards).is_empty()


## Draws the 4 opening table cards. While the table is invalid, the LAST
## problem card goes back into the middle of the talon and is replaced by a
## fresh card, as the rules describe.
static func deal_table(deck: Deck) -> Array[Card]:
	var table := deck.draw_many(TABLE_CARDS_AT_DEAL)
	for _attempt in 1000:
		var problems := problem_card_indices(table)
		if problems.is_empty():
			return table
		var last: int = problems[problems.size() - 1]
		deck.insert_middle(table[last])
		table[last] = deck.draw()
	push_error("RondaRules.deal_table(): could not build a valid table")
	return table


## 4-player opening: a hand of four cards with identical ranks is a false
## deal and everything must be dealt again.
static func has_four_of_a_kind(cards: Array[Card]) -> bool:
	var counts := {}
	for c in cards:
		counts[c.rank] = counts.get(c.rank, 0) + 1
		if counts[c.rank] >= 4:
			return true
	return false


# ---------------------------------------------------------------------------
# End-of-round card scoring
# ---------------------------------------------------------------------------

## Number of cards a side can win without scoring: 13 with 3 players,
## 20 with 2 players or 2 teams of 2.
static func card_threshold(player_count: int) -> int:
	return 13 if player_count == 3 else 20


## Points for the cards won in a round: every card beyond the threshold is 1 point.
static func card_points(cards_won: int, player_count: int) -> int:
	return maxi(0, cards_won - card_threshold(player_count))
