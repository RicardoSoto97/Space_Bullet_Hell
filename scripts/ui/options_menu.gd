class_name OptionsMenu
extends CanvasLayer
## Opciones (GDD 10.6): pantalla, volumen, sacudida de cámara y teclas del teclado y del mando.
## Se abre encima de cualquier pantalla (inicio, pausa, estación) y emite `closed` al volver.

signal closed

const COLOR_HEAD := Color(0.55, 0.85, 1.0)
const COLOR_DIM := Color(0.65, 0.7, 0.8)

var _mode: OptionButton
var _res: OptionButton
var _res_list: Array[Vector2i] = []
## Acción y tipo («key» o «joy») que esperan una tecla nueva.
var _wait_action: StringName = &""
var _wait_kind: String = ""
var _wait_button: Button
var _bind_buttons: Dictionary[String, Button] = {}
var _first: Control


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_to_group(&"gamepad_menu")
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", panel_style())
	dim.add_child(panel)
	StageHud._place(panel, Control.PRESET_CENTER, Rect2(-400, -330, 800, 660))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override(&"separation", 10)
	panel.add_child(outer)
	_label(outer, "Opciones", 30, Color.WHITE)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 8)
	scroll.add_child(box)

	_build_display(box)
	_build_audio(box)
	_build_effects(box)
	_build_controls(box)

	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(0, 44)
	back.add_theme_font_size_override(&"font_size", 20)
	back.pressed.connect(close)
	outer.add_child(back)
	Settings.changed.connect(_refresh_bindings)
	_refresh_bindings()
	_first.grab_focus.call_deferred()
	Sfx.play(&"ui_open")


## Fondo de los menús: opaco, con borde azul y márgenes.
static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.97)
	sb.border_color = Color(0.3, 0.55, 0.8, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(22)
	return sb


func close() -> void:
	Sfx.play(&"ui_close")
	closed.emit()
	queue_free()


# ---------- secciones ----------

func _build_display(box: VBoxContainer) -> void:
	_label(box, "Pantalla", 22, COLOR_HEAD)
	_mode = OptionButton.new()
	_mode.add_item("Pantalla completa")
	_mode.add_item("Ventana")
	_mode.selected = 0 if Settings.fullscreen else 1
	_mode.item_selected.connect(func(i: int) -> void:
		Settings.fullscreen = i == 0
		_apply_display())
	_row(box, "Modo", _mode)
	_first = _mode

	_res = OptionButton.new()
	_res_list = Settings.resolutions()
	for r in _res_list:
		var native := " (pantalla)" if r == Settings.screen_size() else ""
		_res.add_item("%d × %d%s" % [r.x, r.y, native])
	_res.selected = maxi(_res_list.find(Settings.resolution), 0)
	_res.item_selected.connect(func(i: int) -> void:
		Settings.resolution = _res_list[i]
		_apply_display())
	_row(box, "Resolución de la ventana", _res)
	_res.disabled = Settings.fullscreen

	var vsync := CheckButton.new()
	vsync.text = "Sincronización vertical (VSync)"
	vsync.button_pressed = Settings.vsync
	vsync.toggled.connect(func(on: bool) -> void:
		Settings.vsync = on
		_apply_display())
	box.add_child(vsync)


func _apply_display() -> void:
	_res.disabled = Settings.fullscreen
	Settings.apply_display()
	Settings.save()


func _build_audio(box: VBoxContainer) -> void:
	_label(box, "Sonido", 22, COLOR_HEAD)
	for bus: String in ["Master", "SFX", "UI"]:
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Settings.volumes[bus]
		slider.custom_minimum_size = Vector2(260, 28)
		var pct := Label.new()
		pct.custom_minimum_size = Vector2(56, 0)
		pct.text = "%d %%" % roundi(slider.value * 100.0)
		slider.value_changed.connect(func(v: float) -> void:
			pct.text = "%d %%" % roundi(v * 100.0)
			Settings.volumes[bus] = v
			Settings.apply_audio()
			Settings.save()
			Sfx.play(&"ui_hover" if bus == "UI" else &"scrap"))
		var h := _row(box, Settings.BUS_NAMES[bus], slider)
		h.add_child(pct)
	_label(box, "La música llegará más adelante.", 14, COLOR_DIM)


func _build_effects(box: VBoxContainer) -> void:
	_label(box, "Efectos", 22, COLOR_HEAD)
	var shake := CheckButton.new()
	shake.text = "Sacudida de cámara"
	shake.button_pressed = Settings.camera_shake
	shake.toggled.connect(func(on: bool) -> void:
		Settings.camera_shake = on
		Settings.save())
	box.add_child(shake)


func _build_controls(box: VBoxContainer) -> void:
	_label(box, "Controles", 22, COLOR_HEAD)
	_label(box, "Elige un control y pulsa la tecla o el botón nuevo (Esc para cancelar).", 14, COLOR_DIM)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 12)
	box.add_child(grid)
	_label(grid, "Acción", 15, COLOR_DIM)
	_label(grid, "Teclado", 15, COLOR_DIM)
	_label(grid, "Mando", 15, COLOR_DIM)
	for action in Settings.REBINDABLE:
		var l := _label(grid, Settings.ACTION_NAMES[action], 17, Color(0.9, 0.93, 1.0))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for kind: String in ["key", "joy"]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(170, 34)
			b.pressed.connect(_start_wait.bind(action, kind, b))
			grid.add_child(b)
			_bind_buttons["%s/%s" % [action, kind]] = b
	_label(box, "Las flechas también mueven la nave. Se apunta con el ratón o con el stick derecho.\n"
			+ "En la estación, la base y el mapa, el stick izquierdo mueve el puntero, A hace clic "
			+ "(mantener A y mover gira la vista), X es el clic derecho, el stick derecho hace zoom y "
			+ "LB / RB cambian de pestaña. B vuelve atrás.", 14, COLOR_DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reset := Button.new()
	reset.text = "Restablecer los controles"
	reset.pressed.connect(func() -> void:
		Settings.reset_bindings()
		Sfx.play(&"ui_confirm"))
	box.add_child(reset)


func _refresh_bindings() -> void:
	for key: String in _bind_buttons:
		var parts := key.split("/")
		var action := StringName(parts[0])
		var ev: InputEvent = Settings.key_event(action) if parts[1] == "key" else Settings.joy_event(action)
		_bind_buttons[key].text = Settings.input_name(ev)


# ---------- reasignar ----------

func _start_wait(action: StringName, kind: String, button: Button) -> void:
	# Se espera un fotograma: la pulsación que eligió el botón no cuenta como tecla nueva.
	await get_tree().process_frame
	_wait_action = action
	_wait_kind = kind
	_wait_button = button
	button.text = "Pulsa una tecla…" if kind == "key" else "Pulsa un botón…"


func _input(event: InputEvent) -> void:
	if _wait_action == &"":
		return
	var done: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE and not (_wait_kind == "key" and _wait_action == &"pause"):
			_stop_wait()
			get_viewport().set_input_as_handled()
			return
		if _wait_kind == "key":
			var nk := InputEventKey.new()
			nk.physical_keycode = k.physical_keycode
			done = nk
	elif _wait_kind == "joy" and event is InputEventJoypadButton and event.pressed:
		var nb := InputEventJoypadButton.new()
		nb.button_index = (event as InputEventJoypadButton).button_index
		done = nb
	elif _wait_kind == "joy" and event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
		var jm := event as InputEventJoypadMotion
		var nm := InputEventJoypadMotion.new()
		nm.axis = jm.axis
		nm.axis_value = signf(jm.axis_value)
		done = nm
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
	if done:
		var action := _wait_action
		_stop_wait()
		Settings.rebind(action, done)
		Sfx.play(&"ui_confirm")


func _stop_wait() -> void:
	var b := _wait_button
	_wait_action = &""
	_wait_button = null
	_refresh_bindings()
	if b:
		b.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _wait_action == &"" and (event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		close()


# ---------- ayudas ----------

func _label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	parent.add_child(l)
	return l


func _row(parent: Control, text: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 12)
	parent.add_child(h)
	var l := _label(h, text, 17, Color(0.9, 0.93, 1.0))
	l.custom_minimum_size = Vector2(250, 0)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	return h
