class_name GameTable
extends Control
## The game screen: felt background, the hands, the table, the talon and the
## captured piles. It builds its whole interface in code, so the scene only
## needs this script on a full-rect Control (see main.tscn).
##
## GameTable never applies rules. It reads the RoundState held by
## GameController, turns each MoveResult into an animation, and forwards the
## human's clicks to the controller.
##
## Layout (2 players: you at the bottom, the opponent at the top):
##
##   [New round]        opponent's hand (face down)        opp. pile
##   [talon]              cards on the table
##                      status / last move
##                        your hand                          your pile

const HUMAN_SEAT := 0
const OPPONENT_SEAT := 1

const MOVE_TIME := 0.3
const PAUSE_TIME := 0.25
const TOP_MARGIN := 20.0
const BOTTOM_MARGIN := 28.0
const SIDE_MARGIN := 150.0   # space kept free on both sides of the card rows

var controller: GameController

var _card_layer: Control
var _status_label: Label
var _detail_label: Label
var _new_round_button: Button
var _announce_button: Button
var _score_label: Label
var _talon_view: CardView
var _talon_label: Label
var _pile_views: Array[CardView] = []   # indexed by side (= seat with 2 players)
var _pile_labels: Array[Label] = []

var _human_views: Array[CardView] = []
var _opponent_views: Array[CardView] = []
var _table_views: Array[CardView] = []

var _input_enabled: bool = false
## Bumped whenever a new round starts so that animations of an abandoned round
## stop touching views that no longer exist.
var _presentation_id: int = 0


func _ready() -> void:
	CardView.update_card_size_from_artwork()
	_build_ui()

	controller = GameController.new()
	controller.human_seat = HUMAN_SEAT
	add_child(controller)
	controller.round_started.connect(_on_round_started)
	controller.move_applied.connect(_on_move_applied)
	controller.awaiting_human.connect(_on_awaiting_human)
	controller.round_finished.connect(_on_round_finished)

	resized.connect(_on_resized)
	await get_tree().process_frame   # let the root Control get its real size
	_layout(false)
	controller.start_round()


# ---------------------------------------------------------------------------
# Building the interface
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var felt := ColorRect.new()
	felt.color = Color(0.09, 0.33, 0.20)
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(felt)
	felt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# All cards live in this layer, so moving a card between zones is just a
	# matter of giving it a new target position.
	_card_layer = Control.new()
	_card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_layer)
	_card_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_talon_view = CardView.new(null, false)
	_card_layer.add_child(_talon_view)
	for _side in 2:
		var pile := CardView.new(null, false)
		_card_layer.add_child(pile)
		_pile_views.append(pile)

	_talon_label = _make_label(16, HORIZONTAL_ALIGNMENT_CENTER)
	for _side in 2:
		_pile_labels.append(_make_label(16, HORIZONTAL_ALIGNMENT_RIGHT))

	_status_label = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label = _make_label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_score_label = _make_label(16, HORIZONTAL_ALIGNMENT_LEFT)

	_new_round_button = Button.new()
	_new_round_button.text = "New round"
	_new_round_button.pressed.connect(_on_new_round_pressed)
	add_child(_new_round_button)

	_announce_button = Button.new()
	_announce_button.visible = false
	_announce_button.pressed.connect(_on_announce_pressed)
	add_child(_announce_button)


func _make_label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _on_resized() -> void:
	_layout(false)


## Puts every card and HUD element where it belongs. With `animate` the cards
## glide there, otherwise they jump (used when the window is resized).
func _layout(animate: bool) -> void:
	var w := size.x
	var h := size.y
	var card_size := CardView.card_size
	var row_width := w - 2.0 * SIDE_MARGIN
	_place_row(_opponent_views, w / 2.0, TOP_MARGIN, row_width, animate)
	_place_row(_table_views, w / 2.0, _table_y(), row_width, animate)
	_place_row(_human_views, w / 2.0, _human_y(), row_width, animate)

	_talon_view.position = _talon_position()
	_talon_label.position = _talon_position() + Vector2(0.0, card_size.y + 4.0)
	_talon_label.size = Vector2(card_size.x, 24.0)
	for side in 2:
		var pile_pos := _pile_position(side)
		_pile_views[side].position = pile_pos
		_pile_labels[side].position = pile_pos + Vector2(-146.0, card_size.y / 2.0 - 12.0)
		_pile_labels[side].size = Vector2(136.0, 24.0)

	_status_label.position = Vector2(SIDE_MARGIN, _table_y() - 76.0)
	_status_label.size = Vector2(row_width, 68.0)
	_detail_label.position = Vector2(SIDE_MARGIN, _table_y() + card_size.y + 12.0)
	_detail_label.size = Vector2(row_width, 56.0)
	_new_round_button.position = Vector2(24.0, TOP_MARGIN)
	_score_label.position = Vector2(24.0, TOP_MARGIN + 46.0)
	_score_label.size = Vector2(150.0, 70.0)
	_announce_button.size = Vector2(180.0, 44.0)
	_announce_button.position = Vector2(w / 2.0 - 340.0, _human_y() + card_size.y / 2.0 - 22.0)


## Lays `views` out in one horizontal row centred on `center_x`. When the row
## would be too wide the cards overlap a little.
func _place_row(
	views: Array[CardView], center_x: float, y: float, max_width: float, animate: bool
) -> void:
	var count := views.size()
	if count == 0:
		return
	var card_width := CardView.card_size.x
	var gap := card_width + 14.0
	if count > 1:
		gap = minf(gap, (max_width - card_width) / float(count - 1))
	var total := gap * float(count - 1) + card_width
	var x := center_x - total / 2.0
	for i in count:
		views[i].move_to(Vector2(x + gap * float(i), y), MOVE_TIME if animate else 0.0)


func _table_y() -> float:
	return (size.y - CardView.card_size.y) / 2.0


func _human_y() -> float:
	return size.y - CardView.card_size.y - BOTTOM_MARGIN


func _talon_position() -> Vector2:
	return Vector2(24.0, _table_y())


func _pile_position(side: int) -> Vector2:
	var x := size.x - CardView.card_size.x - 24.0
	return Vector2(x, _human_y() if side == HUMAN_SEAT else TOP_MARGIN)


# ---------------------------------------------------------------------------
# Controller events
# ---------------------------------------------------------------------------

func _on_new_round_pressed() -> void:
	controller.start_round()


func _on_round_started() -> void:
	_presentation_id += 1
	var id := _presentation_id
	_input_enabled = false
	_announce_button.hide()
	_clear_views()
	_status_label.text = "Dealing..."
	_detail_label.text = ""

	# Everything is dealt from the talon.
	for c in controller.state.table:
		_table_views.append(_spawn_view(c, true, _talon_position()))
	_spawn_hand_views()
	_update_hud()
	_layout(true)

	await _wait(MOVE_TIME + 0.2)
	if id != _presentation_id:
		return
	controller.presentation_finished()


func _on_awaiting_human() -> void:
	_input_enabled = true
	_status_label.text = "Your turn: click a card to play it."
	for view in _human_views:
		view.interactive = true
	_update_announce_button()


## Animates one applied move. The RoundState has already advanced (it may even
## have dealt new hands or finished the round), so this only tells the story.
func _on_move_applied(result: MoveResult) -> void:
	var id := _presentation_id
	var state := controller.state
	_input_enabled = false
	_announce_button.hide()
	_clear_highlights()
	for view in _human_views:
		view.interactive = false

	# An announcement uses no card: show it, then hand the turn back.
	if result.kind == Move.Type.ANNOUNCE:
		var verb := "announce" if result.player == HUMAN_SEAT else "announces"
		_status_label.text = "%s %s %s!" % [
			_seat_name(result.player), verb, result.announcement.kind_name()
		]
		_detail_label.text = ""
		await _wait(0.9)
		if id != _presentation_id:
			return
		controller.presentation_finished()
		return

	_detail_label.text = _describe_move(result)
	var awards_text := _describe_awards(result)
	if not awards_text.is_empty():
		_detail_label.text += "\n" + awards_text

	var played_view := _take_from_hand(result.player, result.played)
	if played_view == null:
		push_error("GameTable: no view found for %s" % [result.played])
		controller.presentation_finished()
		return
	played_view.face_up = true
	played_view.interactive = false
	_card_layer.move_child(played_view, -1)   # draw it above everything else

	if not result.was_capture:
		# No pair: the card is thrown onto the table.
		_table_views.append(played_view)
		_layout(true)
		await _wait(MOVE_TIME + PAUSE_TIME)
		if id != _presentation_id:
			return
	else:
		var taken_views: Array[CardView] = []
		for c in result.captured_cards:
			var taken_view := _take_from_table(c)
			if taken_view != null:
				taken_views.append(taken_view)

		# 1) the played card lands on the card it pairs with
		if not taken_views.is_empty():
			played_view.move_to(taken_views[0].position + Vector2(10.0, 10.0), MOVE_TIME)
		await _wait(MOVE_TIME + PAUSE_TIME)
		if id != _presentation_id:
			return

		# 2) the whole run goes to the capturer's pile; the table closes up
		var pile_pos := _pile_position(state.side_of(result.player))
		played_view.move_to(pile_pos, MOVE_TIME)
		for view in taken_views:
			view.move_to(pile_pos, MOVE_TIME)
		_layout(true)
		await _wait(MOVE_TIME + 0.05)
		if id != _presentation_id:
			return
		played_view.queue_free()
		for view in taken_views:
			view.queue_free()

	if result.new_hands_dealt:
		_spawn_hand_views()
		_layout(true)
		await _wait(MOVE_TIME + 0.2)
		if id != _presentation_id:
			return

	if result.round_over:
		# The last capturer takes whatever is left on the table.
		if result.swept_by != -1 and not _table_views.is_empty():
			var sweep_pos := _pile_position(state.side_of(result.swept_by))
			for view in _table_views:
				view.move_to(sweep_pos, MOVE_TIME)
			_detail_label.text += " %s takes the remaining cards." % _seat_name(result.swept_by)
			await _wait(MOVE_TIME + 0.1)
			if id != _presentation_id:
				return
			for view in _table_views:
				view.queue_free()
			_table_views.clear()

	_update_hud()
	controller.presentation_finished()


func _on_round_finished() -> void:
	_input_enabled = false
	var state := controller.state
	var mine := state.cards_won(HUMAN_SEAT)
	var theirs := state.cards_won(OPPONENT_SEAT)
	var headline := "Round over: a tie on cards."
	if mine > theirs:
		headline = "Round over: you collected more cards!"
	elif theirs > mine:
		headline = "Round over: the opponent collected more cards."
	_status_label.text = "%s\nYou: %d cards (+%d)    Opponent: %d cards (+%d)" % [
		headline, mine, state.card_points(HUMAN_SEAT),
		theirs, state.card_points(OPPONENT_SEAT),
	]


# ---------------------------------------------------------------------------
# Human input
# ---------------------------------------------------------------------------

func _on_hand_card_pressed(view: CardView) -> void:
	if not _input_enabled:
		return
	_input_enabled = false
	_announce_button.hide()
	_clear_highlights()
	controller.human_play(view.card)


func _on_announce_pressed() -> void:
	if not _input_enabled:
		return
	_input_enabled = false
	_announce_button.hide()
	for view in _human_views:
		view.interactive = false
	_clear_highlights()
	controller.human_announce()


## Shows the announce button only when the human may announce right now.
func _update_announce_button() -> void:
	var announcement := controller.state.available_announcement(HUMAN_SEAT)
	_announce_button.visible = _input_enabled and announcement != null
	if announcement == null:
		return
	_announce_button.text = "Announce %s" % announcement.kind_name()
	_announce_button.tooltip_text = (
		"Scores points but tells your opponent you hold a pair.\n"
		+ "If you hide it and later play both cards, you lose %d points."
		% RondaRules.HIDDEN_RONDA_PENALTY
	)


## Hovering a card in your hand outlines the table cards it would capture.
func _on_hand_card_hover(view: CardView, is_hovered: bool) -> void:
	_clear_highlights()
	if not is_hovered or not _input_enabled:
		return
	var captured_ids := {}
	for c in RondaRules.find_capture(view.card, controller.state.table):
		captured_ids[c.id()] = true
	for table_view in _table_views:
		table_view.highlighted = captured_ids.has(table_view.card.id())


func _clear_highlights() -> void:
	for view in _table_views:
		view.highlighted = false


# ---------------------------------------------------------------------------
# Views bookkeeping
# ---------------------------------------------------------------------------

## Creates a CardView that starts at `from` (usually the talon).
func _spawn_view(card: Card, face_up: bool, from: Vector2) -> CardView:
	var view := CardView.new(card, face_up)
	_card_layer.add_child(view)
	view.position = from
	return view


## Creates views for the hands currently held in the RoundState.
func _spawn_hand_views() -> void:
	var state := controller.state
	for c in state.hand_of(HUMAN_SEAT):
		var view := _spawn_view(c, true, _talon_position())
		view.pressed.connect(_on_hand_card_pressed)
		view.hover_changed.connect(_on_hand_card_hover)
		_human_views.append(view)
	for c in state.hand_of(OPPONENT_SEAT):
		_opponent_views.append(_spawn_view(c, false, _talon_position()))


func _take_from_hand(seat: int, card: Card) -> CardView:
	var views: Array[CardView] = _human_views if seat == HUMAN_SEAT else _opponent_views
	return _take_view(views, card)


func _take_from_table(card: Card) -> CardView:
	return _take_view(_table_views, card)


## Removes (and returns) the view showing `card` from `views`.
func _take_view(views: Array[CardView], card: Card) -> CardView:
	for i in views.size():
		if views[i].card.id() == card.id():
			var view := views[i]
			views.remove_at(i)
			return view
	return null


func _clear_views() -> void:
	for views in [_human_views, _opponent_views, _table_views]:
		for view in views:
			view.queue_free()
		views.clear()


# ---------------------------------------------------------------------------
# HUD and text
# ---------------------------------------------------------------------------

func _update_hud() -> void:
	var state := controller.state
	_talon_view.visible = state.talon_size() > 0
	_talon_label.text = "Talon: %d" % state.talon_size()
	for side in 2:
		var won := state.cards_won(side)
		_pile_views[side].visible = won > 0
		_pile_labels[side].text = "%s: %d cards" % [_seat_name(side), won]
	_score_label.text = "Points this round\nYou: %d\nOpponent: %d" % [
		state.round_points[HUMAN_SEAT], state.round_points[OPPONENT_SEAT]
	]


func _seat_name(seat: int) -> String:
	return "You" if seat == HUMAN_SEAT else "Opponent"


func _describe_move(result: MoveResult) -> String:
	var who := _seat_name(result.player)
	if not result.was_capture:
		return "%s threw the %s." % [who, result.played]
	var ranks := PackedStringArray()
	for c in result.captured_cards:
		ranks.append(str(c.rank))
	var text := "%s played the %s and captured %s." % [who, result.played, ", ".join(ranks)]
	if result.cleared_table and not result.was_last_hand:
		text += " Missa!"
	return text


func _describe_awards(result: MoveResult) -> String:
	var parts := PackedStringArray()
	for award in result.awards:
		parts.append("%s: %s +%d" % [award.reason, _seat_name(award.side), award.points])
	return "    ".join(parts)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
