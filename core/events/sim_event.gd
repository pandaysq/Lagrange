class_name SimEvent
extends RefCounted

## Event emitted by the simulation core. Events are outputs of the core:
## view/ui only listens to them and never mutates state in response.
## Payload `data` holds ints and strings only.

const PAUSED := "paused"
const UNPAUSED := "unpaused"
const SPEED_CHANGED := "speed_changed"
const SCHEDULED := "scheduled"

## Event type constant (one of the TYPE_ constants above or a system kind).
var type: String
## Tick at which the event was emitted.
var tick: int
## Acting player id (ADR-0015).
var player_id: int
## Payload: ints and strings only.
var data: Dictionary


func _init(p_type: String, p_tick: int, p_player_id: int = SimConstants.DEFAULT_PLAYER_ID, p_data: Dictionary = {}) -> void:
	type = p_type
	tick = p_tick
	player_id = p_player_id
	data = p_data.duplicate(true)
