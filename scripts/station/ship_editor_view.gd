class_name ShipEditorView
extends SubViewportContainer
## Vista 3D de la nave en la estación, con una cámara que orbita a su alrededor (como en el
## mapa estelar): arrastrar para girar, rueda para acercar o alejar. Muestra todas las
## ranuras libres (laterales, de arriba y de abajo) y deja elegir una ranura (para acoplar
## una pieza) o una pieza (para verla, mejorarla o venderla).

signal slot_selected(part_index: int, slot: int)
signal part_selected(part_index: int)
signal deselected

const COLOR_SIDE := Color(0.2, 0.85, 1.0)
const COLOR_FACE := Color(1.0, 0.55, 0.15)
const COLOR_SELECTED := Color(1.0, 0.95, 0.3)
## Distancia en píxeles para acertar a una ranura con el ratón.
const PICK_RADIUS := 16.0
const FOV := 40.0
## Inclinación de la cámara: positiva = desde arriba, negativa = desde abajo.
const PITCH_TOP := 1.1
const PITCH_BOTTOM := -1.1

## Si la cámara mira la nave desde abajo (para el botón «Ver desde abajo»).
var from_below: bool = false
var selected_part: int = -1
## {part_index, slot} de la ranura elegida, o vacío.
var selected_slot: Dictionary = {}

var _viewport: SubViewport
var _camera: Camera3D
var _ship: Ship
var _overlay: Node3D
var _marker_mesh: SphereMesh
var _box_mesh: BoxMesh
## Ranuras libres: {part_index, slot, position, normal, node}.
var _markers: Array[Dictionary] = []
## Cajas de las piezas, para saber si una ranura queda tapada desde la cámara.
var _boxes: Array[AABB] = []
# Cámara orbital: lo que se pide y lo que se ve (se interpola).
var _focus: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = PITCH_TOP
var _dist: float = 9.0
var _cur_focus: Vector3 = Vector3.ZERO
var _cur_yaw: float = 0.0
var _cur_pitch: float = PITCH_TOP
var _cur_dist: float = 9.0
var _fit_dist: float = 9.0
var _framed: bool = false
var _pressed: bool = false
var _dragging: bool = false
var _press_pos: Vector2


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.6)
	env.glow_enabled = true
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -35, 0)
	_viewport.add_child(sun)
	# Luz desde abajo para que la cara inferior de la nave no quede negra.
	var under := DirectionalLight3D.new()
	under.rotation_degrees = Vector3(60, 145, 0)
	under.light_energy = 0.7
	_viewport.add_child(under)

	_ship = Ship.new()
	_ship.preview = true
	_viewport.add_child(_ship)
	_overlay = Node3D.new()
	_viewport.add_child(_overlay)

	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.near = 0.05
	_camera.far = 300.0
	# La cámara se mueve en _process: sin interpolación física.
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_viewport.add_child(_camera)

	_marker_mesh = SphereMesh.new()
	_marker_mesh.radius = 0.13
	_marker_mesh.height = 0.26
	_marker_mesh.radial_segments = 12
	_marker_mesh.rings = 6
	_box_mesh = BoxMesh.new()
	_box_mesh.size = Vector3.ONE


## Vuelve a montar la nave y las marcas después de un cambio en el plano.
func refresh() -> void:
	if selected_part >= GameState.blueprint.size():
		selected_part = -1
	_ship.build()
	_frame_camera()
	_rebuild_overlay()


## Pone la cámara arriba o abajo de la nave (se puede seguir girando con el ratón).
func set_from_below(value: bool) -> void:
	from_below = value
	_pitch = PITCH_BOTTOM if value else PITCH_TOP
	_rebuild_overlay()


## Vuelve a la vista inicial: desde arriba, con el frente de la nave hacia arriba.
func reset_view() -> void:
	from_below = false
	_yaw = 0.0
	_pitch = PITCH_TOP
	_dist = _fit_dist


func clear_selection() -> void:
	selected_part = -1
	selected_slot = {}
	_rebuild_overlay()


## Centra la cámara en la nave. La distancia solo cambia si la nave cambió de tamaño
## (para no deshacer el zoom del jugador en cada compra).
func _frame_camera() -> void:
	var bounds := GameState.ship_bounds()
	_focus = bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 1.5)
	var fit := radius / sin(deg_to_rad(FOV * 0.5)) * 1.05
	if not _framed or absf(fit - _fit_dist) > 0.3:
		_dist = fit
	_fit_dist = fit
	if not _framed:
		_framed = true
		_cur_focus = _focus
		_cur_dist = _dist
		_cur_pitch = _pitch
		_cur_yaw = _yaw
		_update_camera()


func _rebuild_overlay() -> void:
	for child in _overlay.get_children():
		child.queue_free()
	_markers.clear()
	_boxes.clear()
	for i in GameState.blueprint.size():
		for box in GameState.footprints(i):
			_boxes.append(GameState._shrink(box))
	# Piezas perdidas o destruidas: un bloque translúcido donde estaban.
	for i in GameState.blueprint.size():
		var e := GameState.blueprint[i]
		if GameState.is_alive(i):
			continue
		var color := ShipStatusView.COLOR_DESTROYED if e["destroyed"] else ShipStatusView.COLOR_LOST
		_add_box(GameState.footprints(i)[0], Color(color, 0.55))
	# Todas las ranuras libres, un poco por fuera de su cara.
	for s in GameState.free_slots():
		var n: Vector3 = s["normal"]
		var pos: Vector3 = s["position"] + n * 0.14
		var is_selected: bool = not selected_slot.is_empty() and selected_slot["part_index"] == s["part_index"] \
				and selected_slot["slot"] == s["slot"]
		var color := COLOR_SELECTED if is_selected else (COLOR_FACE if s["kind"] == PartData.SlotKind.FACE else COLOR_SIDE)
		var marker := MeshInstance3D.new()
		marker.mesh = _marker_mesh
		marker.material_override = Effects.glow_material(color)
		marker.position = pos
		marker.scale = Vector3.ONE * (1.5 if is_selected else 1.0)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_overlay.add_child(marker)
		_markers.append({"part_index": s["part_index"], "slot": s["slot"], "position": pos, "normal": n,
				"node": marker})
	# Pieza elegida: un recuadro amarillo encima.
	if selected_part >= 0:
		_add_box(GameState.footprints(selected_part)[0].grow(0.05), Color(COLOR_SELECTED, 0.35))
	_update_marker_visibility()


func _add_box(box: AABB, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.no_depth_test = true
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box_mesh
	mesh.material_override = mat
	mesh.position = box.get_center()
	mesh.scale = box.size
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.add_child(mesh)


# ---------- cámara ----------

func _process(delta: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)
	_cur_focus = _cur_focus.lerp(_focus, k)
	_cur_dist = lerpf(_cur_dist, _dist, k)
	_cur_yaw = lerp_angle(_cur_yaw, _yaw, k)
	_cur_pitch = lerpf(_cur_pitch, _pitch, k)
	_update_camera()
	_update_marker_visibility()


func _update_camera() -> void:
	var offset := Vector3(cos(_cur_pitch) * sin(_cur_yaw), sin(_cur_pitch), cos(_cur_pitch) * cos(_cur_yaw))
	_camera.position = _cur_focus + offset * _cur_dist
	# Mirando casi en vertical, el «arriba» de la pantalla es el frente de la nave (-Z).
	var up := Vector3.UP if absf(_cur_pitch) < 1.4 else Vector3(-sin(_cur_yaw), 0, -cos(_cur_yaw))
	_camera.look_at(_cur_focus, up)


## Una ranura solo se ve (y se puede elegir) si ninguna pieza la tapa desde la cámara: las
## de la cara de abajo aparecen al girar la nave.
func _slot_faces_camera(m: Dictionary) -> bool:
	var cam := _camera.global_position
	for box in _boxes:
		if box.intersects_segment(cam, m["position"]):
			return false
	return true


func _update_marker_visibility() -> void:
	for m in _markers:
		(m["node"] as Node3D).visible = _slot_faces_camera(m)


# ---------- entrada ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = maxf(_dist * 0.88, 2.5)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = minf(_dist * 1.13, _fit_dist * 3.0)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			if mb.pressed:
				_pressed = true
				_dragging = false
				_press_pos = mb.position
			else:
				# Un clic sin arrastrar (con el botón izquierdo) elige; arrastrar gira.
				if _pressed and not _dragging and mb.button_index == MOUSE_BUTTON_LEFT:
					pick(mb.position)
				_pressed = false
				_dragging = false
	elif event is InputEventMouseMotion and _pressed:
		var mm := event as InputEventMouseMotion
		if _dragging or mm.position.distance_to(_press_pos) > 5.0:
			_dragging = true
			_yaw -= mm.relative.x * 0.008
			_pitch = clampf(_pitch + mm.relative.y * 0.007, -1.5, 1.5)
			from_below = _pitch < 0.0
			accept_event()


## Elige lo que hay bajo un punto de la vista (en píxeles del control): primero una ranura
## visible, después la pieza más cercana que toque el rayo del ratón.
func pick(screen_pos: Vector2) -> void:
	var best := {}
	var best_d := PICK_RADIUS
	var best_depth := INF
	for m in _markers:
		if not _slot_faces_camera(m) or _camera.is_position_behind(m["position"]):
			continue
		var d := _camera.unproject_position(m["position"]).distance_to(screen_pos)
		var depth := _camera.global_position.distance_to(m["position"])
		# Entre varias ranuras bajo el ratón, la más cercana a la cámara.
		if d < PICK_RADIUS and (d < best_d - 6.0 or (d < best_d + 6.0 and depth < best_depth)):
			best_d = d
			best_depth = depth
			best = m
	if not best.is_empty():
		selected_part = -1
		selected_slot = {"part_index": best["part_index"], "slot": best["slot"]}
		_rebuild_overlay()
		slot_selected.emit(best["part_index"], best["slot"])
		return
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var found := -1
	var found_d := INF
	for i in GameState.blueprint.size():
		var hit: Variant = GameState.footprints(i)[0].intersects_ray(from, dir)
		if hit == null:
			continue
		var d := from.distance_to(hit as Vector3)
		if d < found_d:
			found_d = d
			found = i
	selected_slot = {}
	selected_part = found
	_rebuild_overlay()
	if found >= 0:
		part_selected.emit(found)
	else:
		deselected.emit()


## Posición en pantalla de una ranura (para las pruebas automáticas).
func slot_screen_position(part_index: int, slot: int) -> Vector2:
	for m in _markers:
		if m["part_index"] == part_index and m["slot"] == slot:
			return _camera.unproject_position(m["position"])
	return Vector2(-1, -1)
