class_name ContentRegistry
extends RefCounted

## Content registry (ADR-0006): stores validated content definitions under
## namespaced string ids (`base:iron_ore`), loaded from JSON packs in `data/`.
## Saves and commands reference content by these string ids, never by indexes.
##
## A pack is one JSON dictionary:
##   {
##     "pack_id": "base",      # unique pack name, [a-z][a-z0-9_]*
##     "namespace": "base",    # id namespace, [a-z][a-z0-9_]*
##     "items": [ {..}, .. ],  # optional, schema: SCHEMA_ITEM
##     "buildings": [ {..} ]   # optional, schema: SCHEMA_BUILDING
##   }
## Local entry ids are joined as "namespace:local_id". A pack is atomic:
## if any error is found, nothing from it is registered. Reference fields
## (e.g. produces[].item) are validated against ids registered so far plus
## the pack's own earlier sections, so load order matters (like mod packs).
##
## Reads files with FileAccess/JSON only; no scene types and no timing calls.

# Variant type tags used by the generic field validator.
const _SCHEMA_ITEM := {
	"id": {"type": TYPE_STRING, "required": true},
	"name": {"type": TYPE_STRING, "required": true},
}

const _SCHEMA_PRODUCES := {
	"item": {"type": TYPE_STRING, "required": true, "ref_kind": "item"},
	"per_ticks": {"type": TYPE_INT, "required": true, "min": 1},
	"amount": {"type": TYPE_INT, "required": true, "min": 1},
}

const _SCHEMA_BUILDING := {
	"id": {"type": TYPE_STRING, "required": true},
	"name": {"type": TYPE_STRING, "required": true},
	"produces": {"type": TYPE_ARRAY, "required": false, "entries": _SCHEMA_PRODUCES},
}

# Known top-level pack sections. Extend this map (with a schema) to add kinds.
const _PACK_SECTIONS := {
	"items": {"kind": "item", "schema": _SCHEMA_ITEM},
	"buildings": {"kind": "building", "schema": _SCHEMA_BUILDING},
}

# kind -> (full_id -> definition copy with "id" set to the full namespaced id)
var _defs: Dictionary = {}


## Validate and register one pack. Returns a report:
## {"ok": bool, "errors": Array[String], "registered": int}.
## On failure the registry is left untouched (atomic packs).
func load_pack(pack: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var staged: Dictionary = {} # kind -> (full_id -> def)
	var registered := 0

	_pack_section_errors(pack, errors)
	# First pass: validate every entry, stage defs under full ids.
	for section in _PACK_SECTIONS:
		var cfg: Dictionary = _PACK_SECTIONS[section]
		var kind: String = cfg["kind"]
		var entries: Variant = pack.get(section, [])
		if not (entries is Array):
			continue # already reported by _pack_section_errors
		for e in entries:
			var def: Dictionary = e
			var local_id := String(def.get("id", ""))
			var full_id := "%s:%s" % [String(pack.get("namespace", "?")), local_id]
			_entry_errors(kind, full_id, def, cfg["schema"], staged, errors)
			if not staged.has(kind):
				staged[kind] = {}
			staged[kind][full_id] = def
	# Second pass: reference validation happens after all defs are staged so
	# a pack can reference its own earlier-declared kinds regardless of order.
	for section in _PACK_SECTIONS:
		var cfg: Dictionary = _PACK_SECTIONS[section]
		var kind: String = cfg["kind"]
		var entries: Variant = pack.get(section, [])
		if not (entries is Array):
			continue # already reported by _pack_section_errors
		for e in entries:
			var def: Dictionary = e
			var full_id := "%s:%s" % [String(pack.get("namespace", "?")), String(def.get("id", ""))]
			_ref_errors(kind, full_id, def, cfg["schema"], staged, errors)

	if errors.is_empty():
		for kind in staged:
			if not _defs.has(kind):
				_defs[kind] = {}
			for full_id in staged[kind]:
				var def: Dictionary = _normalize(staged[kind][full_id].duplicate(true))
				def["id"] = full_id
				_defs[kind][full_id] = def
				registered += 1
	return {"ok": errors.is_empty(), "errors": errors, "registered": registered}


## Load and register a JSON pack file (path inside the project, res://...).
## Returns the same report as load_pack(); on file/JSON errors the pack
## body is empty and ok is false.
func load_pack_file(path: String) -> Dictionary:
	var errors: Array[String] = []
	var body := read_pack_file(path, errors)
	if errors.is_empty():
		var report := load_pack(body)
		for err in report["errors"]:
			errors.append(err)
		report["errors"] = errors
		return report
	return {"ok": false, "errors": errors, "registered": 0}


## Definition by kind and full namespaced id, or an empty Dictionary.
func get_def(kind: String, full_id: String) -> Dictionary:
	if _defs.has(kind) and _defs[kind].has(full_id):
		return _defs[kind][full_id]
	return {}


func has_def(kind: String, full_id: String) -> bool:
	return _defs.has(kind) and _defs[kind].has(full_id)


## All registered ids of a kind, sorted for deterministic iteration.
func ids(kind: String) -> Array[String]:
	var out: Array[String] = []
	if _defs.has(kind):
		for full_id in _defs[kind]:
			out.append(full_id)
	out.sort()
	return out


## Read and parse a JSON pack file; appends readable errors to out_errors.
## Returns {} when the file cannot be read or parsed.
static func read_pack_file(path: String, out_errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		out_errors.append("registry: file not found: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		out_errors.append("registry: file is empty: %s" % path)
		return {}
	# Instance-based parse: returns an Error code instead of printing to the
	# console, so negative tests keep the log clean.
	var parser := JSON.new()
	if parser.parse(text) != OK or not (parser.get_data() is Dictionary):
		out_errors.append("registry: invalid JSON in %s" % path)
		return {}
	return parser.get_data()


# --- validation internals ---------------------------------------------------

static func _pack_section_errors(pack: Dictionary, errors: Array[String]) -> void:
	if not pack.has("pack_id") or not _is_name_part(String(pack.get("pack_id", ""))):
		errors.append("registry: pack needs a valid pack_id (pattern [a-z][a-z0-9_]*)")
	if not pack.has("namespace") or not _is_name_part(String(pack.get("namespace", ""))):
		errors.append("registry: pack needs a valid namespace (pattern [a-z][a-z0-9_]*)")
	for key in pack:
		if key != "pack_id" and key != "namespace" and not _PACK_SECTIONS.has(key):
			errors.append("registry: unknown pack section '%s'" % key)
	for section in _PACK_SECTIONS:
		var entries: Variant = pack.get(section, [])
		if not (entries is Array):
			errors.append("registry: pack section '%s' must be an array" % section)


# Instance methods below read _defs to reject ids that are already registered.
func _entry_errors(kind: String, full_id: String, def: Dictionary, schema: Dictionary, staged: Dictionary, errors: Array[String]) -> void:
	var local_id := String(def.get("id", ""))
	if not _is_name_part(local_id):
		errors.append("registry: %s '%s': invalid id (pattern [a-z][a-z0-9_]*)" % [kind, local_id])
	if staged.has(kind) and staged[kind].has(full_id):
		errors.append("registry: %s: duplicate id '%s' within pack" % [kind, full_id])
	elif _defs.has(kind) and _defs[kind].has(full_id):
		errors.append("registry: %s: duplicate id '%s' already registered" % [kind, full_id])
	for key in def:
		if not schema.has(key):
			errors.append("registry: %s '%s': unknown field '%s'" % [kind, full_id, key])
	for key in schema:
		var spec: Dictionary = schema[key]
		if not def.has(key):
			if bool(spec.get("required", false)):
				errors.append("registry: %s '%s': missing field '%s'" % [kind, full_id, key])
			continue
		_field_errors(kind, full_id, key, def[key], spec, errors)


static func _field_errors(kind: String, full_id: String, key: String, value: Variant, spec: Dictionary, errors: Array[String]) -> void:
	var want: int = int(spec["type"])
	if not _type_ok(value, want):
		errors.append("registry: %s '%s': field '%s' has wrong type (expected %d, got %d)" % [kind, full_id, key, want, typeof(value)])
		return
	if spec.has("min") and int(value) < int(spec["min"]):
		errors.append("registry: %s '%s': field '%s' must be >= %d" % [kind, full_id, key, int(spec["min"])])
	if spec.has("entries"):
		var entry_schema: Dictionary = spec["entries"]
		for i in (value as Array).size():
			var entry: Variant = (value as Array)[i]
			if not (entry is Dictionary):
				errors.append("registry: %s '%s': field '%s'[%d] must be an object" % [kind, full_id, key, i])
				continue
			for ekey in entry:
				if not entry_schema.has(ekey):
					errors.append("registry: %s '%s': field '%s'[%d]: unknown field '%s'" % [kind, full_id, key, i, ekey])
			for ekey in entry_schema:
				var espec: Dictionary = entry_schema[ekey]
				if not entry.has(ekey):
					if bool(espec.get("required", false)):
						errors.append("registry: %s '%s': field '%s'[%d]: missing field '%s'" % [kind, full_id, key, i, ekey])
					continue
				_entry_field_errors(kind, full_id, key, i, ekey, entry[ekey], espec, errors)


static func _entry_field_errors(kind: String, full_id: String, key: String, i: int, ekey: String, value: Variant, espec: Dictionary, errors: Array[String]) -> void:
	var want: int = int(espec["type"])
	if not _type_ok(value, want):
		errors.append("registry: %s '%s': field '%s'[%d].%s has wrong type" % [kind, full_id, key, i, ekey])
		return
	if espec.has("min") and int(value) < int(espec["min"]):
		errors.append("registry: %s '%s': field '%s'[%d].%s must be >= %d" % [kind, full_id, key, i, ekey, int(espec["min"])])


# JSON numbers arrive as float in Godot, so an integer field also accepts a
# float with an exact integer value (normalized to int at registration).
static func _type_ok(value: Variant, want: int) -> bool:
	if typeof(value) == want:
		return true
	if want == TYPE_INT and typeof(value) == TYPE_FLOAT:
		var f: float = value
		return f == floorf(f) and f >= -9223372036854775808.0 and f <= 9223372036854775807.0
	return false


# Deep copy with integer-valued floats converted to int: registry content is
# plain data (ints and strings only), see AGENTS.md hard rule 5.
static func _normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for k in value:
			out[k] = _normalize(value[k])
		return out
	if value is Array:
		var arr := []
		for v in value:
			arr.append(_normalize(v))
		return arr
	if value is float:
		var f: float = value
		if f == floorf(f):
			return int(f)
	return value


func _ref_errors(kind: String, full_id: String, def: Dictionary, schema: Dictionary, staged: Dictionary, errors: Array[String]) -> void:
	for key in schema:
		var spec: Dictionary = schema[key]
		if not def.has(key):
			continue
		if spec.has("ref_kind"):
			_check_ref(kind, full_id, key, String(def[key]), String(spec["ref_kind"]), staged, errors)
		if spec.has("entries") and spec["entries"].has("item"):
			var entry_schema: Dictionary = spec["entries"]
			for i in (def[key] as Array).size():
				var entry: Variant = (def[key] as Array)[i]
				if entry is Dictionary and entry.has("item"):
					_check_ref(kind, full_id, "%s[%d].item" % [key, i], String(entry["item"]), String(entry_schema["item"]["ref_kind"]), staged, errors)


func _check_ref(kind: String, full_id: String, field: String, ref_id: String, ref_kind: String, staged: Dictionary, errors: Array[String]) -> void:
	var known: bool = (_defs.has(ref_kind) and _defs[ref_kind].has(ref_id)) \
		or (staged.has(ref_kind) and staged[ref_kind].has(ref_id))
	if not known:
		errors.append("registry: %s '%s': %s references unknown %s id '%s'" % [kind, full_id, field, ref_kind, ref_id])


# Local part of namespaced ids: [a-z][a-z0-9_]*; checked without RegEx so the
# core keeps no extra engine dependency in the hot path.
static func _is_name_part(s: String) -> bool:
	if s.is_empty():
		return false
	for i in s.length():
		var c := s.unicode_at(i)
		var is_lower := c >= 97 and c <= 122 # a..z
		var is_digit := c >= 48 and c <= 57 # 0..9
		var is_underscore := c == 95
		if i == 0:
			if not is_lower:
				return false
		elif not (is_lower or is_digit or is_underscore):
			return false
	return true
