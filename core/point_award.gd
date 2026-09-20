class_name PointAward
extends RefCounted
## Points given to a side, and why. Returned inside MoveResult.awards so the UI
## can tell the player what just scored.

var side: int
var points: int
var reason: String


func _init(p_side: int = 0, p_points: int = 0, p_reason: String = "") -> void:
	side = p_side
	points = p_points
	reason = p_reason


func _to_string() -> String:
	return "%s: side %d +%d" % [reason, side, points]
