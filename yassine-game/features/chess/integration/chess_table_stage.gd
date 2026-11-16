extends "res://scripts/ui/table_scene.gd"
## Inherit the existing art, dialogue, location controls and entrance unchanged.
const Activity = preload("res://features/chess/ChessActivity.tscn")
var match_layer: CanvasLayer
var activity: Control

func _ready() -> void:
	super._ready()
	match_layer = CanvasLayer.new()
	match_layer.name = "ChessLayer"
	match_layer.layer = 20
	add_child(match_layer)

func _answer(joke: bool) -> void:
	if changing_view or not invitation_ready or is_instance_valid(activity) or _letter_is_reading():
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
	if is_instance_valid(activity) or _letter_is_reading():
		return
	ui.hide()
	activity = Activity.instantiate()
	activity.leave_requested.connect(_close_match)
	match_layer.add_child(activity)

func _close_match() -> void:
	if not is_instance_valid(activity):
		return
	# Remove immediately so re-entry cannot leave overlapping controls/signals.
	match_layer.remove_child(activity)
	activity.queue_free()
	activity = null
	ui.show()
	changing_view = false
	board_button.disabled = false
	_show_invitation()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(activity) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		activity.leave_match()
	else:
		super._unhandled_key_input(event)
