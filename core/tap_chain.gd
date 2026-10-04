class_name TapChain
extends RefCounted
## A tap ("Bount") that has not been settled yet.
##
## The card that was just thrown and the card that tapped it are stacked, and the
## following players may add a card of the same rank on top of the stack
## (Khamsa, then Aachra). The chain is settled by RoundState once nobody can, or
## wants to, add another card.

## The rank all the stacked cards share.
var rank: int
## The cards of the stack: the thrown card first, then each card laid on it.
var stack: Array[Card] = []
## laid_by[i] is the seat that laid stack[i] (the thrower for index 0).
var laid_by: Array[int] = []


func _init(p_rank: int = 1) -> void:
	rank = p_rank


func add(card: Card, seat: int) -> void:
	stack.append(card)
	laid_by.append(seat)


## Number of stacked cards: 2 = Bount, 3 = Khamsa, 4 = Aachra.
func level() -> int:
	return stack.size()


## The seat that laid the most recent card. It is the one who scores if the chain
## stops now.
func last_layer_seat() -> int:
	return laid_by[laid_by.size() - 1]


func clone() -> TapChain:
	var copy := TapChain.new(rank)
	for i in stack.size():
		copy.add(stack[i], laid_by[i])
	return copy
