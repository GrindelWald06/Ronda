class_name Deck
extends RefCounted
## A pile of cards. The TOP of the pile is the END of the `cards` array,
## so drawing is a cheap pop_back().

var cards: Array[Card] = []


## Builds an unshuffled 40-card deck.
static func create_full() -> Deck:
	var deck := Deck.new()
	for suit in Card.SUIT_COUNT:
		for rank in Card.RANK_ORDER:
			deck.cards.append(Card.new(suit, rank))
	return deck


## Fisher-Yates shuffle. Pass a seeded RandomNumberGenerator for reproducible
## games (useful for debugging and for AI simulations).
func shuffle(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


func size() -> int:
	return cards.size()


func is_empty() -> bool:
	return cards.is_empty()


## Removes and returns the top card.
func draw() -> Card:
	assert(not cards.is_empty(), "Deck.draw(): the deck is empty")
	return cards.pop_back()


## Draws `count` cards; the first card drawn is first in the returned array.
func draw_many(count: int) -> Array[Card]:
	var drawn: Array[Card] = []
	for _i in count:
		drawn.append(draw())
	return drawn


## Puts a card back in the middle of the pile (used when the opening table
## is invalid and a card has to be replaced).
@warning_ignore("integer_division")
func insert_middle(card: Card) -> void:
	cards.insert(cards.size() / 2, card)


## Independent copy of the pile (Card instances are shared, they are immutable).
func clone() -> Deck:
	var copy := Deck.new()
	copy.cards = Card.copy_array(cards)
	return copy
