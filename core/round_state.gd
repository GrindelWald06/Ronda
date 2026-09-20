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
## A "side" is whoever collects cards and points together. With 2 or 3 players
## each seat is its own side. With 4 players seats 0 and 2 form side 0 and
## seats 1 and 3 form side 1 (partners sit opposite each other). `captured` and
## `round_points` are indexed by side.
##
## CARD FLOW
## talon -> hands (dealt in blocks) and table (opening only) -> captured piles.
## Total number of cards is always 40.
##
## ANNOUNCEMENTS (see Move.announce)
## Before playing their first card of a deal a player may announce the ronda or
## tringla they hold. Once every player has played a first card the
## announcements are compared and the points are awarded. A player who hides a
## ronda and then plays both cards of the pair is penalised as soon as it comes
## to light.
##
## POINTS
## Everything that scores during the round goes into `round_points`: announcements
## and penalties, missa (clearing the table, except on the last hand) and, when
## the round ends, one point per card beyond the threshold. The match score
## across rounds is kept by MatchState.

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

## Points scored this round so far (announcements, penalties), indexed by SIDE.
var round_points: Array[int] = []
## Announcements made in the current deal, in the order they were made.
var announcements: Array[Announcement] = []

## Seat that made the most recent capture (-1 if nobody has captured yet).
var last_capturer: int = -1
## True once the dealer's final deal has been made ("Khlassou!").
var is_last_hand: bool = false
var finished: bool = false

# Per-deal bookkeeping, reset by _begin_deal_tracking(). All indexed by seat.
var _announcement_by_seat: Array = []   # Announcement, or null if none
var _has_played: Array[bool] = []       # has played a card in this deal
var _played_rank_counts: Array = []     # Dictionary: rank -> times played this deal
var _hidden_penalized: Array[bool] = [] # already penalised for a hidden ronda
var _first_plays_left: int = 0          # seats yet to play their first card


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
		round_points.append(0)
	_begin_deal_tracking()


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
## the first player. Flags the last hand when the talon runs dry, and starts
## a fresh round of announcements.
func _deal_hands(cards_each: int) -> void:
	for seat in player_count:
		hands[seat] = talon.draw_many(cards_each)
	current_player = first_player()
	is_last_hand = talon.is_empty()
	_begin_deal_tracking()


func _begin_deal_tracking() -> void:
	announcements.clear()
	_announcement_by_seat.clear()
	_has_played.clear()
	_played_rank_counts.clear()
	_hidden_penalized.clear()
	for _seat in player_count:
		_announcement_by_seat.append(null)
		_has_played.append(false)
		_played_rank_counts.append({})
		_hidden_penalized.append(false)
	_first_plays_left = player_count


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


## The announcement `seat` could make right now, or null if it can't announce:
## it must be their turn, they must not have played a card yet in this deal or
## announced already, and their hand must hold a pair or three of a kind.
func available_announcement(seat: int) -> Announcement:
	if finished or seat != current_player:
		return null
	if _has_played[seat] or _announcement_by_seat[seat] != null:
		return null
	var hand: Array[Card] = hands[seat]
	return RondaRules.find_announcement(seat, hand)


# ---------------------------------------------------------------------------
# Playing
# ---------------------------------------------------------------------------

## All moves available to the current player: one PLAY per card in hand, plus
## an ANNOUNCE move (last in the list) when an announcement is possible. Empty
## once the round is finished.
func legal_moves() -> Array[Move]:
	var moves: Array[Move] = []
	if finished:
		return moves
	var hand: Array[Card] = hands[current_player]
	for card in hand:
		moves.append(Move.play(current_player, card))
	if available_announcement(current_player) != null:
		moves.append(Move.announce(current_player))
	return moves


func is_legal(move: Move) -> bool:
	if finished or move == null:
		return false
	if move.player != current_player:
		return false
	if move.type == Move.Type.ANNOUNCE:
		return available_announcement(move.player) != null
	if move.card == null:
		return false
	var hand: Array[Card] = hands[current_player]
	return _index_of(hand, move.card) != -1


## Applies a move and returns a MoveResult describing what happened. An illegal
## move changes nothing and comes back with `ok == false`.
func apply_move(move: Move) -> MoveResult:
	if not is_legal(move):
		return MoveResult.illegal("Illegal move: %s" % [move])
	if move.type == Move.Type.ANNOUNCE:
		return _apply_announce()
	return _apply_play(move)


## Records the announcement. The turn does NOT advance: the same player still
## has to play a card.
func _apply_announce() -> MoveResult:
	var announcement := available_announcement(current_player)
	announcements.append(announcement)
	_announcement_by_seat[current_player] = announcement
	var result := MoveResult.new()
	result.kind = Move.Type.ANNOUNCE
	result.player = current_player
	result.announcement = announcement
	return result


func _apply_play(move: Move) -> MoveResult:
	var seat := current_player
	var hand: Array[Card] = hands[seat]
	var hand_index := _index_of(hand, move.card)
	var played: Card = hand[hand_index]  # use our own instance, not the caller's
	hand.remove_at(hand_index)

	var result := MoveResult.new()
	result.player = seat
	result.played = played
	result.was_last_hand = is_last_hand

	var taken := RondaRules.find_capture(played, table)
	if taken.is_empty():
		table.append(played)  # no pair: the card is thrown onto the table
	else:
		for c in taken:
			table.erase(c)
		var pile: Array[Card] = captured[side_of(seat)]
		pile.append(played)
		pile.append_array(taken)
		last_capturer = seat
		result.was_capture = true
		result.captured_cards = taken
		result.cleared_table = table.is_empty()
		if result.cleared_table and not is_last_hand:
			_award(side_of(seat), RondaRules.MISSA_POINTS, "Missa", result)

	# Must happen before a possible re-deal, which resets the per-deal tracking.
	_register_play(seat, played, result)

	current_player = next_player(seat)

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
	# Every card beyond the threshold is worth a point.
	for side in side_count():
		_award(side, card_points(side), "%d cards" % cards_won(side), result)


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
# Announcements and points
# ---------------------------------------------------------------------------

## Bookkeeping after every card played: spots a hidden ronda and settles the
## announcements once everybody has played a first card.
func _register_play(seat: int, played: Card, result: MoveResult) -> void:
	# A pair that was never announced comes to light when the player has played
	# two cards of the same rank from the same deal.
	var counts: Dictionary = _played_rank_counts[seat]
	var times: int = counts.get(played.rank, 0) + 1
	counts[played.rank] = times
	if times >= 2 and _announcement_by_seat[seat] == null and not _hidden_penalized[seat]:
		_hidden_penalized[seat] = true
		_award(_penalty_side(seat), RondaRules.HIDDEN_RONDA_PENALTY,
			"Hidden ronda penalty", result)

	# Announcements are final once every seat has played its first card.
	if not _has_played[seat]:
		_has_played[seat] = true
		_first_plays_left -= 1
		if _first_plays_left == 0:
			_resolve_announcements(result)


## Compares the announcements of the deal and awards the points:
##  - Tringlas: 5 points each. The strongest tringla takes all the tringla points
##    AND the points of every ronda announced.
##  - Otherwise every ronda announced puts one token in the pot, and the pot goes
##    to the strongest ronda. If several players share the strongest ronda they
##    split the pot equally; a token that doesn't divide goes back to the bank
##    (three rondas, two of them tied for best: one token each, one to the bank).
@warning_ignore("integer_division")
func _resolve_announcements(result: MoveResult) -> void:
	var tringlas: Array[Announcement] = []
	var rondas: Array[Announcement] = []
	for a in announcements:
		if a.kind == Announcement.Kind.TRINGLA:
			tringlas.append(a)
		else:
			rondas.append(a)

	if not tringlas.is_empty():
		var best_tringla := _strongest(tringlas)
		var total := RondaRules.TRINGLA_POINTS * tringlas.size() + rondas.size()
		_award(side_of(best_tringla.seat), total, "Tringla of %d" % best_tringla.rank, result)
	elif not rondas.is_empty():
		var best_ronda := _strongest(rondas)
		var holders: Array[Announcement] = []
		for a in rondas:
			if a.rank == best_ronda.rank:
				holders.append(a)
		var share := rondas.size() / holders.size()
		for a in holders:
			_award(side_of(a.seat), share, "Ronda of %d" % a.rank, result)


static func _strongest(list: Array[Announcement]) -> Announcement:
	var best: Announcement = null
	for a in list:
		if best == null or a.strength() > best.strength():
			best = a
	return best


## Who receives the penalty for a hidden ronda. With 2 players or 2 teams: the
## other side. With 3 players: the opponent holding the strongest announcement
## of the deal, or the next seat in play order if nobody announced.
func _penalty_side(offender_seat: int) -> int:
	var offender_side := side_of(offender_seat)
	if side_count() == 2:
		return 1 - offender_side
	var best: Announcement = null
	for a in announcements:
		if side_of(a.seat) == offender_side:
			continue
		if best == null or a.strength() > best.strength():
			best = a
	if best != null:
		return side_of(best.seat)
	return side_of(next_player(offender_seat))


func _award(side: int, points: int, reason: String, result: MoveResult) -> void:
	if points <= 0:
		return
	round_points[side] += points
	result.awards.append(PointAward.new(side, points, reason))


# ---------------------------------------------------------------------------
# Copying (for AI look-ahead)
# ---------------------------------------------------------------------------

## Independent copy of the whole state. Card and Announcement objects are
## shared between the copies (they are immutable), every container is duplicated.
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
		copy._announcement_by_seat[seat] = _announcement_by_seat[seat]
		copy._has_played[seat] = _has_played[seat]
		copy._hidden_penalized[seat] = _hidden_penalized[seat]
		var counts: Dictionary = _played_rank_counts[seat]
		copy._played_rank_counts[seat] = counts.duplicate()
	for side in side_count():
		copy.captured[side] = Card.copy_array(captured[side])
		copy.round_points[side] = round_points[side]
	copy.announcements.append_array(announcements)
	copy._first_plays_left = _first_plays_left
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
		lines.append("Side %d: %d cards won, %d points" % [side, cards_won(side), round_points[side]])
	return "\n".join(lines)


static func _cards_to_string(cards: Array[Card]) -> String:
	var parts := PackedStringArray()
	for c in cards:
		parts.append(str(c))
	return "[" + ", ".join(parts) + "]"
