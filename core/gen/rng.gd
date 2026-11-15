class_name Rng
extends RefCounted

## Own seeded integer generator (PCG32, O'Neill reference variant).
## Deterministic across runs with the same seed: no engine global
## random number generator is used, and the full state is serializable
## (see to_dict / load_dict) so saves and replays reproduce the stream.
##
## Int64 arithmetic note (ADR-0004): GDScript ints are 64-bit. The state
## update multiplies two 64-bit values; when the mathematical result does
## not fit in 64 bits it wraps to the low 64-bit pattern, which is exactly
## the "mod 2^64" behavior the PCG32 algorithm specifies. Reproducibility
## is required per build (same engine binary), not bit-exact cross-platform.

const _MULT: int = 6364136223846793005 # 0x5851F42D4C957F2D
const _U32_MASK: int = 0xFFFFFFFF

var _state: int = 0
var _inc: int = 0


## Create a generator from an integer seed and an optional stream id.
func _init(p_seed: int = 0, p_stream: int = 0) -> void:
	reseed(p_seed, p_stream)


## (Re)initialize the generator. Same inputs always give the same stream.
## Named reseed: a method named `seed` would collide with the global
## built-in function of the same name.
func reseed(p_seed: int, p_stream: int = 0) -> void:
	# Odd increment; the low bit set is the only requirement, so no mask is
	# needed beyond the natural 64-bit width of GDScript ints.
	_inc = (p_stream << 1) | 1
	_state = 0
	next_u32()
	# Seed may be any int64 (including negative); adding it uses the same
	# low-64-bit wrap as the unsigned reference implementation.
	_state = _state + p_seed
	next_u32()


## Next raw value in [0, 2^32).
func next_u32() -> int:
	var oldstate := _state
	_state = oldstate * _MULT + _inc
	var xorshifted := (((oldstate >> 18) ^ oldstate) >> 27) & _U32_MASK
	var rot := (oldstate >> 59) & 31
	return (((xorshifted >> rot) | (xorshifted << ((-rot) & 31))) & _U32_MASK)


## Uniform value in [0, bound). bound must be >= 1; values above 2^32 fall
## back to a (slightly biased) modulo so the call still stays deterministic.
func next_below(bound: int) -> int:
	if bound <= 1:
		return 0
	var limit: int = 4294967296 - (4294967296 % bound)
	var v := next_u32()
	while bound <= _U32_MASK and v >= limit:
		v = next_u32()
	return v % bound


## Uniform integer in [from_value, to_value], both ends included.
func next_in_range(from_value: int, to_value: int) -> int:
	if to_value <= from_value:
		return from_value
	return from_value + next_below(to_value - from_value + 1)


## Serialize the full generator state (ints only).
func to_dict() -> Dictionary:
	return {"state": _state, "inc": _inc}


## Restore a generator state produced by to_dict().
## Returns false and keeps the current state if the dictionary is invalid.
func load_dict(d: Dictionary) -> bool:
	if not d.has_all(["state", "inc"]):
		return false
	_state = int(d["state"])
	_inc = int(d["inc"])
	return true


## Build a generator from a state dictionary produced by to_dict().
static func from_dict(d: Dictionary) -> Rng:
	var r := Rng.new(0)
	r.load_dict(d)
	return r
