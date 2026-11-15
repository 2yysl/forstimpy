extends Node
## Fixed-depth, deterministic alpha-beta. Only opening-book choices use RNG.
const Rules = preload("res://features/chess/chess_rules.gd")
const Book = preload("res://features/chess/chess_opening_book.gd")
const MATE := 100000.0
@export var behavior: Resource = preload("res://features/chess/chess_behavior.tres")
var rng := RandomNumberGenerator.new()
var book = Book.new()
var generation := 0
var last_search_ms := 0.0
var last_total_ms := 0.0
var last_cpu_ms := 0.0
var last_max_slice_ms := 0.0
var last_nodes := 0
var last_cutoffs := 0
var last_yields := 0
var last_completed_depth := 0
var last_source := ""
var last_score := 0.0

func _ready() -> void:
	rng.randomize()

func cancel() -> void:
	generation += 1

func choose_move(game) -> Dictionary:
	var token := generation
	var started := Time.get_ticks_usec()
	# Snapshot once; restarts and callers cannot alter a suspended search.
	var position = game.copy_position()
	await get_tree().create_timer(behavior.think_delay_seconds).timeout
	if token != generation or not is_inside_tree():
		return {}
	var compute_started := Time.get_ticks_usec()
	var context := {"token": token, "nodes": 0, "cutoffs": 0, "yields": 0,
		"slice_started": compute_started, "max_slice_us": 0, "cpu_us": 0,
		"frame_us": maxi(1, behavior.frame_budget_ms) * 1000}
	var legal: Array = position.legal_moves()
	if legal.is_empty():
		_record(context, started, compute_started, "terminal", 0, -MATE if position.in_check(position.turn) else 0.0)
		return {}
	var opening: Dictionary = book.choose(position, legal, rng, behavior.book_full_moves)
	if not opening.is_empty():
		_record(context, started, compute_started, "book", 0, 0.0)
		return opening
	_order_moves(position, legal)
	var best: Dictionary = legal[0]
	var best_score := -INF
	var depth: int = behavior.search_depth
	for move in legal:
		if not await _checkpoint(context):
			return {}
		var next = position.copy_position()
		next._apply(move)
		var score: float = -await _search(next, depth - 1, -INF, -best_score, 1, context)
		if token != generation or not is_inside_tree():
			return {}
		# Stable ordering and strict comparison give deterministic tie breaking.
		if score > best_score:
			best_score = score
			best = move
	_record(context, started, compute_started, "search", depth, best_score)
	return best

func _search(game, depth: int, alpha: float, beta: float, ply: int, context: Dictionary) -> float:
	context.nodes += 1
	if not await _checkpoint(context):
		return 0.0
	# At the horizon, stop after the first legal move instead of generating
	# every legal move solely to rule out mate/stalemate.
	if depth == 0:
		if not game.has_legal_move():
			return -MATE + ply if game.in_check(game.turn) else 0.0
		if game.halfmove >= 100 or game.insufficient_material():
			return 0.0
		return evaluate(game) * game.turn
	var moves: Array = game.legal_moves()
	if moves.is_empty():
		return -MATE + ply if game.in_check(game.turn) else 0.0
	if game.halfmove >= 100 or game.insufficient_material():
		return 0.0
	_order_moves(game, moves)
	var best := -INF
	for move in moves:
		var next = game.copy_position()
		next._apply(move)
		var score: float = -await _search(next, depth - 1, -beta, -alpha, ply + 1, context)
		if context.token != generation or not is_inside_tree():
			return 0.0
		best = maxf(best, score)
		alpha = maxf(alpha, score)
		if alpha >= beta:
			context.cutoffs += 1
			break
	return best

func _checkpoint(context: Dictionary) -> bool:
	if context.token != generation or not is_inside_tree():
		return false
	var elapsed := Time.get_ticks_usec() - int(context.slice_started)
	context.max_slice_us = maxi(context.max_slice_us, elapsed)
	if elapsed >= int(context.frame_us):
		context.yields += 1
		context.cpu_us += elapsed
		await get_tree().process_frame
		context.slice_started = Time.get_ticks_usec()
	return context.token == generation and is_inside_tree()

func _record(context: Dictionary, started: int, compute_started: int, source: String, depth: int, score: float) -> void:
	var now := Time.get_ticks_usec()
	last_search_ms = (now - compute_started) / 1000.0
	last_total_ms = (now - started) / 1000.0
	last_cpu_ms = (context.cpu_us + now - int(context.slice_started)) / 1000.0
	last_max_slice_ms = maxi(context.max_slice_us, now - int(context.slice_started)) / 1000.0
	last_nodes = context.nodes
	last_cutoffs = context.cutoffs
	last_yields = context.yields
	last_completed_depth = depth
	last_source = source
	last_score = score

func _priority(game, move: Dictionary) -> int:
	var victim: int = absi(game.board[move.to])
	if victim == 0 and absi(game.board[move.from]) == Rules.PAWN and move.to == game.ep:
		victim = Rules.PAWN
	var piece: int = game.board[move.from]
	var kind := absi(piece)
	var dx: float = absf(move.from % 8 - 3.5) - absf(move.to % 8 - 3.5)
	var dy: float = absf(int(move.from / 8) - 3.5) - absf(int(move.to / 8) - 3.5)
	var positional := (dx + dy) * (9.0 if kind == Rules.KNIGHT or kind == Rules.BISHOP else 2.0)
	if kind == Rules.PAWN:
		positional += (int(move.from / 8) - int(move.to / 8)) * signi(piece) * 6
	return Rules.VALUES[victim] * 16 + int(move.promotion) * 2000 + int(positional)

func _order_moves(game, moves: Array) -> void:
	moves.sort_custom(func(a, b):
		var pa := _priority(game, a)
		var pb := _priority(game, b)
		if pa != pb:
			return pa > pb
		return a.from * 512 + a.to * 8 + a.promotion < b.from * 512 + b.to * 8 + b.promotion)

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
