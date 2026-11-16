extends Control
signal reading_changed(reading: bool)
signal hover_sound_started
const ReaderScene = preload("res://features/letter/NoteReader.tscn")
@export var closed_texture: Texture2D = preload("res://features/letter/assets/envelope_closed.svg")
@export var open_texture: Texture2D = preload("res://features/letter/assets/envelope_open.svg")
@export var paper_sound: AudioStream = preload("res://assets/sfx/paper crumple.wav")
@export_range(-40, 6, 0.5) var paper_volume_db := -6.0
@export_file("*.txt") var note_path := "res://features/letter/content/birthday_note.txt"
var enabled := false
var opened := false
var reading := false
var suppress_hover_audio := false
var reader

func _ready() -> void:
	reader = ReaderScene.instantiate()
	add_child(reader)
	reader.note_closed.connect(_reader_closed)
	$EnvelopeHover.mouse_entered.connect(_hover_entered)
	$EnvelopeHover.mouse_exited.connect(_reconcile_hover.call_deferred)
	$Note.mouse_entered.connect(_hover_entered)
	$Note.mouse_exited.connect(_reconcile_hover.call_deferred)
	$Note.pressed.connect(read_note)
	$Note.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	$Note.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	$Note.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("#709391")
	focus.set_border_width_all(2)
	$Note.add_theme_stylebox_override("focus", focus)
	$Caption.add_theme_font_override("font", preload("res://ttf/JetBrainsMono-Regular.ttf"))
	$Caption.add_theme_font_size_override("font_size", 17)
	$Caption.add_theme_color_override("font_color", Color("#243333"))
	$Artwork.texture = closed_texture
	visibility_changed.connect(_visibility_changed)
	set_enabled(false)

func set_enabled(value: bool) -> void:
	enabled = value
	$EnvelopeHover.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	$Note.disabled = not value
	if not value:
		reader.close_note()
		_set_open(false, false)
	else:
		_reconcile_hover.call_deferred()

func _hover_entered() -> void:
	if enabled and is_visible_in_tree() and not reading:
		_set_open(true)

func _pointer_over_letter() -> bool:
	if not enabled or not is_visible_in_tree():
		return false
	var pointer := get_global_mouse_position()
	return $EnvelopeHover.get_global_rect().has_point(pointer) or ($Note.visible and $Note.get_global_rect().has_point(pointer))

func _reconcile_hover() -> void:
	if not reading:
		_set_open(_pointer_over_letter(), not suppress_hover_audio)

func _set_open(value: bool, with_sound := true) -> void:
	if value == opened:
		return
	opened = value
	$Artwork.texture = open_texture if value else closed_texture
	$Note.visible = value
	if value and with_sound and not suppress_hover_audio and paper_sound != null:
		$PaperSound.stream = paper_sound
		$PaperSound.volume_db = paper_volume_db
		$PaperSound.play(0.0)
		hover_sound_started.emit()

func read_note() -> void:
	if not enabled or not opened or reading or not is_visible_in_tree():
		return
	if reader.open_note(note_path):
		reading = true
		reading_changed.emit(true)

func _reader_closed() -> void:
	reading = false
	suppress_hover_audio = true
	_set_open(_pointer_over_letter(), false)
	reading_changed.emit(false)
	_finish_return.call_deferred()

func _finish_return() -> void:
	_set_open(_pointer_over_letter(), false)
	suppress_hover_audio = false

func _visibility_changed() -> void:
	if not is_visible_in_tree():
		reader.close_note()
		_set_open(false, false)
