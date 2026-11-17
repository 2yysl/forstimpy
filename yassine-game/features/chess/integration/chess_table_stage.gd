extends "res://scripts/ui/table_scene.gd"
## Inherit the existing art, dialogue, location controls and entrance unchanged.
const Activity = preload("res://features/chess/ChessActivity.tscn")
const MatchArchive = preload("res://features/chess/match_archive.gd")
var match_layer: CanvasLayer
var activity: Control
var match_archive = MatchArchive.new()
var table_new_game: Button

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

func _show_invitation() -> void:
	super._show_invitation()
	if is_instance_valid(table_new_game):
		table_new_game.visible = is_instance_valid(activity) and not activity.ended.is_empty()

func _new_table_game() -> void:
	if changing_view or _letter_is_reading() or not is_instance_valid(activity) or activity.ended.is_empty():
		return
	_open_match()
	activity._return_live()
	activity.start_new_game()

func _answer(joke: bool) -> void:
	if changing_view or not invitation_ready or (is_instance_valid(activity) and not activity.suspended) or _letter_is_reading():
		return
	changing_view = true
	dap.stop()
	letter.set_enabled(false)
	choices.hide()
	board_button.disabled = true
	if joke:
		dialogue.text = "Red? Bro brought his own chess rules."
		await get_tree().create_timer(2.2).timeout
	_open_match()
	changing_view = false

func _open_board() -> void:
	_answer(false)

func _open_match() -> void:
	if (is_instance_valid(activity) and not activity.suspended) or _letter_is_reading():
		return
	ui.hide()
	if is_instance_valid(activity):
		activity.resume_match()
	else:
		activity = Activity.instantiate()
		activity.archive = match_archive
		activity.leave_requested.connect(_close_match)
		match_layer.add_child(activity)

func _close_match() -> void:
	if not is_instance_valid(activity):
		return
	activity.suspend_match()
	ui.show()
	changing_view = false
	board_button.disabled = false
	_show_invitation()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(activity) and not activity.suspended and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		activity.leave_match()
	else:
		super._unhandled_key_input(event)
