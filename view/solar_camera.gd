extends Camera2D
## Mouse and touch share camera intents; camera never sends gameplay commands.
var touches: Dictionary = {}
var base_zoom: float = 1.0

func _ready() -> void:
	get_viewport().size_changed.connect(fit_system)
	fit_system()

func fit_system() -> void:
	var size: Vector2 = get_viewport_rect().size
	base_zoom = maxf(0.08, minf(size.x - 100.0, size.y - 300.0) / 1120.0)
	position = Vector2.ZERO
	zoom = Vector2.ONE * base_zoom

func change_zoom(factor: float) -> void:
	zoom = Vector2.ONE * clampf(zoom.x * factor, base_zoom * 0.5, base_zoom * 12.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			change_zoom(1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_zoom(1.0 / 1.15)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		position -= event.relative / zoom
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag and touches.has(event.index):
		if touches.size() == 2:
			var points: Array = touches.values()
			var before: float = points[0].distance_to(points[1])
			touches[event.index] = event.position
			points = touches.values()
			if before > 1.0:
				change_zoom(points[0].distance_to(points[1]) / before)
		else:
			position -= event.relative / zoom
			touches[event.index] = event.position

func _input(event: InputEvent) -> void:
	# A release over HUD must still clear a finger that started on the map.
	if event is InputEventScreenTouch and not event.pressed:
		touches.erase(event.index)
