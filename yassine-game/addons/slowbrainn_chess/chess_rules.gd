extends RefCounted
## Board indices: a8 = 0, h1 = 63. Positive pieces are White.
const PAWN = 1
const KNIGHT = 2
const BISHOP = 3
const ROOK = 4
const QUEEN = 5
const KING = 6
const VALUES = [0, 100, 320, 330, 500, 900, 20000]
const KNIGHT_STEPS = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)]
const ORTHOGONAL = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const RAYS = ORTHOGONAL + DIAGONAL
const ROOK_RIGHTS = {0: "q", 7: "k", 56: "Q", 63: "K"}
var board: Array[int] = []
var turn: int = 1
var castling: String = "KQkq"
var ep: int = -1
var halfmove: int = 0
var fullmove: int = 1
var repetitions: Dictionary = {}

func _init(start := true) -> void:
	if start:
		load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

static func square(name: String) -> int:
	return (8 - int(name[1])) * 8 + "abcdefgh".find(name[0])

static func square_name(index: int) -> String:
	return "abcdefgh"[index % 8] + str(8 - index / 8)

static func uci(move: Dictionary) -> String:
	var suffix := ""
	if move.get("promotion", 0) != 0:
		suffix = {2: "n", 3: "b", 4: "r", 5: "q"}[move.promotion]
	return square_name(move.from) + square_name(move.to) + suffix

func load_fen(fen: String) -> void:
	var fields := fen.split(" ")
	board.clear()
	for c in fields[0]:
		if c == "/":
			continue
		if c.is_valid_int():
			for _i in int(c):
				board.append(0)
		else:
			var kind := " pnbrqk".find(c.to_lower())
			board.append(kind * (1 if c == c.to_upper() else -1))
	turn = 1 if fields[1] == "w" else -1
	castling = "" if fields[2] == "-" else fields[2]
	ep = -1 if fields[3] == "-" else square(fields[3])
	halfmove = int(fields[4]) if fields.size() > 4 else 0
	fullmove = int(fields[5]) if fields.size() > 5 else 1
	repetitions = {position_key(): 1}

func copy_position():
	var copy = get_script().new(false)
	copy.board = board.duplicate()
	copy.turn = turn
	copy.castling = castling
	copy.ep = ep
	copy.halfmove = halfmove
	copy.fullmove = fullmove
	# Search copies do not need game history.
	copy.repetitions = {}
	return copy

func attacked(target: int, by: int) -> bool:
	# Scan outward from the king/target, stopping each ray at its first piece.
	var tx: int = target % 8
	var ty: int = target / 8
	var pawn_y := ty + by
	if pawn_y >= 0 and pawn_y < 8:
		for dx in [-1, 1]:
			var px: int = tx + dx
			if px >= 0 and px < 8 and board[pawn_y * 8 + px] == by * PAWN:
				return true
	for step: Vector2i in KNIGHT_STEPS:
		var x := tx + step.x
		var y := ty + step.y
		if x >= 0 and x < 8 and y >= 0 and y < 8 and board[y * 8 + x] == by * KNIGHT:
			return true
	for step: Vector2i in RAYS:
		var x := tx + step.x
		var y := ty + step.y
		var distance := 1
		while x >= 0 and x < 8 and y >= 0 and y < 8:
			var piece := board[y * 8 + x]
			if piece != 0:
				if piece * by > 0:
					var kind := absi(piece)
					if kind == QUEEN or (kind == KING and distance == 1):
						return true
					if kind == (ROOK if step.x == 0 or step.y == 0 else BISHOP):
						return true
				break
			x += step.x
			y += step.y
			distance += 1
	return false

func in_check(color: int) -> bool:
	var king := board.find(KING * color)
	return king == -1 or attacked(king, -color)

func _add_move(moves: Array, origin: int, target: int) -> void:
	if absi(board[target]) == KING:
		return
	if absi(board[origin]) == PAWN and (target < 8 or target >= 56):
		for promotion in [QUEEN, ROOK, BISHOP, KNIGHT]:
			moves.append({"from": origin, "to": target, "promotion": promotion})
	else:
		moves.append({"from": origin, "to": target, "promotion": 0})

func _pseudo_moves() -> Array:
	var moves: Array = []
	for i in 64:
		if board[i] * turn <= 0:
			continue
		var x: int = i % 8
		var y: int = i / 8
		var kind := absi(board[i])
		if kind == PAWN:
			var next := i - turn * 8
			if next >= 0 and next < 64 and board[next] == 0:
				_add_move(moves, i, next)
				if y == (6 if turn == 1 else 1) and board[i - turn * 16] == 0:
					_add_move(moves, i, i - turn * 16)
			for dx in [-1, 1]:
				var to: int = next + dx
				if x + dx < 0 or x + dx > 7 or to < 0 or to >= 64:
					continue
				if board[to] * turn < 0 or (to == ep and board[to] == 0 and board[to + turn * 8] == -turn * PAWN):
					_add_move(moves, i, to)
			continue
		var directions: Array = KNIGHT_STEPS if kind == KNIGHT else (DIAGONAL if kind == BISHOP else (ORTHOGONAL if kind == ROOK else RAYS))
		for direction: Vector2i in directions:
			var point := Vector2i(x, y) + direction
			while point.x >= 0 and point.x < 8 and point.y >= 0 and point.y < 8:
				var to := point.y * 8 + point.x
				if board[to] * turn > 0:
					break
				_add_move(moves, i, to)
				if board[to] != 0 or kind == KING or kind == KNIGHT:
					break
				point += direction
		if kind == KING:
			var home := 60 if turn == 1 else 4
			if i != home or in_check(turn):
				continue
			for kingside in [true, false]:
				var right := ("K" if kingside else "Q") if turn == 1 else ("k" if kingside else "q")
				var rook_square := home + (3 if kingside else -4)
				var step := 1 if kingside else -1
				if right not in castling or board[rook_square] != turn * ROOK:
					continue
				var clear := true
				for distance in range(1, 3 if kingside else 4):
					if board[home + step * distance] != 0:
						clear = false
				if clear and not attacked(home + step, -turn) and not attacked(home + step * 2, -turn):
					_add_move(moves, i, home + step * 2)
	return moves

func legal_moves() -> Array:
	var moves: Array = []
	for move in _pseudo_moves():
		if _keeps_king_safe(move):
			moves.append(move)
	return moves

func has_legal_move() -> bool:
	# Most search leaves have a legal pawn push. Try one directly before
	# allocating the entire pseudo-move list; use the full path if it fails.
	for origin in 64:
		if board[origin] != turn * PAWN:
			continue
		var target := origin - turn * 8
		if target >= 0 and target < 64 and board[target] == 0:
			if _keeps_king_safe({"from": origin, "to": target, "promotion": QUEEN if target < 8 or target >= 56 else 0}):
				return true
			break
	for move in _pseudo_moves():
		if _keeps_king_safe(move):
			return true
	return false

func _keeps_king_safe(move: Dictionary) -> bool:
	# Synchronous make/unmake: legality only needs changed board squares,
	# not a new rules object, clocks, castling strings or history per candidate.
	var origin: int = move.from
	var target: int = move.to
	var piece := board[origin]
	var captured := board[target]
	var ep_square := -1
	var rook_from := -1
	var rook_to := -1
	if absi(piece) == PAWN and target == ep and captured == 0:
		ep_square = target + turn * 8
		board[ep_square] = 0
	if absi(piece) == KING and absi(target - origin) == 2:
		rook_from = origin + (3 if target > origin else -4)
		rook_to = origin + (1 if target > origin else -1)
		board[rook_to] = board[rook_from]
		board[rook_from] = 0
	board[target] = piece if move.promotion == 0 else turn * int(move.promotion)
	board[origin] = 0
	var safe := not in_check(turn)
	board[origin] = piece
	board[target] = captured
	if ep_square >= 0:
		board[ep_square] = -turn * PAWN
	if rook_from >= 0:
		board[rook_from] = board[rook_to]
		board[rook_to] = 0
	return safe

func _apply(move: Dictionary) -> void:
	var origin: int = move.from
	var target: int = move.to
	var piece := board[origin]
	var capture := board[target] != 0
	if absi(piece) == PAWN and target == ep and board[target] == 0:
		board[target + turn * 8] = 0
		capture = true
	board[target] = piece if move.get("promotion", 0) == 0 else turn * int(move.promotion)
	board[origin] = 0
	if absi(piece) == KING:
		for right in (["K", "Q"] if turn == 1 else ["k", "q"]):
			castling = castling.replace(right, "")
		if absi(target - origin) == 2:
			var rook_from := origin + (3 if target > origin else -4)
			var rook_to := origin + (1 if target > origin else -1)
			board[rook_to] = board[rook_from]
			board[rook_from] = 0
	for rook_square in ROOK_RIGHTS:
		if origin == rook_square or target == rook_square:
			castling = castling.replace(ROOK_RIGHTS[rook_square], "")
	ep = (origin + target) / 2 if absi(piece) == PAWN and absi(target - origin) == 16 else -1
	halfmove = 0 if absi(piece) == PAWN or capture else halfmove + 1
	if turn == -1:
		fullmove += 1
	turn = -turn

func play(move: Dictionary) -> bool:
	# Public entry point validates even bot and UI requests.
	for legal in legal_moves():
		if uci(legal) == uci(move):
			_apply(legal)
			var key := position_key()
			repetitions[key] = repetitions.get(key, 0) + 1
			return true
	return false

func play_uci(text: String) -> bool:
	for move in legal_moves():
		if uci(move) == text:
			return play(move)
	return false

func position_key() -> String:
	# An unusable en passant target does not distinguish repetition positions.
	var effective_ep := -1
	if ep >= 0:
		for move in _pseudo_moves():
			if move.to == ep and absi(board[move.from]) == PAWN:
				var next = copy_position()
				next._apply(move)
				if not next.in_check(turn):
					effective_ep = ep
	return str(board) + str(turn) + castling + str(effective_ep)

func insufficient_material() -> bool:
	var minors: Array[int] = []
	var bishop_colors: Array[int] = []
	for i in 64:
		match absi(board[i]):
			PAWN, ROOK, QUEEN:
				return false
			KNIGHT:
				minors.append(KNIGHT)
			BISHOP:
				minors.append(BISHOP)
				bishop_colors.append((i % 8 + i / 8) % 2)
	if minors.size() <= 1:
		return true
	if KNIGHT not in minors:
		return bishop_colors.all(func(color): return color == bishop_colors[0])
	return false

func can_claim_draw() -> bool:
	return halfmove >= 100 or repetitions.get(position_key(), 0) >= 3

func outcome(moves: Array) -> String:
	# Mate takes precedence over the automatic move-count draw.
	if moves.is_empty():
		return ("Black wins by checkmate" if turn == 1 else "White wins by checkmate") if in_check(turn) else "Draw by stalemate"
	if insufficient_material():
		return "Draw by insufficient material"
	if halfmove >= 150:
		return "Draw by 75-move rule"
	if repetitions.get(position_key(), 0) >= 5:
		return "Draw by fivefold repetition"
	return ""
