extends SceneTree

## Minimal headless test runner for the core (TASK 001). No addons.
## Run: powershell -File tools/run_tests.ps1  (needs GODOT_BIN, see docs/LOCAL_SETUP.md)
## Prints PASS/FAIL per test and exits non-zero when any test fails.

var _pass_count: int = 0
var _fail_count: int = 0


class Collector extends RefCounted:
	## Collects events emitted by one bus, in emission order.
	var got: Array[SimEvent] = []

	func on_event(ev: SimEvent) -> void:
		got.append(ev)


func _initialize() -> void:
	_run_test("rng_reproducibility", _test_rng)
	_run_test("event_queue_ordering", _test_queue)
	_run_test("commands_validate_apply_emit", _test_commands)
	_run_test("speed_pause_frame_rules", _test_speed_pause)
	_run_test("determinism_10k_ticks", _test_determinism)
	_run_test("serialize_roundtrip_keeps_hash", _test_roundtrip)
	print("== %d checks passed, %d failed" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


func _run_test(test_name: String, fn: Callable) -> void:
	print("-- test: " + test_name)
	var fails_before := _fail_count
	fn.call()
	if _fail_count == fails_before:
		print("PASS: " + test_name)
	else:
		print("FAIL: " + test_name)


func check(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
	else:
		_fail_count += 1
		print("   !! " + msg)


func check_eq(got, want, msg: String) -> void:
	if got == want and typeof(got) == typeof(want):
		_pass_count += 1
	else:
		_fail_count += 1
		print("   !! %s (got: %s, want: %s)" % [msg, got, want])


# --- tests -----------------------------------------------------------------

func _test_rng() -> void:
	# Same seed -> identical stream.
	var a := Rng.new(42)
	var b := Rng.new(42)
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []
	for i in 1000:
		seq_a.append(a.next_u32())
		seq_b.append(b.next_u32())
	check_eq(seq_a, seq_b, "same seed gives identical streams")

	# Different seed -> different stream.
	var c := Rng.new(43)
	check(c.next_u32() != seq_a[0], "different seed gives different stream")

	# Bounded draws stay in bounds and are varied.
	var r := Rng.new(7)
	var values: Array[int] = []
	var in_bounds := true
	for i in 200:
		var v := r.next_in_range(3, 17)
		if v < 3 or v > 17:
			in_bounds = false
		values.append(v)
	check(in_bounds, "next_in_range stays within [3, 17]")
	var distinct := {}
	for v in values:
		distinct[v] = true
	check(distinct.size() > 5, "next_in_range produces varied values, got %d distinct" % distinct.size())
	check_eq(r.next_below(1), 0, "next_below(1) is always 0")

	# Serialized state continues the exact same stream.
	var r1 := Rng.new(9)
	for i in 5:
		r1.next_u32()
	var r2 := Rng.from_dict(r1.to_dict())
	var continued := true
	for i in 100:
		if r1.next_u32() != r2.next_u32():
			continued = false
	check(continued, "serialization roundtrip continues the stream")
	check_eq(r2.load_dict({}), false, "load_dict rejects invalid dictionaries")


func _test_queue() -> void:
	var q := EventQueue.new()
	var seq_b := q.push(5, "b")
	var seq_a := q.push(10, "a")
	var seq_d := q.push(5, "d")
	var seq_c := q.push(10, "c")
	check_eq(seq_a, 1, "sequence numbers are assigned in push order")
	check(seq_b == 0 and seq_d == 2 and seq_c == 3, "sequence numbers grow monotonically")

	var due := q.pop_due(9)
	check_eq(_kinds(due), ["b", "d"], "equal ticks pop in insertion order")
	check_eq(_kinds(q.pop_due(20)), ["a", "c"], "earlier ticks pop first")
	check(q.is_empty(), "queue drains fully")
	check_eq(q.pop_due(100).size(), 0, "empty queue pops nothing")

	q.push(50, "e")
	check_eq(q.pop_due(10).size(), 0, "future entries stay queued")
	check_eq(_kinds(q.pop_due(50)), ["e"], "entries run exactly when due")

	# Serialization roundtrip preserves order and the sequence counter.
	var q2 := EventQueue.from_dict(q.to_dict())
	q.push(60, "f")
	q2.push(60, "f")
	check_eq(_kinds(q.pop_due(70)), _kinds(q2.pop_due(70)), "restored queue keeps order and counter")
	check_eq(q2.load_dict({}), false, "load_dict rejects invalid dictionaries")

	# Through the simulation: due entries become emitted events in order.
	var sim := Simulation.new(1)
	var col := Collector.new()
	sim.bus.subscribe(Callable(col, "on_event"))
	sim.schedule_event(sim.state.tick + 5, "test_kind", {"v": 1})
	sim.schedule_event(sim.state.tick + 5, "test_kind2")
	sim.advance(6)
	check_eq(col.got.size(), 2, "both scheduled entries emitted one event")
	check_eq(col.got[0].type, "test_kind", "events keep insertion order for equal ticks")
	check_eq(col.got[0].tick, 5, "event tick is the tick when it ran")
	check_eq(col.got[0].data.get("v", 0), 1, "event payload passes through")


func _kinds(entries: Array[Dictionary]) -> Array:
	var out: Array = []
	for e in entries:
		out.append(String(e["kind"]))
	return out


func _test_commands() -> void:
	var host := LocalHost.new(5)
	var col := Collector.new()
	host.subscribe(Callable(col, "on_event"))
	var state := host.get_state_view()

	# Invalid command: rejected, no changes, no events.
	check_eq(host.send_command(SetSpeedCommand.new(7)), false, "invalid speed is rejected")
	check_eq(state.speed, SimConstants.DEFAULT_SPEED, "state untouched after rejection")
	check_eq(col.got.size(), 0, "no events after rejection")

	# Base Command validates to false as well.
	check_eq(host.send_command(Command.new()), false, "base command is always rejected")

	# Valid speed change applies and emits one event.
	check_eq(host.send_command(SetSpeedCommand.new(10)), true, "valid speed change applies")
	check_eq(state.speed, 10, "speed applied to state")
	check_eq(col.got.size(), 1, "speed change emits one event")
	check_eq(col.got[0].type, SimEvent.SPEED_CHANGED, "event type")
	check_eq(col.got[0].data.get("speed", 0), 10, "event payload: new speed")
	check_eq(col.got[0].data.get("old_speed", 0), 1, "event payload: old speed")
	check_eq(col.got[0].player_id, 1, "event carries the acting player id")

	# Same speed again is a no-op.
	check_eq(host.send_command(SetSpeedCommand.new(10)), false, "no-op speed change rejected")

	# Pause: applies, emits, and stops ticking.
	check_eq(host.send_command(PauseCommand.new(true)), true, "pause applies")
	check_eq(col.got[1].type, SimEvent.PAUSED, "pause emits paused")
	check(state.paused, "paused flag set")
	check_eq(host.advance(10), 0, "paused simulation does not tick")
	check_eq(host.send_command(PauseCommand.new(true)), false, "pause is a no-op when already paused")

	# Unpause resumes ticking.
	check_eq(host.send_command(PauseCommand.new(false)), true, "unpause applies")
	check_eq(col.got[2].type, SimEvent.UNPAUSED, "unpause emits unpaused")
	check_eq(host.advance(10), 10, "simulation ticks after unpause")
	check_eq(state.tick, 10, "tick count correct after pause/unpause")


func _test_speed_pause() -> void:
	var host := LocalHost.new(1)
	# speed x1: 1000 ms at 10 ticks per second -> 10 ticks.
	check_eq(host.advance_frame(1000), 10, "x1: 1000 ms -> 10 ticks")
	check_eq(host.send_command(SetSpeedCommand.new(100)), true, "speed set to x100")
	check_eq(host.advance_frame(100), 100, "x100: 100 ms -> 100 ticks")
	# Raw advance ignores speed on purpose (deterministic primitive).
	check_eq(host.advance(2), 2, "raw advance ignores speed")
	check_eq(host.send_command(PauseCommand.new(true)), true, "pause for frame test")
	check_eq(host.advance_frame(1000), 0, "paused frames tick nothing")
	check_eq(host.advance_frame(-5), 0, "negative ms tick nothing")
	check_eq(host.get_state_view().tick, 112, "tick total is exact")


# Deterministic command script shared by all three simulations.
func _run_determinism_script(host: LocalHost) -> Array[int]:
	var snapshots: Array[int] = []
	host.send_command(SetSpeedCommand.new(10))
	host.advance(4000)
	snapshots.append(StateHash.hash_state(host.get_state_view()))
	host.send_command(PauseCommand.new(true))
	host.advance(100) # 0 ticks: pause respected in both runs
	host.send_command(PauseCommand.new(false))
	host.send_command(SetSpeedCommand.new(100))
	host.advance(6000)
	snapshots.append(StateHash.hash_state(host.get_state_view()))
	return snapshots


func _test_determinism() -> void:
	var host_a := LocalHost.new(777)
	var host_b := LocalHost.new(777)
	var host_c := LocalHost.new(999)
	var snap_a := _run_determinism_script(host_a)
	var snap_b := _run_determinism_script(host_b)
	var snap_c := _run_determinism_script(host_c)
	check_eq(snap_a, snap_b, "same seed + same script -> identical hashes")
	check(snap_a[0] != snap_c[0], "different seed -> different hash mid-run")
	check(snap_a[1] != snap_c[1], "different seed -> different hash at 10k ticks")
	check_eq(host_a.get_state_view().tick, 10000, "exactly 10000 ticks performed")


func _test_roundtrip() -> void:
	# Direct Simulation (not LocalHost): scheduling is a core-internal API,
	# not part of the host contract; this also makes the queue non-empty.
	var sim := Simulation.new(4242)
	sim.apply_command(SetSpeedCommand.new(10))
	sim.advance(123)
	sim.schedule_event(sim.state.tick + 50, "test_kind", {"v": 2})
	sim.advance(10)

	var data := sim.state.to_dict()
	check_eq(StateHash.hash_dict(data), StateHash.hash_state(sim.state), "hash of dict equals hash of state")

	var restored := SimState.from_dict(data)
	check_eq(StateHash.hash_state(restored), StateHash.hash_state(sim.state), "roundtrip keeps the hash")

	# Restored state continues deterministically alongside the original.
	sim.advance(500)
	var sim2 := Simulation.from_state(restored)
	sim2.advance(500)
	check_eq(
		StateHash.hash_state(sim2.state),
		StateHash.hash_state(sim.state),
		"restored state continues identically"
	)
	check_eq(restored.load_dict({}), false, "load_dict rejects invalid dictionaries")
