extends RefCounted
## Immutable before-move snapshots. Reviews never assign these to live play.
const MAX_SNAPSHOTS := 3
var entries: Array[Dictionary] = []
var latest_human_id := 0
var challenged_human_id := 0

func clear() -> void:
	entries.clear()
	latest_human_id = 0
	challenged_human_id = 0

func capture(game, rng_state: int, last_move: Dictionary) -> Dictionary:
	var position = game.copy_position()
	position.repetitions = game.repetitions.duplicate()
	return {"position": position, "rng_state": rng_state, "last_move": last_move.duplicate()}

func record(before: Dictionary, move: Dictionary, human_color: int) -> bool:
	var human_id := 0
	if before.position.turn == human_color:
		latest_human_id += 1
		human_id = latest_human_id
	entries.append({"before": before, "move": move.duplicate(), "human_id": human_id})
	# Latest user turn + reply + one preceding move for the read-only preview.
	if entries.size() > MAX_SNAPSHOTS:
		entries.pop_front()
		return true
	return false

func challenge_index() -> int:
	if latest_human_id == 0 or challenged_human_id == latest_human_id:
		return -1
	for i in range(entries.size() - 1, -1, -1):
		if entries[i].human_id > 0:
			# A won takeback cannot be chained into older turns without a new move.
			return i if entries[i].human_id == latest_human_id else -1
	return -1

func consume_challenge(index: int) -> bool:
	if index < 0 or index != challenge_index():
		return false
	challenged_human_id = latest_human_id
	return true

func restore(index: int) -> Dictionary:
	if index < 0 or index >= entries.size() or entries[index].human_id <= 0 or entries[index].human_id != latest_human_id:
		return {}
	var before: Dictionary = entries[index].before
	var restored := capture(before.position, before.rng_state, before.last_move)
	entries.resize(index)
	return restored
