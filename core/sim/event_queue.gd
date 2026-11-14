class_name EventQueue
extends RefCounted

## Deterministic priority queue of scheduled entries (ADR-0003). Entries are
## ordered by (tick, sequence number): equal ticks pop in insertion order,
## which is stable because the sequence counter is monotonic and serialized.
## Entries are plain dictionaries: {"tick", "seq", "kind", "data"} where data
## holds ints and strings only.

var _next_seq: int = 0
var _entries: Array[Dictionary] = []


## Schedule an entry to run at run_tick. Returns its sequence number.
func push(run_tick: int, kind: String, data: Dictionary = {}) -> int:
	var seq := _next_seq
	_next_seq += 1
	var entry := {"tick": run_tick, "seq": seq, "kind": kind, "data": data.duplicate(true)}
	# Keep the array sorted by (tick, seq); entries are usually pushed with
	# growing ticks, so a backward scan is cheap for the expected sizes.
	var i := _entries.size()
	while i > 0 and _entry_before(entry, _entries[i - 1]):
		i -= 1
	_entries.insert(i, entry)
	return seq


## Remove and return all entries with tick <= due_tick, in (tick, seq) order.
func pop_due(due_tick: int) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	while not _entries.is_empty() and _entries[0]["tick"] <= due_tick:
		due.append(_entries.pop_front())
	return due


func size() -> int:
	return _entries.size()


func is_empty() -> bool:
	return _entries.is_empty()


func to_dict() -> Dictionary:
	return {"next_seq": _next_seq, "entries": _entries.duplicate(true)}


## Restore a queue written by to_dict(). Returns false if invalid.
func load_dict(d: Dictionary) -> bool:
	if not d.has_all(["next_seq", "entries"]):
		return false
	var restored: Array[Dictionary] = []
	var raw_entries: Array = d["entries"]
	for e in raw_entries:
		var entry: Dictionary = e
		if not entry.has_all(["tick", "seq", "kind", "data"]):
			return false
		restored.append({
			"tick": int(entry["tick"]),
			"seq": int(entry["seq"]),
			"kind": String(entry["kind"]),
			"data": entry["data"].duplicate(true),
		})
	_entries = restored
	_next_seq = int(d["next_seq"])
	return true


## Build a queue from a dictionary produced by to_dict().
static func from_dict(d: Dictionary) -> EventQueue:
	var q := EventQueue.new()
	q.load_dict(d)
	return q


# True when entry a must pop before entry b: strictly smaller tick, or equal
# tick with smaller sequence number.
static func _entry_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["tick"]) != int(b["tick"]):
		return int(a["tick"]) < int(b["tick"])
	return int(a["seq"]) < int(b["seq"])
