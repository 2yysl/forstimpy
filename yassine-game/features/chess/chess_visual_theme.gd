extends Resource
@export var light_square := Color("#e8e1b4")
@export var dark_square := Color("#709391")
@export var highlight := Color("#f0c65b")
@export var legal_destination := Color("#254d43b0")
@export var panel_color := Color("#fffaf0")
@export var ink_color := Color("#243333")
@export_group("Scene artwork")
@export var top_strip: Texture2D
@export var time_music: Texture2D
@export var portrait_idle: Texture2D
@export var portrait_thinking: Texture2D
@export var memories: Texture2D
@export var dialogue_bubble: Texture2D
@export var board_frame: Texture2D
@export var sealed_envelope: Texture2D
@export var back_arrow: Texture2D
@export_group("Fist choice artwork")
@export var left_fist_closed: Texture2D
@export var right_fist_closed: Texture2D
@export var left_fist_opened: Texture2D
@export var right_fist_opened: Texture2D
@export_group("Typography")
@export var interface_font: Font = preload("res://ttf/JetBrainsMono-Regular.ttf")
@export_group("Chess pieces")
@export var white_pawn: Texture2D
@export var white_knight: Texture2D
@export var white_bishop: Texture2D
@export var white_rook: Texture2D
@export var white_queen: Texture2D
@export var white_king: Texture2D
@export var black_pawn: Texture2D
@export var black_knight: Texture2D
@export var black_bishop: Texture2D
@export var black_rook: Texture2D
@export var black_queen: Texture2D
@export var black_king: Texture2D

func piece_texture(piece: int) -> Texture2D:
	var names := ["", "pawn", "knight", "bishop", "rook", "queen", "king"]
	return get(("white_" if piece > 0 else "black_") + names[absi(piece)])
