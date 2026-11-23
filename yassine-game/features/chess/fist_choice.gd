extends Control
signal colour_chosen(colour: int)
# Visible bounds of the source PNGs in the same order as the on-screen paws.
const CLOSED_BOUNDS := [Rect2(147, 0, 212, 340), Rect2(101, 0, 212, 340)]
const OPEN_BOUNDS := [Rect2(15, 0, 370, 467), Rect2(71, 0, 330, 449)]
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
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var hand: NinePatchRect = button.get_node("Hand")
		button.focus_entered.connect(func(): hand.modulate = Color(1.1, 1.1, 1.1))
		button.focus_exited.connect(func(): hand.modulate = Color.WHITE)
	_layout()

func begin_choice() -> void:
	# One shuffle, committed before either hand can be selected.
	left_colour = 1 if rng.randi_range(0, 1) == 0 else -1
	selected_hand = -1
	for button in [$Left, $Right]:
		button.disabled = false
		button.get_node("Hand/Queen").hide()
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
	colour_chosen.emit(colour)

func apply_artwork() -> void:
	$Left/Hand.texture = visual_theme.left_fist_opened if selected_hand == 0 else visual_theme.left_fist_closed
	$Right/Hand.texture = visual_theme.right_fist_opened if selected_hand == 1 else visual_theme.right_fist_closed

	_layout()

func _layout() -> void:
	var gap := 16.0
	var column_width := (size.x - gap) * 0.5
	if column_width <= 0.0 or size.y <= 0.0:
		return
	for side in 2:
		var button: Button = $Left if side == 0 else $Right
		var hand: NinePatchRect = button.get_node("Hand")
		if hand.texture == null:
			continue
		var pixels := hand.texture.get_size()
		var bounds: Rect2 = OPEN_BOUNDS[side] if selected_hand == side else CLOSED_BOUNDS[side]
		var texture_ratio := pixels / Vector2(460, 496)
		bounds = Rect2(bounds.position * texture_ratio, bounds.size * texture_ratio)
		# Stretch the upper forearm while keeping the paw and queen in proportion.
		var factor := minf(column_width * 0.82 / bounds.size.x, size.y / bounds.size.y)
		hand.patch_margin_bottom = roundi(pixels.y * 0.82)
		hand.scale = Vector2.ONE * factor
		hand.size = Vector2(pixels.x, size.y / factor + pixels.y - bounds.end.y)
		hand.position = Vector2(column_width * 0.5 - bounds.get_center().x * factor, 0.0)
		button.position = Vector2(side * (column_width + gap), 0)
		button.size = Vector2(column_width, size.y)
