class_name SaveManager
extends RefCounted

## Save/Load v1 (ADR-0007). A save is one JSON document:
##   {
##     "format_version": 1,          # this class writes FORMAT_VERSION
##     "generator_version": 1,       # placeholder until generation lands (ADR-0008)
##     "mods": [],                   # active mod list, [{id: String, version: String}]
##     "chunks": {
##       "core": {"sim_state": {..SimState.to_dict()..}}   # global chunk
##     }
##   }
## Future sector chunks add their own keys under "chunks"; a new format version
## must come with a migration (hard rule 10, ADR-0007).
##
## JSON numbers are parsed as double by Godot, so int64 values beyond 2^53
## (e.g. generator seeds, generator state) would lose precision as numbers.
## Save v1 therefore encodes any int64 with |value| > _SAFE_INT_LIMIT as a
## decimal string, and known sim-state fields decode strings back to int.
## Values inside event data keep their stored type (limitation, documented).
##
## Reads/writes files with FileAccess/JSON only; no scene types, no timing calls.

const FORMAT_VERSION: int = 1
const GENERATOR_VERSION: int = 1
# Beyond this magnitude an int64 does not round-trip through double exactly.
const _SAFE_INT_LIMIT: int = 9007199254740992 # 2^53


## Build a save document (current format version) from a simulation state.
## mods: array of {"id": String, "version": String}.
static func build_document(state: SimState, mods: Array = []) -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"generator_version": GENERATOR_VERSION,
		"mods": mods.duplicate(true),
		"chunks": {"core": {"sim_state": _encode_int64s(state.to_dict())}},
	}


## Structural/typical errors of a save document (empty array = valid shape).
static func document_errors(doc: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not doc.has("format_version"):
		errors.append("save: missing format_version")
	if not doc.has("generator_version"):
		errors.append("save: missing generator_version")
	if not doc.has("mods") or not (doc["mods"] is Array):
		errors.append("save: 'mods' must be an array")
		return errors
	for mod_entry in doc["mods"]:
		var m: Variant = mod_entry
		if not (m is Dictionary) or not (m as Dictionary).has_all(["id", "version"]) \
				or not ((m as Dictionary)["id"] is String) or not ((m as Dictionary)["version"] is String):
			errors.append("save: mods entries must be objects with string 'id' and 'version'")
			break
	if not doc.has("chunks") or not (doc["chunks"] is Dictionary):
		errors.append("save: 'chunks' must be an object")
		return errors
	var chunks: Dictionary = doc["chunks"]
	for key in chunks:
		if not (chunks[key] is Dictionary):
			errors.append("save: chunk '%s' must be an object" % key)
	if not chunks.has("core"):
		errors.append("save: chunks must contain a 'core' chunk")
	if chunks.has("core"):
		var core: Variant = chunks["core"]
		if not (core is Dictionary) or not (core as Dictionary).has("sim_state") \
				or not ((core as Dictionary)["sim_state"] is Dictionary):
			errors.append("save: chunk 'core' must contain a 'sim_state' object")
	return errors


## Parse a save document into a simulation state: version check, migration
## chain, strict field decoding. Returns null and fills errors on failure.
static func state_from_document(doc: Dictionary, errors: Array[String]) -> SimState:
	document_errors(doc) # shape errors surface through the same list
	var version := _read_int(doc.get("format_version"), errors, "format_version")
	if version > FORMAT_VERSION:
		errors.append("save: document is from a newer version (%d > %d)" % [version, FORMAT_VERSION])
		return null
	while version < FORMAT_VERSION:
		version = _apply_migration(doc, version, errors)
		if version < 0:
			return null
	var sim_doc := _normalized_sim_state(doc, errors)
	if not errors.is_empty() or sim_doc.is_empty():
		return null
	var state := SimState.new(0)
	if not state.load_dict(sim_doc):
		errors.append("save: sim_state does not match the expected fields")
		return null
	return state


## Read a save file from disk; returns {} and appends an error on failure.
static func read_save_file(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("save: file not found: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("save: file is empty: %s" % path)
		return {}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		errors.append("save: invalid JSON in %s" % path)
		return {}
	var parsed: Variant = parser.get_data()
	if not (parsed is Dictionary):
		errors.append("save: %s: top level must be an object" % path)
		return {}
	return parsed


## Write a save document as pretty JSON; returns false and appends an error
## when the file cannot be created or replaced.
static func write_save_file(path: String, doc: Dictionary, errors: Array[String]) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		errors.append("save: cannot write %s (code %d)" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	return true


## Apply the migration registered for document version `from_version` by
## bumping it in place. Returns the new version, or -1 when no migration
## exists (a missing link must never load silently).
static func _apply_migration(doc: Dictionary, from_version: int, errors: Array[String]) -> int:
	errors.append("save: no migration for format version %d" % from_version)
	return -1


# --- decoding internals ----------------------------------------------------

# Restore the sim_state sub-document to the exact shape SimState.load_dict
# expects: known int fields accept int, integral float (JSON) or decimal
# string (encoded int64); unknown fields and wrong types are errors.
static func _normalized_sim_state(doc: Dictionary, errors: Array[String]) -> Dictionary:
	var chunks: Variant = doc.get("chunks")
	if not (chunks is Dictionary):
		return {}
	var core: Variant = (chunks as Dictionary).get("core")
	if not (core is Dictionary):
		return {}
	var raw: Variant = (core as Dictionary).get("sim_state")
	if not (raw is Dictionary):
		return {}
	var sim: Dictionary = raw

	var required := ["tick", "seed", "paused", "speed", "player_id", "rng_state", "event_queue"]
	for key in sim:
		if not required.has(key):
			errors.append("save: unknown sim_state field '%s'" % key)
	for key in required:
		if not sim.has(key):
			errors.append("save: missing sim_state field '%s'" % key)
			return {}

	var rng: Variant = sim["rng_state"]
	if not (rng is Dictionary) or not (rng as Dictionary).has_all(["state", "inc"]):
		errors.append("save: rng_state must be an object with 'state' and 'inc'")
		return {}
	var out_rng := {
		"state": _read_int(rng["state"], errors, "rng_state.state"),
		"inc": _read_int(rng["inc"], errors, "rng_state.inc"),
	}

	var queue: Variant = sim["event_queue"]
	if not (queue is Dictionary) or not (queue as Dictionary).has_all(["next_seq", "entries"]) \
			or not ((queue as Dictionary)["entries"] is Array):
		errors.append("save: event_queue must be an object with 'next_seq' and an 'entries' array")
		return {}
	var qd: Dictionary = queue
	var entries := []
	for e in qd["entries"]:
		var entry: Variant = e
		if not (entry is Dictionary) or not (entry as Dictionary).has_all(["tick", "seq", "kind", "data"]):
			errors.append("save: event_queue entry must be an object with tick/seq/kind/data")
			return {}
		var ed: Dictionary = entry
		var data: Variant = ed["data"]
		if not (data is Dictionary):
			errors.append("save: event_queue entry data must be an object")
			return {}
		var out_data := {}
		for dkey in data:
			var dval: Variant = data[dkey]
			if dval is String:
				out_data[dkey] = dval
			elif dval is int or (dval is float and float(dval) == floorf(float(dval))):
				# int or integral float (JSON); encoded int64 strings stay strings
				# (documented v1 limitation for event data payloads).
				out_data[dkey] = int(dval)
			else:
				errors.append("save: event data '%s' must be an integer or a string" % dkey)
				return {}
		entries.append({
			"tick": _read_int(ed["tick"], errors, "event_queue.entries.tick"),
			"seq": _read_int(ed["seq"], errors, "event_queue.entries.seq"),
			"kind": String(ed["kind"]),
			"data": out_data,
		})

	return {
		"tick": _read_int(sim["tick"], errors, "tick"),
		"seed": _read_int(sim["seed"], errors, "seed"),
		"paused": _read_int(sim["paused"], errors, "paused"),
		"speed": _read_int(sim["speed"], errors, "speed"),
		"player_id": _read_int(sim["player_id"], errors, "player_id"),
		"rng_state": out_rng,
		"event_queue": {"next_seq": _read_int(qd["next_seq"], errors, "event_queue.next_seq"), "entries": entries},
	}


# int, integral float (JSON numbers), or a decimal string (encoded int64).
static func _read_int(value: Variant, errors: Array[String], field: String) -> int:
	if value is int:
		return value
	if value is float:
		var f: float = value
		if f == floorf(f):
			return int(f)
		errors.append("save: field '%s' must be an integer" % field)
		return 0
	if value is String:
		var s := value as String
		if s.is_valid_int():
			return int(s)
		errors.append("save: field '%s' must be an integer" % field)
		return 0
	errors.append("save: field '%s' must be an integer" % field)
	return 0


# Encode int64 values that would not survive a double round-trip.
static func _encode_int64s(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = _encode_int64s(value[key])
		return out
	if value is Array:
		var arr := []
		for v in value:
			arr.append(_encode_int64s(v))
		return arr
	if value is int:
		var v := value as int
		if v > _SAFE_INT_LIMIT or v < -_SAFE_INT_LIMIT:
			return str(v)
	return value
