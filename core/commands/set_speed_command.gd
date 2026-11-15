class_name SetSpeedCommand
extends Command

## Set the simulation speed to one of the allowed levels (x1/x10/x100).

var speed: int = SimConstants.DEFAULT_SPEED


func _init(p_speed: int = SimConstants.DEFAULT_SPEED, p_player_id: int = SimConstants.DEFAULT_PLAYER_ID) -> void:
	speed = p_speed
	player_id = p_player_id


## Valid only for speeds listed in SimConstants.SPEED_LEVELS, and different
## from the current one.
func validate(state: SimState) -> bool:
	return state.speed != speed and SimConstants.SPEED_LEVELS.has(speed)


## Set state.speed and emit speed_changed with the previous value.
func apply(state: SimState, bus: EventBus) -> void:
	var old_speed := state.speed
	state.speed = speed
	var ev := SimEvent.new(SimEvent.SPEED_CHANGED, state.tick, player_id, {"speed": speed, "old_speed": old_speed})
	bus.emit_event(ev)
