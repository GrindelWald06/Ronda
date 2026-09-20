class_name CardView
extends Control
## On-screen representation of one Card.
##
## The face is drawn in code (rank, suit shape, colors) so the game runs with
## no image assets. To use real artwork later, replace _draw_face() and
## _draw_back() with draw_texture_rect() calls; nothing else has to change.
##
## CardView knows nothing about the rules. It reports clicks and hovering
## through signals and lets GameTable decide what they mean.

signal pressed(view: CardView)
signal hover_changed(view: CardView, is_hovered: bool)

const CARD_SIZE := Vector2(84, 120)
const HOVER_LIFT := 10.0
const FACE_COLOR := Color(0.97, 0.94, 0.86)
const SUIT_COLORS: Array[Color] = [
	Color(0.80, 0.60, 0.05),  # coins
	Color(0.75, 0.15, 0.15),  # cups
	Color(0.15, 0.30, 0.70),  # swords
	Color(0.15, 0.50, 0.20),  # clubs
]
const FACE_NAMES := {10: "Jack", 11: "Knight", 12: "King"}

## The card shown. May be null for decorative pile/talon backs.
var card: Card

## False shows the card back (the opponent's hand, piles).
var face_up: bool = true:
	set(value):
		face_up = value
		queue_redraw()

## Only interactive cards react to hovering and clicking.
var interactive: bool = false:
	set(value):
		interactive = value
		if not interactive:
			_hover = false
		mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
		)
		queue_redraw()

## Draws a gold outline (used to preview which table cards would be captured).
var highlighted: bool = false:
	set(value):
		highlighted = value
		queue_redraw()

var _hover := false
var _tween: Tween
var _face_style: StyleBoxFlat
var _back_style: StyleBoxFlat
var _back_inner_style: StyleBoxFlat
var _highlight_style: StyleBoxFlat


func _init(p_card: Card = null, p_face_up: bool = true) -> void:
	card = p_card
	face_up = p_face_up
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	_face_style = _make_style(FACE_COLOR, Color(0.25, 0.20, 0.15), 2, 8, true, true)
	_back_style = _make_style(Color(0.15, 0.25, 0.50), Color(0.95, 0.95, 0.95), 2, 8, true, true)
	_back_inner_style = _make_style(Color.WHITE, Color(0.85, 0.70, 0.30), 2, 5, false, false)
	_highlight_style = _make_style(Color.WHITE, Color(1.0, 0.85, 0.15), 4, 10, false, false)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## Smoothly slides the card to `target` (in its parent's coordinates).
## Pass a duration of 0 to jump there instantly.
func move_to(target: Vector2, duration: float = 0.3) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0 or not is_inside_tree():
		position = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()


func _on_mouse_entered() -> void:
	if not interactive:
		return
	_hover = true
	queue_redraw()
	hover_changed.emit(self, true)


func _on_mouse_exited() -> void:
	if not _hover:
		return
	_hover = false
	queue_redraw()
	hover_changed.emit(self, false)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	# A hovered card is drawn slightly higher; its clickable area stays put.
	var lift := -HOVER_LIFT if (_hover and interactive) else 0.0
	draw_set_transform(Vector2(0.0, lift))
	var rect := Rect2(Vector2.ZERO, size)
	if face_up and card != null:
		_draw_face(rect)
	else:
		_draw_back(rect)
	if highlighted:
		draw_style_box(_highlight_style, rect.grow(3.0))


func _draw_face(rect: Rect2) -> void:
	draw_style_box(_face_style, rect)
	var color: Color = SUIT_COLORS[card.suit]
	var font := get_theme_default_font()
	var label := str(card.rank)
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(font, Vector2(8.0, 24.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
	draw_string(font, Vector2(rect.size.x - 8.0 - label_width, rect.size.y - 8.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
	_draw_suit(rect.get_center() + Vector2(0.0, -4.0), color)
	if FACE_NAMES.has(card.rank):
		draw_string(font, Vector2(0.0, rect.size.y - 26.0), FACE_NAMES[card.rank],
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, color)


func _draw_back(rect: Rect2) -> void:
	draw_style_box(_back_style, rect)
	draw_style_box(_back_inner_style, rect.grow(-7.0))
	var c := rect.get_center()
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.0, -22.0), c + Vector2(16.0, 0.0),
		c + Vector2(0.0, 22.0), c + Vector2(-16.0, 0.0),
	]), Color(0.85, 0.70, 0.30))


## Simple placeholder pictograms for the four suits.
func _draw_suit(c: Vector2, color: Color) -> void:
	match card.suit:
		Card.Suit.COINS:
			draw_circle(c, 24.0, color)
			draw_circle(c, 17.0, FACE_COLOR)
			draw_circle(c, 9.0, color)
		Card.Suit.CUPS:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-20.0, -20.0), c + Vector2(20.0, -20.0),
				c + Vector2(12.0, 2.0), c + Vector2(-12.0, 2.0),
			]), color)
			draw_rect(Rect2(c + Vector2(-3.0, 2.0), Vector2(6.0, 16.0)), color)
			draw_rect(Rect2(c + Vector2(-13.0, 18.0), Vector2(26.0, 5.0)), color)
		Card.Suit.SWORDS:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, -28.0), c + Vector2(6.0, -18.0),
				c + Vector2(6.0, 8.0), c + Vector2(-6.0, 8.0), c + Vector2(-6.0, -18.0),
			]), color)
			draw_rect(Rect2(c + Vector2(-16.0, 8.0), Vector2(32.0, 5.0)), color)
			draw_rect(Rect2(c + Vector2(-3.0, 13.0), Vector2(6.0, 14.0)), color)
		Card.Suit.CLUBS:
			draw_line(c + Vector2(-14.0, 24.0), c + Vector2(8.0, -8.0), color, 9.0)
			draw_circle(c + Vector2(12.0, -14.0), 13.0, color)


static func _make_style(
	fill: Color, border: Color, border_width: int, radius: int,
	filled: bool, shadow: bool
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.draw_center = filled
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	if shadow:
		style.shadow_size = 4
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
		style.shadow_offset = Vector2(0.0, 2.0)
	return style
