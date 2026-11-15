extends Control
signal leave_requested
const Rules = preload("res://addons/slowbrainn_chess/chess_rules.gd")
const Bot = preload("res://addons/slowbrainn_chess/chess_bot.gd")
@export var visual_theme: Resource = preload("res://addons/slowbrainn_chess/chess_visual_theme.tres")
var game = Rules.new()
var bot: Node
var human_color := 1
var selected := -1
var legal: Array = []
var promotion_moves: Array = []
var thinking := false
var ended := ""
var session := 0
var last_move: Dictionary = {}
var board_rect := Rect2()
var panel: VBoxContainer
var status: Label
var details: Label
var promotion_row: HBoxContainer
var claim: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	bot = Bot.new()
	bot.name = "SlowbrainnBot"
	add_child(bot)
	panel = VBoxContainer.new()
	panel.name = "MatchControls"
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)
	var heading := Label.new()
	heading.text = "chess with slowbrainn"
	heading.add_theme_font_size_override("font_size", 25)
	panel.add_child(heading)
	status = Label.new()
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 54
	panel.add_child(status)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 14)
	panel.add_child(details)
	var colors := HBoxContainer.new()
	panel.add_child(colors)
	_button(colors, "Play White", func(): restart(1)).name = "PlayWhite"
	_button(colors, "Play Black", func(): restart(-1)).name = "PlayBlack"
	_button(panel, "Restart", func(): restart(human_color)).name = "Restart"
	claim = _button(panel, "Claim draw", _claim_draw)
	claim.name = "ClaimDraw"
	promotion_row = HBoxContainer.new()
	promotion_row.name = "Promotion"
	panel.add_child(promotion_row)
	for kind in [Rules.QUEEN, Rules.ROOK, Rules.BISHOP, Rules.KNIGHT]:
		_button(promotion_row, {5: "Queen", 4: "Rook", 3: "Bishop", 2: "Knight"}[kind], _promote.bind(kind))
	_button(panel, "Leave match", leave_match).name = "LeaveMatch"
	for label in [heading, status, details]:
		label.add_theme_color_override("font_color", visual_theme.ink_color)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_fit_window)
	_fit_window()
	restart(human_color)

func _fit_window() -> void:
	# The original project stretches a 1280-wide canvas. Use actual window
	# dimensions for this overlay so portrait controls remain readable.
	var stretch := get_viewport().get_stretch_transform().get_scale()
	scale = Vector2.ONE / stretch
	size = get_viewport_rect().size * stretch
	_layout()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _layout() -> void:
	if not is_instance_valid(panel):
		return
	var narrow := size.x < 760
	var extent := minf(size.x - 48, size.y - 365) if narrow else minf(size.y - 80, size.x * 0.59)
	extent = maxf(80, extent)
	board_rect = Rect2(Vector2(24, 32), Vector2.ONE * extent)
	panel.position = Vector2(24, board_rect.end.y + 24) if narrow else Vector2(board_rect.end.x + 32, 32)
	panel.size = Vector2(size.x - panel.position.x - 24, 0)
	queue_redraw()

func restart(color: int) -> void:
	session += 1
	bot.cancel()
	human_color = color
	game = Rules.new()
	selected = -1
	promotion_moves.clear()
	last_move = {}
	ended = ""
	thinking = false
	_refresh()
	if game.turn != human_color:
		_bot_turn()

func leave_match() -> void:
	session += 1
	bot.cancel()
	thinking = false
	leave_requested.emit()

func _exit_tree() -> void:
	session += 1
	if is_instance_valid(bot):
		bot.cancel()

func _refresh() -> void:
	legal = game.legal_moves()
	if ended.is_empty():
		ended = game.outcome(legal)
	status.text = ended if not ended.is_empty() else ("slowbrainn is thinking…" if thinking else "Your move" + (" — check!" if game.in_check(game.turn) else ""))
	details.text = "You: " + ("White" if human_color == 1 else "Black") + " · " + bot.behavior.target_rating_label
	claim.disabled = thinking or not ended.is_empty() or not game.can_claim_draw()
	promotion_row.visible = not promotion_moves.is_empty()
	queue_redraw()

func _bot_turn() -> void:
	if not ended.is_empty():
		return
	if game.can_claim_draw():
		ended = "Draw claimed by slowbrainn"
		_refresh()
		return
	thinking = true
	_refresh()
	var token := session
	var move: Dictionary = await bot.choose_move(game)
	if token != session or not is_inside_tree():
		return
	thinking = false
	if not move.is_empty() and game.play(move):
		last_move = move
	_refresh()

func _claim_draw() -> void:
	if not thinking and ended.is_empty() and game.can_claim_draw():
		ended = "Draw claimed"
		_refresh()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if board_rect.has_point(event.position):
			var cell: Vector2 = (event.position - board_rect.position) / (board_rect.size.x / 8.0)
			var column := int(cell.x)
			var row := int(cell.y)
			select_square(row * 8 + column if human_color == 1 else (7 - row) * 8 + 7 - column)
			accept_event()

func select_square(index: int) -> void:
	if thinking or not ended.is_empty() or game.turn != human_color or not promotion_moves.is_empty():
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
	for move in promotion_moves:
		if move.promotion == kind:
			promotion_moves.clear()
			_make_move(move)
			return

func _make_move(move: Dictionary) -> void:
	if not game.play(move):
		return
	last_move = move
	selected = -1
	_refresh()
	if ended.is_empty():
		_bot_turn()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		leave_match()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), visual_theme.panel_color)
	if board_rect.size.x <= 0:
		return
	var cell := board_rect.size.x / 8.0
	var font := ThemeDB.fallback_font
	for row in 8:
		for column in 8:
			var index := row * 8 + column if human_color == 1 else (7 - row) * 8 + 7 - column
			var rect := Rect2(board_rect.position + Vector2(column, row) * cell, Vector2.ONE * cell)
			draw_rect(rect, visual_theme.light_square if (row + column) % 2 == 0 else visual_theme.dark_square)
			if index == selected or index == last_move.get("from", -1) or index == last_move.get("to", -1):
				draw_rect(rect.grow(-2), visual_theme.highlight, false, 3)
			if game.board[index] != 0:
				var texture: Texture2D = visual_theme.piece_texture(game.board[index])
				if texture:
					var available := rect.size * 0.90
					var scale_factor := minf(available.x / texture.get_width(), available.y / texture.get_height())
					var extent := texture.get_size() * scale_factor
					draw_texture_rect(texture, Rect2(rect.get_center() - extent * 0.5, extent), false)
			for move in legal:
				if move.from == selected and move.to == index:
					draw_circle(rect.get_center(), cell * 0.10, visual_theme.legal_destination)
					break
		var rank_label := str(8 - row if human_color == 1 else row + 1)
		draw_string(font, board_rect.position + Vector2(-18, (row + 0.6) * cell), rank_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, visual_theme.ink_color)
		var file_label: String = "abcdefgh"[row if human_color == 1 else 7 - row]
		draw_string(font, board_rect.position + Vector2((row + 0.45) * cell, board_rect.size.y + 19), file_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, visual_theme.ink_color)
