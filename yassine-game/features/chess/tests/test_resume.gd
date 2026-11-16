extends SceneTree
const Rules = preload("res://features/chess/chess_rules.gd")
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

func wait_bot(a) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while a.thinking and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not a.thinking, "Resumed bot completes without freezing")

func signature(a) -> Array:
	return [a.game.board.duplicate(), a.game.turn, a.game.castling, a.game.ep, a.game.halfmove, a.game.fullmove,
		a.game.repetitions.duplicate(), a.bot.rng.state, a.last_move.duplicate(), a.human_color, a.selected,
		a.history.entries.duplicate(true), a.history.latest_human_id, a.history.challenged_human_id,
		a.review_index, a.promotion_moves.duplicate(true), a.rps_active, a.rps_resolved, a.rps_target, a.rps_choice, a.ended,
		a.captured_by_white.duplicate(), a.captured_by_black.duplicate()]

func run() -> void:
	var main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(main)
	main.title_screen.get_node("Continue").pressed.emit()
	await pause(2.0)
	var stage = main._stage
	stage.board_button.pressed.emit()
	var a = stage.activity
	var identity: int = a.get_instance_id()
	var fist_state: int = a.fist_choice.rng.state
	var left_colour: int = a.fist_choice.left_colour
	a.back.pressed.emit()
	check(a.suspended and not a.visible and stage.ui.visible and stage.letter.enabled, "Back suspends chess and restores the table and letter")
	check(a.process_mode == Node.PROCESS_MODE_DISABLED and stage.match_layer.get_child_count() == 1, "Exactly one retained match has its processing disabled")
	a.fist_choice.choose(0)
	check(a.human_color == 0 and a.fist_choice.selected_hand == -1, "Hidden fists cannot be selected")
	var daps: int = stage.dap_count
	stage.dap_button.pressed.emit()
	check(stage.dap_count == daps + 1, "Table dap works while chess is saved")
	stage.board_button.pressed.emit()
	check(stage.activity.get_instance_id() == identity and not a.suspended and not stage.dap.active, "Returning reuses the same match and stops table dap")
	check(a.fist_choice.rng.state == fist_state and a.fist_choice.left_colour == left_colour, "Returning before colour selection does not reroll the queens")
	a.fist_choice.left_colour = 1
	a.fist_choice.choose(0)
	await pause(0.2)
	a.back.pressed.emit()
	var reveal_left: float = a.colour_timer.time_left
	await pause(1.4)
	check(a.choosing_colour and a.human_color == 1 and is_equal_approx(a.colour_timer.time_left, reveal_left), "Leaving during the reveal freezes its remaining time and committed colour")
	stage.board_button.pressed.emit()
	await pause(reveal_left + 0.15)
	check(not a.choosing_colour and a.human_color == 1 and a.history.entries.is_empty(), "The same reveal completes after returning without another fist choice")
	a.bot.behavior = a.bot.behavior.duplicate()
	a.bot.behavior.think_delay_seconds = 0.6
	a.select_square(Rules.square("e2"))
	a.select_square(Rules.square("e4"))
	check(a.thinking, "A reply is pending before leaving")
	var saved := signature(a)
	a.back.pressed.emit()
	await pause(0.8)
	check(signature(a) == saved and not a.thinking, "Leaving during bot delay freezes board, rights, counters, RNG and inventory")
	a.select_square(Rules.square("d2"))
	a._request_takeback()
	a._resign()
	a._bot_turn()
	check(signature(a) == saved, "Suspended chess rejects direct move, takeback, resign and bot actions")
	for i in range(5):
		stage.board_button.pressed.emit()
		check(a.thinking, "Returning queues one interrupted bot reply")
		a.back.pressed.emit()
	stage.board_button.pressed.emit()
	await wait_bot(a)
	check(a.history.entries.size() == 2 and a.game.turn == 1 and a.game.board[Rules.square("c6")] == -Rules.PAWN, "Repeated interruptions produce exactly one legal book reply")
	a.undo.pressed.emit()
	saved = signature(a)
	a.back.pressed.emit()
	stage.board_button.pressed.emit()
	check(signature(a) == saved and a.review_index >= 0, "Undo preview and untouched live position survive Back")
	a.undo.pressed.emit()
	a.takeback.pressed.emit()
	saved = signature(a)
	var rps_text: String = a.get_node("RPS/Dialog/Contents/Result").text
	a.back.pressed.emit()
	stage.board_button.pressed.emit()
	check(signature(a) == saved and a.get_node("RPS").visible and a.get_node("RPS/Dialog/Contents/Result").text == rps_text, "An unfinished RPS challenge resumes with the same committed hand")
	a._play_rps((a.rps_choice + 2) % 3)
	a._close_rps()
	saved = signature(a)
	a.back.pressed.emit()
	stage.board_button.pressed.emit()
	check(signature(a) == saved and a.takeback.disabled, "Leaving cannot restore a consumed takeback attempt")
	a.restart(1)
	a.game.load_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	a._refresh()
	a.select_square(Rules.square("a7"))
	a.select_square(Rules.square("a8"))
	saved = signature(a)
	a.back.pressed.emit()
	stage.board_button.pressed.emit()
	check(signature(a) == saved and a.promotion_row.visible and a.promotion_moves.size() == 4, "A pending promotion resumes without moving the pawn or auto-choosing")
	a._promote(Rules.KNIGHT)
	saved = signature(a)
	a.back.pressed.emit()
	stage.board_button.pressed.emit()
	check(signature(a) == saved and a.ended == "Draw by insufficient material", "A finished game remains saved and cannot silently restart")
	a.restart(-1)
	saved = signature(a)
	a.back.pressed.emit()
	await pause(0.8)
	check(signature(a) == saved and a.history.entries.is_empty(), "Black's pending White opening stays frozen at the table")
	stage.board_button.pressed.emit()
	await wait_bot(a)
	check(a.human_color == -1 and a.game.turn == -1 and a.history.entries.size() == 1, "Returning as Black preserves orientation and applies one White opening")
	a.restart(1)
	a.bot.behavior.think_delay_seconds = 0.0
	a.select_square(Rules.square("h2"))
	a.select_square(Rules.square("h4"))
	await process_frame
	await process_frame
	check(a.thinking, "Fallback search is running before suspension")
	saved = signature(a)
	a.back.pressed.emit()
	await pause(0.2)
	check(signature(a) == saved and not a.thinking, "An interrupted search cannot apply a hidden move")
	stage.board_button.pressed.emit()
	await wait_bot(a)
	check(a.history.entries.size() == 2 and a.game.turn == 1, "Fallback search safely resumes and commits once")
	var nodes := get_node_count()
	saved = signature(a)
	for i in range(20):
		a.back.pressed.emit()
		stage.board_button.pressed.emit()
	await process_frame
	check(get_node_count() == nodes and stage.match_layer.get_child_count() == 1 and a.leave_requested.get_connections().size() == 1, "Twenty round trips do not accumulate scenes or signal connections")
	check(signature(a) == saved and a.get_instance_id() == identity, "Repeated round trips preserve the full match")
	a._resign()
	saved = signature(a)
	a.back.pressed.emit()
	stage.board_button.pressed.emit()
	check(signature(a) == saved and "resigned" in a.ended, "A resigned match stays resigned after returning")
	main.queue_free()
	await process_frame
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	await process_frame
	print("RESUME: ", checks - failures, "/", checks, " checks passed")
	quit(1 if failures else 0)
