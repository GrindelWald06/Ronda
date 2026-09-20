class_name Card
extends RefCounted
## A single card of the 40-card Spanish deck.
##
## Cards are treated as IMMUTABLE after construction: never change suit or
## rank afterwards. That lets RoundState.clone() share Card instances between
## copies, which keeps AI simulations cheap.
##
## Ranks are 1-7, then 10 (Jack/Sota), 11 (Knight/Caballo) and 12 (King/Rey).
## There is no 8 or 9, so in a sequence 7 is followed directly by 10.

enum Suit { COINS, CUPS, SWORDS, CLUBS }  # deniers, coupes, épées, bâtons

const SUIT_COUNT := 4
const SUIT_NAMES: Array[String] = ["Coins", "Cups", "Swords", "Clubs"]

## Ranks listed in sequence order. A rank's position in this list is its
## "order index" (0-9); two cards are consecutive when their indices differ by 1.
const RANK_ORDER: Array[int] = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12]
const RANKS_PER_SUIT := 10
const DECK_SIZE := 40

var suit: int
var rank: int


func _init(p_suit: int = 0, p_rank: int = 1) -> void:
	assert(p_suit >= 0 and p_suit < SUIT_COUNT, "Invalid suit: %d" % p_suit)
	assert(RANK_ORDER.has(p_rank), "Invalid rank: %d" % p_rank)
	suit = p_suit
	rank = p_rank


## Position of this card's rank in the sequence (0 for the 1, 9 for the 12).
func order_index() -> int:
	return RANK_ORDER.find(rank)


## Unique id from 0 to 39. Handy for texture lookup, dictionaries and AI code.
func id() -> int:
	return suit * RANKS_PER_SUIT + order_index()


func same_rank(other: Card) -> bool:
	return rank == other.rank


func equals(other: Card) -> bool:
	return other != null and id() == other.id()


@warning_ignore("integer_division")
static func from_id(card_id: int) -> Card:
	return Card.new(card_id / RANKS_PER_SUIT, RANK_ORDER[card_id % RANKS_PER_SUIT])


## Returns a new typed array holding the same Card references.
## (Array.duplicate()/filter()/map() can lose the Array[Card] type, so we
## always copy card lists through this helper.)
static func copy_array(source: Array[Card]) -> Array[Card]:
	var out: Array[Card] = []
	out.append_array(source)
	return out


func _to_string() -> String:
	return "%d of %s" % [rank, SUIT_NAMES[suit]]
