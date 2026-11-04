@tool
extends Control
## A reusable title view. Message history and camera motion live elsewhere.

signal continue_requested

@export_range(0.2, 0.95, 0.01) var title_width_ratio := 0.80
@export var title_color := Color("#ffe9a3")
@export var prompt_color := Color("#477477")

var _interaction_enabled := true
@onready var title: Control = $Title
@onready var prompt: Button = $Continue


func _ready() -> void:
	if not Engine.is_editor_hint():
		title.set("text", get_node("/root/LoadingMessages").choose_message())
	prompt.pressed.connect(_request_continue)
	resized.connect(_layout)
	_layout()


func fit_to_view(view_size: Vector2) -> void:
	size = view_size
	_layout()


func _layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	var font: Font = title.get("font")
	var available_width := size.x * title_width_ratio
	var low := 1
	var high := 2048
	while low < high:
		var candidate := int(ceil((low + high) / 2.0))
		var measured: Dictionary = _measure_ink(font, candidate)
		var ink: Rect2 = measured.ink
		if ink.size.x <= available_width and ink.size.y <= size.y * 0.70:
			low = candidate
		else:
			high = candidate - 1
	var metrics: Dictionary = _measure_ink(font, low)
	var bounds: Rect2 = metrics.ink
	title.call("configure", metrics, low, title_color)
	var prompt_size := int(clampf(size.x * 0.025, 22.0, 34.0))
	prompt.add_theme_font_size_override("font_size", prompt_size)
	for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		prompt.add_theme_color_override(state_name, prompt_color)
	var prompt_height := maxf(44.0, prompt.get_theme_font("font").get_height(prompt_size))
	var gap := clampf(size.y * 0.018, 10.0, 20.0)
	var group_height := bounds.size.y + gap + prompt_height
	var group_y := (size.y - group_height) * 0.5
	title.position = Vector2((size.x - bounds.size.x) * 0.5, group_y)
	prompt.position = Vector2(size.x * 0.1, group_y + bounds.size.y + gap)
	prompt.size = Vector2(size.x * 0.8, prompt_height)


func _measure_ink(font: Font, font_size: int) -> Dictionary:
	var line := TextLine.new()
	line.add_string(str(title.get("text")), font, font_size)
	var server := TextServerManager.get_primary_interface()
	var cursor := 0.0
	var ink := Rect2()
	var found := false
	for glyph in server.shaped_text_get_glyphs(line.get_rid()):
		var glyph_size: Vector2 = server.font_get_glyph_size(
			glyph.font_rid, Vector2i(glyph.font_size, 0), glyph.index)
		var glyph_offset: Vector2 = server.font_get_glyph_offset(
			glyph.font_rid, Vector2i(glyph.font_size, 0), glyph.index)
		for repeat_index in range(glyph.repeat):
			if glyph_size.x > 0.0 and glyph_size.y > 0.0:
				var rect := Rect2(Vector2(cursor, 0.0) + glyph.offset + glyph_offset, glyph_size)
				ink = ink.merge(rect) if found else rect
				found = true
			cursor += float(glyph.advance)
	return {"ink": ink, "line": line}


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	prompt.disabled = not enabled
	prompt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _interaction_enabled:
		return
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var tapped: bool = event is InputEventScreenTouch and event.pressed
	if clicked or tapped or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_request_continue()


func _request_continue() -> void:
	if _interaction_enabled and not Engine.is_editor_hint():
		continue_requested.emit()
