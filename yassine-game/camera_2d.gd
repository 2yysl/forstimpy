func pan_into_game() -> void:
	var camera := $Camera2D
	var distance := get_viewport_rect().size.y / camera.zoom.y

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		camera,
		"position:y",
		camera.position.y + distance,
		1.2
	)

	await tween.finished
	$LoadingMessage.hide()
