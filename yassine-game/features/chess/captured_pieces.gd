extends Control
## A fixed-size placeholder tray. Reuses piece theme textures; no per-piece nodes.
var pieces: Array[int] = []
var visual_theme: Resource
var caption := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func display(values: Array, artwork: Resource, title: String) -> void:
	pieces.assign(values)
	visual_theme = artwork
	caption = title
	queue_redraw()

func _draw() -> void:
	if visual_theme == null:
		return
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, visual_theme.light_square.lightened(0.65))
	draw_rect(bounds, visual_theme.ink_color * Color(1, 1, 1, 0.25), false, 1.0)
	draw_string(get_theme_default_font(), Vector2(8, 14), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 11, visual_theme.ink_color)
	var columns := 15 if size.x >= 300 else maxi(1, int((size.x - 16) / 26))
	var rows := maxi(1, ceili(pieces.size() / float(columns)))
	var cell_width := (size.x - 16) / columns
	var edge := maxf(1, minf(28, minf(cell_width, (size.y - 24) / rows)))
	for i in pieces.size():
		var texture: Texture2D = visual_theme.piece_texture(pieces[i])
		if texture == null:
			continue
		var extent := texture.get_size() * minf(edge / texture.get_width(), edge / texture.get_height())
		var center := Vector2(8 + (i % columns + 0.5) * cell_width, 22 + (int(i / columns) + 0.5) * edge)
		draw_texture_rect(texture, Rect2(center - extent * 0.5, extent), false)
