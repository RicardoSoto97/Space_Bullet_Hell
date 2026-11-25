class_name BaseView
extends SubViewportContainer
## Vista 3D de una base (GDD 7.7): un trozo del suelo del cuerpo celeste con los edificios en
## sus parcelas, alrededor de la plataforma de aterrizaje donde está la nave. Cámara orbital
## como la de la nave en la estación: arrastrar para girar, rueda para acercar o alejar.
## Un clic en una parcela la elige (para construir o ver su edificio); en la nave, abre el hangar.

signal lot_selected(lot: int)
signal ship_clicked
signal deselected

const COLOR_FREE := Color(0.2, 0.85, 1.0)
const COLOR_SELECTED := Color(1.0, 0.9, 0.3)
const FOV := 45.0
const LOT_RADIUS := 2.1
const PAD_RADIUS := 2.4
const BUILDING_SCENES_DIR := "res://assets/models/buildings/"

var body_id: StringName = &""
var selected_lot: int = -1

var _viewport: SubViewport
var _camera: Camera3D
var _ship: Ship
var _lots_root: Node3D
var _ring_radius: float = 7.0
var _lot_positions: Array[Vector3] = []
var _yaw: float = 0.35
var _pitch: float = 0.95
var _dist: float = 20.0
var _cur_yaw: float = 0.35
var _cur_pitch: float = 0.95
var _cur_dist: float = 20.0
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
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.shadow_enabled = true
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.near = 0.1
	_camera.far = 600.0
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_viewport.add_child(_camera)


## Monta el suelo y la decoración de la base de ese cuerpo celeste.
func setup(p_body_id: StringName) -> void:
	body_id = p_body_id
	var base := Bases.base_of(body_id)
	var body := Catalog.body(body_id)
	var n := Bases.lot_count(base)
	_ring_radius = {4: 6.0, 6: 7.0, 9: 8.6}.get(n, 7.0)
	_lot_positions.clear()
	for i in n:
		var a := TAU * float(i) / float(n) + PI * 0.5
		_lot_positions.append(Vector3(cos(a), 0, sin(a)) * _ring_radius)
	_build_ground(body)
	var pad := _instance_model("landing_pad")
	if pad:
		_viewport.add_child(pad)
	_ship = Ship.new()
	_ship.preview = true
	_viewport.add_child(_ship)
	_lots_root = Node3D.new()
	_viewport.add_child(_lots_root)
	_dist = _ring_radius * 3.5
	_cur_dist = _dist
	_update_camera()
	refresh()


func _build_ground(body: CelestialBodyData) -> void:
	var radius := _ring_radius + 5.0
	var ground := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 0.92
	cyl.height = 1.2
	cyl.radial_segments = 48
	ground.mesh = cyl
	ground.position.y = -0.6
	var mat := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.seed = absi(hash(body.id)) % 10000
	noise.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, body.color.darkened(0.45))
	ramp.set_color(1, body.color.lightened(0.1))
	tex.color_ramp = ramp
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(3, 3, 3)
	mat.roughness = 0.95
	ground.material_override = mat
	_viewport.add_child(ground)
	# Rocas alrededor, siempre en el mismo sitio para cada cuerpo.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(body.id)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = body.color.darkened(0.35)
	rock_mat.roughness = 1.0
	for i in 40:
		var a := rng.randf() * TAU
		var d := rng.randf_range(_ring_radius + 2.6, radius - 0.6)
		if i % 3 == 0:
			d = rng.randf_range(PAD_RADIUS + 0.8, _ring_radius - 2.6)
			if d < PAD_RADIUS + 0.8:
				continue
		var rock := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 6
		s.rings = 3
		rock.mesh = s
		rock.material_override = rock_mat
		var size := rng.randf_range(0.2, 0.8)
		rock.scale = Vector3(size * rng.randf_range(0.8, 1.4), size * 0.6, size)
		rock.rotation.y = rng.randf() * TAU
		rock.position = Vector3(cos(a) * d, 0.05, sin(a) * d)
		_viewport.add_child(rock)
	# En un satélite se ve su planeta en el cielo.
	if body.kind == CelestialBodyData.Kind.MOON and body.parent != &"":
		var parent := Catalog.body(body.parent)
		var sky := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 40.0
		sp.height = 80.0
		sky.mesh = sp
		var pm := StandardMaterial3D.new()
		pm.albedo_color = parent.color
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sky.material_override = pm
		sky.position = Vector3(-120, 45, -220)
		_viewport.add_child(sky)


func _instance_model(model_name: String) -> Node3D:
	var path := BUILDING_SCENES_DIR + model_name + ".glb"
	if not ResourceLoader.exists(path):
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


## Vuelve a montar los edificios, las parcelas y la nave después de un cambio.
func refresh() -> void:
	if _lots_root == null:
		return
	for c in _lots_root.get_children():
		c.queue_free()
	var base := Bases.base_of(body_id)
	var body := Catalog.body(body_id)
	_ship.build()
	var bounds := GameState.ship_bounds()
	_ship.position = Vector3(-bounds.get_center().x, 0.35 - bounds.position.y, -bounds.get_center().z)
	for i in _lot_positions.size():
		var pos := _lot_positions[i]
		var b := Bases.building_at(base, i)
		var selected := i == selected_lot
		var pad := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = LOT_RADIUS
		disc.bottom_radius = LOT_RADIUS
		disc.height = 0.06
		disc.radial_segments = 24
		pad.mesh = disc
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.22, 0.24, 0.27) if not b.is_empty() else Color(0.1, 0.12, 0.15, 0.7)
		if b.is_empty():
			pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pad.material_override = pm
		pad.position = pos + Vector3(0, 0.02, 0)
		_lots_root.add_child(pad)
		if b.is_empty() or selected:
			var ring := MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = LOT_RADIUS - 0.12
			t.outer_radius = LOT_RADIUS + 0.04
			t.rings = 32
			t.ring_segments = 4
			ring.mesh = t
			ring.material_override = Effects.glow_material(COLOR_SELECTED if selected else COLOR_FREE)
			ring.position = pos + Vector3(0, 0.06, 0)
			ring.scale = Vector3(1, 0.4, 1)
			_lots_root.add_child(ring)
		if b.is_empty():
			var plus := Label3D.new()
			plus.text = "+"
			plus.font_size = 160
			plus.pixel_size = 0.01
			plus.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			plus.modulate = COLOR_SELECTED if selected else COLOR_FREE
			plus.position = pos + Vector3(0, 0.6, 0)
			plus.no_depth_test = true
			_lots_root.add_child(plus)
			continue
		var model := _instance_model(String(b["type"]))
		if model:
			_lots_root.add_child(model)
			model.position = pos
			model.look_at(Vector3(0, 0, 0) + Vector3(0, 0, 0.001), Vector3.UP)
			model.position = pos
			# El centro de investigación de un satélite lleva un telescopio encima (GDD 7.3).
			if b["type"] == &"research_center" and body.kind == CelestialBodyData.Kind.MOON:
				var scope := _instance_model("telescope")
				if scope:
					scope.position = Vector3(0, 1.45, 0)
					model.add_child(scope)
		var label := Label3D.new()
		var data := Catalog.building(b["type"])
		label.text = data.display_name + ("  ·  nivel %d" % b["level"] if data.has_levels else "")
		label.font_size = 30
		label.fixed_size = true
		label.pixel_size = 0.0009
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = COLOR_SELECTED if selected else Color(0.9, 0.95, 1.0)
		label.position = pos + Vector3(0, 3.6, 0)
		label.no_depth_test = true
		_lots_root.add_child(label)


func clear_selection() -> void:
	selected_lot = -1
	refresh()


# ---------- cámara ----------

func _process(delta: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)
	_cur_dist = lerpf(_cur_dist, _dist, k)
	_cur_yaw = lerp_angle(_cur_yaw, _yaw, k)
	_cur_pitch = lerpf(_cur_pitch, _pitch, k)
	_update_camera()


func _update_camera() -> void:
	if _camera == null:
		return
	var offset := Vector3(cos(_cur_pitch) * sin(_cur_yaw), sin(_cur_pitch), cos(_cur_pitch) * cos(_cur_yaw))
	_camera.position = Vector3(0, 0.5, 0) + offset * _cur_dist
	_camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)


func reset_view() -> void:
	_yaw = 0.35
	_pitch = 0.95
	_dist = _ring_radius * 3.5


# ---------- entrada ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = maxf(_dist * 0.88, 6.0)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = minf(_dist * 1.13, _ring_radius * 5.0)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			if mb.pressed:
				_pressed = true
				_dragging = false
				_press_pos = mb.position
			else:
				if _pressed and not _dragging and mb.button_index == MOUSE_BUTTON_LEFT:
					pick(mb.position)
				_pressed = false
				_dragging = false
	elif event is InputEventMouseMotion and _pressed:
		var mm := event as InputEventMouseMotion
		if _dragging or mm.position.distance_to(_press_pos) > 5.0:
			_dragging = true
			_yaw -= mm.relative.x * 0.008
			_pitch = clampf(_pitch + mm.relative.y * 0.007, 0.2, 1.45)
			accept_event()


## Elige la parcela (o la nave) bajo un punto de la vista, en píxeles del control.
func pick(screen_pos: Vector2) -> void:
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return
	# El edificio tapa su parcela: también vale un clic sobre su parte alta.
	var best := -1
	var best_d := LOT_RADIUS + 0.4
	for h: float in [0.0, 1.0, 2.0]:
		var t := (h - from.y) / dir.y
		if t <= 0.0:
			continue
		var p := from + dir * t
		for i in _lot_positions.size():
			var d := Vector2(p.x - _lot_positions[i].x, p.z - _lot_positions[i].z).length()
			if d < best_d and (h == 0.0 or not Bases.building_at(Bases.base_of(body_id), i).is_empty()):
				best_d = d
				best = i
		if h == 0.0 and best < 0 and Vector2(p.x, p.z).length() < PAD_RADIUS:
			ship_clicked.emit()
			return
	selected_lot = best
	refresh()
	if best >= 0:
		lot_selected.emit(best)
	else:
		deselected.emit()


## Posición en pantalla de una parcela (para las pruebas automáticas).
func lot_screen_position(lot: int) -> Vector2:
	if lot < 0 or lot >= _lot_positions.size():
		return Vector2(-1000, -1000)
	return _camera.unproject_position(_lot_positions[lot])
