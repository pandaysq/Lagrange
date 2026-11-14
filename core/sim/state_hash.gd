class_name StateHash
extends RefCounted

## Own deterministic hash of simulation state (TASK 001): FNV-1a 64-bit over
## the canonical int/string serialization produced by SimState.to_dict().
## Godot's built-in hash() is deliberately not used: hash stability is our
## contract, defined here, not an engine implementation detail.

# FNV-1a 64-bit parameters. The offset basis 0xcbf29ce484222325 is written
# as its signed int64 two's complement value, because GDScript int literals
# are signed 64-bit.
const _OFFSET_BASIS: int = -3750763034362895579
const _FNV_PRIME: int = 1099511628211 # 0x100000001B3

# Canonicalization markers so nested shapes cannot collide with scalars
# (e.g. dict {a:{b:1}} vs dict {"a.b": 1} would otherwise hash alike only by
# accident; markers keep structure unambiguous).
const _MARK_DICT: int = 0x5EC1A101
const _MARK_ARRAY: int = 0x5EC2A202
const _MARK_STRING: int = 0x5EC3A303


## Hash any SimState through its canonical serialization.
static func hash_state(state: SimState) -> int:
	return hash_dict(state.to_dict())


## FNV-1a 64-bit over a dictionary: keys sorted, values canonicalized.
## The returned value is the signed int64 view of the 64-bit hash pattern.
static func hash_dict(d: Dictionary) -> int:
	var h := _mix(_OFFSET_BASIS, _MARK_DICT)
	for key in _sorted_keys(d):
		h = _hash_value(h, key)
		h = _hash_value(h, d[key])
	return h


# --- internals -------------------------------------------------------------

static func _sorted_keys(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort()
	return keys


static func _hash_value(h: int, value) -> int:
	if value is Dictionary:
		h = _mix(h, _MARK_DICT)
		for key in _sorted_keys(value):
			h = _hash_value(h, key)
			h = _hash_value(h, value[key])
		return h
	if value is Array:
		h = _mix(h, _MARK_ARRAY)
		h = _mix_int(h, value.size())
		for item in value:
			h = _hash_value(h, item)
		return h
	if value is String:
		h = _mix(h, _MARK_STRING)
		var bytes := (value as String).to_utf8_buffer()
		h = _mix_int(h, bytes.size())
		for b in bytes:
			h = _mix(h, b)
		return h
	# Bools fold into ints; everything else must already be an int by the
	# "ints and strings only" serialization rule.
	return _mix_int(h, int(value))


# Feed a full int as 8 little-endian bytes (two's complement bit pattern),
# so every bit of the value contributes to the hash.
static func _mix_int(h: int, value: int) -> int:
	for i in 8:
		h = _mix(h, (value >> (8 * i)) & 0xFF)
	return h


# One FNV-1a step: XOR the low byte and multiply by the prime. The 64-bit
# multiply wraps to the low 64-bit pattern, which is exactly the "mod 2^64"
# the algorithm defines; determinism is required per build (ADR-0004).
static func _mix(h: int, byte_value: int) -> int:
	return (h ^ (byte_value & 0xFF)) * _FNV_PRIME
