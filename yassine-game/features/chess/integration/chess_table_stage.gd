extends "res://scripts/ui/table_scene.gd"
## Inherit the existing art, dialogue, location controls and entrance unchanged.
const Activity = preload("res://features/chess/ChessActivity.tscn")
const MatchArchive = preload("res://features/chess/match_archive.gd")
var match_layer: CanvasLayer
var activity: Control
var match_archive = MatchArchive.new()
var table_new_game: Button
var history_button: Button
var history_label: Label
var history_popup: ColorRect
var history_panel: Panel
var history_list: ItemList
var history_empty: Label
var history_close: Button

func _ready() -> void:
	super._ready()
	match_layer = CanvasLayer.new()
	match_layer.name = "ChessLayer"
	match_layer.layer = 20
	add_child(match_layer)
	table_new_game = _button(ui, "new game", Vector2(562, 644), Vector2(156, 52), INK)
	table_new_game.name = "NewChessGame"
	table_new_game.hide()
	table_new_game.pressed.connect(_new_table_game)
	history_label = _label(ui, "match history", Vector2(1010, 608), Vector2(230, 35), SETTING_FONT_SIZE)
	history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	history_label.hide()
	history_button = _button(ui, "", Vector2(1194, 644), SETTING_BUTTON_SIZE, INK)
	history_button.add_theme_font_size_override("font_size", SETTING_FONT_SIZE)
	history_button.accessibility_name = "match history"
	history_button.hide()
	history_button.pressed.connect(_show_match_history)
	_build_match_history()
	match_archive.changed.connect(_refresh_match_history)
	_refresh_match_history()

func _build_match_history() -> void:
	history_popup = ColorRect.new()
	history_popup.color = Color(0.08, 0.12, 0.12, 0.55)
	history_popup.hide()
	ui.add_child(history_popup)
	history_panel = Panel.new()
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#fffaf0")
	paper.border_color = INK
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(6)
	history_panel.add_theme_stylebox_override("panel", paper)
	history_popup.add_child(history_panel)
	var title := _label(history_panel, "match history", Vector2(20, 16), Vector2(220, 32), 24)
	history_list = ItemList.new()
	history_list.position = Vector2(20, 62)
	history_list.add_theme_color_override("font_color", INK)
	history_list.add_theme_color_override("font_selected_color", INK)
	history_list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	history_list.add_theme_stylebox_override("selected", paper)
	history_list.add_theme_stylebox_override("selected_focus", paper)
	history_list.item_selected.connect(_open_saved_match)
	history_panel.add_child(history_list)
	history_empty = _label(history_panel, "No finished matches yet.", Vector2(20, 68), Vector2(270, 32), 16)
	history_close = _button(history_panel, "close", Vector2.ZERO, Vector2(140, 44), INK)
	history_close.pressed.connect(_close_match_history)
	# The popup compensates for table scaling, so rasterize its font at screen size.
	var popup_font: FontFile = preload("res://ttf/JetBrainsMono-Regular.ttf").duplicate()
	popup_font.oversampling = 1.0
	for control in [title, history_list, history_empty, history_close]:
		control.add_theme_font_override("font", popup_font)
	_layout_match_history()

func _layout() -> void:
	super._layout()
	if is_instance_valid(history_popup):
		_layout_match_history()

func _layout_match_history() -> void:
	if layout_scale <= 0.0:
		return
	var stretch := get_viewport().get_stretch_transform().get_scale()
	history_popup.scale = Vector2.ONE / (stretch * layout_scale)
	history_popup.position = -layout_offset / layout_scale
	history_popup.size = size * stretch
	history_panel.size = Vector2(minf(600.0, history_popup.size.x - 32.0), minf(360.0, history_popup.size.y - 32.0))
	history_panel.position = (history_popup.size - history_panel.size) * 0.5
	history_list.size = history_panel.size - Vector2(40, 136)
	history_list.add_theme_font_size_override("font_size", 14 if history_panel.size.x < 450.0 else 18)
	history_close.position = history_panel.size - Vector2(160, 64)

func _refresh_match_history() -> void:
	history_list.clear()
	for saved in match_archive.records:
		var summary: String = saved.summary()
		var item := history_list.add_item(summary)
		history_list.set_item_tooltip(item, summary)
	history_empty.visible = match_archive.records.is_empty()
	history_button.text = str(match_archive.records.size())
	history_button.tooltip_text = "Match history (%s)" % history_button.text

func _show_match_history() -> void:
	if changing_view:
		return
	dap.stop()
	history_list.deselect_all()
	history_popup.show()
	history_list.grab_focus()

func _close_match_history() -> void:
	history_popup.hide()
	history_button.grab_focus()

func _open_saved_match(index: int) -> void:
	if not history_popup.visible or index < 0 or index >= match_archive.records.size():
		return
	_close_match_history()
	_open_match(index)

func _show_invitation() -> void:
	super._show_invitation()
	if is_instance_valid(table_new_game):
		table_new_game.visible = is_instance_valid(activity) and not activity.ended.is_empty()
		history_button.show()
		history_label.show()

func _new_table_game() -> void:
	if changing_view or history_popup.visible or not is_instance_valid(activity) or activity.ended.is_empty():
		return
	_open_match()
	activity._return_live()
	activity.start_new_game()

func _answer(joke: bool) -> void:
	if changing_view or history_popup.visible or not invitation_ready or (is_instance_valid(activity) and not activity.suspended):
		return
	changing_view = true
	dap.stop()
	choices.hide()
	board_button.disabled = true
	if joke:
		dialogue.text = "Red? Bro brought his own chess rules."
		await get_tree().create_timer(2.2).timeout
	_open_match()
	changing_view = false

func _open_board() -> void:
	_answer(false)

func _open_match(saved_match := -1) -> void:
	if is_instance_valid(activity) and not activity.suspended:
		return
	ui.hide()
	if is_instance_valid(activity):
		var returning_from_archive: bool = activity.review_record != null
		activity.resume_match(saved_match < 0 and not returning_from_archive)
		if saved_match < 0 and returning_from_archive:
			activity._return_live()
	else:
		activity = Activity.instantiate()
		activity.archive = match_archive
		activity.leave_requested.connect(_close_match)
		match_layer.add_child(activity)
	if saved_match >= 0:
		activity._open_archived(saved_match)

func _close_match() -> void:
	if not is_instance_valid(activity):
		return
	activity.suspend_match()
	ui.show()
	changing_view = false
	board_button.disabled = false
	_show_invitation()

func _unhandled_key_input(event: InputEvent) -> void:
	if history_popup.is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_match_history()
	else:
		super._unhandled_key_input(event)
