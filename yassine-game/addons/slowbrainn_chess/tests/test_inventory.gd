extends SceneTree
const Rules = preload("res://addons/slowbrainn_chess/chess_rules.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	print("PASS: " if condition else "FAIL: ", message)
	if not condition:
		failures += 1
		push_error(message)

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func wait_bot(a) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while a.thinking and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not a.thinking, "Bot completes or cancels without freezing")

func signature(a) -> Array:
	return [a.game.board.duplicate(), a.game.turn, a.game.castling, a.game.ep, a.game.halfmove, a.game.fullmove,
		a.game.repetitions.duplicate(), a.bot.rng.state, a.last_move.duplicate()]

func manual_move(a, text: String) -> void:
	for move in a.game.legal_moves():
		if Rules.uci(move) == text:
			var before: Dictionary = a.history.capture(a.game, a.bot.rng.state, a.last_move)
			check(a.game.play(move), "Fixture move legal: " + text)
			a.history.record(before, move, a.human_color)
			a.last_move = move
			a._refresh()
			return
	check(false, "Fixture move missing: " + text)

func win(a) -> void:
	a.takeback.pressed.emit()
	check(a.rps_active, "Takeback opens RPS")
	a.rps_choice = 2
	a._play_rps(0)
	check(a.rps_resolved and "won" in a.get_node("RPS/Dialog/Contents/Result").text, "Rock beats scissors and grants takeback")
	a.get_node("RPS/Dialog/Contents/Close").pressed.emit()

func _run() -> void:
	var a = load("res://addons/slowbrainn_chess/ChessActivity.tscn").instantiate()
	root.add_child(a)
	a.bot.behavior = a.bot.behavior.duplicate()
	a.bot.behavior.think_delay_seconds = 0.4
	check(a.undo.disabled and a.takeback.disabled and not a.resign.disabled, "Fresh game: review/takeback unavailable, resign available")
	check(a.inventory.get_node("Contents/Buttons").get_child_count() == 3 and not a.has_node("TopStrip/Controls/Actions/ClaimDraw"), "Three inventory buttons replace Claim draw")
	a.select_square(Rules.square("e2"))
	a.select_square(Rules.square("e4"))
	await wait_bot(a)
	check(a.history.entries.size() == 2, "Both human and bot moves recorded")
	var actual := signature(a)
	a.undo.pressed.emit()
	check(a.review_index == 1 and a.undo.button_pressed, "Undo toggles latest-move preview")
	check(a.history.entries[1].before.position.board[Rules.square("c7")] == -Rules.PAWN, "Preview shows before the latest bot move")
	a.select_square(Rules.square("d2"))
	a.select_square(Rules.square("d4"))
	check(signature(a) == actual and a.history.entries.size() == 2, "Review cannot make moves or mutate live state/history")
	a.undo.pressed.emit()
	check(a.review_index == -1 and signature(a) == actual, "Undo again returns to untouched live game")
	# Losing does not move anything and cannot be bypassed by reopening/review.
	a.takeback.pressed.emit()
	await process_frame
	await process_frame
	var dialog: Rect2 = a.get_node("RPS/Dialog").get_rect()
	check(dialog.size.y <= 340 and Rect2(Vector2.ZERO, a.size).encloses(dialog), "Wrapped RPS dialog stays compact and inside the viewport")
	var committed_hand: int = a.rps_choice
	check(committed_hand >= 0 and committed_hand <= 2, "Character hand is committed before player choice")
	a._play_rps((committed_hand + 2) % 3)
	check(a.rps_resolved and signature(a) == actual, "Loss leaves full chess state unchanged")
	a._close_rps()
	check(a.takeback.disabled and a.history.challenge_index() == -1, "Loss consumes this player move's challenge")
	a.undo.pressed.emit()
	a.undo.pressed.emit()
	a.takeback.pressed.emit()
	check(not a.rps_active, "Review/reopening cannot bypass one-attempt limit")
	# A new user move earns another attempt; tied rounds do not consume it.
	var before_second := signature(a)
	a.select_square(Rules.square("d2"))
	a.select_square(Rules.square("d4"))
	await wait_bot(a)
	check(not a.takeback.disabled and a.history.entries.size() == 3, "A new player move permits the next challenge with bounded history")
	a.takeback.pressed.emit()
	actual = signature(a)
	a.rps_choice = 0
	a._play_rps(0)
	check(not a.rps_resolved and a.history.challenge_index() >= 0 and signature(a) == actual, "Tie replays without consuming the attempt")
	a.rps_choice = 2
	a._play_rps(0)
	check(signature(a) == before_second and a.game.turn == a.human_color and a.history.entries.size() == 1, "Win restores previous user turn and removes both plies")
	a._play_rps(0)
	check(signature(a) == before_second, "Repeated result clicks cannot apply a second takeback")
	a._close_rps()
	check(a.takeback.disabled, "A win cannot chain older takebacks without another chess move")
	# Claiming the same move again reproduces the opening response/RNG state.
	a.select_square(Rules.square("d2"))
	a.select_square(Rules.square("d4"))
	await wait_bot(a)
	check(signature(a) == actual, "Replaying the same move reproduces the character's book reply")
	a.select_square(Rules.square("b1"))
	a.select_square(Rules.square("c3"))
	a.undo.pressed.emit()
	await wait_bot(a)
	check(a.review_index >= 0 and a.history.entries[a.review_index].move.from == Rules.square("b1") and a.history.entries[a.review_index].before.position.board[Rules.square("b1")] == Rules.KNIGHT, "Preview remains on the chosen move when bot reply trims bounded history")
	a.undo.pressed.emit()
	check(a.history.entries.size() == 3 and a.game.board[Rules.square("c3")] == Rules.KNIGHT, "Returning from preview shows live game after the bot finished")
	# Interrupt a pending bot turn; loss/cancel resumes, win never queues a stale reply.
	a.restart(1)
	a.select_square(Rules.square("e2"))
	a.select_square(Rules.square("e4"))
	check(a.thinking, "Bot is pending before challenge")
	a.takeback.pressed.emit()
	actual = signature(a)
	await pause(0.7)
	check(not a.thinking and signature(a) == actual and a.history.entries.size() == 1, "RPS freezes pending bot reply")
	a._close_rps()
	check(a.thinking, "Cancelling an unplayed challenge resumes the pending turn")
	await wait_bot(a)
	check(a.history.entries.size() == 2 and not a.takeback.disabled, "Cancelled challenge does not consume the attempt or duplicate bot moves")
	a.restart(1)
	actual = signature(a)
	a.select_square(Rules.square("e2"))
	a.select_square(Rules.square("e4"))
	win(a)
	await pause(0.7)
	check(signature(a) == actual and a.history.entries.is_empty() and not a.thinking, "Takeback before bot reply restores the user turn and rejects stale work")
	# A Black player keeps the opening White move when restoring their first turn.
	a.restart(-1)
	await wait_bot(a)
	check(a.takeback.disabled and not a.undo.disabled, "Black cannot take back an opening before making a user move")
	actual = signature(a)
	a.select_square(Rules.square("c7"))
	a.select_square(Rules.square("c6"))
	win(a)
	check(signature(a) == actual and a.game.turn == -1 and a.history.entries.size() == 1, "Black takeback restores the previous Black turn, retaining White's opening")
	# Special-state restoration, using legal fixture moves to avoid long AI waits.
	for fixture in [
		["r3k2r/ppp2ppp/8/8/8/8/PPP2PPP/R3K2R w KQkq - 9 12", "e1g1", "a7a6"],
		["4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 12", "e5d6", "e8d7"],
		["4k3/P6p/8/8/8/8/8/4K3 w - - 0 5", "a7a8q", "e8d7"]]:
		a.restart(1)
		a.game.load_fen(fixture[0])
		a.game.repetitions[a.game.position_key()] = 2
		a._refresh()
		actual = signature(a)
		manual_move(a, fixture[1])
		manual_move(a, fixture[2])
		win(a)
		check(signature(a) == actual, "Takeback restores rights/EP/promotion, counters and repetition history: " + fixture[1])
	# Resign is a loss, including during pending AI work; never a draw claim.
	a.restart(1)
	a.select_square(Rules.square("e2"))
	a.select_square(Rules.square("e4"))
	a.resign.pressed.emit()
	actual = signature(a)
	await pause(0.7)
	check(a.ended == "Black wins — you resigned" and signature(a) == actual and not a.thinking, "Resign concedes and cancels pending replies")
	check(a.resign.disabled and a.takeback.disabled, "Ended games disable resign/takeback")
	a.select_square(Rules.square("d2"))
	a.select_square(Rules.square("d4"))
	check(signature(a) == actual, "Ended game cannot accept moves")
	a.restart(1)
	check(a.history.entries.is_empty() and a.review_index == -1 and not a.rps_active and a.ended.is_empty(), "Restart resets inventory and challenge lifecycle")
	a.queue_free()
	await process_frame
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	await process_frame
	print("INVENTORY: ", checks - failures, "/", checks, " checks passed")
	quit(1 if failures else 0)
