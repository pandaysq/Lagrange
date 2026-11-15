class_name SimulationHost
extends RefCounted

## Interface to the simulation core (ADR-0011). View/ui code talks only to a
## host: it sends commands, subscribes to events and reads state. The default
## implementation is LocalHost; a future authoritative server is another
## implementation of this same interface (ADR-0015).
##
## Base methods are intentionally non-functional: subclasses override them.


## Validate and apply a command. Returns true when it was applied.
func send_command(_cmd: Command) -> bool:
	return false


## Subscribe a callable that takes one SimEvent argument.
func subscribe(_cb: Callable) -> void:
	pass


## Remove a subscription added with subscribe().
func unsubscribe(_cb: Callable) -> void:
	pass


## Read-only view of the current simulation state. By convention callers
## never mutate it; changes happen only through commands and events.
func get_state_view() -> SimState:
	return null


## Advance exactly p_ticks ticks (raw deterministic primitive). Returns
## ticks performed.
func advance(p_ticks: int) -> int:
	return 0


## Map integer real time (milliseconds) to ticks through speed and pause.
## Returns ticks performed.
func advance_frame(delta_ms: int) -> int:
	return 0
