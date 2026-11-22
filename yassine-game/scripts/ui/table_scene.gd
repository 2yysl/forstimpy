extends Control
## Storyboard prototype. All foreground art is replaceable; no chess rules yet.
const INK := Color("#243333")
const CREAM := Color("#fff2cc")
const WOOD := Color("#bb805e")
const BASE := Vector2(1280, 720)
const SETTING_BUTTON_SIZE := Vector2(46, 44)
const SETTING_FONT_SIZE := 22
const TANGERS_BACKGROUND := preload("res://assets/backgrounds/tangersbackground.png")
const BESSERER_BACKGROUND := preload("res://assets/backgrounds/195background.png")
const LOCATION_TEXT_COLORS := [INK, CREAM, Color("#fff8ef")]
const DapScene = preload("res://features/dap/DapInteraction.tscn")
var overhead := false
var started := false
var entrance_done := false
var invitation_ready := false
var changing_view := false
var location_index := 0
var dap_count := 0
var dap_busy := false
var hand_hover := false
var layout_scale := 1.0
var layout_offset := Vector2.ZERO
var entrance_finished_msec := 0
var invitation_shown_msec := 0
var ui: Control
var settings_panel: Control
var dialogue: Label
var choices: Control
var dap_button: Button
var dap_line: Label
var board_button: Button
var back_button: Button
var view_label: Label
var dap

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 1.0
	ui = Control.new()
	ui.name = "StoryboardUI"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	settings_panel = Control.new()
	settings_panel.name = "LocationSettings"
	settings_panel.position = Vector2(-180, 130)
	settings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(settings_panel)
	_label(settings_panel, "setting", Vector2.ZERO, Vector2(160, 35), SETTING_FONT_SIZE)
	var names := ["Park", "Tangers", "195 Besserer"]
	var colors := [Color("#c3825c"), Color("#7d8b90"), Color("#a30c31")]
	for i in range(3):
		var button := _button(settings_panel, str(i + 1), Vector2(0, 44 + i * 55), SETTING_BUTTON_SIZE, colors[i])
		button.tooltip_text = names[i]
		button.pressed.connect(_change_location.bind(i))
	dialogue = _label(ui, "", Vector2(250, 30), Vector2(860, 85), 34)
	dialogue.name = "Invitation"
	dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.hide()
	choices = Control.new()
	choices.name = "Responses"
	choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(choices)
	var sure := _button(choices, '"sure"', Vector2(315, 644), Vector2(230, 52), Color("#5655d8"))
	sure.name = "Sure"
	sure.pressed.connect(_answer.bind(false))
	var joke := _button(choices, '"yes but red"', Vector2(750, 644), Vector2(230, 52), Color("#d63d4a"))
	joke.name = "YesButRed"
	joke.pressed.connect(_answer.bind(true))
	choices.hide()
	dap_button = _button(ui, "", Vector2(867, 340), Vector2(140, 108), INK, true)
	dap_button.name = "Dap"
	dap_button.tooltip_text = "dap?"
	dap_button.disabled = true
	dap_button.pressed.connect(_dap)
	dap_button.mouse_entered.connect(func(): hand_hover = true; queue_redraw())
	dap_button.mouse_exited.connect(func(): hand_hover = false; queue_redraw())
	dap_line = _label(ui, "", Vector2(950, 270), Vector2(280, 100), 24)
	dap_line.name = "DapReaction"
	dap_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dap_line.hide()
	dap = DapScene.instantiate()
	add_child(dap)
	dap.triggered.connect(_dap_triggered)
	dap.feedback_finished.connect(_dap_finished)
	ui.visibility_changed.connect(_table_visibility_changed)
	board_button = _button(ui, "", Vector2(330, 451), Vector2(600, 175), INK, true)
	board_button.name = "Board"
	board_button.tooltip_text = "Play chess"
	board_button.disabled = true
	board_button.pressed.connect(_open_board)
	back_button = _button(ui, "< back", Vector2(40, 642), Vector2(160, 48), INK)
	back_button.name = "Back"
	back_button.pressed.connect(_return_to_table)
	back_button.hide()
	view_label = _label(ui, "chess board placeholder", Vector2(470, 668), Vector2(370, 30), 18)
	view_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view_label.hide()
	resized.connect(_layout)
	_layout()
	_change_location(location_index)

func _label(parent: Node, text: String, pos: Vector2, extent: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_override("font", preload("res://ttf/JetBrainsMono-Regular.ttf"))
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, pos: Vector2, extent: Vector2, color: Color, invisible := false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = extent
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", preload("res://ttf/JetBrainsMono-Regular.ttf"))
	button.add_theme_font_size_override("font_size", 23)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, color)
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0) if invisible else CREAM
		style.set_border_width_all(0 if invisible else 2)
		style.border_color = color
		style.set_corner_radius_all(3)
		if not invisible and state_name == "hover":
			style.bg_color = Color("#ffffff")
		button.add_theme_stylebox_override(state_name, style)
	parent.add_child(button)
	return button

func _layout() -> void:
	if not is_instance_valid(ui):
		return
	layout_scale = minf(size.x / BASE.x, size.y / BASE.y)
	layout_offset = (size - BASE * layout_scale) * 0.5
	ui.position = layout_offset
	ui.scale = Vector2.ONE * layout_scale
	queue_redraw()

func start_game() -> void:
	if started:
		return
	started = true
	var slide := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(settings_panel, "position:x", 34.0, 0.45)
	await slide.finished
	entrance_done = true
	dap_button.disabled = false
	entrance_finished_msec = Time.get_ticks_msec()
	invitation_ready = true
	invitation_shown_msec = Time.get_ticks_msec()
	_show_invitation()

func _show_invitation() -> void:
	if overhead:
		return
	dialogue.text = "Let's play chess."
	dialogue.show()
	choices.show()
	board_button.disabled = false

func _change_location(index: int) -> void:
	location_index = index
	for label in [dialogue, dap_line]:
		label.add_theme_color_override("font_color", LOCATION_TEXT_COLORS[index])
		label.add_theme_color_override("font_outline_color", INK)
		label.add_theme_constant_override("outline_size", 0 if index == 0 else 3)
	queue_redraw()

func _dap() -> void:
	if not entrance_done or changing_view or overhead or not ui.is_visible_in_tree():
		return
	dap.trigger()

func _dap_triggered(_outcome: int, comment: String) -> void:
	dap_busy = true
	dap_count += 1
	dap_line.text = comment
	dap_line.show()
	queue_redraw()

func _dap_finished() -> void:
	dap_busy = false
	dap_line.hide()
	queue_redraw()

func _table_visibility_changed() -> void:
	if not ui.is_visible_in_tree():
		dap.stop()
		hand_hover = false
		queue_redraw()

func _answer(joke: bool) -> void:
	if changing_view or not invitation_ready:
		return
	changing_view = true
	dap.stop()
	choices.hide()
	board_button.disabled = true
	if joke:
		dialogue.text = "Red? Bro brought his own chess rules."
		await get_tree().create_timer(2.2).timeout
	await _switch_view(true)
	changing_view = false

func _open_board() -> void:
	_answer(false)

func _return_to_table() -> void:
	if changing_view:
		return
	changing_view = true
	await _switch_view(false)
	changing_view = false

func _switch_view(to_overhead: bool) -> void:
	# Keep the previous view opaque while the new view is uncovered left to right.
	await RenderingServer.frame_post_draw
	var previous_frame := ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	var wipe_layer := CanvasLayer.new()
	wipe_layer.name = "ViewWipe"
	wipe_layer.layer = 100
	add_child(wipe_layer)
	var cover := TextureRect.new()
	cover.name = "PreviousView"
	cover.texture = previous_frame
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	wipe_layer.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var wipe_shader := Shader.new()
	wipe_shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	COLOR = texture(TEXTURE, UV);
	if (UV.x < progress) {
		discard;
	}
}
"""
	var wipe_material := ShaderMaterial.new()
	wipe_material.shader = wipe_shader
	cover.material = wipe_material
	overhead = to_overhead
	dialogue.hide()
	choices.hide()
	dap_line.hide()
	dap_button.visible = not overhead
	board_button.visible = not overhead
	back_button.visible = overhead
	view_label.visible = overhead
	if not overhead and invitation_ready:
		_show_invitation()
	queue_redraw()
	var wipe := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	wipe.tween_method(func(value: float): wipe_material.set_shader_parameter("progress", value), 0.0, 1.0, 0.55)
	await wipe.finished
	wipe_layer.queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if overhead and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_table()

func _line(points: Array, color := INK, width := 4.0) -> void:
	draw_polyline(PackedVector2Array(points), color, width, true)

func _shape(points: Array, fill: Color) -> void:
	var packed := PackedVector2Array(points)
	draw_colored_polygon(packed, fill)
	packed.append(packed[0])
	draw_polyline(packed, INK, 3.0, true)

func _board(top_left: Vector2, top_right: Vector2, bottom_left: Vector2, bottom_right: Vector2) -> void:
	for row in range(8):
		for col in range(8):
			var a := top_left.lerp(bottom_left, row / 8.0).lerp(top_right.lerp(bottom_right, row / 8.0), col / 8.0)
			var b := top_left.lerp(bottom_left, row / 8.0).lerp(top_right.lerp(bottom_right, row / 8.0), (col + 1) / 8.0)
			var c := top_left.lerp(bottom_left, (row + 1) / 8.0).lerp(top_right.lerp(bottom_right, (row + 1) / 8.0), (col + 1) / 8.0)
			var d := top_left.lerp(bottom_left, (row + 1) / 8.0).lerp(top_right.lerp(bottom_right, (row + 1) / 8.0), col / 8.0)
			draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color("#e8e1b4") if (row + col) % 2 == 0 else Color("#709391"))
			if row < 2 or row > 5:
				var center := (a + b + c + d) * 0.25
				var radius := 12.0 if overhead else 7.5
				var piece_color := Color("#f9f3df") if row < 2 else INK
				draw_circle(center, radius + 1.5, INK)
				draw_circle(center, radius, piece_color)
				if row == 0 or row == 7:
					draw_line(center + Vector2(-radius, radius), center + Vector2(radius, radius), piece_color, 5.0)
	_line([top_left, top_right, bottom_right, bottom_left, top_left], INK, 5)

func _draw() -> void:
	draw_set_transform(layout_offset, 0.0, Vector2.ONE * layout_scale)
	# Background details remain behind the same persistent foreground.
	if location_index == 0:
		_line([Vector2(1138, 430), Vector2(1130, 224), Vector2(1102, 185)], WOOD, 11)
		for p in [Vector2(1090, 160), Vector2(1160, 165), Vector2(1120, 112)]:
			draw_circle(p, 67, Color("#abc899"))
		_line([Vector2(980, 156), Vector2(994, 163), Vector2(1008, 155)], INK, 3)
	elif location_index == 1:
		draw_texture_rect(TANGERS_BACKGROUND, Rect2(Vector2.ZERO, BASE), false)
	else:
		draw_texture_rect(BESSERER_BACKGROUND, Rect2(Vector2.ZERO, BASE), false)
	if overhead:
		_shape([Vector2(240, 155), Vector2(1050, 155), Vector2(1110, 715), Vector2(185, 715)], WOOD)
		_board(Vector2(410, 180), Vector2(890, 180), Vector2(410, 660), Vector2(890, 660))
		draw_circle(Vector2(650, 110), 46, CREAM)
		_line([Vector2(619, 106), Vector2(645, 106), Vector2(650, 114), Vector2(678, 106)], INK, 6)
		_line([Vector2(635, 130), Vector2(653, 137), Vector2(670, 127)], INK, 3)
	else:
		# Character placeholder: face, hair, glasses, shirt and arms.
		_shape([Vector2(570, 294), Vector2(738, 294), Vector2(826, 371), Vector2(785, 424), Vector2(520, 424), Vector2(475, 369)], Color("#7caaa9"))
		_shape([Vector2(619, 258), Vector2(690, 258), Vector2(690, 307), Vector2(619, 307)], CREAM)
		draw_circle(Vector2(651, 215), 92, INK)
		draw_circle(Vector2(651, 215), 87, CREAM)
		_shape([Vector2(555, 214), Vector2(564, 169), Vector2(620, 135), Vector2(654, 144), Vector2(701, 125), Vector2(741, 175), Vector2(748, 212), Vector2(697, 174), Vector2(638, 188), Vector2(600, 216)], INK)
		_line([Vector2(568, 223), Vector2(630, 220), Vector2(630, 251), Vector2(574, 251), Vector2(568, 223)], INK, 5)
		_line([Vector2(653, 220), Vector2(725, 216), Vector2(721, 248), Vector2(655, 250), Vector2(653, 220)], INK, 5)
		_line([Vector2(630, 229), Vector2(653, 227)], INK, 5)
		_line([Vector2(621, 269), Vector2(653, 279), Vector2(685, 264)], INK, 4)
		_shape([Vector2(380, 395), Vector2(920, 395), Vector2(1240, 715), Vector2(40, 715)], WOOD)
		_board(Vector2(461, 434), Vector2(835, 434), Vector2(318, 625), Vector2(982, 625))
		_shape([Vector2(560, 330), Vector2(510, 351), Vector2(452, 398), Vector2(484, 419), Vector2(583, 370)], Color("#7caaa9"))
		_shape([Vector2(752, 329), Vector2(807, 348), Vector2(911, 393), Vector2(888, 422), Vector2(735, 370)], Color("#7caaa9"))
		draw_circle(Vector2(482, 402), 29, CREAM)
		draw_circle(Vector2(912, 402 - (12 if dap_busy else 0)), 30, CREAM)
		if hand_hover or dap_busy:
			draw_arc(Vector2(912, 402), 40, 0.0, TAU, 40, Color("#fff1a1"), 4, true)
		_line([Vector2(465, 402), Vector2(490, 410), Vector2(507, 400)], INK, 3)
		_line([Vector2(895, 400), Vector2(922, 410), Vector2(938, 399)], INK, 3)
