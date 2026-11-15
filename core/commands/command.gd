class_name Command
extends RefCounted

## Base class for all player actions (ADR-0002). A command is validated
## against the current state, then applied to it; applying emits events on
## the event bus. View/ui code never mutates state directly, it only sends
## commands through a SimulationHost.

## Acting player id (ADR-0015); singleplayer uses player 1.
var player_id: int = SimConstants.DEFAULT_PLAYER_ID


## Return true when the command may be applied to `state` right now.
## The base implementation rejects everything: concrete commands override it.
func validate(_state: SimState) -> bool:
	return false


## Apply the command to `state` and emit events on `bus`.
## Only call after validate() returned true.
func apply(_state: SimState, _bus: EventBus) -> void:
	pass
