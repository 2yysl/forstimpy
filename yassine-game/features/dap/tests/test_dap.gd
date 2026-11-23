extends SceneTree
const PATHS := ["dapbad.wav", "dapmid.wav", "dapmid2.wav", "dapgoat.wav"]
const LINES := [["we suck", "look at the elbow"], ["we could do better", "shibal"], ["we could do better", "shibal"], ["we are goated", "nice"]]
var checks := 0
var failures := 0
var last_outcome := -1
var last_comment := ""
var observed := 0
var buckets := [0, 0, 0, 0]
var pairings_valid := true
var seen := {}

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

func observe(outcome: int, comment: String) -> void:
	last_outcome = outcome
	last_comment = comment
	observed += 1
	buckets[outcome] += 1
	pairings_valid = pairings_valid and comment in LINES[outcome]
	seen[str(outcome) + ":" + comment] = true

func seed_for(outcome: int, variant: int) -> int:
	var probe := RandomNumberGenerator.new()
	var lower := [0, 20, 55, 90]
	var upper := [20, 55, 90, 100]
	for candidate in range(10000):
		probe.seed = candidate
		var roll := probe.randi_range(0, 99)
		var line := probe.randi_range(0, 1)
		if roll >= lower[outcome] and roll < upper[outcome] and line == variant:
			return candidate
	assert(false, "Could not find a deterministic outcome fixture")
	return 0

func run() -> void:
	var main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(main)
	main.title_screen.get_node("Continue").pressed.emit()
	var stage = main._stage
	stage.dap.triggered.connect(observe)
	stage.dap_button.pressed.emit()
	check(stage.dap_count == 0, "Dap is blocked before the table entrance finishes")
	await pause(2.0)
	var dap = stage.dap
	check(stage.entrance_done and not stage.dap_button.disabled, "The normal game launch enables the hand")
	check(dap.player.max_polyphony == 1 and dap.player.bus == &"SFX", "Dap uses one voice on the shared SFX bus")
	check(dap.find_children("*", "AudioStreamPlayer", true, false).size() == 1 and dap.find_children("*", "Timer", true, false).size() == 1, "Exactly one reusable audio player and feedback timer exist")
	var bus := AudioServer.get_bus_index("SFX")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus, capture, 0)
	for outcome in range(4):
		for variant in range(2):
			if variant == 0:
				dap.stop()
				await pause(0.05)
			dap.rng.seed = seed_for(outcome, variant)
			capture.clear_buffer()
			stage.dap_button.pressed.emit()
			await process_frame
			check(last_outcome == outcome and last_comment == LINES[outcome][variant] and stage.dap_line.text == last_comment and dap.player.stream.resource_path.ends_with(PATHS[outcome]), "Outcome %d / comment %d pairs the correct WAV and character text" % [outcome, variant])
			if variant == 0:
				await pause(0.25)
				var samples := capture.get_buffer(capture.get_frames_available())
				var peak := 0.0
				for sample in samples:
					peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
				print("DAP_AUDIO file=", PATHS[outcome], " driver=", AudioServer.get_driver_name(), " frames=", samples.size(), " peak=", peak)
				check(peak > 0.0001, PATHS[outcome] + " produces audible samples on the SFX bus")
	AudioServer.remove_bus_effect(bus, 0)
	check(observed == 8 and stage.dap_count == 8 and seen.size() == 8, "All eight requested sound/comment combinations work without a cooldown")
	await pause(1.1)
	stage.dap_button.pressed.emit()
	await pause(1.1)
	check(stage.dap_busy and dap.active and stage.dap_line.visible, "An old deadline cannot clear a newer dap")
	await pause(1.0)
	check(not dap.active and not stage.dap_busy and not stage.dap_line.visible and not dap.player.playing and dap.feedback_timer.is_stopped(), "Feedback clears two seconds after the latest press")
	# Warm the engine before comparing resource use and measuring a much faster
	# input rate than a human can produce. Do not allocate a timer per press.
	for i in range(100):
		stage.dap_button.pressed.emit()
	dap.stop()
	await pause(0.1)
	var nodes_before := get_node_count()
	var objects_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var memory_before := OS.get_static_memory_usage()
	var count_before: int = stage.dap_count
	var batch_times: Array[float] = []
	seed(556677)
	var expected_global := randi()
	seed(556677)
	buckets = [0, 0, 0, 0]
	dap.rng.seed = 20261116
	for batch in range(100):
		var began := Time.get_ticks_usec()
		for i in range(100):
			stage.dap_button.pressed.emit()
		batch_times.append((Time.get_ticks_usec() - began) / 1000.0)
		await process_frame
	var global_unchanged := randi() == expected_global
	var live_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	check(stage.dap_count == count_before + 10000 and pairings_valid, "10,000 rapid presses all register with valid sound/comment pairings")
	check(get_node_count() == nodes_before and live_objects <= objects_before + 8, "Rapid presses do not accumulate nodes, timers or pending objects")
	check(global_unchanged, "Dap draws do not consume the shared global RNG")
	var odds_ok := true
	var weights := [0.20, 0.35, 0.35, 0.10]
	for i in range(4):
		odds_ok = odds_ok and absf(buckets[i] / 10000.0 - weights[i]) < 0.02
	check(odds_ok, "10,000 seeded draws follow 20/35/35/10 odds within two percentage points")
	dap.stop()
	await pause(0.1)
	var memory_after := OS.get_static_memory_usage()
	batch_times.sort()
	print("DAP_STRESS presses=10000 batches=100 nodes_before=", nodes_before, " nodes_after=", get_node_count(), " objects_before=", objects_before, " objects_during=", live_objects, " objects_after=", Performance.get_monitor(Performance.OBJECT_COUNT), " retained_bytes=", memory_after - memory_before, " p95_ms_per_100_presses=", batch_times[94], " counts=", buckets)
	check(memory_after - memory_before < 524288, "Spam leaves less than 512 KiB of additional retained memory after warmup")
	check(batch_times[94] < 16.67, "At least 95% of 100-press batches fit within one 60 Hz frame")
	stage.dap_button.pressed.emit()
	stage.ui.hide()
	check(not dap.active and not stage.dap_busy and not dap.player.playing and dap.feedback_timer.is_stopped(), "Hiding the table stops all dap feedback")
	count_before = stage.dap_count
	stage.dap_button.pressed.emit()
	check(stage.dap_count == count_before, "Hidden table ignores direct hand signals")
	stage.ui.show()
	stage.overhead = true
	stage.dap_button.pressed.emit()
	check(stage.dap_count == count_before, "Overhead board view cannot trigger a hidden hand")
	stage.overhead = false
	stage.changing_view = true
	stage.dap_button.pressed.emit()
	check(stage.dap_count == count_before, "A table transition blocks dap input")
	stage.changing_view = false
	stage.dap_button.pressed.emit()
	stage.choices.get_node("YesButRed").pressed.emit()
	check(not dap.active and not stage.dap_line.visible, "The affirmative joke path cancels dap before its dialogue delay")
	await pause(2.4)
	check(is_instance_valid(stage.activity) and stage.activity.choosing_colour and not dap.active, "Chess still opens its fists with dap stopped")
	var fist_state: int = stage.activity.fist_choice.rng.state
	var book_state: int = stage.activity.bot.rng.state
	for i in range(100):
		dap.trigger()
	check(stage.activity.fist_choice.rng.state == fist_state and stage.activity.bot.rng.state == book_state, "Dap RNG is independent of fist assignment and chess openings")
	dap.stop()
	stage.activity.leave_match()
	stage.dap_button.pressed.emit()
	check(dap.active and stage.dap_busy and stage.dap_line.visible, "Returning from chess restores immediate dap input")
	main.queue_free()
	await process_frame
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	await process_frame
	print("DAP: ", checks - failures, "/", checks, " checks passed")
	quit(1 if failures else 0)
