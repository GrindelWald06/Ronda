class_name Announcement
extends RefCounted
## A ronda (a pair in hand) or a tringla (three of a kind in hand) announced
## before the player's first card of a deal.
##
## `rank` is private information until announcements are compared: in a real
## game you only say "Ronda!". The engine stores it so it can score correctly;
## the UI and any AI should not show or use another player's rank before it is
## revealed in a MoveResult's point awards.

enum Kind { RONDA, TRINGLA }

var seat: int
var kind: int
var rank: int


func _init(p_seat: int = 0, p_kind: int = Kind.RONDA, p_rank: int = 1) -> void:
	seat = p_seat
	kind = p_kind
	rank = p_rank


## Used to compare announcements: any tringla beats any ronda, then the higher
## rank wins (ranks compared in sequence order, so the 12 is the strongest).
func strength() -> int:
	return kind * 100 + Card.RANK_ORDER.find(rank)


func kind_name() -> String:
	return "Tringla" if kind == Kind.TRINGLA else "Ronda"


func _to_string() -> String:
	return "%s of %d (seat %d)" % [kind_name(), rank, seat]
