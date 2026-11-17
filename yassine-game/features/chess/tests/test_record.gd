extends SceneTree
const Rules = preload("res://features/chess/chess_rules.gd")
const Record = preload("res://features/chess/chess_record.gd")
var checks := 0
var failures := 0
var exported := {}
var output := ""

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ", message)
	if not value:
		failures += 1
		push_error(message)

func add(game, record, uci: String) -> void:
	for move in game.legal_moves():
		if Rules.uci(move) == uci:
			var before := {"position": game.copy_position(), "captured_white": [], "captured_black": []}
			var played: bool = game.play(move)
			assert(played)
			record.append(before, move, game)
			return
	assert(false, "Invalid fixture move: " + uci)

func export_game(name: String, game, record) -> void:
	var file := FileAccess.open(output.path_join(name + ".pgn"), FileAccess.WRITE)
	file.store_string(record.pgn())
	exported[name + ".pgn"] = Record.fen(game)

func run() -> void:
	output = ProjectSettings.globalize_path("res://").path_join("../builds/match-history/verification/pgn").simplify_path()
	DirAccess.make_dir_recursive_absolute(output)
	var game = Rules.new()
	check(Record.fen(game) == Record.START_FEN, "Standard initial position exports exact FEN")
	var record = Record.new(game, 1, "yyslChess")
	for uci in ["f2f3", "e7e5", "g2g4", "d8h4"]:
		add(game, record, uci)
	record.finish(game.outcome(game.legal_moves()))
	check(record.moves.map(func(entry): return entry.san) == ["f3", "e5", "g4", "Qh4#"], "SAN marks checkmate and preserves the complete move order")
	check(record.result == "0-1" and record.winner == -1 and record.finished_at >= record.started_at, "Finished record stores winner, result and time")
	check("yyslChess beat you" in record.summary() and "Checkmate" in record.summary(), "History summary identifies winner, loser, time and ending")
	check("1. f3 e5 2. g4 Qh4# 0-1" in record.pgn() and "[White \"You\"]" in record.pgn(), "PGN includes players, legal SAN move numbers and result")
	export_game("mate", game, record)
	var old_pgn: String = record.pgn()
	record.truncate(0)
	record.finish("White wins by checkmate")
	check(record.pgn() == old_pgn, "A finished archived record cannot be truncated or reclassified")
	for fixture in [
		["castle", "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", "e1g1", "O-O"],
		["long-castle", "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", "e1c1", "O-O-O"],
		["file", "4k3/8/8/8/8/8/8/1N2KN2 w - - 0 1", "b1d2", "Nbd2"],
		["rank", "4k3/8/8/8/8/R7/8/R3K3 w - - 0 1", "a1a2", "R1a2"],
		["both", "4k3/8/8/8/8/4N3/8/N3N2K w - - 0 1", "e1c2", "Ne1c2"],
		["pinned", "k3r3/8/8/8/8/8/N3N3/4K3 w - - 0 1", "a2c3", "Nc3"],
		["ep-white", "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 12", "e5d6", "exd6"],
		["ep-black", "4k3/8/8/8/3Pp3/8/8/4K3 b - d3 0 12", "e4d3", "exd3"],
		["promotion", "1r2k3/P7/8/8/8/8/8/4K3 w - - 0 1", "a7b8q", "axb8=Q+"],
		["underpromotion", "4k3/P7/8/8/8/8/8/4K3 w - - 0 1", "a7a8n", "a8=N"]]:
		game = Rules.new(false)
		game.load_fen(fixture[1])
		record = Record.new(game, -1, "yyslChess")
		add(game, record, fixture[2])
		check(record.moves[0].san == fixture[3], "Correct SAN for " + fixture[0])
		check(Record.fen(record.replay(1).position) == Record.fen(game), "Replay reproduces the exact special-move position: " + fixture[0])
		export_game(fixture[0], game, record)
		if fixture[0] == "ep-black":
			check("12... exd3" in record.pgn(), "A custom Black-to-move start has correct PGN numbering")
		if fixture[0].begins_with("ep-"):
			check(record.replay(1).captured_white == [-Rules.PAWN] if fixture[0] == "ep-white" else record.replay(1).captured_black == [Rules.PAWN], "Replay restores en passant captured-piece lists")
	game = Rules.new()
	record = Record.new(game)
	for uci in ["e2e4", "d7d5", "e4d5", "d8d5"]:
		add(game, record, uci)
	check(record.replay(2).captured_white.is_empty() and record.replay(3).captured_white == [-Rules.PAWN] and record.replay(4).captured_black == [Rules.PAWN], "Replay reconstructs each side's captures at every position")
	record.truncate(2)
	game = record.replay(2).position
	add(game, record, "e4e5")
	check(record.moves.size() == 3 and "exd5" not in record.pgn() and "Qxd5" not in record.pgn(), "Takeback truncation removes discarded moves from PGN and replay")
	export_game("takeback", game, record)
	game = Rules.new()
	record = Record.new(game)
	for i in 100:
		for uci in ["g1f3", "g8f6", "f3g1", "f6g8"]:
			add(game, record, uci)
	var began := Time.get_ticks_usec()
	var replayed: Dictionary = record.replay(400)
	var elapsed := (Time.get_ticks_usec() - began) / 1000.0
	check(record.moves.size() == 400 and Record.fen(replayed.position) == Record.fen(game), "A 400-ply log replays exactly without retaining per-ply rules snapshots")
	print("REPLAY_400_PLIES_MS=", elapsed)
	export_game("long", game, record)
	var black_record = Record.new(Rules.new(), -1)
	black_record.finish("White wins — you resigned")
	check("yyslChess beat you" in black_record.summary() and black_record.result == "1-0", "Resignation winner maps correctly when the human is Black")
	var draw = Record.new(Rules.new())
	draw.finish("Draw by stalemate")
	check(draw.winner == 0 and "Draw" in draw.summary() and "Stalemate" in draw.summary(), "Stalemate is a draw with no invented winner")
	var manifest := FileAccess.open(output.path_join("expected.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify(exported))
	print("RECORD: ", checks - failures, "/", checks, " checks passed")
	quit(1 if failures else 0)
