extends Node
## Ajustes del jugador (GDD 10.6 y 11): pantalla, volumen, sacudida de cámara y teclas.
## Se guardan en `user://settings.cfg`, aparte de la partida. Carga después de `GameState`,
## que crea las acciones de entrada con sus teclas por defecto.

signal changed

const PATH := "user://settings.cfg"
## Acciones que el jugador puede reasignar, con su nombre en pantalla.
const REBINDABLE: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right",
		&"jump", &"star_map", &"pause"]
const ACTION_NAMES := {
	&"move_up": "Mover arriba", &"move_down": "Mover abajo", &"move_left": "Mover a la izquierda",
	&"move_right": "Mover a la derecha", &"jump": "Saltar (mantener)", &"star_map": "Mapa estelar",
	&"pause": "Pausa",
}
## Buses de audio: el general y uno por tipo de sonido. La música llegará más adelante.
const BUSES: Array[String] = ["SFX", "UI", "Music"]
const BUS_NAMES := {"Master": "Volumen general", "SFX": "Efectos", "UI": "Interfaz"}
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
		Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]

var fullscreen: bool = true
## Tamaño de la ventana (solo en modo ventana). Por defecto, el de la pantalla.
var resolution: Vector2i = Vector2i.ZERO
var vsync: bool = true
var camera_shake: bool = true
## Volumen de cada bus, de 0 a 1.
var volumes := {"Master": 0.8, "SFX": 0.8, "UI": 0.7, "Music": 0.7}
## true si el último control usado fue el mando (los textos de ayuda muestran sus botones).
var using_gamepad: bool = false

## Eventos por defecto de cada acción reasignable, para «Restablecer».
var _defaults: Dictionary[StringName, Array] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for action in REBINDABLE:
		_defaults[action] = InputMap.action_get_events(action).duplicate()
	resolution = screen_size()
	_load()
	apply_audio()
	# Las pruebas automáticas (con argumentos) no cambian la ventana.
	if GameState.args.is_empty():
		apply_display()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		if not using_gamepad:
			using_gamepad = true
			changed.emit()
	elif event is InputEventKey or event is InputEventMouseButton:
		if using_gamepad:
			using_gamepad = false
			changed.emit()


# ---------- pantalla ----------

func screen_size() -> Vector2i:
	return DisplayServer.screen_get_size()


## Resoluciones que caben en la pantalla, más la de la pantalla.
func resolutions() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var screen := screen_size()
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y:
			out.append(r)
	if not out.has(screen):
		out.append(screen)
	return out


func apply_display() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size := resolution
	var screen := screen_size()
	# Una ventana del tamaño de la pantalla no cabe con su borde: se achica un poco.
	if size.x >= screen.x or size.y >= screen.y:
		size = Vector2i(int(screen.x * 0.9), int(screen.y * 0.9))
	DisplayServer.window_set_size(size)
	var origin := DisplayServer.screen_get_position()
	DisplayServer.window_set_position(origin + (screen - size) / 2)


# ---------- sonido ----------

func _setup_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, &"Master")


func apply_audio() -> void:
	for bus_name: String in volumes:
		var i := AudioServer.get_bus_index(bus_name)
		if i < 0:
			continue
		var v: float = volumes[bus_name]
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


# ---------- teclas ----------

## La tecla del teclado que el jugador asignó a una acción (la primera de la lista).
func key_event(action: StringName) -> InputEventKey:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev
	return null


## El botón o eje del mando asignado a una acción (el primero de la lista).
func joy_event(action: StringName) -> InputEvent:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			return ev
	return null


## Reemplaza la tecla (o el control del mando) de una acción. Si otra acción usaba esa misma
## tecla, se la quita, para que una tecla no haga dos cosas.
func rebind(action: StringName, event: InputEvent) -> void:
	var is_key := event is InputEventKey
	for other in REBINDABLE:
		for ev in InputMap.action_get_events(other):
			if _same_input(ev, event):
				InputMap.action_erase_event(other, ev)
	var old := key_event(action) if is_key else joy_event(action)
	var events := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var placed := false
	for ev in events:
		if ev == old and not placed:
			InputMap.action_add_event(action, event)
			placed = true
		else:
			InputMap.action_add_event(action, ev)
	if not placed:
		InputMap.action_add_event(action, event)
	save()
	changed.emit()


func reset_bindings() -> void:
	for action in REBINDABLE:
		InputMap.action_erase_events(action)
		for ev: InputEvent in _defaults[action]:
			InputMap.action_add_event(action, ev)
	save()
	changed.emit()


func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false


## Nombre corto de una tecla o un control del mando, para mostrarlo en pantalla.
static func input_name(ev: InputEvent) -> String:
	if ev == null:
		return "—"
	if ev is InputEventKey:
		var code: Key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
		var names := {KEY_SPACE: "Espacio", KEY_ESCAPE: "Esc", KEY_ENTER: "Intro", KEY_TAB: "Tab",
				KEY_SHIFT: "Mayús", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_BACKSPACE: "Retroceso",
				KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→"}
		if names.has(code):
			return names[code]
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))
	if ev is InputEventJoypadButton:
		var buttons := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
				JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_SHOULDER: "LB",
				JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
				JOY_BUTTON_DPAD_UP: "Cruceta ↑", JOY_BUTTON_DPAD_DOWN: "Cruceta ↓",
				JOY_BUTTON_DPAD_LEFT: "Cruceta ←", JOY_BUTTON_DPAD_RIGHT: "Cruceta →", JOY_BUTTON_GUIDE: "Guía"}
		return buttons.get(ev.button_index, "Botón %d" % ev.button_index)
	if ev is InputEventJoypadMotion:
		var neg: bool = ev.axis_value < 0.0
		match ev.axis:
			JOY_AXIS_LEFT_X:
				return "Stick izq. ←" if neg else "Stick izq. →"
			JOY_AXIS_LEFT_Y:
				return "Stick izq. ↑" if neg else "Stick izq. ↓"
			JOY_AXIS_RIGHT_X:
				return "Stick der. ←" if neg else "Stick der. →"
			JOY_AXIS_RIGHT_Y:
				return "Stick der. ↑" if neg else "Stick der. ↓"
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
		return "Eje %d" % ev.axis
	return "?"


## Cómo se llama ahora el control de una acción: el botón del mando si se está jugando con
## mando; si no, la tecla.
func control_name(action: StringName) -> String:
	if using_gamepad:
		return input_name(joy_event(action))
	return input_name(key_event(action))


# ---------- guardar y cargar ----------

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("effects", "camera_shake", camera_shake)
	for bus_name: String in volumes:
		cfg.set_value("audio", bus_name, volumes[bus_name])
	for action in REBINDABLE:
		var list: Array = []
		for ev in InputMap.action_get_events(action):
			list.append(_event_to_dict(ev))
		cfg.set_value("controls", String(action), list)
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	resolution = cfg.get_value("display", "resolution", resolution)
	vsync = cfg.get_value("display", "vsync", vsync)
	camera_shake = cfg.get_value("effects", "camera_shake", camera_shake)
	for bus_name: String in volumes:
		volumes[bus_name] = float(cfg.get_value("audio", bus_name, volumes[bus_name]))
	for action in REBINDABLE:
		if not cfg.has_section_key("controls", String(action)):
			continue
		var list: Array = cfg.get_value("controls", String(action), [])
		InputMap.action_erase_events(action)
		for d: Dictionary in list:
			var ev := _event_from_dict(d)
			if ev:
				InputMap.action_add_event(action, ev)


func _event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"type": "key", "code": int(ev.physical_keycode)}
	if ev is InputEventJoypadButton:
		return {"type": "button", "index": int(ev.button_index)}
	if ev is InputEventJoypadMotion:
		return {"type": "axis", "axis": int(ev.axis), "value": float(ev.axis_value)}
	return {}


func _event_from_dict(d: Dictionary) -> InputEvent:
	match d.get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = int(d["code"]) as Key
			return k
		"button":
			var b := InputEventJoypadButton.new()
			b.button_index = int(d["index"]) as JoyButton
			return b
		"axis":
			var m := InputEventJoypadMotion.new()
			m.axis = int(d["axis"]) as JoyAxis
			m.axis_value = float(d["value"])
			return m
	return null
