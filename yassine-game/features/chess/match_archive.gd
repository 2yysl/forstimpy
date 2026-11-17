extends RefCounted
## Session-owned records, never retained gameplay scenes.
signal changed
var records: Array = []

func add(record) -> void:
	if not record.is_finished() or records.has(record):
		return
	records.push_front(record)
	changed.emit()
