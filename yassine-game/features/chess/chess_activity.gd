extends Control
signal leave_requested
const Rules = preload("res://features/chess/chess_rules.gd")
const Bot = preload("res://features/chess/chess_bot.gd")
const History = preload("res://features/chess/chess_history.gd")
const Record = preload("res://features/chess/chess_record.gd")
const Archive = preload("res://features/chess/match_archive.gd")
const CHESS_REVIEW_URL := "https://www.chess.com/analysis"
const LICHESS_REVIEW_URL := "https://lichess.org/paste"
const COLOUR_REVEAL_SECONDS := 1.2
@export var visual_theme: Resource = preload("res://features/chess/chess_visual_theme.tres")
@export var idle_dialogue := "your move btw."
@export var thinking_dialogue := "hmm… let me think."
var game = Rules.new()
var bot: Node
var human_color := 0
var choosing_colour := true
var fist_choice
var selected := -1
var legal: Array = []
var promotion_moves: Array = []
var thinking := false
var suspended := false
var pending_bot_rng := 0
var colour_timer: Timer
var ended := ""
var session := 0
var last_move: Dictionary = {}
var captured_by_white: Array[int] = []
var captured_by_black: Array[int] = []
var board_rect := Rect2()
var panel: VBoxContainer
var status: Label
var details: Label
var promotion_row: HBoxContainer
var history = History.new()
var record
var archive = Archive.new()
var review_record
var replay_cache: Dictionary = {}
var moves_open := false
var move_labels: Array[String] = []
var review_index := -1
var previous: Button
var next: Button
var live: Button
var new_game: Button
var chess_review: Button
var takeback: Button
var resign: Button
var inventory: PanelContainer
var rps_rng := RandomNumberGenerator.new()
var rps_active := false
var rps_resolved := false
var rps_target := -1
var rps_choice := -1
var header: NinePatchRect
var portrait: TextureRect
var dialogue_bubble: TextureRect
var board_frame: NinePatchRect
var letter
var back: Button
var scene_font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	scene_font = visual_theme.interface_font.duplicate() if visual_theme.interface_font else ThemeDB.fallback_font.duplicate()
	# Keep local text crisp when this overlay compensates for the original
	# project's canvas stretch; do not change the shared project's font resource.
	if scene_font is FontFile:
		scene_font.oversampling = 1.0
	theme = Theme.new()
	theme.default_font = scene_font
	bot = Bot.new()
	bot.name = bot.behavior.display_name
	add_child(bot)
	header = $TopStrip
	panel = $TopStrip/Controls
	portrait = $TopStrip/Portrait
	dialogue_bubble = $Dialogue
	status = $Dialogue/Status
	details = $Details
	board_frame = $BoardFrame
	letter = $Letter
	back = $Back
	inventory = $Inventory
	previous = $MovePanel/Contents/Replay/Previous
	next = $MovePanel/Contents/Replay/Next
	live = $MovePanel/Contents/Replay/Live
	new_game = $Inventory/Contents/Buttons/NewGame
	chess_review = $Inventory/Contents/Buttons/ChessReview
	takeback = $Inventory/Contents/Buttons/Takeback
	resign = $Inventory/Contents/Buttons/Resign
	fist_choice = $FistChoice
	fist_choice.colour_chosen.connect(_on_colour_chosen)
	colour_timer = Timer.new()
	colour_timer.name = "ColourRevealTimer"
	colour_timer.wait_time = COLOUR_REVEAL_SECONDS
	colour_timer.one_shot = true
	colour_timer.timeout.connect(_finish_colour_reveal)
	add_child(colour_timer)
	rps_rng.randomize()
	promotion_row = $Promotion/Options
	previous.pressed.connect(_review_previous)
	next.pressed.connect(_review_next)
	live.pressed.connect(_leave_replay)
	new_game.pressed.connect(start_new_game)
	chess_review.pressed.connect(_open_external_review)
	$MovesButton.pressed.connect(_show_moves)
	$MovePanel/Contents/Close.pressed.connect(_close_moves)
	$MovePanel/Contents/List.item_selected.connect(_select_recorded_move)
	$PGN/Dialog/Contents/Buttons/Close.pressed.connect(func(): $PGN.hide())
	$PGN/Dialog/Contents/Buttons/Copy.pressed.connect(_copy_pgn)
	$PGN/Dialog/Contents/Buttons/Chess.pressed.connect(_launch_review.bind(CHESS_REVIEW_URL))
	$PGN/Dialog/Contents/Buttons/Lichess.pressed.connect(_launch_review.bind(LICHESS_REVIEW_URL))
	takeback.pressed.connect(_request_takeback)
	resign.pressed.connect(_resign)
	for hand in 3:
		$RPS/Dialog/Contents/Choices.get_child(hand).pressed.connect(_play_rps.bind(hand))
	$RPS/Dialog/Contents/Close.pressed.connect(_close_rps)
	back.pressed.connect(leave_match)
	for kind in [Rules.QUEEN, Rules.ROOK, Rules.BISHOP, Rules.KNIGHT]:
		promotion_row.get_node({5: "Queen", 4: "Rook", 3: "Bishop", 2: "Knight"}[kind]).pressed.connect(_promote.bind(kind))
	_apply_artwork()
	for label in [status, details, $TopStrip/Atmosphere, $TopStrip/Controls/Assignment, $Inventory/Contents/Title, $MovePanel/Contents/Replay/Position, $MovePanel/Contents/Title, $MovePanel/Contents/Empty, $PGN/Dialog/Contents/Title, $PGN/Dialog/Contents/Help,
		$RPS/Dialog/Contents/Title, $RPS/Dialog/Contents/Description, $RPS/Dialog/Contents/Result]:
		label.add_theme_color_override("font_color", visual_theme.ink_color)
	status.add_theme_font_size_override("font_size", 22)
	details.add_theme_font_size_override("font_size", 14)
	$TopStrip/Atmosphere.add_theme_font_size_override("font_size", 14)
	$Inventory/Contents/Title.add_theme_font_size_override("font_size", 12)
	$TopStrip/Controls/Assignment.add_theme_font_size_override("font_size", 14)
	$MovePanel/Contents/Replay/Position.add_theme_font_size_override("font_size", 12)
	$MovePanel/Contents/Title.add_theme_font_size_override("font_size", 12)
	$MovePanel/Contents/Empty.add_theme_font_size_override("font_size", 12)
	$MovePanel/Contents/List.add_theme_font_size_override("font_size", 12)
	$PGN/Dialog/Contents/Help.add_theme_font_size_override("font_size", 14)
	for button in [back, previous, next, live, new_game, chess_review, takeback, resign, $MovesButton, $MovePanel/Contents/Close, $RPS/Dialog/Contents/Close] + $PGN/Dialog/Contents/Buttons.get_children() + promotion_row.get_children() + $RPS/Dialog/Contents/Choices.get_children():
		_style_button(button)
	var promotion_style := StyleBoxFlat.new()
	promotion_style.bg_color = visual_theme.panel_color
	promotion_style.border_color = visual_theme.ink_color
	promotion_style.set_border_width_all(2)
	promotion_style.set_corner_radius_all(4)
	promotion_style.content_margin_left = 6
	promotion_style.content_margin_right = 6
	promotion_style.content_margin_top = 6
	promotion_style.content_margin_bottom = 6
	$Promotion.add_theme_stylebox_override("panel", promotion_style)
	inventory.add_theme_stylebox_override("panel", promotion_style.duplicate())
	var dialog_style: StyleBoxFlat = promotion_style.duplicate()
	dialog_style.content_margin_left = 16
	dialog_style.content_margin_right = 16
	dialog_style.content_margin_top = 16
	dialog_style.content_margin_bottom = 16
	$RPS/Dialog.add_theme_stylebox_override("panel", dialog_style)
	$MovePanel.add_theme_stylebox_override("panel", promotion_style.duplicate())
	var list_style: StyleBoxFlat = promotion_style.duplicate()
	list_style.set_border_width_all(0)
	$MovePanel/Contents/List.add_theme_stylebox_override("panel", list_style)
	$MovePanel/Contents/List.add_theme_color_override("font_color", visual_theme.ink_color)
	$MovePanel/Contents/List.add_theme_color_override("font_selected_color", visual_theme.ink_color)
	$MovePanel/Contents/List.add_theme_color_override("font_hovered_color", visual_theme.ink_color)
	var selection_style: StyleBoxFlat = list_style.duplicate()
	selection_style.bg_color = visual_theme.light_square
	$MovePanel/Contents/List.add_theme_stylebox_override("selected", selection_style)
	$MovePanel/Contents/List.add_theme_stylebox_override("selected_focus", selection_style)
	$MovePanel/Contents/List.add_theme_stylebox_override("hovered", selection_style)
	$PGN/Dialog/Contents/Text.add_theme_stylebox_override("normal", list_style.duplicate())
	$PGN/Dialog/Contents/Text.add_theme_stylebox_override("read_only", list_style.duplicate())
	$PGN/Dialog/Contents/Text.add_theme_color_override("font_color", visual_theme.ink_color)
	$PGN/Dialog/Contents/Text.add_theme_color_override("font_readonly_color", visual_theme.ink_color)
	$PGN/Dialog/Contents/Text.add_theme_font_size_override("font_size", 14)
	$PGN/Dialog.add_theme_stylebox_override("panel", dialog_style.duplicate())
	# Wrapped labels can briefly report a tall minimum before containers lay out.
	$RPS/Dialog.minimum_size_changed.connect(_layout_rps.call_deferred)
	$PGN/Dialog.minimum_size_changed.connect(_layout_pgn.call_deferred)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_fit_window)
	_fit_window()
	restart(0)

func _fit_window() -> void:
	# The original project stretches a 1280-wide canvas. Use actual window
	# dimensions for this overlay so portrait controls remain readable.
	var stretch := get_viewport().get_stretch_transform().get_scale()
	scale = Vector2.ONE / stretch
	size = get_viewport_rect().size * stretch
	_layout()

func _apply_artwork() -> void:
	header.texture = visual_theme.top_strip
	$TopStrip/TimeMusic.texture = visual_theme.time_music
	portrait.texture = visual_theme.portrait_idle
	$TopStrip/Memories.texture = visual_theme.memories
	dialogue_bubble.texture = visual_theme.dialogue_bubble
	board_frame.texture = visual_theme.board_frame
	$Back/Arrow.texture = visual_theme.back_arrow
	fist_choice.visual_theme = visual_theme
	fist_choice.apply_artwork()
	_refresh_captures()

func _style_button(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14 if button != back else 20)
	for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state_name, visual_theme.ink_color)
	button.add_theme_color_override("font_disabled_color", visual_theme.ink_color * Color(1, 1, 1, 0.45))
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = visual_theme.panel_color
		if state_name == "hover" or state_name == "pressed":
			style.bg_color = visual_theme.light_square
		style.border_color = visual_theme.ink_color * Color(1, 1, 1, 0.3 if state_name == "disabled" else 1.0)
		style.set_border_width_all(0 if button == back else 1)
		style.set_corner_radius_all(3)
		button.add_theme_stylebox_override(state_name, style)

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _layout() -> void:
	if not is_instance_valid(panel):
		return
	var narrow := size.x < 760
	var picking_colour := choosing_colour and review_record == null
	var moves_popup := size.x < 1100 or size.y < 655
	status.add_theme_font_size_override("font_size", 18 if narrow else 22)
	if narrow:
		var compact := size.y < 700
		_place(header, Rect2(16, 16, size.x - 32, 98 if compact else 148))
		_place($TopStrip/TimeMusic, Rect2(10, 10, 48, 24))
		_place(portrait, Rect2(56, 6, header.size.x * 0.46, 28 if compact else 66))
		_place($TopStrip/Memories, Rect2(header.size.x * 0.64, 8, header.size.x * 0.33, 26 if compact else 64))
		_place(panel, Rect2(12, 36 if compact else 80, header.size.x - 24, 58 if compact else 62))
		_place(dialogue_bubble, Rect2(82, 126 if compact else 176, size.x - 98, 40 if compact else 76))
		var extent := maxf(80, minf(size.x - 48, size.y - (462 if compact else 592)))
		board_rect = Rect2(Vector2((size.x - extent) * 0.5, 222 if compact else 326), Vector2.ONE * extent)
		_place($CharacterCaptures, Rect2(24, 178 if compact else 266, size.x - 48, 30 if compact else 44))
		_place($PlayerCaptures, Rect2(24, board_rect.end.y + (22 if compact else 24), size.x - 48, 30 if compact else 44))
		_place(details, Rect2(24, $PlayerCaptures.get_rect().end.y + 8, size.x - 48, 54))
		details.add_theme_font_size_override("font_size", 12)
		details.visible = details.get_rect().end.y <= size.y - 188
		_place(inventory, Rect2(16, size.y - 180, size.x - 32, 108))
		_place(back, Rect2(24, size.y - 62, 124, 44))
	else:
		_place(header, Rect2(32, 20, size.x - 64, 118))
		_place($TopStrip/TimeMusic, Rect2(16, 8, 110, 26))
		_place($TopStrip/Atmosphere, Rect2(140, 10, header.size.x * 0.25 - 156, 22))
		_place(panel, Rect2(16, 42, header.size.x * 0.25 - 32, 62))
		_place(portrait, Rect2(header.size.x * 0.25 + 12, 5, header.size.x * 0.34 - 24, 108))
		_place($TopStrip/Memories, Rect2(header.size.x * 0.59 + 12, 8, header.size.x * 0.41 - 24, 102))
		_place(dialogue_bubble, Rect2((size.x - minf(770, size.x - 320)) * 0.5, 150, minf(770, size.x - 320), 76))
		var extent := maxf(80, minf(size.y - 284, size.x - 316))
		var side_inventory := size.x - (size.x + extent) * 0.5 - 62 >= 300
		if not side_inventory:
			extent = maxf(80, minf(extent, size.y - 406))
		board_rect = Rect2(Vector2((size.x - extent) * 0.5, 252), Vector2.ONE * extent)
		var tray_width := minf(188, board_rect.position.x - 56)
		_place($CharacterCaptures, Rect2(board_rect.position.x - tray_width - 28, board_rect.position.y + 28, tray_width, 100))
		_place($PlayerCaptures, Rect2(board_rect.position.x - tray_width - 28, board_rect.end.y - 112, tray_width, 100))
		_place(details, Rect2(board_rect.end.x + 30, 278, maxf(120, size.x - board_rect.end.x - 62), 96))
		details.show()
		details.add_theme_font_size_override("font_size", 14)
		if side_inventory:
			_place(inventory, Rect2(size.x - 360, size.y - 130, 328, 108))
		else:
			_place(inventory, Rect2(maxf(220, (size.x - 400) * 0.5), size.y - 130, minf(400, size.x - 252), 108))
		_place(back, Rect2(60, size.y - 80, 134, 50))
	$TopStrip/Atmosphere.visible = not narrow and header.size.x >= 1200
	letter.scale = Vector2.ONE * (0.38 if narrow else 0.72)
	letter.position = Vector2(14, dialogue_bubble.position.y - 6) if narrow else Vector2(dialogue_bubble.position.x - 142, 156)
	letter.visible = not picking_colour
	if letter.enabled != letter.visible:
		letter.set_enabled(letter.visible)
	inventory.visible = not picking_colour
	details.visible = details.visible and not picking_colour
	dialogue_bubble.z_index = 3 if picking_colour else 0
	if picking_colour:
		var wrist_y := header.get_rect().end.y + 2.0
		var hand_width := minf(680.0, size.x - 32.0)
		var hand_bottom := back.position.y - 8.0 if (size.x - hand_width) * 0.5 < back.get_rect().end.x else size.y - 48.0
		if narrow:
			hand_bottom = minf(hand_bottom, wrist_y + hand_width * 0.9)
		_place(fist_choice, Rect2((size.x - hand_width) * 0.5, wrist_y, hand_width, maxf(1.0, hand_bottom - wrist_y)))
		var bubble_width := minf(770.0, size.x - 32.0)
		_place(dialogue_bubble, Rect2((size.x - bubble_width) * 0.5, wrist_y + (22.0 if narrow else 38.0), bubble_width, 52.0 if narrow else 76.0))
	_place(status, Rect2(24, 18, dialogue_bubble.size.x - 48, dialogue_bubble.size.y - 26))
	_place($Back/Arrow, Rect2(0, 5, 76, 36))
	_place(board_frame, board_rect.grow(14))
	_place($Promotion, Rect2(board_rect.position.x, board_rect.get_center().y - 24, board_rect.size.x, 48))
	_place($RPS, Rect2(Vector2.ZERO, size))
	_place($MovesShade, Rect2(Vector2.ZERO, size))
	_place($PGN, Rect2(Vector2.ZERO, size))
	_layout_pgn()
	_place($MovesButton, Rect2(size.x - 164, size.y - 62, 140, 44))
	$MovesButton.visible = moves_popup and not picking_colour
	$MovePanel.visible = not picking_colour and (not moves_popup or moves_open)
	$MovePanel/Contents/Close.visible = moves_popup
	$MovesShade.visible = not picking_colour and moves_popup and moves_open
	$MovePanel.z_index = 21 if moves_popup else 0
	if moves_popup:
		var popup_width := minf(460.0, size.x - 32.0)
		var popup_height := minf(240.0, size.y * 0.45)
		_place($MovePanel, Rect2((size.x - popup_width) * 0.5, size.y - popup_height - 16.0, popup_width, popup_height))
	else:
		var panel_x := board_rect.end.x + 30.0
		_place($MovePanel, Rect2(panel_x, 388, size.x - panel_x - 24.0, maxf(130.0, inventory.position.y - 402)))
	_layout_rps()
	queue_redraw()

func _layout_rps() -> void:
	var dialog_width := minf(440, size.x - 32)
	_place($RPS/Dialog, Rect2((size.x - dialog_width) * 0.5, maxf(8, (size.y - 320) * 0.5), dialog_width, 320))

func _layout_pgn() -> void:
	var extent := Vector2(minf(820, maxf(100, size.x - 32)), minf(600, maxf(120, size.y - 32)))
	_place($PGN/Dialog, Rect2((size - extent) * 0.5, extent))

func restart(color: int) -> void:
	session += 1
	bot.cancel()
	colour_timer.stop()
	colour_timer.paused = false
	suspended = false
	process_mode = Node.PROCESS_MODE_INHERIT
	show()
	human_color = color
	choosing_colour = color == 0
	game = Rules.new()
	selected = -1
	promotion_moves.clear()
	last_move = {}
	captured_by_white.clear()
	captured_by_black.clear()
	ended = ""
	record = Record.new(game, color, bot.behavior.display_name) if color != 0 else null
	review_record = null
	replay_cache.clear()
	moves_open = false
	$PGN.hide()
	thinking = false
	history.clear()
	review_index = -1
	rps_active = false
	rps_resolved = false
	rps_target = -1
	$RPS.hide()
	if choosing_colour:
		fist_choice.begin_choice()
	else:
		fist_choice.hide()
	_refresh()
	_layout()
	if not choosing_colour and game.turn != human_color:
		_bot_turn()

func _on_colour_chosen(colour: int) -> void:
	if suspended or not choosing_colour or human_color != 0:
		return
	human_color = colour
	_refresh()
	colour_timer.start()

func _finish_colour_reveal() -> void:
	if not suspended and review_record == null and choosing_colour and human_color != 0:
		restart(human_color)

func leave_match() -> void:
	if suspended:
		return
	suspend_match()
	leave_requested.emit()

func suspend_match() -> void:
	if suspended:
		return
	if thinking:
		bot.rng.state = pending_bot_rng
	session += 1
	bot.cancel()
	thinking = false
	suspended = true
	moves_open = false
	colour_timer.paused = true
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()

func resume_match(start_bot := true) -> void:
	if not suspended:
		return
	suspended = false
	process_mode = Node.PROCESS_MODE_INHERIT
	colour_timer.paused = review_record != null
	show()
	_fit_window()
	_refresh()
	if start_bot and review_record == null and not choosing_colour and ended.is_empty() and not rps_active and promotion_moves.is_empty() and game.turn != human_color:
		_bot_turn()

func _exit_tree() -> void:
	session += 1
	if is_instance_valid(bot):
		bot.cancel()

func _refresh() -> void:
	legal = game.legal_moves()
	if ended.is_empty():
		ended = game.outcome(legal)
	if record != null and not record.is_finished() and not ended.is_empty():
		if record.moves.is_empty():
			record.start_fen = Record.fen(game)
		record.finish(ended)
		archive.add(record)
	status.text = ended if not ended.is_empty() else (thinking_dialogue if thinking else ("Check!" if game.in_check(game.turn) else idle_dialogue))
	details.text = "with " + bot.behavior.display_name + "\nYou: " + ("White" if human_color == 1 else "Black") + "\n" + bot.behavior.target_rating_label
	portrait.texture = visual_theme.portrait_thinking if thinking else visual_theme.portrait_idle
	var viewing_color := _view_colour()
	$TopStrip/Controls/Assignment.text = "White or Black?" if viewing_color == 0 else ("You: White\n" + bot.behavior.display_name + ": Black" if viewing_color == 1 else "You: Black\n" + bot.behavior.display_name + ": White")
	board_frame.visible = not choosing_colour or review_record != null
	_refresh_captures()
	var source = _review_source()
	var total: int = source.moves.size() if source != null else 0
	var replay_blocked := _replay_blocked()
	previous.disabled = total == 0 or review_index == 0 or replay_blocked
	next.disabled = review_index < 0 or review_index >= total or replay_blocked
	live.disabled = review_index < 0 and review_record == null
	live.text = "live" if review_record == null else "table"
	_refresh_move_list(source, total)
	$MovePanel/Contents/Replay/Position.text = "%d / %d" % [review_index if review_index >= 0 else total, total]
	takeback.visible = review_record == null and ended.is_empty()
	resign.visible = takeback.visible
	new_game.visible = review_record == null and not ended.is_empty()
	chess_review.visible = review_record != null or not ended.is_empty()
	takeback.disabled = not ended.is_empty() or not promotion_moves.is_empty() or rps_active or history.challenge_index() < 0
	resign.disabled = choosing_colour or not ended.is_empty() or rps_active
	$Inventory/Contents/Title.text = "inventory · review only" if review_index >= 0 else "inventory"
	promotion_row.visible = not promotion_moves.is_empty() and review_index < 0 and not rps_active and review_record == null
	$Promotion.visible = promotion_row.visible
	if not promotion_moves.is_empty():
		status.text = "Promote to?"
	if review_index >= 0:
		status.text = "Move %d of %d · %s" % [review_index, total, str(source.moves[review_index - 1].san) if review_index > 0 else "start position"]
		if review_record != null:
			details.text = review_record.summary()
	if choosing_colour and review_record == null:
		status.text = "choose a paw." if human_color == 0 else ("You're White." if human_color == 1 else "You're Black.")
		details.text = "with " + bot.behavior.display_name + "\n" + ("Your colour is hidden" if human_color == 0 else ("You: White" if human_color == 1 else "You: Black"))
	queue_redraw()

func _bot_turn() -> void:
	if suspended or review_record != null or thinking or choosing_colour or not ended.is_empty() or rps_active or not promotion_moves.is_empty() or game.turn == human_color:
		return
	if game.can_claim_draw():
		ended = "Draw claimed by " + bot.behavior.display_name
		_refresh()
		return
	thinking = true
	_refresh()
	var token := session
	pending_bot_rng = bot.rng.state
	var before := _capture_snapshot()
	var move: Dictionary = await bot.choose_move(game)
	if token != session or not is_inside_tree():
		return
	thinking = false
	if not move.is_empty():
		_commit_move(move, before)
	_refresh()

func _review_source():
	return review_record if review_record != null else record

func _replay_blocked() -> bool:
	return suspended or rps_active or letter.reading or $PGN.visible or (review_record == null and (choosing_colour or not promotion_moves.is_empty()))

func _review_previous() -> void:
	var source = _review_source()
	if _replay_blocked() or source == null or source.moves.is_empty() or review_index == 0:
		return
	_go_to_move(source.moves.size() - 1 if review_index < 0 else review_index - 1)

func _review_next() -> void:
	if review_index >= 0:
		_go_to_move(review_index + 1)

func _select_recorded_move(item: int) -> void:
	_go_to_move(item + 1)

func _go_to_move(index: int) -> void:
	var source = _review_source()
	if _replay_blocked() or source == null or index < 0 or index > source.moves.size():
		_refresh_move_selection(source.moves.size() if source != null else 0)
		return
	if review_record == null and index == source.moves.size():
		_return_live()
	else:
		_set_review(index)

func _leave_replay() -> void:
	if review_record != null:
		leave_match()
	else:
		_return_live()

func _set_review(index: int) -> void:
	review_index = index
	replay_cache = _review_source().replay(index)
	selected = -1
	_refresh()

func _return_live() -> void:
	if suspended:
		return
	review_record = null
	review_index = -1
	replay_cache.clear()
	colour_timer.paused = false
	fist_choice.visible = choosing_colour
	_refresh()
	_layout()
	if not rps_active and promotion_moves.is_empty() and ended.is_empty() and not choosing_colour and game.turn != human_color:
		_bot_turn()

func _resign() -> void:
	if suspended or review_record != null or choosing_colour or not ended.is_empty() or rps_active:
		return
	session += 1
	bot.cancel()
	thinking = false
	review_index = -1
	promotion_moves.clear()
	selected = -1
	ended = ("Black" if human_color == 1 else "White") + " wins — you resigned"
	_refresh()

func _request_takeback() -> void:
	if suspended or review_record != null or choosing_colour or not ended.is_empty() or not promotion_moves.is_empty() or rps_active:
		return
	rps_target = history.challenge_index()
	if rps_target < 0:
		return
	# Freeze the live position during the challenge, including any queued reply.
	session += 1
	bot.cancel()
	thinking = false
	selected = -1
	review_index = -1
	replay_cache.clear()
	rps_active = true
	rps_resolved = false
	rps_choice = rps_rng.randi_range(0, 2) # Commit before the player chooses.
	$RPS/Dialog/Contents/Result.text = "Choose your hand."
	$RPS/Dialog/Contents/Close.text = "cancel"
	for button in $RPS/Dialog/Contents/Choices.get_children():
		button.disabled = false
	$RPS.show()
	_refresh()

func _play_rps(hand: int) -> void:
	if suspended or not rps_active or rps_resolved or hand < 0 or hand > 2:
		return
	var names := ["rock", "paper", "scissors"]
	var result := (hand - rps_choice + 3) % 3
	var description: String = "You: " + names[hand] + " · " + bot.behavior.display_name + ": " + names[rps_choice] + "\n"
	if result == 0:
		$RPS/Dialog/Contents/Result.text = description + "Tie — choose again."
		rps_choice = rps_rng.randi_range(0, 2)
		return
	if not history.consume_challenge(rps_target):
		_close_rps()
		return
	rps_resolved = true
	for button in $RPS/Dialog/Contents/Choices.get_children():
		button.disabled = true
	if result == 1:
		var restored: Dictionary = history.restore(rps_target)
		game = restored.position
		bot.rng.state = restored.rng_state
		last_move = restored.last_move
		captured_by_white.assign(restored.captured_white)
		captured_by_black.assign(restored.captured_black)
		record.truncate(restored.ply_count)
		review_index = -1
		promotion_moves.clear()
		ended = ""
		$RPS/Dialog/Contents/Result.text = description + "You won! Your previous turn is restored."
	else:
		$RPS/Dialog/Contents/Result.text = description + "You lost. Make a new chess move before trying again."
	$RPS/Dialog/Contents/Close.text = "return to game"
	_refresh()

func _close_rps() -> void:
	if suspended or not rps_active:
		return
	rps_active = false
	$RPS.hide()
	_refresh()
	if ended.is_empty() and game.turn != human_color:
		_bot_turn()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if board_rect.has_point(event.position):
			var cell: Vector2 = (event.position - board_rect.position) / (board_rect.size.x / 8.0)
			var column := int(cell.x)
			var row := int(cell.y)
			select_square(row * 8 + column if human_color == 1 else (7 - row) * 8 + 7 - column)
			accept_event()

func select_square(index: int) -> void:
	if suspended or review_record != null or choosing_colour or thinking or not ended.is_empty() or game.turn != human_color or not promotion_moves.is_empty() or review_index >= 0 or rps_active or moves_open or letter.reading or $PGN.visible:
		return
	var candidates := legal.filter(func(move): return move.from == selected and move.to == index)
	if not candidates.is_empty():
		if candidates.size() > 1:
			promotion_moves = candidates
			_refresh()
		else:
			_make_move(candidates[0])
		return
	selected = index if game.board[index] * human_color > 0 else -1
	queue_redraw()

func _promote(kind: int) -> void:
	if suspended:
		return
	for move in promotion_moves:
		if move.promotion == kind:
			promotion_moves.clear()
			_make_move(move)
			return

func _make_move(move: Dictionary) -> void:
	if suspended:
		return
	var before := _capture_snapshot()
	if not _commit_move(move, before):
		return
	selected = -1
	_refresh()
	if ended.is_empty():
		_bot_turn()

func _capture_snapshot() -> Dictionary:
	return history.capture(game, bot.rng.state, last_move, captured_by_white, captured_by_black, record.moves.size() if record != null else 0)

func _commit_move(move: Dictionary, before: Dictionary) -> bool:
	if suspended or review_record != null or not ended.is_empty():
		return false
	# Capture identity must be read before play removes it, including en passant.
	var mover: int = game.turn
	var taken: int = game.board[move.to]
	if absi(game.board[move.from]) == Rules.PAWN and move.to == game.ep and taken == 0:
		taken = game.board[move.to + mover * 8]
	if not game.play(move):
		return false
	if taken != 0:
		if mover == 1:
			captured_by_white.append(taken)
		else:
			captured_by_black.append(taken)
	history.record(before, move, human_color)
	record.append(before, move, game)
	last_move = move
	return true

func _refresh_captures() -> void:
	$PlayerCaptures.visible = not choosing_colour or review_record != null
	$CharacterCaptures.visible = not choosing_colour or review_record != null
	var white: Array = captured_by_white
	var black: Array = captured_by_black
	if review_index >= 0:
		white = replay_cache.captured_white
		black = replay_cache.captured_black
	var colour := _view_colour()
	$PlayerCaptures.display(white if colour == 1 else black, visual_theme, "your captures")
	$CharacterCaptures.display(black if colour == 1 else white, visual_theme, bot.behavior.display_name + " captures")

func _view_colour() -> int:
	return review_record.human_color if review_record != null else human_color

func start_new_game() -> void:
	if suspended or ended.is_empty() or review_record != null or rps_active:
		return
	restart(0)

func _refresh_move_list(source, total: int) -> void:
	var lines: Array[String] = []
	if total > 0:
		var fen_fields: PackedStringArray = source.start_fen.split(" ")
		var number := int(fen_fields[5])
		var white := fen_fields[1] == "w"
		for move in source.moves:
			lines.append("%d%s %s" % [number, "." if white else "...", move.san])
			if not white:
				number += 1
			white = not white
	var list: ItemList = $MovePanel/Contents/List
	if lines != move_labels:
		move_labels = lines
		list.clear()
		for line in move_labels:
			list.add_item(line)
	$MovePanel/Contents/Empty.visible = total == 0
	_refresh_move_selection(total)

func _refresh_move_selection(total: int) -> void:
	var list: ItemList = $MovePanel/Contents/List
	var current := (total if review_index < 0 else review_index) - 1
	if current < 0 or current >= list.item_count:
		list.deselect_all()
	elif not list.is_selected(current):
		list.select(current)
		list.ensure_current_is_visible()

func _show_moves() -> void:
	if _replay_blocked():
		return
	moves_open = true
	_layout()
	$MovePanel/Contents/List.ensure_current_is_visible()

func _close_moves() -> void:
	moves_open = false
	_layout()

func _open_archived(index: int) -> void:
	if suspended or rps_active or $PGN.visible or index < 0 or index >= archive.records.size():
		return
	if thinking:
		bot.rng.state = pending_bot_rng
	session += 1
	bot.cancel()
	thinking = false
	colour_timer.paused = true
	fist_choice.hide()
	review_record = archive.records[index]
	_close_moves()
	_set_review(review_record.moves.size())

func _show_pgn() -> bool:
	var source = _review_source()
	if suspended or source == null or not source.is_finished() or rps_active:
		return false
	$PGN/Dialog/Contents/Text.text = source.pgn()
	$PGN.show()
	_layout_pgn.call_deferred()
	return true

func _copy_pgn() -> void:
	if not suspended and $PGN.visible:
		DisplayServer.clipboard_set($PGN/Dialog/Contents/Text.text)

func _launch_review(url: String) -> void:
	if suspended or not $PGN.visible or url not in [CHESS_REVIEW_URL, LICHESS_REVIEW_URL]:
		return
	_copy_pgn()
	if OS.shell_open(url) != OK:
		$PGN/Dialog/Contents/Help.text = "Open " + url + " in your browser, then paste the PGN shown below."

func _open_external_review() -> void:
	if _show_pgn():
		_launch_review(CHESS_REVIEW_URL)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if letter.reading:
			letter.reader.close_note()
		elif $PGN.visible:
			$PGN.hide()
		elif moves_open:
			_close_moves()
		elif rps_active:
			_close_rps()
		elif review_index >= 0:
			_leave_replay()
		else:
			leave_match()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), visual_theme.panel_color)
	if (choosing_colour and review_record == null) or board_rect.size.x <= 0:
		return
	var cell := board_rect.size.x / 8.0
	var font: Font = scene_font if scene_font else ThemeDB.fallback_font
	var displayed = replay_cache.position if review_index >= 0 else game
	var highlighted: Dictionary = replay_cache.last_move if review_index >= 0 else last_move
	var colour := _view_colour()
	for row in 8:
		for column in 8:
			var index := row * 8 + column if colour == 1 else (7 - row) * 8 + 7 - column
			var rect := Rect2(board_rect.position + Vector2(column, row) * cell, Vector2.ONE * cell)
			draw_rect(rect, visual_theme.light_square if (row + column) % 2 == 0 else visual_theme.dark_square)
			if index == selected or index == highlighted.get("from", -1) or index == highlighted.get("to", -1):
				draw_rect(rect.grow(-2), visual_theme.highlight, false, 3)
			if displayed.board[index] != 0:
				var texture: Texture2D = visual_theme.piece_texture(displayed.board[index])
				if texture:
					var available := rect.size * 0.90
					var scale_factor := minf(available.x / texture.get_width(), available.y / texture.get_height())
					var extent := texture.get_size() * scale_factor
					draw_texture_rect(texture, Rect2(rect.get_center() - extent * 0.5, extent), false)
			for move in ([] if review_index >= 0 or rps_active else legal):
				if move.from == selected and move.to == index:
					draw_circle(rect.get_center(), cell * 0.10, visual_theme.legal_destination)
					break
		var rank_label := str(8 - row if colour == 1 else row + 1)
		draw_string(font, board_rect.position + Vector2(-24, (row + 0.6) * cell), rank_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, visual_theme.ink_color)
		var file_label: String = "abcdefgh"[row if colour == 1 else 7 - row]
		draw_string(font, board_rect.position + Vector2((row + 0.45) * cell, board_rect.size.y + 19), file_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, visual_theme.ink_color)
