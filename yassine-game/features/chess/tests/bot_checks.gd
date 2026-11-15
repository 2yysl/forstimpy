extends Node
const Rules = preload("res://features/chess/chess_rules.gd")
const Bot = preload("res://features/chess/chess_bot.gd")
const Book = preload("res://features/chess/chess_opening_book.gd")
var failures := 0
var checks := 0
var baseline_nodes := 0
var measurements: Array = []

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func replay(line: String):
	var game = Rules.new()
	for text in line.split(" "):
		check(game.play_uci(text), "Legal repertoire move " + text)
	return game

func record(bot, label: String, move: Dictionary) -> void:
	var entry := {"position": label, "move": Rules.uci(move) if not move.is_empty() else "none", "source": bot.last_source,
		"depth": bot.last_completed_depth, "nodes": bot.last_nodes, "cutoffs": bot.last_cutoffs,
		"search_ms": bot.last_search_ms, "cpu_ms": bot.last_cpu_ms, "max_slice_ms": bot.last_max_slice_ms, "yields": bot.last_yields}
	measurements.append(entry)
	print("BENCH ", JSON.stringify(entry))

func reference(bot, game, depth: int, ply: int) -> float:
	baseline_nodes += 1
	var moves: Array = game.legal_moves()
	if moves.is_empty():
		return -bot.MATE + ply if game.in_check(game.turn) else 0.0
	if game.halfmove >= 100 or game.insufficient_material():
		return 0.0
	if depth == 0:
		return bot.evaluate(game) * game.turn
	var best := -INF
	for move in moves:
		var next = game.copy_position()
		next._apply(move)
		best = maxf(best, -reference(bot, next, depth - 1, ply + 1))
	return best

func run_cancel(bot, game, results: Array) -> void:
	results.append(await bot.choose_move(game))

func _run() -> void:
	var bot = Bot.new()
	get_tree().root.add_child(bot)
	bot.behavior = bot.behavior.duplicate()
	bot.behavior.think_delay_seconds = 0.0
	check(bot.behavior.search_depth == 3 and bot.behavior.book_full_moves == 6, "Agreed three-ply/six-full-move preset")
	check(not bot.book.build_failed, "All opening entries and aliases validate")
	# Replay every curated branch, verifying book support at every bot turn,
	# and rejection after move six even when an earlier position repeats.
	for line in Book.LINES:
		var game = Rules.new()
		var texts: PackedStringArray = line.moves.split(" ")
		check(texts.size() == 12, line.name + " contains six full moves")
		for text in texts:
			if game.turn == line.color:
				var weights: Dictionary = Book.positions.get(game.position_key(), {})
				check(weights.has(text), line.name + " supports " + text)
			check(game.play_uci(text), line.name + " legal " + text)
		check(game.fullmove == 7 and bot.book.choose(game, game.legal_moves(), bot.rng).is_empty(), line.name + " ends book after six full moves")
	var game = replay("e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4 c8f5 e4g3 f5g6 h2h4")
	var move: Dictionary = await bot.choose_move(game)
	check(bot.last_source == "book" and Rules.uci(move) == "h7h6", "Black's sixth move still uses book")
	game.play(move)
	move = await bot.choose_move(game)
	check(bot.last_source == "search" and bot.last_completed_depth == 3 and not move.is_empty(), "White move seven uses full search")
	record(bot, "Caro-Kann move seven", move)
	game = Rules.new()
	game.fullmove = 7
	check(bot.book.choose(game, game.legal_moves(), bot.rng).is_empty(), "Repeated earlier position cannot bypass cutoff")
	game.fullmove = 6
	check(not bot.book.choose(game, game.legal_moves(), bot.rng).is_empty(), "White move six remains inside cutoff")
	# Real move-order transpositions; castling/EP are part of position identity.
	var a = replay("d2d4 c7c6 c2c4 d7d5")
	var b = replay("c2c4 c7c6 d2d4 d7d5")
	check(a.position_key() == b.position_key(), "Equivalent Slav move orders share position")
	a.play_uci("g1f3")
	b.play_uci("g1f3")
	var transposed: Dictionary = bot.book.choose(b, b.legal_moves(), bot.rng)
	check(not transposed.is_empty() and Rules.uci(transposed) == "g8f6", "Slav transposition supported")
	var choices: Dictionary = {}
	game = replay("e2e4 e7e5")
	for seed_value in 32:
		bot.rng.seed = seed_value + 1
		move = bot.book.choose(game, game.legal_moves(), bot.rng)
		choices[Rules.uci(move)] = true
	check(choices.size() == 2 and choices.has("g1f3") and choices.has("d2d4"), "Variation is limited to approved Scotch/Center choices")
	# Fixed search: RNG, frame budget, and previous matches cannot affect result.
	bot.behavior.book_full_moves = 0
	game = replay("h2h4")
	var key: String = game.position_key()
	bot.rng.seed = 1
	move = await bot.choose_move(game)
	record(bot, "h4 fallback", move)
	var expected: String = Rules.uci(move)
	var nodes: int = bot.last_nodes
	var score: float = bot.last_score
	check(bot.last_source == "search" and bot.last_completed_depth == 3 and bot.last_cutoffs > 0, "Three-ply alpha-beta completes with pruning")
	check(game.position_key() == key and game.fullmove == 1 and game.turn == -1, "Search leaves caller's position unchanged")
	bot.rng.seed = 99999
	bot.behavior.frame_budget_ms = 1
	move = await bot.choose_move(game)
	check(Rules.uci(move) == expected and bot.last_nodes == nodes and bot.last_score == score, "Frame slicing and RNG seed do not alter search")
	bot.free()
	bot = Bot.new()
	get_tree().root.add_child(bot)
	bot.behavior = bot.behavior.duplicate()
	bot.behavior.book_full_moves = 0
	bot.behavior.think_delay_seconds = 0.0
	move = await bot.choose_move(game)
	check(Rules.uci(move) == expected and bot.last_nodes == nodes and bot.last_score == score, "Fresh bot session makes the same decision")
	# Terminal states at the horizon must not be scored as ordinary material.
	game.load_fen("7k/8/5KQ1/8/8/8/8/8 w - - 0 1")
	move = await bot.choose_move(game)
	check(game.play(move) and "checkmate" in game.outcome(game.legal_moves()), "Finds mate in one")
	game.load_fen("6k1/8/8/8/8/8/5qPP/5RK1 w - - 0 1")
	move = await bot.choose_move(game)
	check(move.to == Rules.square("f2") and game.play(move) and game.board[Rules.square("f2")] > 0, "Captures the free attacking queen legally")
	game = replay("e2e4 e7e5 f1c4 b8c6 d1h5")
	move = await bot.choose_move(game)
	check(game.play(move), "Legal defense against Scholar's Mate threat")
	var allows_mate := false
	for reply in game.legal_moves():
		var reply_position = game.copy_position()
		reply_position._apply(reply)
		if "checkmate" in reply_position.outcome(reply_position.legal_moves()):
			allows_mate = true
	check(not allows_mate, "Search avoids the opponent's immediate mate")
	# Compare alpha-beta's exact minimax score with an unpruned reference.
	for fen in ["7k/8/8/8/8/3p4/3P4/K7 w - - 0 1", "7k/6p1/8/8/8/8/1P6/K7 b - - 0 1"]:
		game.load_fen(fen)
		baseline_nodes = 0
		var truth := reference(bot, game, 3, 0)
		move = await bot.choose_move(game)
		check(bot.last_score == truth and game.play(move), "Alpha-beta agrees with unpruned three-ply minimax")
		check(bot.last_nodes < baseline_nodes, "Pruning reduces visited nodes")
	# Exercise a busy middlegame and cancel a real suspended search.
	game.load_fen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
	bot.behavior.frame_budget_ms = 1
	var results: Array = []
	run_cancel(bot, game, results)
	await get_tree().process_frame
	await get_tree().process_frame
	check(results.is_empty(), "Search is genuinely in flight before cancellation")
	bot.cancel()
	while results.is_empty():
		await get_tree().process_frame
	check(results[0].is_empty(), "Mid-search cancellation returns no stale move")
	bot.behavior.frame_budget_ms = 4
	move = await bot.choose_move(game)
	record(bot, "Kiwipete middlegame", move)
	check(bot.last_completed_depth == 3 and game.play(move), "Busy middlegame completes agreed depth legally")
	# Asserts that make/unmake legality restores all special-state fields.
	for fen in ["r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 7 12", "k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 1", "4k3/P7/8/8/8/8/8/4K3 w - - 0 1"]:
		game.load_fen(fen)
		var before := [game.board.duplicate(), game.turn, game.castling, game.ep, game.halfmove, game.fullmove, game.repetitions.duplicate()]
		var legal: Array = game.legal_moves()
		check(game.has_legal_move() == not legal.is_empty(), "Fast legal-existence check agrees with full generation")
		check(before == [game.board, game.turn, game.castling, game.ep, game.halfmove, game.fullmove, game.repetitions], "Legality make/unmake preserves full position state")
	bot.queue_free()
	print("BOT: ", checks - failures, "/", checks, " checks passed")
	# Optional committed test scene below runs this suite in a release browser.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.yyslChessVerification = " + JSON.stringify({"checks": checks, "failures": failures, "measurements": measurements}), true)
	else:
		get_tree().quit(1 if failures else 0)
