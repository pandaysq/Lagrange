class_name SimState
extends RefCounted

## Plain deterministic simulation state. Only ints, bools and owned data
## objects (Rng, EventQueue); no engine scene types, no floats. Entities are
## referenced by stable integer ids (hard rule 4), and player-specific data
## sits on `player_id` (hard rule 12).

var tick: int = 0
var seed: int = SimConstants.DEFAULT_SEED
var paused: bool = false
var speed: int = SimConstants.DEFAULT_SPEED
var player_id: int = SimConstants.DEFAULT_PLAYER_ID
var rng: Rng
var queue: EventQueue


func _init(p_seed: int = SimConstants.DEFAULT_SEED, p_player_id: int = SimConstants.DEFAULT_PLAYER_ID) -> void:
	seed = p_seed
	player_id = p_player_id
	rng = Rng.new(p_seed)
	queue = EventQueue.new()


## Serialize the full state to ints and strings only (nested dictionaries
## and arrays included). Used by hashing, save v1 (TASK 004) and tests.
func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"seed": seed,
		"paused": 1 if paused else 0,
		"speed": speed,
		"player_id": player_id,
		"rng_state": rng.to_dict(),
		"event_queue": queue.to_dict(),
	}


## Restore state written by to_dict(). Returns false if the dictionary is
## missing required keys; the state is left untouched in that case.
func load_dict(d: Dictionary) -> bool:
	if not d.has_all(["tick", "seed", "paused", "speed", "player_id", "rng_state", "event_queue"]):
		return false
	tick = int(d["tick"])
	seed = int(d["seed"])
	paused = int(d["paused"]) != 0
	speed = int(d["speed"])
	player_id = int(d["player_id"])
	var new_rng := Rng.new(0)
	if not new_rng.load_dict(d["rng_state"]):
		return false
	var new_queue := EventQueue.new()
	if not new_queue.load_dict(d["event_queue"]):
		return false
	rng = new_rng
	queue = new_queue
	return true


## Build a state from a dictionary produced by to_dict().
static func from_dict(d: Dictionary) -> SimState:
	var s := SimState.new(0)
	s.load_dict(d)
	return s
