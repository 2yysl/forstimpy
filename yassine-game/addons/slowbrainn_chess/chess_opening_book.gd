extends RefCounted
## Exact positions, with legal-move filtering at lookup. No forced sequences.
const Rules = preload("res://addons/slowbrainn_chess/chess_rules.gd")
static var positions: Dictionary = {}

func _init() -> void:
	if not positions.is_empty():
		return
	_register("e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4", 1, 22)
	_register("e2e4 e7e5 d2d4 e5d4 d1d4", 1, 5)
	_register("d2d4 d7d5 c2c4", 1, 1)
	_register("e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4", -1, 27)
	_register("e2e4 c7c6 d2d4 d7d5 e4e5 c8f5", -1, 27)
	_register("e2e4 c7c6 b1c3 d7d5", -1, 27)
	_register("d2d4 c7c6 c2c4 d7d5", -1, 27)
	_register("c2c4 c7c6 d2d4 d7d5", -1, 27)
	_register("g1f3 c7c6 d2d4 d7d5", -1, 27)

func _register(line: String, color: int, weight: int) -> void:
	var game = Rules.new()
	for move_text in line.split(" "):
		if game.turn == color:
			var key: String = game.position_key()
			if not positions.has(key):
				positions[key] = {}
			# Multiple continuations should not inflate a repeated prefix's weight.
			positions[key][move_text] = maxi(weight, positions[key].get(move_text, 0))
		# Assertions are omitted in release exports; advancing the position must
		# always execute so native and browser opening preferences match.
		if not game.play_uci(move_text):
			push_error("Illegal opening-book entry: " + move_text)
			return

func choose(game, legal: Array, rng: RandomNumberGenerator) -> Dictionary:
	var weights: Dictionary = positions.get(game.position_key(), {})
	var candidates: Array = []
	var total := 0
	for move in legal:
		var weight: int = weights.get(Rules.uci(move), 0)
		if weight > 0:
			total += weight
			candidates.append([move, weight])
	if total == 0:
		return {}
	var pick := rng.randi_range(1, total)
	for candidate in candidates:
		pick -= int(candidate[1])
		if pick <= 0:
			return candidate[0]
	return {}
