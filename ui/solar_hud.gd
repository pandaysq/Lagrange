extends CanvasLayer
signal zoom_requested(factor: float)
signal home_requested
var host: SimulationHost
var status: Label
var pause_button: Button
var speed_buttons: Dictionary = {}

func _ready() -> void:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for edge: String in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + edge, 16)
	add_child(root)
	var panel := PanelContainer.new()
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "LAGRANGE  /  СОЛНЕЧНАЯ СИСТЕМА"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	status = Label.new()
	column.add_child(status)
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 8)
	column.add_child(controls)
	pause_button = add_button(controls, "", toggle_pause)
	for speed: int in [1, 10, 100]:
		speed_buttons[speed] = add_button(controls, "×%d" % speed, set_speed.bind(speed))
	add_button(controls, "−", func() -> void: zoom_requested.emit(1.0 / 1.3))
	add_button(controls, "+", func() -> void: zoom_requested.emit(1.3))
	add_button(controls, "Обзор", func() -> void: home_requested.emit())
	var footer := Label.new()
	footer.text = "Перетаскивание · колесо / два пальца: масштаб\nСхема не в масштабе · 1 день орбиты = 1 с симуляции\nАвтор и руководитель: Pandays (Пандейс)"
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 16
	footer.offset_top = -84
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_font_size_override("font_size", 14)
	add_child(footer)
	refresh()

func add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(64, 48)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func toggle_pause() -> void:
	var state: SimState = host.get_state_view()
	host.send_command(PauseCommand.new(not state.paused, state.player_id))
	refresh()

func set_speed(speed: int) -> void:
	host.send_command(SetSpeedCommand.new(speed, host.get_state_view().player_id))
	refresh()

func refresh() -> void:
	var state: SimState = host.get_state_view()
	status.text = "Тик %d  ·  %s  ·  ×%d" % [state.tick, "Пауза" if state.paused else "Симуляция", state.speed]
	pause_button.text = "Продолжить" if state.paused else "Пауза"
	for speed: int in speed_buttons:
		speed_buttons[speed].disabled = state.speed == speed
