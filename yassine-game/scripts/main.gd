extends Node2D
## Coordinates title -> camera pan -> optional future stage.
## Future 3D chess should be a Control scene with its own SubViewport.

signal transition_started
signal stage_entered(stage: Control)

enum FlowState { TITLE, PANNING, STAGE }
@export var next_scene: PackedScene
@export_range(0.2, 4.0, 0.1) var pan_seconds := 1.2

var state: FlowState = FlowState.TITLE
var pan_progress := 0.0
var _stage: Control

@onready var camera: Camera2D = $Camera2D
@onready var title_screen: Control = $TitleScreen
@onready var game_host: Node2D = $GameHost
@onready var game_view: Marker2D = $GameView


func _ready() -> void:
	# Use the selected cursor unchanged in orientation; import settings limit its size.
	var cursor_path: String = ProjectSettings.get_setting("display/mouse_cursor/custom_image", "")
	var hand_cursor := load(cursor_path) as Texture2D
	# Fingertip position in the selected source image, scaled to the imported texture.
	var hand_hotspot := (Vector2(224.0 / 291.0, 91.0 / 255.0) * hand_cursor.get_size()).round()
	Input.set_custom_mouse_cursor(hand_cursor, Input.CURSOR_ARROW, hand_hotspot)
	Input.set_custom_mouse_cursor(hand_cursor, Input.CURSOR_POINTING_HAND, hand_hotspot)
	get_viewport().size_changed.connect(_layout)
	title_screen.connect("continue_requested", _continue_to_stage)
	_layout()
	camera.make_current()


func _layout() -> void:
	var view_size := get_viewport_rect().size
	title_screen.call("fit_to_view", view_size)
	game_host.position = Vector2(0.0, view_size.y)
	game_view.position = Vector2(view_size.x * 0.5, view_size.y * 1.5)
	if is_instance_valid(_stage):
		_stage.size = view_size
	_set_pan_progress(pan_progress)


func _continue_to_stage() -> void:
	if state != FlowState.TITLE:
		return
	# The empty slot is intentional until a real stage is assigned.
	if next_scene != null:
		var candidate := next_scene.instantiate()
		if not candidate is Control:
			candidate.free()
			push_error("Next scene must have a Control root; wrap 3D content in a SubViewport.")
			return
		_stage = candidate as Control
		_stage.process_mode = Node.PROCESS_MODE_DISABLED
		game_host.add_child(_stage)
		_stage.position = Vector2.ZERO
		_stage.size = get_viewport_rect().size
	state = FlowState.PANNING
	title_screen.call("set_interaction_enabled", false)
	transition_started.emit()
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_pan_progress, 0.0, 1.0, pan_seconds)
	await tween.finished
	state = FlowState.STAGE
	title_screen.hide()
	if is_instance_valid(_stage):
		_stage.process_mode = Node.PROCESS_MODE_INHERIT
		if _stage.has_method("start_game"):
			_stage.call("start_game")
	stage_entered.emit(_stage)


func _set_pan_progress(value: float) -> void:
	pan_progress = value
	var view_size := get_viewport_rect().size
	camera.position = Vector2(view_size.x * 0.5, view_size.y * (0.5 + value))
	camera.force_update_scroll()
