extends Node2D
## Presentation only: analytic local positions in sector (0,0), never core state.
const CameraScript = preload("res://view/solar_camera.gd")
const HudScript = preload("res://ui/solar_hud.gd")
var sector: Vector2i = Vector2i.ZERO
var host: SimulationHost = LocalHost.new()
var bodies: Array = []
var camera: Camera2D
var hud: CanvasLayer
var pending_seconds: float = 0.0

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://view/solar_system.json"))
	if not parsed is Dictionary or not parsed.get("bodies") is Array:
		push_error("Solar system view data is missing or invalid.")
		get_tree().quit(1)
		return
	bodies = parsed["bodies"]
	camera = CameraScript.new()
	add_child(camera)
	hud = HudScript.new()
	hud.host = host
	hud.zoom_requested.connect(camera.change_zoom)
	hud.home_requested.connect(camera.fit_system)
	add_child(hud)
	host.subscribe(_on_event)

func _exit_tree() -> void:
	host.unsubscribe(_on_event)

func _on_event(_event: SimEvent) -> void:
	# Time accumulated before pause/speed changes must not leak across them.
	pending_seconds = 0.0

func _process(delta: float) -> void:
	advance_view(delta)
	hud.refresh()
	queue_redraw()

func advance_view(delta: float) -> void:
	if host.get_state_view().paused:
		pending_seconds = 0.0
		return
	pending_seconds += delta
	# Core advance_frame drops sub-tick remainders. Supply whole 100ms quanta.
	var quanta: int = int(floor(pending_seconds * 10.0 + 0.000001))
	if quanta > 0:
		pending_seconds -= float(quanta) / 10.0
		host.advance_frame(quanta * 100)

func _draw() -> void:
	if camera == null:
		return
	var tick: int = host.get_state_view().tick
	var font: Font = ThemeDB.fallback_font
	var inv_zoom: float = 1.0 / camera.zoom.x
	for body: Dictionary in bodies:
		var radius: float = float(body["radius"])
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 160, Color("#223248"), inv_zoom, true)
		var period: int = int(body["period_ticks"])
		var angle: float = float(tick % period) / float(period) * TAU + float(body["phase"])
		var local: Vector2 = Vector2.from_angle(angle) * radius
		var color: Color = Color(body["color"])
		var size: float = maxf(float(body["size"]), 3.0 * inv_zoom)
		draw_circle(local, size, color)
		if int(body["id"]) == 6:
			draw_arc(local, size * 1.7, 0.0, TAU, 40, color, inv_zoom, true)
		draw_string(font, local + Vector2(size + 7.0 * inv_zoom, 5.0 * inv_zoom),
			String(body["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(16.0 * inv_zoom), color)
	draw_circle(Vector2.ZERO, 30.0, Color("#3e3024"))
	draw_circle(Vector2.ZERO, 23.0, Color("#806044"))
	draw_circle(Vector2.ZERO, 18.0, Color("#f1cd83"))
	draw_string(font, Vector2(28, -22) * inv_zoom, "СОЛНЦЕ",
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(16.0 * inv_zoom), Color("#f1cd83"))
