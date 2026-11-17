extends SceneTree
const Rules = preload("res://features/chess/chess_rules.gd")
const Record = preload("res://features/chess/chess_record.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ", message)
	if not value:
		failures += 1
		push_error(message)

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func move(a, uci: String) -> void:
	for legal in a.game.legal_moves():
		if Rules.uci(legal) == uci:
			var committed: bool = a._commit_move(legal, a._capture_snapshot())
			assert(committed)
			a._refresh()
			return
	assert(false, "Missing fixture move " + uci)

func wait_bot(a) -> void:
	var until := Time.get_ticks_msec() + 10000
	while a.thinking and Time.get_ticks_msec() < until:
		await process_frame
	check(not a.thinking, "A pending live reply resumes without freezing")

func run() -> void:
	var main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(main)
	main.title_screen.get_node("Continue").pressed.emit()
	await pause(2.0)
	var stage = main._stage
	check(not stage.table_new_game.visible and stage.match_archive.records.is_empty(), "The table starts with no restart action or archived matches")
	stage.board_button.pressed.emit()
	var a = stage.activity
	a.restart(1)
	check(a.previous.disabled and a.next.disabled and a.live.disabled and not a.new_game.visible and not a.chess_review.visible, "Fresh games expose no completed-game or unavailable replay actions")
	for uci in ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6", "e1g1", "f8e7"]:
		move(a, uci)
	check(a.record.moves.size() == 10 and a.history.entries.size() == 3, "Full move recording is independent of the three takeback snapshots")
	var live_fen: String = Record.fen(a.game)
	var live_rng: int = a.bot.rng.state
	var challenge: int = a.history.challenge_index()
	for i in 12:
		a.previous.pressed.emit()
	check(a.review_index == 0 and a.previous.disabled and Record.fen(a.replay_cache.position) == Record.START_FEN, "Repeated previous arrows reach the exact start and stop there")
	check(Record.fen(a.game) == live_fen and a.bot.rng.state == live_rng and a.history.challenge_index() == challenge, "Navigation cannot change the live board, opening RNG or takeback eligibility")
	a.select_square(Rules.square("d2"))
	a.select_square(Rules.square("d4"))
	check(Record.fen(a.game) == live_fen and a.record.moves.size() == 10, "Review input cannot commit chess moves")
	for i in 10:
		a.next.pressed.emit()
	check(a.review_index == -1 and a.next.disabled and Record.fen(a.game) == live_fen, "Next arrows reach live play without changing the match")
	check(a.get_node("Inventory/Contents/Replay/Position").text == "10 / 10", "Navigation labels each individual move position")
	a.takeback.pressed.emit()
	a.rps_choice = 2
	a._play_rps(0)
	a._close_rps()
	check(a.record.moves.size() == 8 and "O-O" not in a.record.pgn() and a.game.castling.contains("K"), "An earned takeback removes both withdrawn moves from replay and export")
	a._resign()
	check(stage.match_archive.records.size() == 1 and a.record.is_finished() and a.new_game.visible and a.chess_review.visible, "Resignation archives the record and exposes New game and external review")
	for i in 10:
		a._refresh()
	check(stage.match_archive.records.size() == 1, "Refreshing or revisiting a finished game cannot archive it twice")
	var saved = stage.match_archive.records[0]
	var saved_pgn: String = saved.pgn()
	check("yyslChess beat you" in saved.summary() and "Resignation" in saved.summary(), "Match history names winner, loser and result")
	a.back.pressed.emit()
	check(a.suspended and stage.table_new_game.visible, "Back after a result exposes New game at the table")
	stage.table_new_game.pressed.emit()
	check(not a.suspended and a.choosing_colour and a.human_color == 0 and a.record == null, "The table's New game starts fresh fists in the same activity")
	check(stage.match_archive.records.size() == 1 and saved.pgn() == saved_pgn, "New game preserves the completed record and its full PGN")
	a._open_archived(0)
	check(a.review_record == saved and a.review_index == 8 and a.board_frame.visible and not a.fist_choice.visible, "A previous match opens as a replay even while the new game is choosing fists")
	a.previous.pressed.emit()
	check(a.review_index == 7 and saved.pgn() == saved_pgn, "Archived replay navigation leaves the archived moves immutable")
	a._return_live()
	check(a.review_record == null and a.choosing_colour and a.fist_choice.visible and a.human_color == 0, "Returning restores the unfinished fist selection without assigning a colour")
	a.bot.behavior = a.bot.behavior.duplicate()
	a.bot.behavior.think_delay_seconds = 0.6
	a.fist_choice.left_colour = -1
	a.fist_choice.choose(0)
	await pause(0.2)
	var reveal_left: float = a.colour_timer.time_left
	a._open_archived(0)
	a.back.pressed.emit()
	stage.board_button.pressed.emit()
	await pause(reveal_left + 0.1)
	check(a.review_record == saved and a.choosing_colour and is_equal_approx(a.colour_timer.time_left, reveal_left), "Archived review keeps the live fist reveal paused across Back and resume")
	a._return_live()
	await pause(reveal_left + 0.1)
	check(a.thinking and a.human_color == -1, "The new Black game has a pending White opening")
	var pending_record = a.record
	var pending_fen: String = Record.fen(a.game)
	var pending_rng: int = a.bot.rng.state
	a._open_archived(0)
	await pause(0.8)
	check(a.record == pending_record and Record.fen(a.game) == pending_fen and a.bot.rng.state == pending_rng and a.record.moves.is_empty(), "Viewing an old game freezes the pending live board and opening RNG")
	check(a._view_colour() == 1, "Archived replay uses the colour from that older match")
	a._return_live()
	await wait_bot(a)
	check(a.human_color == -1 and a.game.turn == -1 and a.record == pending_record and a.record.moves.size() == 1, "Returning restores Black orientation and records one resumed opening")
	# A zero-move custom-position fixture checks stalemate and FEN export.
	a.restart(1)
	a.game.load_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
	a._refresh()
	check(a.ended == "Draw by stalemate" and stage.match_archive.records.size() == 2, "Stalemate archives once and offers a new game")
	var draw = stage.match_archive.records[0]
	check(draw.winner == 0 and draw.result == "1/2-1/2" and "Stalemate" in draw.summary(), "A drawn history entry has no false winner or loser")
	check(a.get_node("MatchHistory/Contents/List").get_item_text(0) == draw.summary(), "History is newest first and includes the local finishing date/time")
	a.new_game.pressed.emit()
	check(a.choosing_colour and stage.match_archive.records.size() == 2, "The ended-board New game button also preserves all earlier games")
	a._open_archived(0)
	check(a._show_pgn() and a.get_node("PGN").visible, "Completed games expose their exact export in a modal")
	await process_frame
	await process_frame
	check(Rect2(Vector2.ZERO, a.size).encloses(a.get_node("PGN/Dialog").get_rect()), "The PGN reader and its buttons fit within the viewport")
	var pgn: String = a.get_node("PGN/Dialog/Contents/Text").text
	check(pgn == draw.pgn() and "[SetUp \"1\"]" in pgn and "[FEN \"7k/5Q2/6K1/8/8/8/8/8 b - - 0 1\"]" in pgn, "PGN export preserves custom starting positions and draw results")
	a._copy_pgn()
	check(DisplayServer.clipboard_get() == pgn, "Native copy places the exact game PGN in the clipboard")
	var old_moves: int = a.record.moves.size() if a.record != null else 0
	a.select_square(Rules.square("f7"))
	a._resign()
	a._request_takeback()
	check(a.review_record == draw and stage.match_archive.records.size() == 2 and a.choosing_colour, "Archived review and its export cannot mutate the unfinished live game")
	a.get_node("PGN/Dialog/Contents/Buttons/Close").pressed.emit()
	a._return_live()
	a._show_history()
	await process_frame
	check(a.history_open and a.get_node("MatchHistory").visible, "Small screens can open the session match-history panel")
	a._close_history()
	var nodes := get_node_count()
	for i in 20:
		a._open_archived(i % 2)
		a._return_live()
	check(get_node_count() == nodes and stage.match_layer.get_child_count() == 1 and stage.match_archive.records.size() == 2, "Repeated archived reviews reuse one scene and do not duplicate records")
	a.restart(1)
	a.game.load_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	a._refresh()
	a.select_square(Rules.square("a7"))
	a.select_square(Rules.square("a8"))
	a._open_archived(1)
	a.previous.pressed.emit()
	check(not a.next.disabled and a.promotion_moves.size() == 4, "Archived navigation works while the live match has an unfinished promotion")
	a._return_live()
	check(a.promotion_row.visible and a.game.board[Rules.square("a7")] == Rules.PAWN, "Returning from old-game review restores the pending promotion")
	a.restart(1)
	for uci in ["f2f3", "e7e5", "g2g4", "d8h4"]:
		move(a, uci)
	check(stage.match_archive.records.size() == 3 and a.record.result == "0-1" and a.new_game.visible, "Actual checkmate archives its full game and exposes New game")
	main.queue_free()
	await process_frame
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	await process_frame
	print("MATCH HISTORY: ", checks - failures, "/", checks, " checks passed")
	quit(1 if failures else 0)
