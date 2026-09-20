class_name AIKnowledge
extends RefCounted
## What a player can legitimately know about a round, worked out from the real
## RoundState WITHOUT looking at anybody else's hand.
##
## Public information: the table, every captured pile (all captures happen face
## up in front of everyone), your own hand, and how many cards the others hold.
## Everything else, i.e. the other hands and the talon, is "unseen".

var seat: int
## Cards that are somewhere in the other hands or in the talon.
var unseen: Array[Card] = []
## rank -> how many unseen cards have that rank.
var unseen_rank_counts := {}
## seat -> number of cards in that hand (only the count is public).
var opponent_hand_sizes := {}
var opponent_cards_total: int = 0


func _init(state: RoundState, p_seat: int) -> void:
	seat = p_seat
	var known := {}   # card id -> true
	for c in state.hand_of(seat):
		known[c.id()] = true
	for c in state.table:
		known[c.id()] = true
	for side in state.side_count():
		for c in state.captured_by_side(side):
			known[c.id()] = true

	for card_id in Card.DECK_SIZE:
		if known.has(card_id):
			continue
		var card := Card.from_id(card_id)
		unseen.append(card)
		unseen_rank_counts[card.rank] = unseen_rank_counts.get(card.rank, 0) + 1

	for other in state.player_count:
		if other != seat:
			var count: int = state.hand_of(other).size()   # the count only
			opponent_hand_sizes[other] = count
			opponent_cards_total += count


## Chance that at least one card of `rank` is in the opponents' hands, given
## the unseen cards (the opponents' hands are a random sample of them).
func probability_opponents_hold(rank: int) -> float:
	var total := unseen.size()
	var matching: int = unseen_rank_counts.get(rank, 0)
	var drawn := opponent_cards_total
	if matching == 0 or drawn == 0 or total == 0:
		return 0.0
	var none := 1.0   # chance that none of the drawn cards has this rank
	for i in drawn:
		none *= float(total - matching - i) / float(total - i)
	return 1.0 - clampf(none, 0.0, 1.0)
