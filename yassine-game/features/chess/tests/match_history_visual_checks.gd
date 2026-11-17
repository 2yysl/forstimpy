extends Node
## Developer-only session fixture. S creates a stalemate for end-flow checks.
const Rules = preload("res://features/chess/chess_rules.gd")
var main
var activity

func _ready() -> void:
	main = load("res://features/chess/integration/ChessIntegratedMain.tscn").instantiate()
	add_child(main)
	main.title_screen.get_node("Continue").pressed.emit()
	await get_tree().create_timer(2.0).timeout
	main._stage.board_button.pressed.emit()
	activity = main._stage.activity
	activity.restart(1)
	for uci in ["f2f3", "e7e5", "g2g4", "d8h4"]:
		_commit(uci)
	_stalemate()
	activity.restart(1)
	for uci in ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6", "e1g1", "f8e7"]:
		_commit(uci)

func _commit(uci: String) -> void:
	for move in activity.game.legal_moves():
		if Rules.uci(move) == uci:
			var committed: bool = activity._commit_move(move, activity._capture_snapshot())
			assert(committed)
			activity._refresh()
			return
	assert(false, "Invalid fixture move: " + uci)

func _stalemate() -> void:
	activity.restart(1)
	activity.game.load_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
	activity._refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S and is_instance_valid(activity):
		_stalemate()
		get_viewport().set_input_as_handled()
