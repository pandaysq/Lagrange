class_name EventBus
extends RefCounted

## Event bus of the core (ADR-0002): everything that changes state emits an
## event here. Subscribers connect through subscribe() (or the signal) and
## receive SimEvent values in emission order, which is deterministic because
## emissions happen inside the deterministic tick loop.

signal event_emitted(ev: SimEvent)


## Emit an event to all subscribers, in subscription order.
func emit_event(ev: SimEvent) -> void:
	event_emitted.emit(ev)


## Subscribe a callable that takes one SimEvent argument.
func subscribe(cb: Callable) -> void:
	if cb.is_valid():
		event_emitted.connect(cb)


## Remove a subscription added with subscribe().
func unsubscribe(cb: Callable) -> void:
	if cb.is_valid() and event_emitted.is_connected(cb):
		event_emitted.disconnect(cb)
