extends Node
## Two-ply search, bounded by time and yielded between root candidates.
const Rules = preload("res://addons/slowbrainn_chess/chess_rules.gd")
const Book = preload("res://addons/slowbrainn_chess/chess_opening_book.gd")
@export var behavior: Resource = preload("res://addons/slowbrainn_chess/chess_behavior.tres")
var rng := RandomNumberGenerator.new()
var book = Book.new()
var generation := 0
var last_search_ms := 0

func _ready() -> void:
	rng.randomize()

func cancel() -> void:
	generation += 1

func choose_move(game) -> Dictionary:
	var token := generation
	var started := Time.get_ticks_msec()
	await get_tree().create_timer(behavior.think_delay_seconds).timeout
	if token != generation or not is_inside_tree():
		return {}
	var legal: Array = game.legal_moves()
	if legal.is_empty():
		return {}
	var opening: Dictionary = book.choose(game, legal, rng)
	if not opening.is_empty():
		last_search_ms = Time.get_ticks_msec() - started
		return opening
	var search_started := Time.get_ticks_msec()
	var slice_started := search_started
	# Seed a legal fallback even if the first candidate exhausts the budget.
	var best: Dictionary = legal[rng.randi_range(0, legal.size() - 1)]
	var best_score := -INF
	# Shuffle with our own RNG so tests can reproduce results.
	for i in range(legal.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = legal[i]
		legal[i] = legal[j]
		legal[j] = temp
	for move in legal:
		var next = game.copy_position()
		next._apply(move)
		var replies: Array = next.legal_moves()
		var score := INF
		if replies.is_empty():
			score = 100000.0 if next.in_check(next.turn) else 0.0
		else:
			for reply in replies:
				var leaf = next.copy_position()
				leaf._apply(reply)
				score = minf(score, evaluate(leaf) * game.turn)
				if Time.get_ticks_msec() - slice_started >= behavior.frame_budget_ms:
					await get_tree().process_frame
					if token != generation or not is_inside_tree():
						return {}
					slice_started = Time.get_ticks_msec()
		# Only score fully searched candidates; incomplete candidates get no advantage.
		score += rng.randf_range(-behavior.evaluation_noise, behavior.evaluation_noise)
		if score > best_score:
			best_score = score
			best = move
		await get_tree().process_frame
		if token != generation or not is_inside_tree():
			return {}
		slice_started = Time.get_ticks_msec()
		if slice_started - search_started >= behavior.search_budget_ms:
			break
	last_search_ms = Time.get_ticks_msec() - started
	return best

func evaluate(game) -> float:
	var score := 0.0
	for i in 64:
		var piece: int = game.board[i]
		if piece == 0:
			continue
		var color := signi(piece)
		var kind := absi(piece)
		var file: int = i % 8
		var rank: int = i / 8
		var center := 7.0 - absf(file - 3.5) - absf(rank - 3.5)
		var positional := center * (9.0 if kind == Rules.KNIGHT or kind == Rules.BISHOP else 2.0)
		if kind == Rules.PAWN:
			positional += (6 - rank if color == 1 else rank - 1) * 6.0
		score += color * (Rules.VALUES[kind] + positional)
	return score
