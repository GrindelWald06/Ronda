class_name GameController
extends Node
## Owns the RoundState and decides whose turn it is. It contains no drawing
## code: the view (GameTable) listens to its signals and answers back when it
## has finished animating.
##
## FLOW
##   start_round()      -> emits round_started, then waits for the view
##   view calls presentation_finished()
##   -> the round is over?      emit round_finished
##   -> human to play?          emit awaiting_human, then human_play(card)
##   -> AI to play?             wait a moment, apply the AI's move
##   every applied move emits move_applied(result) and waits for the view again.
##
## Waiting for the view means animations never overlap and the AI never plays
## while cards are still flying around.

signal round_started
signal move_applied(result: MoveResult)
signal awaiting_human
signal round_finished

var player_count: int = 2
var human_seat: int = 0
## Seconds the AI "thinks" before playing.
var ai_think_time: float = 0.7

var state: RoundState
## Dealer of the current round. The seat after the dealer plays first, and the
## job rotates to the next seat after every round.
var dealer: int = 0

var _ai := RandomAI.new()
var _rng := RandomNumberGenerator.new()
var _busy: bool = false      # true while the view is presenting something
var _round_id: int = 0       # lets old AI timers detect that a new round began


func _ready() -> void:
	_rng.randomize()
	dealer = _rng.randi_range(0, player_count - 1)


func start_round() -> void:
	_round_id += 1
	state = RoundState.new_round(player_count, dealer, _rng)
	_busy = true
	round_started.emit()


## The view calls this when it has finished animating the last event.
func presentation_finished() -> void:
	_busy = false
	_advance()


## Called by the view when the human clicks a card in their hand.
func human_play(card: Card) -> void:
	if _busy or state == null or state.finished:
		return
	if state.current_player != human_seat:
		return
	_apply(Move.play(human_seat, card))


## Called by the view when the human clicks the announce button. Announcing
## does not use up the turn: the human still has to play a card afterwards.
func human_announce() -> void:
	if _busy or state == null or state.finished:
		return
	if state.current_player != human_seat:
		return
	_apply(Move.announce(human_seat))


func _advance() -> void:
	if state.finished:
		dealer = state.next_player(dealer)
		round_finished.emit()
	elif state.current_player == human_seat:
		awaiting_human.emit()
	else:
		_run_ai_turn()


func _run_ai_turn() -> void:
	var id := _round_id
	await get_tree().create_timer(ai_think_time).timeout
	if id != _round_id or state.finished:
		return
	_apply(_ai.choose_move(state, _rng))


func _apply(move: Move) -> void:
	var result := state.apply_move(move)
	if not result.ok:
		push_warning(result.error)
		return
	_busy = true
	move_applied.emit(result)
