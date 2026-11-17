extends RefCounted
## Compact committed main line. No AI snapshots or growing repetition tables.
const Rules = preload("res://features/chess/chess_rules.gd")
const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
var start_fen := START_FEN
var moves: Array[Dictionary] = []
var human_color := 1
var opponent := "yyslChess"
var started_at := 0
var finished_at := 0
var result := "*"
var reason := ""
var winner := 0
var initial_white: Array = []
var initial_black: Array = []

func _init(position = null, color := 1, name := "yyslChess") -> void:
	human_color = color
	opponent = name
	started_at = int(Time.get_unix_time_from_system())
	if position != null:
		start_fen = fen(position)

func append(before: Dictionary, move: Dictionary, after) -> void:
	if is_finished():
		return
	if moves.is_empty():
		start_fen = fen(before.position)
		initial_white = before.captured_white.duplicate()
		initial_black = before.captured_black.duplicate()
	var taken := captured_piece(before.position, move)
	moves.append({"move": move.duplicate(), "san": san(before.position, move, after), "captured": taken})

func truncate(ply_count: int) -> void:
	if is_finished():
		return
	moves.resize(clampi(ply_count, 0, moves.size()))

func finish(outcome: String) -> void:
	if is_finished():
		return
	reason = outcome
	winner = 1 if outcome.begins_with("White wins") else (-1 if outcome.begins_with("Black wins") else 0)
	result = "1-0" if winner == 1 else ("0-1" if winner == -1 else "1/2-1/2")
	finished_at = int(Time.get_unix_time_from_system())

func is_finished() -> bool:
	return result != "*"

func replay(ply_count: int) -> Dictionary:
	var position = Rules.new(false)
	position.load_fen(start_fen)
	var white := initial_white.duplicate()
	var black := initial_black.duplicate()
	var count := clampi(ply_count, 0, moves.size())
	for i in count:
		var entry := moves[i]
		if entry.captured != 0:
			(white if position.turn == 1 else black).append(entry.captured)
		# Only validated, committed moves enter this log; replay needs no search.
		position._apply(entry.move)
	return {"position": position, "captured_white": white, "captured_black": black,
		"last_move": moves[count - 1].move if count > 0 else {}}

func summary() -> String:
	var stamp := Time.get_datetime_dict_from_unix_time(finished_at + int(Time.get_time_zone_from_system().bias) * 60)
	var time := "%02d:%02d" % [stamp.hour, stamp.minute]
	var names := "Draw" if winner == 0 else ("You beat " + opponent if winner == human_color else opponent + " beat you")
	var ending := "Checkmate" if "checkmate" in reason else ("Stalemate" if "stalemate" in reason else ("Resignation" if "resigned" in reason else "Draw"))
	return "%s · %s · %s" % [time, names, ending]

func pgn() -> String:
	var stamp := Time.get_datetime_dict_from_unix_time(started_at)
	var headers: Array[String] = [tag("Event", "forstimpy"), tag("Site", "Local"),
		tag("Date", "%04d.%02d.%02d" % [stamp.year, stamp.month, stamp.day]), tag("Round", "-"),
		tag("White", "You" if human_color == 1 else opponent), tag("Black", opponent if human_color == 1 else "You"), tag("Result", result)]
	if start_fen != START_FEN:
		headers.append(tag("SetUp", "1"))
		headers.append(tag("FEN", start_fen))
	var fields := start_fen.split(" ")
	var color := 1 if fields[1] == "w" else -1
	var number := int(fields[5])
	var text: Array[String] = []
	for i in moves.size():
		var prefix := str(number) + ". " if color == 1 else (str(number) + "... " if i == 0 else "")
		text.append(prefix + str(moves[i].san))
		if color == -1:
			number += 1
		color = -color
	text.append(result)
	return "\n".join(headers) + "\n\n" + " ".join(text) + "\n"

static func tag(key: String, value: String) -> String:
	return "[%s \"%s\"]" % [key, value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ").replace("\r", " ")]

static func captured_piece(position, move: Dictionary) -> int:
	if absi(position.board[move.from]) == Rules.PAWN and move.to == position.ep and position.board[move.to] == 0:
		return position.board[move.to + position.turn * 8]
	return position.board[move.to]

static func san(before, move: Dictionary, after) -> String:
	var kind: int = absi(before.board[move.from])
	var text := ""
	if kind == Rules.KING and absi(move.to - move.from) == 2:
		text = "O-O" if move.to > move.from else "O-O-O"
	else:
		var capture := captured_piece(before, move) != 0
		var origin := Rules.square_name(move.from)
		if kind != Rules.PAWN:
			text = " PNBRQK"[kind]
			var alternatives: Array = before.legal_moves().filter(func(other): return other.from != move.from and other.to == move.to and before.board[other.from] == before.board[move.from])
			if not alternatives.is_empty():
				var same_file := alternatives.any(func(other): return other.from % 8 == move.from % 8)
				var same_rank := alternatives.any(func(other): return int(other.from / 8) == int(move.from / 8))
				text += origin[0] if not same_file else (origin[1] if not same_rank else origin)
		elif capture:
			text = origin[0]
		text += ("x" if capture else "") + Rules.square_name(move.to)
		if move.get("promotion", 0) != 0:
			text += "=" + " PNBRQK"[move.promotion]
	if after.in_check(after.turn):
		text += "+" if after.has_legal_move() else "#"
	return text

static func fen(position) -> String:
	var ranks: Array[String] = []
	for row in 8:
		var rank := ""
		var empty := 0
		for col in 8:
			var piece: int = position.board[row * 8 + col]
			if piece == 0:
				empty += 1
				continue
			if empty > 0:
				rank += str(empty)
				empty = 0
			var symbol: String = " pnbrqk"[absi(piece)]
			rank += symbol.to_upper() if piece > 0 else symbol
		if empty > 0:
			rank += str(empty)
		ranks.append(rank)
	return "%s %s %s %s %d %d" % ["/".join(ranks), "w" if position.turn == 1 else "b",
		position.castling if not position.castling.is_empty() else "-", Rules.square_name(position.ep) if position.ep >= 0 else "-", position.halfmove, position.fullmove]
