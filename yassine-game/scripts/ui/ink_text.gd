@tool
extends Control
## Draw a fully shaped line using visible glyph bounds, without font padding.
@export var text := "hello yassine"
@export var font: Font
var font_size := 32
var ink_color := Color.WHITE
var _line: TextLine
var _ink := Rect2()


func configure(metrics: Dictionary, requested_size: int, color: Color) -> void:
	_line = metrics.line
	_ink = metrics.ink
	font_size = requested_size
	ink_color = color
	size = _ink.size
	queue_redraw()


func _draw() -> void:
	if _line != null:
		_line.draw(get_canvas_item(),
			Vector2(-_ink.position.x, -_ink.position.y - _line.get_line_ascent()), ink_color)
