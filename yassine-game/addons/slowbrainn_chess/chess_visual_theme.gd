extends Resource
@export var light_square := Color("#e8e1b4")
@export var dark_square := Color("#709391")
@export var highlight := Color("#f0c65b")
@export var legal_destination := Color("#254d43b0")
@export var panel_color := Color("#fff2cc")
@export var ink_color := Color("#243333")
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
