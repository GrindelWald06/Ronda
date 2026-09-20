class_name MoveResult
extends RefCounted
## Everything that happened when a Move was applied. RoundState.apply_move()
## returns one of these so a controller can drive animations, sounds and
## (in later phases) scoring without the engine knowing anything about them.

## False if the move was rejected; the state is left untouched and `error`
## explains why.
var ok: bool = true
var error: String = ""

var player: int = -1
var played: Card

## True if the played card paired with a table card.
var was_capture: bool = false
## Table cards taken with the played card (the played card is not included).
## Always in sequence order, starting with the paired card.
var captured_cards: Array[Card] = []

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
