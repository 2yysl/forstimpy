extends SceneTree
func _initialize() -> void:
	root.add_child(preload("res://features/chess/tests/bot_checks.gd").new())
