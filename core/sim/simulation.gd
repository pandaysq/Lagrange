class_name Simulation
extends RefCounted

## The tick loop of the core (ADR-0003): owns a SimState and an EventBus,
## advances ticks deterministically and runs due scheduled entries.
##
## Time semantics:
## - step()           -> 1 tick, or 0 when paused.
## - advance(n)       -> exactly n ticks (raw deterministic primitive for
##                       tests, replays and catch-up); 0 when paused.
## - advance_for_ms() -> maps integer real time to ticks through
##                       SimConstants.TICKS_PER_SECOND and state.speed;
##                       0 when paused. This is the only place where speed
##                       matters, because the core itself has no frame clock.

var state: SimState
var bus: EventBus


func _init(p_seed: int = SimConstants.DEFAULT_SEED, p_player_id: int = SimConstants.DEFAULT_PLAYER_ID) -> void:
	state = SimState.new(p_seed, p_player_id)
	bus = EventBus.new()


## Build a simulation around an existing (e.g. restored) state.
## The event bus starts empty: events are outputs, they are not state.
static func from_state(p_state: SimState) -> Simulation:
	var sim := Simulation.new(0)
	sim.state = p_state
	return sim


## One tick. Returns the number of ticks performed (1 or 0 when paused).
func step() -> int:
	if state.paused:
		return 0
	state.tick += 1
	# Placeholder: keep the seeded stream bound to the tick loop. Gameplay
	# systems will replace this with real draws per mechanic.
	for _i in SimConstants.RNG_DRAWS_PER_TICK:
		state.rng.next_u32()
	# Run every scheduled entry that is due now, in (tick, seq) order.
	for entry in state.queue.pop_due(state.tick):
		var ev := SimEvent.new(String(entry["kind"]), state.tick, state.player_id, entry["data"])
		bus.emit_event(ev)
	return 1


## Advance exactly p_ticks ticks. Returns ticks performed (0 when paused).
func advance(p_ticks: int) -> int:
	if state.paused:
		return 0
	var done := 0
	for _i in p_ticks:
		done += step()
	return done


## Map integer real time (milliseconds) to ticks using speed and tick rate.
## Returns ticks performed (0 when paused). Remainder below one tick is
## dropped; precise wall-clock pacing is the view layer's job.
func advance_for_ms(delta_ms: int) -> int:
	if state.paused or delta_ms <= 0:
		return 0
	var ticks := delta_ms * state.speed * SimConstants.TICKS_PER_SECOND / 1000
	return advance(ticks)


## Schedule an entry to run at run_tick; returns its sequence number.
func schedule_event(run_tick: int, kind: String, data: Dictionary = {}) -> int:
	return state.queue.push(run_tick, kind, data)


## Validate and apply a command (ADR-0002). Returns false and changes
## nothing when validation fails.
func apply_command(cmd: Command) -> bool:
	if not cmd.validate(state):
		return false
	cmd.apply(state, bus)
	return true
