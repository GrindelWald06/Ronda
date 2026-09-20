class_name RoundState
extends RefCounted
## The complete state of ONE round (manche) of Ronda, and the code that
## advances it. No nodes, no signals, no UI: the UI only reads this object and
## sends Moves to it, and AI players can clone() it to try moves out.
##
## SEATS AND TURN ORDER
## Seats are numbered 0..player_count-1 in PLAY ORDER: after seat p comes seat
## (p + 1) % player_count. The first to play in every hand is the seat right
## after the dealer, i.e. first_player(). Whether that is clockwise or
## counter-clockwise on screen is purely a display matter.
##
## SIDES
## A "side" is whoever collects cards together. With 2 or 3 players each seat
## is its own side. With 4 players seats 0 and 2 form side 0 and seats 1 and 3
## form side 1 (partners sit opposite each other). `captured` is indexed by side.
##
## CARD FLOW
## talon -> hands (dealt in blocks) and table (opening only) -> captured piles.
## Total number of cards is always 40.

var player_count: int
var dealer: int = 0
var current_player: int = 0

## Array of Array[Card], indexed by seat. (Kept as a plain Array of typed
## arrays so each hand keeps its Array[Card] type.)
var hands: Array = []
## Cards on the table, oldest first. Never holds two cards of the same rank.
var table: Array[Card] = []
var talon: Deck
## Array of Array[Card], indexed by SIDE, holding cards won this round.
var captured: Array = []

## Seat that made the most recent capture (-1 if nobody has captured yet).
var last_capturer: int = -1
## True once the dealer's final deal has been made ("Khlassou!").
var is_last_hand: bool = false
var finished: bool = false


func _init(p_player_count: int = 2) -> void:
	assert(
		p_player_count >= RondaRules.MIN_PLAYERS and p_player_count <= RondaRules.MAX_PLAYERS,
		"Ronda is played by 2, 3 or 4 players"
	)
	player_count = p_player_count
	talon = Deck.new()
	for _seat in player_count:
		var hand: Array[Card] = []
		hands.append(hand)
	for _side in side_count():
		var pile: Array[Card] = []
		captured.append(pile)


# ---------------------------------------------------------------------------
# Creating a round
# ---------------------------------------------------------------------------

## Deals a new round. `rng` may be a seeded RandomNumberGenerator for
## reproducible rounds.
##  - 2 or 3 players: 3 cards each and 4 valid cards on the table.
##  - 4 players: 4 cards each and an empty table (first deal only).
static func new_round(
	p_player_count: int, p_dealer: int = 0, rng: RandomNumberGenerator = null
) -> RoundState:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var state := RoundState.new(p_player_count)
	state.dealer = p_dealer % p_player_count
	if p_player_count == 4:
		state._deal_four_player_opening(rng)
	else:
		state._deal_standard_opening(rng)
	return state


func _deal_standard_opening(rng: RandomNumberGenerator) -> void:
	talon = Deck.create_full()
	talon.shuffle(rng)
	_deal_hands(RondaRules.HAND_SIZE)
	table = RondaRules.deal_table(talon)


func _deal_four_player_opening(rng: RandomNumberGenerator) -> void:
	while true:
		talon = Deck.create_full()
		talon.shuffle(rng)
		_deal_hands(RondaRules.FOUR_PLAYER_OPENING_HAND)
		var false_deal := false
		for hand in hands:
			if RondaRules.has_four_of_a_kind(hand):
				false_deal = true
				break
		if not false_deal:
			return
		# False deal: loop around, reshuffle and deal again.


## Deals `cards_each` cards to every seat from the talon and hands the turn to
## the first player. Flags the last hand when the talon runs dry.
func _deal_hands(cards_each: int) -> void:
	for seat in player_count:
		hands[seat] = talon.draw_many(cards_each)
	current_player = first_player()
	is_last_hand = talon.is_empty()


# ---------------------------------------------------------------------------
# Seats and sides
# ---------------------------------------------------------------------------

func first_player() -> int:
	return (dealer + 1) % player_count


func next_player(seat: int) -> int:
	return (seat + 1) % player_count


func side_count() -> int:
	return 2 if player_count == 4 else player_count


func side_of(seat: int) -> int:
	return seat % 2 if player_count == 4 else seat


# ---------------------------------------------------------------------------
# Reading the state (do not modify the returned arrays)
# ---------------------------------------------------------------------------

func hand_of(seat: int) -> Array[Card]:
	return hands[seat]


func captured_by_side(side: int) -> Array[Card]:
	return captured[side]


func cards_won(side: int) -> int:
	var pile: Array[Card] = captured[side]
	return pile.size()


## Points a side earns from the number of cards it won (see RondaRules).
## Only meaningful once the round is finished.
func card_points(side: int) -> int:
	return RondaRules.card_points(cards_won(side), player_count)


func talon_size() -> int:
	return talon.size()


# ---------------------------------------------------------------------------
# Playing
# ---------------------------------------------------------------------------

## All moves available to the current player: one per card in hand. Empty once
## the round is finished.
func legal_moves() -> Array[Move]:
	var moves: Array[Move] = []
	if finished:
		return moves
	var hand: Array[Card] = hands[current_player]
	for card in hand:
		moves.append(Move.play(current_player, card))
	return moves


func is_legal(move: Move) -> bool:
	if finished or move == null or move.card == null:
		return false
	if move.player != current_player:
		return false
	var hand: Array[Card] = hands[current_player]
	return _index_of(hand, move.card) != -1


## Applies a move and returns a MoveResult describing what happened. An illegal
## move changes nothing and comes back with `ok == false`.
func apply_move(move: Move) -> MoveResult:
	if not is_legal(move):
		return MoveResult.illegal("Illegal move: %s" % [move])

	var hand: Array[Card] = hands[current_player]
	var hand_index := _index_of(hand, move.card)
	var played: Card = hand[hand_index]  # use our own instance, not the caller's
	hand.remove_at(hand_index)

	var result := MoveResult.new()
	result.player = current_player
	result.played = played
	result.was_last_hand = is_last_hand

	var taken := RondaRules.find_capture(played, table)
	if taken.is_empty():
		table.append(played)  # no pair: the card is thrown onto the table
	else:
		for c in taken:
			table.erase(c)
		var pile: Array[Card] = captured[side_of(current_player)]
		pile.append(played)
		pile.append_array(taken)
		last_capturer = current_player
		result.was_capture = true
		result.captured_cards = taken
		result.cleared_table = table.is_empty()

	current_player = next_player(current_player)

	if _all_hands_empty():
		if talon.is_empty():
			_finish_round(result)
		else:
			_deal_hands(RondaRules.HAND_SIZE)
			result.new_hands_dealt = true
	return result


func _finish_round(result: MoveResult) -> void:
	finished = true
	result.round_over = true
	# Whoever made the last capture takes everything left on the table.
	# (If nobody captured all round, which is practically impossible, the
	# cards simply stay on the table.)
	if last_capturer != -1 and not table.is_empty():
		var pile: Array[Card] = captured[side_of(last_capturer)]
		pile.append_array(table)
		result.swept_by = last_capturer
		result.swept_cards = Card.copy_array(table)
		table.clear()


func _all_hands_empty() -> bool:
	for hand in hands:
		if not hand.is_empty():
			return false
	return true


static func _index_of(cards: Array[Card], card: Card) -> int:
	var wanted := card.id()
	for i in cards.size():
		if cards[i].id() == wanted:
			return i
	return -1


# ---------------------------------------------------------------------------
# Copying (for AI look-ahead)
# ---------------------------------------------------------------------------

## Independent copy of the whole state. Card objects are shared between the
## copies (they are immutable), every container is duplicated.
func clone() -> RoundState:
	var copy := RoundState.new(player_count)
	copy.dealer = dealer
	copy.current_player = current_player
	copy.last_capturer = last_capturer
	copy.is_last_hand = is_last_hand
	copy.finished = finished
	copy.table = Card.copy_array(table)
	copy.talon = talon.clone()
	for seat in player_count:
		copy.hands[seat] = Card.copy_array(hands[seat])
	for side in side_count():
		copy.captured[side] = Card.copy_array(captured[side])
	return copy


# ---------------------------------------------------------------------------
# Debugging
# ---------------------------------------------------------------------------

func debug_string() -> String:
	var lines := PackedStringArray()
	lines.append(
		"To play: seat %d | dealer: %d | talon: %d | last hand: %s | finished: %s"
		% [current_player, dealer, talon.size(), is_last_hand, finished]
	)
	lines.append("Table: %s" % _cards_to_string(table))
	for seat in player_count:
		lines.append("Hand %d: %s" % [seat, _cards_to_string(hands[seat])])
	for side in side_count():
		lines.append("Side %d has won %d cards" % [side, cards_won(side)])
	return "\n".join(lines)


static func _cards_to_string(cards: Array[Card]) -> String:
	var parts := PackedStringArray()
	for c in cards:
		parts.append(str(c))
	return "[" + ", ".join(parts) + "]"
