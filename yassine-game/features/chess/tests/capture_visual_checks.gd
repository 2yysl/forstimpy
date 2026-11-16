extends Node
## Developer-only visual fixture. B swaps player colour; F fills both trays.
const Rules = preload("res://features/chess/chess_rules.gd")
var activity

func _ready() -> void:
	activity = load("res://features/chess/ChessActivity.tscn").instantiate()
	add_child(activity)
	activity.restart(1)
	for uci in ["e2e4", "d7d5", "e4d5", "d8d5"]:
		for move in activity.game.legal_moves():
			if Rules.uci(move) == uci:
				var committed: bool = activity._commit_move(move, activity._capture_snapshot())
				assert(committed)
				break
	activity._refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_B:
		activity.human_color = -activity.human_color
	elif event.keycode == KEY_F:
		activity.captured_by_white.assign([-1, -1, -1, -1, -1, -1, -1, -1, -2, -2, -3, -3, -4, -4, -5])
		activity.captured_by_black.assign([1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5])
	else:
		return
	activity._refresh()
	get_viewport().set_input_as_handled()
