extends SceneTree
const Rules = preload("res://features/chess/chess_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	print("PASS: " if condition else "FAIL: ", message)
	if not condition:
		failures += 1
		push_error(message)

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func wait_match(a) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while (a.choosing_colour or a.thinking) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not a.choosing_colour and not a.thinking, "Reveal automatically reaches the player's turn")

func run() -> void:
	var scene = load("res://features/chess/ChessActivity.tscn")
	var a = scene.instantiate()
	root.add_child(a)
	check(a.choosing_colour and a.human_color == 0 and a.status.text == "choose a fist.", "Entry asks choose a fist before assigning a colour")
	check(a.fist_choice.visible and not a.board_frame.visible, "Fists occupy the board area before play")
	check(not a.has_node("TopStrip/Controls/Colors") and not a.has_node("TopStrip/Controls/Actions"), "Manual colour and Restart controls removed")
	check(a.undo.disabled and a.takeback.disabled and a.resign.disabled, "Inventory is unavailable before colour selection")
	var opening_rng: int = a.bot.rng.state
	var start_key: String = a.game.position_key()
	a.select_square(Rules.square("e2"))
	a.select_square(Rules.square("e4"))
	a._resign()
	a._request_takeback()
	a._bot_turn()
	await pause(0.4)
	check(a.game.position_key() == start_key and a.history.entries.is_empty() and a.ended.is_empty() and not a.thinking, "No chess actions or bot moves can occur before choosing")
	var sides := {}
	for seed_value in 64:
		a.fist_choice.rng.seed = seed_value
		a.fist_choice.begin_choice()
		sides[a.fist_choice.left_colour] = true
	check(sides.size() == 2 and a.bot.rng.state == opening_rng, "Colour shuffle supports both assignments without consuming chess RNG")
	check(a.visual_theme.left_fist_closed != null and a.visual_theme.right_fist_closed != null and a.visual_theme.left_fist_opened != null and a.visual_theme.right_fist_opened != null, "All four replaceable hand artwork slots are populated")
	for left_colour in [1, -1]:
		for hand in 2:
			a.restart(0)
			a.fist_choice.left_colour = left_colour
			var expected: int = left_colour if hand == 0 else -left_colour
			var chosen: Button = a.fist_choice.get_node("Left" if hand == 0 else "Right")
			var other: Button = a.fist_choice.get_node("Right" if hand == 0 else "Left")
			check(not chosen.get_node("Hand/Queen").visible and not other.get_node("Hand/Queen").visible, "Both queens remain hidden in closed fists")
			check(a.fist_choice.get_node("Left/Hand").texture == a.visual_theme.left_fist_closed and a.fist_choice.get_node("Right/Hand").texture == a.visual_theme.right_fist_closed, "Entry uses separate left/right closed images")
			chosen.pressed.emit()
			check(a.human_color == expected and a.choosing_colour, "Selected hidden queen sets the player's colour during reveal")
			check(chosen.get_node("Hand/Queen").texture == a.visual_theme.piece_texture(expected * Rules.QUEEN) and chosen.get_node("Hand/Queen").visible and not other.get_node("Hand/Queen").visible, "Only the selected fist reveals its correct queen texture")
			check(chosen.get_node("Hand").texture == (a.visual_theme.left_fist_opened if hand == 0 else a.visual_theme.right_fist_opened) and other.get_node("Hand").texture == (a.visual_theme.right_fist_closed if hand == 0 else a.visual_theme.left_fist_closed), "Chosen fist opens while the other stays closed")
			other.pressed.emit()
			chosen.pressed.emit()
			check(a.human_color == expected and chosen.disabled and other.disabled, "Repeated or alternate clicks cannot change the committed result")
			a.select_square(Rules.square("e2"))
			check(not a.thinking and a.history.entries.is_empty() and a.selected == -1, "Chess remains frozen while the queen is shown")
			await wait_match(a)
			check(a.human_color == expected and a.game.turn == expected and a.board_frame.visible and not a.fist_choice.visible, "Match uses assigned colour and shows the board without another click")
			check(a.history.entries.size() == (0 if expected == 1 else 1), "White player moves first; Black player receives exactly one White opening")
			if expected == -1:
				check(a.game.board[Rules.square("e4")] == Rules.PAWN, "Character opens legally as White when player draws Black")
			var from_square := "e2" if expected == 1 else "c7"
			var to_square := "e4" if expected == 1 else "c6"
			a.select_square(Rules.square(from_square))
			a.select_square(Rules.square(to_square))
			var deadline := Time.get_ticks_msec() + 5000
			while a.thinking and Time.get_ticks_msec() < deadline:
				await process_frame
			check(a.game.board[Rules.square(to_square)] == expected * Rules.PAWN and a.game.turn == expected, "Assigned player colour accepts a legal move and character reply")
	# Leaving or resetting during the reveal must invalidate its timer.
	a.restart(0)
	a.fist_choice.choose(0)
	a.leave_match()
	await pause(a.COLOUR_REVEAL_SECONDS + 0.1)
	check(a.choosing_colour and not a.thinking and a.history.entries.is_empty(), "Leaving during reveal cancels delayed match startup")
	a.restart(0)
	a.fist_choice.choose(1)
	a.restart(0)
	await pause(a.COLOUR_REVEAL_SECONDS + 0.1)
	check(a.human_color == 0 and a.fist_choice.selected_hand == -1 and not a.thinking, "A fresh entry cannot inherit a stale reveal result")
	# Asset replacement must not alter the already committed colour.
	var committed: int = a.fist_choice.left_colour
	a.fist_choice.visual_theme = a.visual_theme.duplicate()
	var replacement := ImageTexture.create_from_image(Image.create(24, 48, false, Image.FORMAT_RGBA8))
	a.fist_choice.visual_theme.left_fist_closed = replacement
	a.fist_choice.apply_artwork()
	check(a.fist_choice.get_node("Left/Hand").texture == replacement and a.fist_choice.left_colour == committed, "Replacing a hand image preserves the committed colour")
	a.queue_free()
	await process_frame
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	await process_frame
	print("FIST CHOICE: ", checks - failures, "/", checks, " checks passed")
	quit(1 if failures else 0)
