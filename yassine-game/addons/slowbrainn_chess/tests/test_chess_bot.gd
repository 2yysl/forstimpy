extends SceneTree
func _initialize() -> void:
	root.add_child(preload("res://addons/slowbrainn_chess/tests/bot_checks.gd").new())
