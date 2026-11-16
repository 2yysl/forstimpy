extends Node
## One weighted draw per press. Audio and feedback always belong to the latest dap.
signal triggered(outcome: int, comment: String)
signal feedback_finished

const THRESHOLDS := [20, 55, 90, 100]
const COMMENTS := [
	["we suck", "look at the elbow"],
	["we could do better", "shibal"],
	["we could do better", "shibal"],
	["we are goated", "nice"],
]

@export var bad_sound: AudioStream = preload("res://assets/sfx/dapbad.wav")
@export var mid_sound: AudioStream = preload("res://assets/sfx/dapmid.wav")
@export var mid2_sound: AudioStream = preload("res://assets/sfx/dapmid2.wav")
@export var goat_sound: AudioStream = preload("res://assets/sfx/dapgoat.wav")
@export_range(-40, 6, 0.5) var volume_db := -6.0

var rng := RandomNumberGenerator.new()
var active := false
var pending_sound: AudioStream
var play_queued := false
@onready var player: AudioStreamPlayer = $Sound
@onready var feedback_timer: Timer = $FeedbackTimer

func _ready() -> void:
	rng.randomize()
	feedback_timer.timeout.connect(stop)

func trigger() -> void:
	var roll := rng.randi_range(0, 99)
	var outcome := 0
	while roll >= THRESHOLDS[outcome]:
		outcome += 1
	var comment: String = COMMENTS[outcome][rng.randi_range(0, 1)]
	active = true
	pending_sound = _sound_for(outcome)
	# Many presses can arrive before the next audio/render update. Choose every
	# outcome immediately, but start only the latest sound once in that frame.
	if not play_queued:
		play_queued = true
		_play_latest.call_deferred()
	feedback_timer.start()
	triggered.emit(outcome, comment)

func _play_latest() -> void:
	play_queued = false
	if not active:
		return
	# Stop before replacing the stream, including when the same outcome repeats.
	player.stop()
	player.stream = pending_sound
	player.volume_db = volume_db
	if player.stream != null:
		player.play(0.0)

func stop() -> void:
	player.stop()
	feedback_timer.stop()
	pending_sound = null
	if active:
		active = false
		feedback_finished.emit()

func _sound_for(outcome: int) -> AudioStream:
	match outcome:
		0: return bad_sound
		1: return mid_sound
		2: return mid2_sound
		_: return goat_sound
