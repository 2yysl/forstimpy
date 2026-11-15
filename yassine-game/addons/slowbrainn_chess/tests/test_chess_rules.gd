extends SceneTree
const Rules = preload("res://addons/slowbrainn_chess/chess_rules.gd")
const Bot = preload("res://addons/slowbrainn_chess/chess_bot.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func has_move(game, text: String) -> bool:
	for move in game.legal_moves():
		if Rules.uci(move) == text:
			return true
	return false

func perft(game, depth: int) -> int:
	if depth == 0:
		return 1
	var count := 0
	for move in game.legal_moves():
		var next = game.copy_position()
		next._apply(move)
		count += perft(next, depth - 1)
	return count

func _run() -> void:
	var started := Time.get_ticks_msec()
	var game = Rules.new()
	check(Rules.square_name(Rules.square("e4")) == "e4", "Square names round trip")
	check(game.board.size() == 64 and game.board.count(0) == 32, "Starting board has 32 pieces")
	check(perft(game, 1) == 20, "Initial perft(1) = 20")
	check(perft(game, 2) == 400, "Initial perft(2) = 400")
	check(perft(game, 3) == 8902, "Initial perft(3) = 8902")
	game.load_fen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
	check(perft(game, 1) == 48, "Kiwipete perft(1) = 48")
	check(perft(game, 2) == 2039, "Kiwipete perft(2) = 2039")
	game.load_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
	check(perft(game, 3) == 2812, "Rook/pawn ending perft(3) = 2812")
	game = Rules.new()
	check(not game.play_uci("e2e5"), "Illegal pawn move rejected")
	for text in ["e2e4", "a7a6", "e4e5", "d7d5"]:
		check(game.play_uci(text), "EP setup: " + text)
	check(game.play_uci("e5d6") and game.board[Rules.square("d5")] == 0, "En passant removes captured pawn")
	game.load_fen("k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	check(not has_move(game, "e5d6"), "En passant exposing own king rejected")
	var pinned_ep_key: String = game.position_key()
	game.ep = -1
	check(game.position_key() == pinned_ep_key, "Unusable EP does not prevent repetition")
	game.load_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	check(has_move(game, "e1g1") and has_move(game, "e1c1"), "Both White castles generated")
	check(game.play_uci("e1g1") and game.board[61] == Rules.ROOK and game.board[63] == 0, "Castling moves rook")
	check(game.castling == "kq", "Castling removes both own rights")
	game.load_fen("4kr2/8/8/8/8/8/8/R3K2R w KQ - 0 1")
	check(not has_move(game, "e1g1") and has_move(game, "e1c1"), "Castling through attack rejected")
	game.load_fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	check(game.play_uci("a1a8") and "q" not in game.castling and "Q" not in game.castling, "Rook capture updates castling rights")
	game.load_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	for suffix in ["q", "r", "b", "n"]:
		check(has_move(game, "a7a8" + suffix), "Promotion choice " + suffix)
	check(game.play_uci("a7a8n") and game.board[0] == Rules.KNIGHT, "Underpromotion applied")
	game.load_fen("4k3/8/8/8/8/8/p7/4K3 b - - 0 1")
	check(game.play_uci("a2a1q") and game.board[56] == -Rules.QUEEN, "Black promotion applied")
	game = Rules.new()
	for text in ["f2f3", "e7e5", "g2g4", "d8h4"]:
		check(game.play_uci(text), "Mate setup: " + text)
	check(game.outcome(game.legal_moves()) == "Black wins by checkmate", "Fool's mate recognized")
	game.load_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
	check(game.outcome(game.legal_moves()) == "Draw by stalemate", "Stalemate recognized")
	game.load_fen("4k3/8/8/8/8/8/8/4KB2 w - - 0 1")
	check(game.insufficient_material(), "King and bishop is insufficient")
	game.load_fen("4k3/8/8/8/8/8/8/R3K3 w - - 100 1")
	check(game.can_claim_draw() and game.outcome(game.legal_moves()).is_empty(), "50-move draw is claimable")
	game.halfmove = 150
	check(game.outcome(game.legal_moves()) == "Draw by 75-move rule", "75-move draw is automatic")
	game = Rules.new()
	for cycle in 4:
		for text in ["g1f3", "g8f6", "f3g1", "f6g8"]:
			check(game.play_uci(text), "Repetition setup " + str(cycle) + " " + text)
		if cycle == 1:
			check(game.can_claim_draw() and game.outcome(game.legal_moves()).is_empty(), "Threefold is claimable")
	check(game.outcome(game.legal_moves()) == "Draw by fivefold repetition", "Fivefold is automatic")
	var bot = Bot.new()
	root.add_child(bot)
	bot.rng.seed = 20261114
	bot.behavior = bot.behavior.duplicate()
	bot.behavior.think_delay_seconds = 0.0
	game = Rules.new()
	var opening: Dictionary = bot.book.choose(game, game.legal_moves(), bot.rng)
	check(Rules.uci(opening) in ["e2e4", "d2d4"], "White book legal opening")
	game.play_uci("e2e4")
	var response: Dictionary = await bot.choose_move(game)
	check(Rules.uci(response) == "c7c6" and game.play(response), "Black book favors c6")
	game.play_uci("d2d4")
	response = await bot.choose_move(game)
	check(Rules.uci(response) == "d7d5" and game.play(response), "Black book follows with d5")
	game = Rules.new()
	game.play_uci("h2h4")
	response = await bot.choose_move(game)
	check(not response.is_empty() and game.play(response), "Legal fallback after book deviation")
	print("Fallback bot time: ", bot.last_search_ms, " ms")
	check(bot.last_search_ms < 1500, "Bot search completes within desktop smoke limit")
	bot.queue_free()
	print("RULES: ", checks - failures, "/", checks, " checks passed in ", Time.get_ticks_msec() - started, " ms")
	quit(1 if failures else 0)
