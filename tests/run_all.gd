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
	_run_test("registry_load_and_validate", _test_registry)
	_run_test("registry_pack_file", _test_registry_file)
	_run_test("save_roundtrip_user_file", _test_save_roundtrip)
	_run_test("save_fixtures_load", _test_save_fixtures)
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


func _valid_pack() -> Dictionary:
	return {
		"pack_id": "base",
		"namespace": "base",
		"items": [
			{"id": "iron_ore", "name": "Iron ore"},
			{"id": "stone", "name": "Stone"},
		],
		"buildings": [
			{"id": "mine", "name": "Mine", "produces": [{"item": "base:iron_ore", "per_ticks": 100, "amount": 1}]},
		],
	}


func _test_registry() -> void:
	var reg := ContentRegistry.new()
	var report := reg.load_pack(_valid_pack())
	check_eq(report["ok"], true, "valid pack loads: %s" % [report["errors"]])
	check_eq(report["registered"], 3, "three defs registered")
	check_eq(report["errors"].size(), 0, "no errors for valid pack")

	check(reg.has_def("item", "base:iron_ore"), "item id is namespaced")
	check_eq(reg.get_def("item", "base:iron_ore").get("name", ""), "Iron ore", "item fields kept")
	check_eq(reg.get_def("item", "iron_ore"), {}, "local id alone is not a key")
	check(reg.has_def("building", "base:mine"), "building registered")
	var produces: Array = reg.get_def("building", "base:mine").get("produces", [])
	check_eq(produces[0].get("item", ""), "base:iron_ore", "building references full item id")
	check_eq(reg.get_def("item", "base:stone").get("id", ""), "base:stone", "stored def id is the full namespaced id")

	# Deterministic iteration: ids are sorted.
	check_eq(reg.ids("item"), ["base:iron_ore", "base:stone"], "ids sorted")
	check_eq(reg.ids("shield").size(), 0, "unknown kind is empty")

	# Errors: missing required field, wrong type, bad id format, unknown field.
	var bad := {
		"pack_id": "base",
		"namespace": "base",
		"items": [
			{"id": "no_name"},
			{"id": "Bad_Id", "name": "Bad"},
			{"id": "extra", "name": "Extra", "mass": 5},
		],
	}
	var bad_report := reg.load_pack(bad)
	check_eq(bad_report["ok"], false, "invalid pack rejected")
	check(bad_report["errors"].size() >= 3, "all three bad entries reported: %s" % [bad_report["errors"]])
	check(bad_report["errors"].any(func(e: String) -> bool: return e.contains("no_name") and e.contains("missing field 'name'")), "missing name reported")
	check(bad_report["errors"].any(func(e: String) -> bool: return e.contains("Bad_Id")), "bad id format reported")
	check(bad_report["errors"].any(func(e: String) -> bool: return e.contains("unknown field 'mass'")), "unknown field reported")
	check(not reg.has_def("item", "base:no_name"), "atomic pack: rejected entries not registered")

	# Duplicate id (in pack and across packs) is rejected, first def stays.
	var dup := {
		"pack_id": "dup",
		"namespace": "base",
		"items": [{"id": "iron_ore", "name": "Impostor"}],
	}
	var dup_report := reg.load_pack(dup)
	check_eq(dup_report["ok"], false, "duplicate id rejected across packs")
	check_eq(reg.get_def("item", "base:iron_ore").get("name", ""), "Iron ore", "first definition kept")

	# Reference errors and int checks.
	var bad_refs := {
		"pack_id": "refs",
		"namespace": "base",
		"buildings": [
			{"id": "bad_mine", "name": "Bad", "produces": [{"item": "base:gold_ore", "per_ticks": 0, "amount": 1.5}]},
		],
		"shields": [],
	}
	var ref_report := reg.load_pack(bad_refs)
	check_eq(ref_report["ok"], false, "pack with bad references rejected")
	var msgs: String = " | ".join(PackedStringArray(ref_report["errors"]))
	check(msgs.contains("unknown item id 'base:gold_ore'"), "unknown reference reported")
	check(msgs.contains("per_ticks"), "per_ticks < min reported")
	check(msgs.contains("amount"), "float amount (wrong type) reported")
	check(msgs.contains("unknown pack section 'shields'"), "unknown pack section reported")
	check(not reg.has_def("building", "base:bad_mine"), "atomic pack: bad building not registered")

	# Duplicate id within one pack.
	var dup_in_pack := {
		"pack_id": "dup2",
		"namespace": "other",
		"items": [
			{"id": "same", "name": "First"},
			{"id": "same", "name": "Second"},
		],
	}
	check_eq(reg.load_pack(dup_in_pack)["ok"], false, "duplicate id inside one pack rejected")


func _test_registry_file() -> void:
	var reg := ContentRegistry.new()
	var report := reg.load_pack_file("res://data/base/content.json")
	check_eq(report["ok"], true, "data/base/content.json loads: %s" % [report["errors"]])
	check_eq(report["registered"], 4, "base pack registers 3 items + 1 building")
	check(reg.has_def("item", "base:copper_ore"), "base:copper_ore registered from file")
	check(reg.has_def("building", "base:mine"), "base:mine registered from file")

	var errors: Array[String] = []
	var body := ContentRegistry.read_pack_file("res://tests/fixtures/registry/invalid_json.json", errors)
	check_eq(body, {}, "broken JSON yields empty body")
	check_eq(errors.size(), 1, "broken JSON yields one error")

	errors = []
	body = ContentRegistry.read_pack_file("res://tests/fixtures/registry/missing.json", errors)
	check_eq(body, {}, "missing file yields empty body")
	check_eq(errors.size(), 1, "missing file yields one error")


func _test_save_roundtrip() -> void:
	# Seed beyond 2^53: the save layer must keep int64 precision.
	var host := LocalHost.new(123456789012345678)
	host.send_command(SetSpeedCommand.new(10))
	host.advance(123)

	var doc := SaveManager.build_document(host.get_state_view())
	check_eq(SaveManager.document_errors(doc).size(), 0, "built document is structurally valid")
	check_eq(doc["format_version"], SaveManager.FORMAT_VERSION, "format_version is current")
	var sim_doc: Dictionary = doc["chunks"]["core"]["sim_state"]
	check_eq(sim_doc["seed"], "123456789012345678", "int64 beyond 2^53 encoded as decimal string")

	var with_mods := SaveManager.build_document(host.get_state_view(), [{"id": "base", "version": "1.0.0"}])
	check_eq(String(with_mods["mods"][0]["id"]), "base", "mod list stored with versions")

	var errors: Array[String] = []
	var path := "user://lagrange_test_save.json"
	check(SaveManager.write_save_file(path, doc, errors), "save file written: %s" % [errors])
	var loaded := SaveManager.read_save_file(path, errors)
	check_eq(SaveManager.document_errors(loaded).size(), 0, "loaded file shape valid: %s" % [errors])

	var restored := SaveManager.state_from_document(loaded, errors)
	check(restored != null, "state restored from file: %s" % [errors])
	check_eq(errors.size(), 0, "no restore errors")
	check_eq(
		StateHash.hash_state(restored),
		StateHash.hash_state(host.get_state_view()),
		"file roundtrip restores the exact state"
	)
	check_eq(restored.seed, 123456789012345678, "large int64 seed survives")
	check_eq(restored.tick, 123, "tick restored")
	check_eq(restored.speed, 10, "speed restored")

	# Restored save continues deterministically alongside the original.
	host.advance(100)
	var sim2 := Simulation.from_state(restored)
	sim2.advance(100)
	check_eq(
		StateHash.hash_state(sim2.state),
		StateHash.hash_state(host.get_state_view()),
		"restored save continues identically"
	)

	# Negative cases: newer version, missing migration link, broken structure.
	errors = []
	var newer := doc.duplicate(true)
	newer["format_version"] = 99
	check_eq(SaveManager.state_from_document(newer, errors), null, "newer version rejected")
	check(errors.any(func(e: String) -> bool: return e.contains("newer version")), "newer version reported")

	errors = []
	var ancient := doc.duplicate(true)
	ancient["format_version"] = 0
	check_eq(SaveManager.state_from_document(ancient, errors), null, "version 0 without migration rejected")
	check(errors.any(func(e: String) -> bool: return e.contains("no migration")), "missing migration reported")

	errors = []
	var nocore := {"format_version": 1, "generator_version": 1, "mods": [], "chunks": {}}
	check_eq(SaveManager.state_from_document(nocore, errors), null, "missing core chunk rejected")
	check(SaveManager.document_errors(nocore).any(func(e: String) -> bool: return e.contains("core")), "missing core reported by shape check")

	errors = []
	var bad_tick := doc.duplicate(true)
	bad_tick["chunks"]["core"]["sim_state"]["tick"] = 1.5
	check_eq(SaveManager.state_from_document(bad_tick, errors), null, "non-integral tick rejected")

	errors = []
	var bad_mods := doc.duplicate(true)
	bad_mods["mods"] = [42]
	check(SaveManager.document_errors(bad_mods).size() > 0, "bad mods entry rejected by shape check")

	errors = []
	var unknown := doc.duplicate(true)
	unknown["chunks"]["core"]["sim_state"]["frobnicate"] = 1
	check_eq(SaveManager.state_from_document(unknown, errors), null, "unknown sim_state field rejected")

	# Cleanup.
	check_eq(DirAccess.open("user://").remove("lagrange_test_save.json"), OK, "test save removed")


func _test_save_fixtures() -> void:
	var dir := DirAccess.open("res://tests/fixtures/saves")
	check(dir != null, "saves fixtures directory opens")
	if dir == null:
		return
	var count := 0
	for f in dir.get_files():
		if not String(f).ends_with(".json"):
			continue
		count += 1
		var errors: Array[String] = []
		var doc := SaveManager.read_save_file("res://tests/fixtures/saves/%s" % f, errors)
		check(doc.size() > 0, "fixture %s parsed" % f)
		check_eq(SaveManager.document_errors(doc).size(), 0, "fixture %s shape valid" % f)
		var state := SaveManager.state_from_document(doc, errors)
		check(state != null, "fixture %s loads and migrates: %s" % [f, errors])
		if state != null:
			check_eq(state.tick, 500, "fixture %s tick restored" % f)
			check_eq(state.seed, 123456789012345678, "fixture %s large seed restored" % f)
			var sim := Simulation.from_state(state)
			sim.advance(10)
			check(StateHash.hash_state(sim.state) != 0, "fixture %s continues after load" % f)
	check(count >= 1, "at least one fixture save present")
