class_name AIFactory
extends RefCounted
## Creates the opponent for a difficulty level.

enum Difficulty { EASY, MEDIUM, HARD }

## Display names, indexed by Difficulty.
const NAMES: Array[String] = ["Easy", "Medium", "Hard"]


static func create(difficulty: int) -> AIPlayer:
	match difficulty:
		Difficulty.EASY:
			return RandomAI.new()
		Difficulty.HARD:
			return MonteCarloAI.new()
		_:
			return HeuristicAI.new()
