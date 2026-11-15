class_name PauseCommand
extends Command

## Set the pause flag of the simulation to an explicit value. The view sends
## the desired value (e.g. `not state.paused` for a toggle button) so the
## command stays deterministic on its own.


var paused: bool = true


func _init(p_paused: bool = true, p_player_id: int = SimConstants.DEFAULT_PLAYER_ID) -> void:
	paused = p_paused
	player_id = p_player_id


## Valid when the target value is different from the current one, so a no-op
## command does not emit a meaningless event.
func validate(state: SimState) -> bool:
	return state.paused != paused


## Set state.paused and emit paused/unpaused.
func apply(state: SimState, bus: EventBus) -> void:
	state.paused = paused
	var ev := SimEvent.new(SimEvent.PAUSED if paused else SimEvent.UNPAUSED, state.tick, player_id)
	bus.emit_event(ev)
