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

func move(a, uci: String) -> bool:
	for legal in a.game.legal_moves():
		if Rules.uci(legal) == uci:
			var success: bool = a._commit_move(legal, a._capture_snapshot())
			a._refresh()
			check(success, "Committed fixture move: " + uci)
			return success
	check(false, "Legal fixture move missing: " + uci)
	return false

func fixture(a, fen: String, colour := 1) -> void:
	a.restart(1)
	a.human_color = colour
	a.game.load_fen(fen)
	a._refresh()

func run() -> void:
	var a = load("res://features/chess/ChessActivity.tscn").instantiate()
	root.add_child(a)
	check(not a.get_node("PlayerCaptures").visible and not a.get_node("CharacterCaptures").visible, "Captured-piece trays stay hidden during fist selection")
	a.restart(1)
	check(a.captured_by_white.is_empty() and a.captured_by_black.is_empty(), "A fresh match starts with empty collections")
	var invalid := {"from": Rules.square("e2"), "to": Rules.square("d7"), "promotion": 0}
	check(not a._commit_move(invalid, a._capture_snapshot()) and a.captured_by_white.is_empty(), "An illegal capture cannot add a piece")
	fixture(a, "4k3/8/8/3n4/1N6/8/8/4K3 w - - 0 1")
	move(a, "b4d5")
	check(a.captured_by_white == [-Rules.KNIGHT] and a.captured_by_black.is_empty(), "White taking a Black knight puts that Black knight in White's collection")
	check(a.get_node("PlayerCaptures").pieces == [-Rules.KNIGHT] and a.get_node("CharacterCaptures").pieces.is_empty(), "White player sees the captured knight on their own side")
	a.human_color = -1
	a._refresh()
	check(a.get_node("CharacterCaptures").pieces == [-Rules.KNIGHT] and a.get_node("PlayerCaptures").pieces.is_empty(), "A Black player sees White's captures on the character's side")
	fixture(a, "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 12")
	move(a, "e5d6")
	check(a.captured_by_white == [-Rules.PAWN] and a.game.board[Rules.square("d5")] == 0, "White en passant collects the pawn from its actual square")
	fixture(a, "4k3/8/8/8/3Pp3/8/8/4K3 b - d3 0 12", -1)
	move(a, "e4d3")
	check(a.captured_by_black == [Rules.PAWN] and a.get_node("PlayerCaptures").pieces == [Rules.PAWN], "Black en passant collects the White pawn on Black's side")
	fixture(a, "1r2k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	move(a, "a7b8q")
	check(a.captured_by_white == [-Rules.ROOK] and a.game.board[Rules.square("b8")] == Rules.QUEEN, "Capture-promotion collects the rook without treating the promoted pawn as captured")
	fixture(a, "1r2k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	move(a, "a7a8q")
	check(a.captured_by_white.is_empty() and a.captured_by_black.is_empty(), "A quiet promotion does not add a captured piece")
	move(a, "b8a8")
	check(a.captured_by_black == [Rules.QUEEN], "Capturing a promoted piece displays its current Queen identity")
	fixture(a, "r3k2r/ppp2ppp/8/8/8/8/PPP2PPP/R3K2R w KQkq - 9 12")
	move(a, "e1g1")
	check(a.captured_by_white.is_empty() and a.captured_by_black.is_empty(), "Castling adds no captured pieces")
	a.restart(1)
	move(a, "e2e4")
	move(a, "d7d5")
	move(a, "e4d5")
	move(a, "d8d5")
	check(a.captured_by_white == [-Rules.PAWN] and a.captured_by_black == [Rules.PAWN], "Both sides maintain independent, ordered capture lists")
	a.previous.pressed.emit()
	check(a.get_node("PlayerCaptures").pieces == [-Rules.PAWN] and a.get_node("CharacterCaptures").pieces.is_empty(), "Undo preview displays the collections before the latest capture")
	check(a.captured_by_black == [Rules.PAWN], "Preview leaves the live capture lists unchanged")
	a.leave_match()
	a.resume_match()
	check(a.review_index >= 0 and a.get_node("CharacterCaptures").pieces.is_empty() and a.captured_by_black == [Rules.PAWN], "Saved previews retain their historical trays and live collections")
	a.live.pressed.emit()
	check(a.get_node("CharacterCaptures").pieces == [Rules.PAWN], "Returning to live play restores the live captured-piece display")
	var saved: Dictionary = a._capture_snapshot()
	a.leave_match()
	a.resume_match()
	check(a.captured_by_white == saved.captured_white and a.captured_by_black == saved.captured_black, "Back and resume preserve both capture collections")
	a.takeback.pressed.emit()
	a.rps_choice = 0
	a._play_rps(2)
	a._close_rps()
	check(a.captured_by_white == [-Rules.PAWN] and a.captured_by_black == [Rules.PAWN], "A lost takeback leaves captured pieces unchanged")
	# Fresh fixture for a won challenge on the same pair of captures.
	a.restart(1)
	for uci in ["e2e4", "d7d5", "e4d5", "d8d5"]:
		move(a, uci)
	a.takeback.pressed.emit()
	a.rps_choice = 2
	a._play_rps(0)
	a._close_rps()
	check(a.captured_by_white.is_empty() and a.captured_by_black.is_empty() and a.game.board[Rules.square("e4")] == Rules.PAWN and a.game.board[Rules.square("d5")] == -Rules.PAWN, "A won takeback removes both collected pawns and returns them to their original squares")
	check(a.get_node("PlayerCaptures").pieces.is_empty() and a.get_node("CharacterCaptures").pieces.is_empty(), "Takeback refreshes both visible trays")
	move(a, "e4d5")
	move(a, "d8d5")
	move(a, "b1c3")
	move(a, "d5e5")
	check(a.history.entries.size() == 3 and a.captured_by_white == [-Rules.PAWN] and a.captured_by_black == [Rules.PAWN], "Capture lists outlive the bounded three-move preview history")
	var before: Dictionary = a._capture_snapshot()
	a.game.legal_moves()
	a.game.copy_position()
	check(a.captured_by_white == before.captured_white and a.captured_by_black == before.captured_black, "Legality checks and search copies never add captured pieces")
	fixture(a, "4k3/8/8/8/8/8/3Q4/3rK3 b - - 0 1")
	a._bot_turn()
	var deadline := Time.get_ticks_msec() + 10000
	while a.thinking and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not a.thinking and a.captured_by_black == [Rules.QUEEN], "The real bot commit path records its captured Queen")
	# Full collections stay inside both placeholder trays without icon nodes.
	a.captured_by_white.assign([-1, -1, -1, -1, -1, -1, -1, -1, -2, -2, -3, -3, -4, -4, -5])
	a.captured_by_black.assign([1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5])
	a._refresh()
	await process_frame
	var nodes := get_node_count()
	check(a.get_node("PlayerCaptures").get_child_count() == 0 and a.get_node("CharacterCaptures").get_child_count() == 0, "All captured-piece icons are drawn without creating nodes")
	for i in range(100):
		a._refresh_captures()
	check(get_node_count() == nodes, "Repeated tray refreshes do not accumulate nodes")
	for tray in [a.get_node("PlayerCaptures"), a.get_node("CharacterCaptures")]:
		print("TRAY_LAYOUT viewport=", a.size, " tray=", tray.name, " rect=", tray.get_rect(), " board=", a.board_rect, " inventory=", a.inventory.get_rect())
		check(Rect2(Vector2.ZERO, a.size).encloses(tray.get_rect()) and not tray.get_rect().intersects(a.board_rect) and not tray.get_rect().intersects(a.inventory.get_rect()), "Capture tray fits without covering the board or inventory")
	a.restart(1)
	check(a.captured_by_white.is_empty() and a.captured_by_black.is_empty(), "A genuinely fresh match clears both collections")
	a.queue_free()
	await process_frame
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	await process_frame
	print("CAPTURED PIECES: ", checks - failures, "/", checks, " checks passed")
	quit(1 if failures else 0)
