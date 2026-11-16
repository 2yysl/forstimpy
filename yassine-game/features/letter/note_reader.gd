extends CanvasLayer
signal note_closed
const FONT = preload("res://ttf/JetBrainsMono-Regular.ttf")

func _ready() -> void:
	var local_font: Font = FONT.duplicate()
	local_font.oversampling = 1.0
	$Root.theme = Theme.new()
	$Root.theme.default_font = local_font
	$Root.theme.default_font_size = 20
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#fffaf0")
	paper.border_color = Color("#243333")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(6)
	paper.content_margin_left = 20
	paper.content_margin_right = 20
	paper.content_margin_top = 16
	paper.content_margin_bottom = 16
	$Root/Paper.add_theme_stylebox_override("panel", paper)
	for label in [$Root/Paper/Contents/Title, $Root/Paper/Contents/Scroll/Text]:
		label.add_theme_color_override("font_color", Color("#243333"))
	$Root/Paper/Contents/Title.add_theme_font_size_override("font_size", 24)
	var back: Button = $Root/Paper/Contents/Back
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := paper.duplicate()
		style.bg_color = Color("#e8e1b4") if state in ["hover", "pressed", "focus"] else Color("#fffaf0")
		style.set_border_width_all(1)
		back.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		back.add_theme_color_override(state, Color("#243333"))
	back.pressed.connect(close_note)
	get_viewport().size_changed.connect(_fit_window)
	_fit_window()

func open_note(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Letter text is missing: " + path)
		return false
	$Root/Paper/Contents/Scroll/Text.text = FileAccess.get_file_as_string(path)
	$Root/Paper/Contents/Scroll.scroll_vertical = 0
	_fit_window()
	show()
	$Root/Paper/Contents/Back.grab_focus.call_deferred()
	return true

func close_note() -> void:
	if not visible:
		return
	hide()
	note_closed.emit()

func _fit_window() -> void:
	var stretch := get_viewport().get_stretch_transform().get_scale()
	var extent := get_viewport().get_visible_rect().size * stretch
	$Root.scale = Vector2.ONE / stretch
	$Root.size = extent
	var paper_size := Vector2(maxf(180, minf(820, extent.x - 32)), maxf(160, minf(700, extent.y - 48)))
	$Root/Paper.position = (extent - paper_size) * 0.5
	$Root/Paper.size = paper_size
	$Root/Paper/Contents/Scroll/Text.add_theme_font_size_override("font_size", 18 if extent.x < 600 else 20)

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_note()
