extends RefCounted
## Curated six-full-move repertoire. Sources and SAN: data/OPENINGS.md.
const Rules = preload("res://features/chess/chess_rules.gd")
const LINES = [
	{"name": "Scotch Classical", "color": 1, "weight": 22, "moves": "e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4 f8c5 c1e3 d8f6 c2c3 g8e7"},
	{"name": "Scotch Mieses", "color": 1, "weight": 22, "moves": "e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4 g8f6 d4c6 b7c6 e4e5 d8e7"},
	{"name": "Center Kupreichik", "color": 1, "weight": 5, "moves": "e2e4 e7e5 d2d4 e5d4 d1d4 b8c6 d4e3 g8f6 b1c3 f8b4 c1d2 e8g8"},
	{"name": "Center Charousek", "color": 1, "weight": 5, "moves": "e2e4 e7e5 d2d4 e5d4 d1d4 b8c6 d4e3 f8b4 c2c3 b4e7 c3c4 g8f6"},
	{"name": "Caro-Kann Classical", "color": -1, "weight": 27, "moves": "e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4 c8f5 e4g3 f5g6 h2h4 h7h6"},
	{"name": "Caro-Kann Advance Short", "color": -1, "weight": 27, "moves": "e2e4 c7c6 d2d4 d7d5 e4e5 c8f5 g1f3 e7e6 f1e2 c6c5 e1g1 b8c6"},
	{"name": "Caro-Kann Exchange", "color": -1, "weight": 27, "moves": "e2e4 c7c6 d2d4 d7d5 e4d5 c6d5 f1d3 b8c6 c2c3 g8f6 c1f4 c8g4"},
	{"name": "Slav Czech Wiesbaden", "color": -1, "weight": 27, "moves": "d2d4 c7c6 c2c4 d7d5 g1f3 g8f6 b1c3 d5c4 a2a4 c8f5 f3e5 e7e6"},
	{"name": "Slav Exchange Symmetrical", "color": -1, "weight": 27, "moves": "d2d4 c7c6 c2c4 d7d5 c4d5 c6d5 b1c3 g8f6 g1f3 b8c6 c1f4 c8f5"},
]
static var positions: Dictionary = {}
static var build_failed := false

func _init() -> void:
	if not positions.is_empty() or build_failed:
		return
	for line in LINES:
		if not _register(line.moves, line.color, line.weight):
			positions.clear()
			build_failed = true
			push_error("Invalid yyslChess opening line: " + line.name)
			return
	# Equivalent, source-backed move orders reuse the same position table.
	var aliases: Array[String] = [LINES[4].moves.replace("b1c3 d5e4 c3e4", "b1d2 d5e4 d2e4")]
	for index in [7, 8]:
		aliases.append(LINES[index].moves.replace("d2d4 c7c6 c2c4 d7d5", "c2c4 c7c6 d2d4 d7d5"))
	aliases.append(LINES[7].moves.replace("d2d4 c7c6 c2c4 d7d5 g1f3 g8f6", "g1f3 c7c6 d2d4 d7d5 c2c4 g8f6"))
	for line in aliases:
		if not _register(line, -1, 27):
			positions.clear()
			build_failed = true
			push_error("Invalid yyslChess opening transposition: " + line)
			return

func _register(line: String, color: int, weight: int) -> bool:
	var game = Rules.new()
	for move_text in line.split(" "):
		var legal: Array = game.legal_moves()
		var found := false
		for move in legal:
			if Rules.uci(move) == move_text:
				if game.turn == color:
					var key: String = game.position_key()
					if not positions.has(key):
						positions[key] = {}
					positions[key][move_text] = maxi(weight, positions[key].get(move_text, 0))
				# Already validated above. No second legal-move generation is needed.
				game._apply(move)
				found = true
				break
		if not found:
			return false
	return true

func choose(game, legal: Array, rng: RandomNumberGenerator, full_move_limit := 6) -> Dictionary:
	if build_failed or game.fullmove > full_move_limit:
		return {}
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
