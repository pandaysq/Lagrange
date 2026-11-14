class_name LocalHost
extends SimulationHost

## Singleplayer host (ADR-0011): owns a Simulation and gives the view/ui a
## narrow API over it. No networking, no sockets, no sync (ADR-0015).

var sim: Simulation


func _init(p_seed: int = SimConstants.DEFAULT_SEED, p_player_id: int = SimConstants.DEFAULT_PLAYER_ID) -> void:
	sim = Simulation.new(p_seed, p_player_id)


## Validate and apply a command. Returns true when it was applied.
func send_command(cmd: Command) -> bool:
	return sim.apply_command(cmd)


## Subscribe a callable that takes one SimEvent argument.
func subscribe(cb: Callable) -> void:
	sim.bus.subscribe(cb)


## Remove a subscription added with subscribe().
func unsubscribe(cb: Callable) -> void:
	sim.bus.unsubscribe(cb)


## Read-only view of the current simulation state.
func get_state_view() -> SimState:
	return sim.state


## Advance exactly p_ticks ticks. Returns ticks performed.
func advance(p_ticks: int) -> int:
	return sim.advance(p_ticks)


## Map integer real time (milliseconds) to ticks through speed and pause.
## Returns ticks performed.
func advance_frame(delta_ms: int) -> int:
	return sim.advance_for_ms(delta_ms)
