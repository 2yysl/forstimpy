extends Control
signal colour_chosen(colour: int)
@export var visual_theme: Resource = preload("res://features/chess/chess_visual_theme.tres")
var rng := RandomNumberGenerator.new()
var left_colour := 1
var selected_hand := -1

func _ready() -> void:
	rng.randomize()
	$Left.pressed.connect(choose.bind(0))
	$Right.pressed.connect(choose.bind(1))
	resized.connect(_layout)
	for button in [$Left, $Right]:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = visual_theme.highlight
		focus.set_border_width_all(3)
		focus.set_corner_radius_all(12)
		button.add_theme_stylebox_override("focus", focus)
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", focus)
		button.add_theme_stylebox_override("pressed", focus)
		button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		button.get_node("Caption").add_theme_color_override("font_color", visual_theme.ink_color)
		button.get_node("Caption").add_theme_font_size_override("font_size", 14)
	_layout()

func begin_choice() -> void:
	# One shuffle, committed before either hand can be selected.
	left_colour = 1 if rng.randi_range(0, 1) == 0 else -1
	selected_hand = -1
	for button in [$Left, $Right]:
		button.disabled = false
		button.get_node("Hand/Queen").hide()
	$Left/Caption.text = "left fist"
	$Right/Caption.text = "right fist"
	apply_artwork()
	show()

func choose(hand: int) -> void:
	if selected_hand >= 0 or not is_visible_in_tree() or hand < 0 or hand > 1:
		return
	selected_hand = hand
	var colour := left_colour if hand == 0 else -left_colour
	var button: Button = $Left if hand == 0 else $Right
	$Left.disabled = true
	$Right.disabled = true
	apply_artwork()
	button.get_node("Hand/Queen").texture = visual_theme.piece_texture(colour * 5)
	button.get_node("Hand/Queen").show()
	button.get_node("Caption").text = "You: " + ("White" if colour == 1 else "Black")
	colour_chosen.emit(colour)

func apply_artwork() -> void:
	$Left/Hand.texture = visual_theme.left_fist_opened if selected_hand == 0 else visual_theme.left_fist_closed
	$Right/Hand.texture = visual_theme.right_fist_opened if selected_hand == 1 else visual_theme.right_fist_closed

func _layout() -> void:
	var extent := maxf(48, minf((size.x - 16) * 0.5, minf(220, size.y - 38)))
	var origin := Vector2((size.x - extent * 2 - 16) * 0.5, (size.y - extent - 38) * 0.5)
	for hand in 2:
		var button: Button = $Left if hand == 0 else $Right
		button.position = origin + Vector2(hand * (extent + 16), 0)
		button.size = Vector2(extent, extent + 38)
		button.get_node("Hand").size = Vector2.ONE * extent
		button.get_node("Caption").position = Vector2(0, extent + 6)
		button.get_node("Caption").size = Vector2(extent, 28)
