extends Control

const GAME_SCENE := "res://game.tscn"
const MINIMUM_SECONDS := 3.0

var elapsed := 0.0

func _ready() -> void:
	var error := ResourceLoader.load_threaded_request(GAME_SCENE)

	if error != OK:
		show_loading_error()

func _process(delta: float) -> void:
	elapsed += delta

	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			if elapsed >= MINIMUM_SECONDS:
				set_process(false)

				var scene := ResourceLoader.load_threaded_get(
					GAME_SCENE
				) as PackedScene

				var error := get_tree().change_scene_to_packed(scene)
				if error != OK:
					show_loading_error()

		ResourceLoader.THREAD_LOAD_FAILED, \
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			show_loading_error()


func show_loading_error() -> void:
	set_process(false)
	$Label.text = "Couldn't load the game."
	push_error("Couldn't load scene: " + GAME_SCENE)
