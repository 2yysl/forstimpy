extends SceneTree
var checks := 0
var failures := 0
var sound_count := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	print("PASS: " if condition else "FAIL: ", message)
	if not condition:
		failures += 1
		push_error(message)

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func run() -> void:
	var main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(main)
	main.title_screen.get_node("Continue").pressed.emit()
	await pause(2.0)
	var stage = main._stage
	check(not stage.ui.has_node("Letter"), "The sit-down scene keeps the letter hidden")
	stage._change_location(2)
	stage.board_button.pressed.emit()
	await process_frame
	var activity = stage.activity
	var letter = activity.letter
	check(not letter.visible and not letter.enabled, "Colour selection keeps the letter hidden")
	activity.fist_choice.left_colour = 1
	activity.fist_choice.choose(0)
	await pause(activity.COLOUR_REVEAL_SECONDS + 0.1)
	check(letter.visible and letter.enabled, "The letter appears once play begins")
	var player: AudioStreamPlayer = letter.get_node("PaperSound")
	letter.hover_sound_started.connect(func(): sound_count += 1)
	check(letter.enabled and not letter.opened and not letter.reading, "Match starts with an enabled, closed letter")
	check(letter.get_node("Artwork").texture == letter.closed_texture and not letter.get_node("Note").visible, "Closed artwork hides the protruding note")
	check(letter.paper_sound.resource_path == "res://assets/sfx/paper crumple.wav", "Letter uses the existing paper crumple WAV")
	check(player.max_polyphony == 1 and player.bus == &"SFX", "One reusable SFX player prevents stacking hover clips")
	var bus := AudioServer.get_bus_index("SFX")
	check(bus >= 0, "Shared SFX bus is available")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus, capture, 0)
	letter.get_node("EnvelopeHover").mouse_entered.emit()
	check(letter.opened and letter.get_node("Note").visible and letter.get_node("Artwork").texture == letter.open_texture, "Hover opens the envelope and exposes the note")
	check(sound_count == 1 and player.playing and player.stream == letter.paper_sound, "Hover starts the assigned WAV exactly once")
	await pause(0.25)
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	print("AUDIO_CAPTURE driver=", AudioServer.get_driver_name(), " frames=", samples.size(), " peak=", peak)
	check(peak > 0.0001, "Paper playback produces nonzero audio on the SFX bus")
	AudioServer.remove_bus_effect(bus, 0)
	letter.get_node("Note").mouse_entered.emit()
	letter.get_node("EnvelopeHover").mouse_entered.emit()
	check(sound_count == 1 and letter.opened, "Moving within the open letter does not replay sound")
	letter._set_open(false, false)
	check(not letter.get_node("Note").visible and player.playing, "Leaving closes the letter without cutting the paper sound")
	letter.get_node("EnvelopeHover").mouse_entered.emit()
	check(sound_count == 2 and player.get_playback_position() < 0.1, "Fresh hover restarts the same player from the beginning")
	letter.get_node("Note").pressed.emit()
	await process_frame
	await process_frame
	check(letter.reading and letter.reader.visible, "Selecting the exposed note opens the full reader")
	var text: Label = letter.reader.get_node("Root/Paper/Contents/Scroll/Text")
	check(text.text == FileAccess.get_file_as_string(letter.note_path), "Reader displays the canonical text asset without rewriting it")
	check(sound_count == 2, "Opening the reader adds no extra hover sound")
	activity.select_square(52)
	check(activity.selected == -1, "The reader keeps chess input blocked")
	var reader_root: Control = letter.reader.get_node("Root")
	var paper: Control = letter.reader.get_node("Root/Paper")
	check(Rect2(Vector2.ZERO, reader_root.size).encloses(paper.get_rect()), "Full reader fits the rendered viewport")
	var scroll: ScrollContainer = letter.reader.get_node("Root/Paper/Contents/Scroll")
	check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "Long note is scrollable")
	scroll.scroll_vertical = 10000
	await process_frame
	check(scroll.scroll_vertical > 0 and text.text == FileAccess.get_file_as_string(letter.note_path), "Scrolling preserves the complete text")
	letter.reader.get_node("Root/Paper/Contents/Back").pressed.emit()
	await process_frame
	check(not letter.reading and not letter.reader.visible and activity.visible, "Back returns to the same match")
	check(sound_count == 2 and stage.location_index == 2, "Back preserves the selected table location without replaying hover audio")
	letter.get_node("EnvelopeHover").mouse_entered.emit()
	letter.read_note()
	check(letter.reading and scroll.scroll_vertical == 0, "Reopening starts the reader at the beginning")
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	letter.reader._unhandled_key_input(cancel)
	check(not letter.reading and activity.visible, "Escape closes the note and keeps the match")
	letter.get_node("EnvelopeHover").mouse_entered.emit()
	letter.read_note()
	activity.suspend_match()
	await process_frame
	check(not letter.reading and not letter.reader.visible and not letter.opened, "Suspending the match cannot leave an orphan reader overlay")
	activity.resume_match()
	letter.set_enabled(false)
	var count_before: int = sound_count
	letter.get_node("EnvelopeHover").mouse_entered.emit()
	letter.read_note()
	check(not letter.opened and not letter.reading and sound_count == count_before, "Disabled letter ignores hover and note selection")
	letter.set_enabled(true)
	activity.leave_match()
	check(stage.ui.visible and not letter.is_visible_in_tree(), "Leaving chess returns to the letter-free table")
	stage.board_button.pressed.emit()
	await process_frame
	check(stage.activity.letter == letter and letter.is_visible_in_tree(), "Resuming chess restores the original letter")
	main.queue_free()
	await process_frame
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	await process_frame
	print("LETTER: ", checks - failures, "/", checks, " checks passed")
	quit(1 if failures else 0)
