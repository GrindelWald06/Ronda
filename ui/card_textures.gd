class_name CardTextures
extends RefCounted
## Loads the card artwork from res://assets/cards/ and caches it.
##
## Expected files: 1.PNG ... 40.PNG for the faces and back.PNG for the deck
## cover. If a file cannot be found the function returns null (with a single
## warning) and CardView falls back to drawing the card in code.

## Master switch. false = always use the cards drawn in code (no image files are
## touched); true = use the images from res://assets/cards/.
const USE_ARTWORK := false

const FOLDER := "res://assets/cards/"
## Must match your file names exactly, letter case included: paths are
## case-sensitive on Linux, Android and web exports.
const EXTENSION := ".PNG"
const BACK_NAME := "back"

## The order in which the four suits appear in the numbered files, ten cards
## per suit, each suit running 1 2 3 4 5 6 7 10 11 12 (the Jack/Sota, Knight/
## Caballo and King/Rey come last).
## Default: 1-10 coins, 11-20 cups, 21-30 swords, 31-40 clubs.
## If your files are ordered differently, this list is the only thing to edit.
const SUIT_FILE_ORDER: Array[int] = [
	Card.Suit.COINS,
	Card.Suit.CUPS,
	Card.Suit.SWORDS,
	Card.Suit.CLUBS,
]

static var _cache := {}


## Number in the file name for a card (1 to 40).
static func file_number(card: Card) -> int:
	return SUIT_FILE_ORDER.find(card.suit) * Card.RANKS_PER_SUIT + card.order_index() + 1


static func face(card: Card) -> Texture2D:
	if not USE_ARTWORK:
		return null
	return _load(str(file_number(card)))


static func back() -> Texture2D:
	if not USE_ARTWORK:
		return null
	return _load(BACK_NAME)


static func _load(file_name: String) -> Texture2D:
	if _cache.has(file_name):
		return _cache[file_name]
	var path := FOLDER + file_name + EXTENSION
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path)
	else:
		push_warning("CardTextures: %s not found, drawing this card in code instead." % path)
	_cache[file_name] = texture   # null is cached too, so the warning shows only once
	return texture
