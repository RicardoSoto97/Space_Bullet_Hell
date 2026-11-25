extends Node
## Mando en todas las interfaces (GDD 11).
## - En los menús (inicio, pausa, opciones, fin de partida, diálogos) se navega con el foco:
##   cruceta o stick para moverse entre botones, A para elegir y B para volver.
## - En las pantallas que se usan con el puntero (estación, base y mapa estelar) el mando
##   mueve el puntero del ratón: stick izquierdo para moverlo, A para hacer clic (mantener A y
##   mover el stick arrastra, por ejemplo para girar la nave), X para el clic derecho, stick
##   derecho para la rueda (zoom y desplazar listas) y LB / RB para cambiar de pestaña.
## Una pantalla pide el puntero entrando en el grupo `gamepad_pointer`; un menú encima entra en
## `gamepad_menu` y tiene prioridad.

const SPEED := 1100.0  # píxeles por segundo a 1080 de alto
const DEADZONE := 0.18
const WHEEL_INTERVAL := 0.07

var _pos := Vector2.ZERO
var _wheel_left: float = 0.0
var _a_down: bool = false
var _x_down: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pos = _window_mouse()


## true si ahora el mando mueve el puntero (pantalla de puntero sin un menú encima).
func pointer_active() -> bool:
	if _menu_open():
		return false
	for n in get_tree().get_nodes_in_group(&"gamepad_pointer"):
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			return true
		if n is CanvasLayer and (n as CanvasLayer).visible:
			return true
	return false


func _menu_open() -> bool:
	for n in get_tree().get_nodes_in_group(&"gamepad_menu"):
		if n is Window and (n as Window).visible:
			return true
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			return true
	return false


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if not pointer_active():
		_ensure_focus(event)
		return
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return
	var jb := event as InputEventJoypadButton
	match jb.button_index:
		JOY_BUTTON_A:
			if jb.pressed != _a_down:
				_a_down = jb.pressed
				_click(MOUSE_BUTTON_LEFT, jb.pressed)
			get_viewport().set_input_as_handled()
		JOY_BUTTON_X:
			if jb.pressed != _x_down:
				_x_down = jb.pressed
				_click(MOUSE_BUTTON_RIGHT, jb.pressed)
			get_viewport().set_input_as_handled()
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_Y:
			get_viewport().set_input_as_handled()
		# B, Start, Back, LB y RB siguen su camino: volver, pausa, mapa y pestañas.


func _process(delta: float) -> void:
	if not pointer_active() or Input.get_connected_joypads().is_empty():
		if _a_down:
			_a_down = false
			_click(MOUSE_BUTTON_LEFT, false)
		return
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > DEADZONE:
		# Curva suave: con el stick apenas inclinado se apunta con precisión.
		var amount := (stick.length() - DEADZONE) / (1.0 - DEADZONE)
		var win := Vector2(DisplayServer.window_get_size())
		_pos += stick.normalized() * amount * amount * SPEED * (win.y / 1080.0) * delta
		_pos = _pos.clamp(Vector2.ZERO, win - Vector2.ONE)
		Input.warp_mouse(_pos)
	else:
		_pos = _window_mouse()
	var wheel := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	_wheel_left -= delta
	if absf(wheel) > 0.4 and _wheel_left <= 0.0:
		_wheel_left = WHEEL_INTERVAL / absf(wheel)
		var b := MOUSE_BUTTON_WHEEL_UP if wheel < 0.0 else MOUSE_BUTTON_WHEEL_DOWN
		_click(b, true)
		_click(b, false)


func _click(button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = _pos
	ev.global_position = _pos
	var mask := 0
	if _a_down:
		mask |= MOUSE_BUTTON_MASK_LEFT
	if _x_down:
		mask |= MOUSE_BUTTON_MASK_RIGHT
	ev.button_mask = mask
	if button == MOUSE_BUTTON_WHEEL_UP or button == MOUSE_BUTTON_WHEEL_DOWN:
		ev.factor = 1.0
	Input.parse_input_event(ev)


func _window_mouse() -> Vector2:
	return Vector2(DisplayServer.mouse_get_position() - DisplayServer.window_get_position())


## En un menú sin nada elegido, el primer movimiento del mando elige el primer botón.
func _ensure_focus(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	var nav := event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed
	if event is InputEventJoypadMotion:
		nav = absf((event as InputEventJoypadMotion).axis_value) > 0.5
	if not nav:
		return
	for n in get_tree().get_nodes_in_group(&"gamepad_menu"):
		var target := first_focusable(n)
		if target:
			target.grab_focus()
			get_viewport().set_input_as_handled()
			return


## El primer control visible que puede tener el foco dentro de un nodo.
static func first_focusable(node: Node) -> Control:
	if node is Control:
		var c := node as Control
		if not c.is_visible_in_tree():
			return null
		if c.focus_mode == Control.FOCUS_ALL and not (c is BaseButton and (c as BaseButton).disabled):
			return c
	for child in node.get_children():
		var found := first_focusable(child)
		if found:
			return found
	return null
