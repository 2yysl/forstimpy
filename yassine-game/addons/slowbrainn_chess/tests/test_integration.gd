extends SceneTree
## Runs real rendered Godot scenes and their connected UI signals.
const Rules = preload("res://addons/slowbrainn_chess/chess_rules.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func wait_for_bot(activity) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while is_instance_valid(activity) and activity.thinking and Time.get_ticks_msec() < deadline:
		await process_frame
	check(is_instance_valid(activity) and not activity.thinking, "Bot finishes without freezing")

func _run() -> void:
	# Verify the suspected baseline bug against the actual current checkout.
	var original = load("res://scenes/ui/table_scene.tscn").instantiate()
	root.add_child(original)
	original.size = Vector2(1280, 720)
	original.start_game()
	await pause(0.6)
	original.choices.get_node("Sure").pressed.emit()
	await pause(1.0)
	check(original.overhead and not original.changing_view, "Original main's sure path already transitions; reported indentation bug absent")
	original.queue_free()
	await process_frame
	var main = load("res://addons/slowbrainn_chess/integration/ChessIntegratedMain.tscn").instantiate()
	root.add_child(main)
	check(main.state == main.FlowState.TITLE and main.title_screen.visible, "Original title is reused")
	main.title_screen.get_node("Continue").pressed.emit()
	check(main.state == main.FlowState.PANNING, "Continue starts original camera pan")
	await pause(1.9)
	var stage = main._stage
	check(main.state == main.FlowState.STAGE and stage.invitation_ready, "Pan enters character invitation")
	check(stage.choices.visible, "Invitation choices visible")
	check(not stage.choices.has_node("NotNow") and stage.choices.get_child_count() == 2, "Invitation has only the two affirmative choices")
	stage.dap_button.pressed.emit()
	check(stage.dap_count == 1, "Character interaction remains usable during invitation")
	stage._change_location(2)
	check(stage.location_index == 2, "Location controls remain usable")
	stage.board_button.pressed.emit()
	await process_frame
	check(is_instance_valid(stage.activity), "Board hotspot opens chess during invitation")
	var activity = stage.activity
	check(activity.game.board.count(0) == 32 and activity.human_color == 1, "White game starts with 32 pieces")
	activity.select_square(Rules.square("e2"))
	check(activity.selected == Rules.square("e2"), "Player can select own piece")
	activity.select_square(Rules.square("e5"))
	check(activity.game.turn == 1 and activity.game.board[Rules.square("e2")] == Rules.PAWN, "Illegal UI move rejected")
	activity.select_square(Rules.square("e2"))
	activity.select_square(Rules.square("e4"))
	await wait_for_bot(activity)
	check(activity.game.board[Rules.square("e4")] == Rules.PAWN and activity.game.board[Rules.square("c6")] == -Rules.PAWN, "Human White e4 receives legal c6")
	# A pending bot reply must not mutate a replacement match.
	activity.restart(1)
	activity.select_square(Rules.square("e2"))
	activity.select_square(Rules.square("e4"))
	activity.restart(1)
	await pause(0.7)
	check(activity.game.turn == 1 and activity.game.board[Rules.square("e2")] == Rules.PAWN and activity.game.board.count(0) == 32, "Restart cancels pending bot reply")
	activity.restart(-1)
	await wait_for_bot(activity)
	check(activity.human_color == -1 and activity.game.turn == -1 and activity.game.board.count(0) == 32, "Human Black gets legal White opening")
	activity.select_square(Rules.square("c7"))
	activity.select_square(Rules.square("c6"))
	await wait_for_bot(activity)
	check(activity.game.turn == -1 and activity.game.board[Rules.square("c6")] == -Rules.PAWN, "Human Black can move and receive a legal White reply")
	# Test an actual fallback and ensure it cannot corrupt a game after leaving.
	activity.restart(1)
	activity.select_square(Rules.square("h2"))
	activity.select_square(Rules.square("h4"))
	await wait_for_bot(activity)
	check(activity.game.turn == 1 and activity.last_move.size() > 0, "Bot continues after book deviation")
	activity.restart(-1)
	activity.leave_match()
	await pause(0.6)
	check(not is_instance_valid(stage.activity) and stage.ui.visible, "Leave cancels bot and restores table")
	stage.board_button.pressed.emit()
	await process_frame
	check(stage.match_layer.get_child_count() == 1, "Re-entry has exactly one activity")
	stage.activity.leave_match()
	await process_frame
	check(stage.choices.visible and stage.dialogue.visible, "Leaving chess restores the invitation")
	stage.choices.get_node("Sure").pressed.emit()
	await process_frame
	check(is_instance_valid(stage.activity), "Sure connected callback opens chess")
	stage.activity.leave_match()
	await process_frame
	stage.choices.get_node("YesButRed").pressed.emit()
	check(stage.dialogue.text == "Red? Bro brought his own chess rules.", "Joke dialogue preserved")
	await pause(2.4)
	check(is_instance_valid(stage.activity), "Yes but red connected callback opens chess")
	activity = stage.activity
	# Texture replacement is independent of the rules and retains aspect ratio.
	var key: String = activity.game.position_key()
	var image := Image.create(40, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORAL)
	activity.visual_theme = activity.visual_theme.duplicate()
	activity.visual_theme.white_pawn = ImageTexture.create_from_image(image)
	activity.queue_redraw()
	await process_frame
	check(activity.visual_theme.piece_texture(Rules.PAWN).get_size() == Vector2(40, 80) and activity.game.position_key() == key, "Theme texture swap leaves rules unchanged")
	# Promotion UI offers all four choices.
	activity.game.load_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	activity._refresh()
	activity.select_square(Rules.square("a7"))
	activity.select_square(Rules.square("a8"))
	check(activity.promotion_moves.size() == 4 and activity.promotion_row.visible, "Promotion chooser opens")
	activity._promote(Rules.KNIGHT)
	check(activity.game.board[0] == Rules.KNIGHT and activity.ended == "Draw by insufficient material", "UI underpromotion and draw work")
	stage.activity.leave_match()
	main.queue_free()
	await process_frame
	var demo = load("res://addons/slowbrainn_chess/demo/ChessCharacterTest.tscn").instantiate()
	root.add_child(demo)
	await pause(0.6)
	check(demo.invitation_ready and demo.choices.visible, "Isolated character harness runs")
	demo.queue_free()
	await process_frame
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	await process_frame
	print("INTEGRATION: ", checks - failures, "/", checks, " checks passed")
	quit(1 if failures else 0)
