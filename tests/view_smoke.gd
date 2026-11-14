extends SceneTree
## Smoke test for the first playable view, without a display or input devices.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://view/solar_system.tscn")
	check(packed != null, "solar-system scene loads")
	if packed == null:
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var host: SimulationHost = scene.get("host")
	var hud: CanvasLayer = scene.get("hud")
	var bodies: Array = scene.get("bodies")
	check(host != null, "scene uses a simulation host")
	check(hud != null, "scene creates a HUD")
	check_eq(bodies.size(), 8, "eight planets are loaded")
	check(not host.get_state_view().paused, "simulation starts running")

	host.send_command(SetSpeedCommand.new(10))
	scene.call("advance_view", 1.0)
	check_eq(host.get_state_view().tick, 100, "one second at x10 advances 100 ticks")
	hud.call("toggle_pause")
	check(host.get_state_view().paused, "pause uses the host command")
	var paused_tick: int = host.get_state_view().tick
	scene.call("advance_view", 1.0)
	check_eq(host.get_state_view().tick, paused_tick, "paused simulation does not advance")
	hud.call("toggle_pause")
	check(not host.get_state_view().paused, "resume uses the host command")

	print("== %d checks passed, %d failed" % [checks - failures, failures])
	scene.queue_free()
	quit(1 if failures > 0 else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (got %s, expected %s)" % [message, actual, expected])
