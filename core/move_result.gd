class_name MoveResult
extends RefCounted
## Everything that happened when a Move was applied. RoundState.apply_move()
## returns one of these so a controller can drive animations, sounds and
## (in later phases) scoring without the engine knowing anything about them.

## False if the move was rejected; the state is left untouched and `error`
## explains why.
var ok: bool = true
var error: String = ""

## The Move.Type of the move (PLAY, ANNOUNCE, TAP, COUNTER or DECLINE).
var kind: int = Move.Type.PLAY
var player: int = -1

## PLAY, TAP and COUNTER moves: the card that was played. Null for ANNOUNCE and
## DECLINE moves.
var played: Card
## ANNOUNCE moves: what was announced.
var announcement: Announcement

## Points scored by this move (announcements are settled once every player has
## played their first card of the deal; a hidden ronda is penalised the moment
## it comes to light).
var awards: Array[PointAward] = []

## True if cards were collected by this move: a card that paired with a table
## card, or a tap that has just been settled (which can also happen on a DECLINE).
var was_capture: bool = false
## The seat that collected them.
var capturer: int = -1
## Cards collected, EXCLUDING the card played by this very move (if any). For a
## normal capture: the paired card and the run above it. For a settled tap: the
## rest of the stack, then the run above it. Always starts with the card the
## played card lands on.
var captured_cards: Array[Card] = []

## A TAP or COUNTER left the chain waiting for the next player's answer: the
## played card is stacked on the tapped card and nothing is collected yet.
var tap_pending: bool = false
## This move settled a tap chain (the scorer is `capturer`, the awards say how
## many points it was worth).
var chain_resolved: bool = false
## Number of stacked cards when it was settled: 2 = Bount, 3 = Khamsa, 4 = Aachra.
var chain_level: int = 0

## The capture emptied the table (a "missa" candidate). Phase 6 decides
## whether it scores: it does not on the last hand, see `was_last_hand`.
var cleared_table: bool = false
## True if this move was played during the last hand (after "Khlassou!").
var was_last_hand: bool = false

## The hands ran out and a new set was dealt from the talon.
var new_hands_dealt: bool = false

## This move ended the round.
var round_over: bool = false
## At the end of the round the last capturer takes whatever is left on the table.
var swept_by: int = -1
var swept_cards: Array[Card] = []


static func illegal(reason: String) -> MoveResult:
	var result := MoveResult.new()
	result.ok = false
	result.error = reason
	return result
