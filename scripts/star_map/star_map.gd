class_name StarMap
extends CanvasLayer
## Mapa estelar 3D (GDD 5.1 y 5.5). Se abre encima de la estación o del nivel (que queda en
## pausa) con M o con el botón Back del mando.
## - Galaxia: los 8 sistemas. Rueda para acercar o alejar, arrastrar para girar.
## - Clic en un sistema: la cámara viaja hasta él y se ven sus cuerpos, estaciones y zonas.
## - Clic en un cuerpo: la cámara se acerca a verlo. Clic en una estación o zona: se elige
##   como destino del salto.
## - Al pasar el ratón aparece la ficha del cuerpo, la estación o la zona.

signal destination_chosen(site_id: StringName)
signal closed

## VIEW: solo mirar (el combustible aún se recarga). STATION: saltar desde la estación.
## STAGE_READY: elegir el destino del salto con el combustible recargado.
enum Mode { VIEW, STATION, STAGE_READY }
enum Level { GALAXY, SYSTEM, FOCUS }

const PLANET_SHADER := preload("res://scripts/star_map/planet.gdshader")
const BG_COLOR := Color(0.01, 0.013, 0.03)
## Distancia de la cámara al abrir la galaxia: se ven el sistema actual y sus vecinos.
## Alejando con la rueda se ve la galaxia entera; arrastrando con el botón derecho se desplaza.
const GALAXY_DIST := 2300.0
const GALAXY_MIN_DIST := 400.0
const GALAXY_MAX_DIST := 6500.0
## Más lejos que esto, en la vista de un sistema solo se ven las estrellas: sus planetas,
## estaciones y zonas se ocultan. Si se sigue alejando, se pasa a la vista de la galaxia.
const CONTENT_HIDE_DIST := 100.0
const SYSTEM_MAX_DIST := 120.0
const FOCUS_MAX_DIST := 40.0
const SYSTEM_DIST := 44.0
## Color de las zonas según su dificultad (1 = 5 min ... 6 = 30 min).
const DIFFICULTY_COLORS: Array[Color] = [Color("#ffe066"), Color("#ffb347"), Color("#ff7a3c"),
		Color("#ff4a4a"), Color("#e0409a"), Color("#a64dff")]
const COLOR_TEXT := Color(0.86, 0.9, 1.0)
const COLOR_DIM := Color(0.62, 0.68, 0.8)
const COLOR_GOOD := Color(0.45, 1.0, 0.6)
const COLOR_BAD := Color(1.0, 0.45, 0.4)
const COLOR_MONEY := Color(1.0, 0.85, 0.3)
const SKULL_PATTERN: Array[String] = [
	"...######...",
	".##########.",
	"############",
	"##...##...##",
	"#....##....#",
	"#....##....#",
	"##..####..##",
	"#####..#####",
	".####..####.",
	"..########..",
	"..#.#..#.#..",
	"..########..",
]

var mode: Mode = Mode.VIEW

var _level: Level = Level.GALAXY
var _system: StarSystemData
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
## Cámara orbital: lo que se pide y lo que se ve (se interpola para que viaje).
var _focus_node: Node3D
var _focus_pos: Vector3 = Vector3.ZERO
var _yaw: float = 0.5
var _pitch: float = 0.75
var _dist: float = GALAXY_DIST
var _cur_focus: Vector3 = Vector3.ZERO
var _cur_yaw: float = 0.5
var _cur_pitch: float = 0.75
var _cur_dist: float = GALAXY_DIST
var _galaxy_center: Vector3 = Vector3.ZERO
## Nodos del mundo: sistema -> raíz; cuerpo/estación/zona -> nodo visual.
var _system_roots: Dictionary[StringName, Node3D] = {}
var _nodes: Dictionary[StringName, Node3D] = {}
var _pivots: Array[Node3D] = []
var _pivot_speeds: Array[float] = []
var _galaxy_labels: Array[Label3D] = []
## Nombres de sistemas, cuerpos, estaciones y zonas: solo se ven con el ratón encima (o elegidos).
var _name_labels: Dictionary[StringName, Array] = {}
var _routes: MeshInstance3D
## Contenido de cada sistema (planetas, estaciones, zonas y órbitas), sin su estrella.
var _contents: Dictionary[StringName, Node3D] = {}
## Halos de las estrellas: crecen al alejar la cámara para que se vean desde la galaxia.
var _halos: Array[MeshInstance3D] = []
## Etiquetas y órbitas de cada sistema: solo se ven con ese sistema abierto.
var _system_details: Dictionary[StringName, Array] = {}
var _hover_id: StringName = &""
var _selected_id: StringName = &""
var _pressed: bool = false
var _dragging: bool = false
var _press_pos: Vector2
## Botón derecho: un clic sube de nivel; arrastrar desplaza la vista de la galaxia.
var _rpressed: bool = false
var _rdragging: bool = false
var _rpress_pos: Vector2
var _time: float = 0.0
## Fotograma en que se abrió: la misma pulsación de M que lo abre no debe cerrarlo.
var _opened_frame: int = 0
## Aros verdes de las bases del jugador, por cuerpo celeste.
var _base_markers: Dictionary[StringName, MeshInstance3D] = {}
## Mensaje de la última compra de terreno que falló.
var _land_notice: String = ""

# Interfaz
var _input_area: Control
var _crumb: Label
var _fuel_label: Label
var _hint: Label
var _back_button: Button
var _card: PanelContainer
var _card_box: VBoxContainer
var _side: PanelContainer
var _side_box: VBoxContainer
var _preview_vp: SubViewport
var _preview_root: Node3D
var _preview_cam: Camera3D
var _preview_for: StringName = &""
var _skull: ImageTexture
var _hover_ring: MeshInstance3D
var _here_ring: MeshInstance3D
var _select_ring: MeshInstance3D


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Con mando, el stick mueve el puntero (ver GamepadCursor).
	add_to_group(&"gamepad_pointer")
	_opened_frame = Engine.get_process_frames()
	_skull = _make_skull_texture()
	_build_world()
	_build_ui()
	_open_system(Catalog.system_of(GameState.location), true)
	Sfx.play(&"ui_open")
	if GameState.args.has("map-test"):
		_map_test()


## Abre el mapa en un modo. Se puede volver a llamar para cambiar el modo.
func setup(p_mode: Mode) -> void:
	mode = p_mode


# ---------- mundo 3D ----------

func _build_world() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(_viewport)
	_world = Node3D.new()
	# Todo el mapa se mueve en _process (cámara y órbitas): sin interpolación física.
	_world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_viewport.add_child(_world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.5)
	env.ambient_light_energy = 0.35
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.near = 0.05
	_camera.far = 60000.0
	_world.add_child(_camera)
	_camera.make_current()

	_build_background_stars()
	var systems := Catalog.sorted_systems()
	for sys in systems:
		_build_system(sys)
		_galaxy_center += sys.galaxy_position
	if not systems.is_empty():
		_galaxy_center /= float(systems.size())
	_build_routes(systems)

	_hover_ring = _ring_mesh(Color(1, 1, 1, 0.9), 1.0, 0.06)
	_select_ring = _ring_mesh(Color(1.0, 0.85, 0.3, 1.0), 1.0, 0.08)
	_here_ring = _ring_mesh(Color(0.3, 0.9, 1.0, 1.0), 1.0, 0.08)
	for r in [_hover_ring, _select_ring, _here_ring]:
		r.visible = false
		_world.add_child(r)
	_build_preview()


## Estrellas de fondo: puntos en una esfera muy lejana.
func _build_background_stars() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad := SphereMesh.new()
	quad.radius = 1.0
	quad.height = 2.0
	quad.radial_segments = 4
	quad.rings = 2
	mm.mesh = quad
	mm.instance_count = 1400
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in mm.instance_count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var s := rng.randf_range(10.0, 34.0)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), dir * 25000.0))
		var tint := Color(0.75, 0.82, 1.0).lerp(Color(1.0, 0.85, 0.7), rng.randf())
		mm.set_instance_color(i, tint * rng.randf_range(0.4, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	_world.add_child(mmi)


## Rutas: líneas tenues que unen los sistemas en orden de lejanía.
func _build_routes(systems: Array[StarSystemData]) -> void:
	var points := PackedVector3Array()
	for i in range(systems.size() - 1):
		points.append(systems[i].galaxy_position)
		points.append(systems[i + 1].galaxy_position)
	_routes = _line_mesh(points, Color(0.4, 0.55, 0.9, 0.35), Mesh.PRIMITIVE_LINES)
	_world.add_child(_routes)


func _build_system(sys: StarSystemData) -> void:
	var root := Node3D.new()
	root.name = String(sys.id)
	root.position = sys.galaxy_position
	_world.add_child(root)
	_system_roots[sys.id] = root
	var details: Array = []
	_system_details[sys.id] = details

	var star := sys.star()
	var star_node := _body_visual(star)
	root.add_child(star_node)
	_halos.append(star_node.get_child(1) as MeshInstance3D)
	var content := Node3D.new()
	content.name = "Content"
	root.add_child(content)
	_contents[sys.id] = content
	_nodes[star.id] = star_node
	var star_label := _label3d(star.display_name, 22, Color(1, 0.95, 0.8))
	star_label.offset = Vector2(0, 30)
	star_node.add_child(star_label)
	_add_name_label(star.id, star_label)
	var light := OmniLight3D.new()
	light.light_color = star.color
	light.light_energy = 2.2
	light.omni_range = 45.0
	light.omni_attenuation = 0.6
	root.add_child(light)

	var label := _label3d(sys.display_name, 30, Color(1, 1, 1))
	label.offset = Vector2(0, 26)
	root.add_child(label)
	_add_name_label(sys.id, label)
	var sub := _label3d("Sistema %d · zonas de %s" % [sys.order, _zone_range_text(sys)], 18, COLOR_DIM)
	sub.offset = Vector2(0, -6)
	root.add_child(sub)
	_add_name_label(sys.id, sub)

	# Cuerpos: primero los que orbitan la estrella, después sus satélites.
	var ordered: Array[CelestialBodyData] = []
	for b in sys.bodies:
		if b.kind != CelestialBodyData.Kind.STAR and b.parent == &"":
			ordered.append(b)
	for b in sys.bodies:
		if b.parent != &"":
			ordered.append(b)
	for b in ordered:
		var parent_node: Node3D = content if b.parent == &"" else _nodes[b.parent]
		var pivot := Node3D.new()
		pivot.rotation.y = deg_to_rad(b.orbit_angle)
		parent_node.add_child(pivot)
		_pivots.append(pivot)
		_pivot_speeds.append(deg_to_rad(b.orbit_speed))
		var node := _body_visual(b)
		node.position = Vector3(b.orbit_radius, 0, 0)
		pivot.add_child(node)
		_nodes[b.id] = node
		var orbit := _orbit_line(b.orbit_radius, Color(0.5, 0.6, 0.85, 0.22))
		parent_node.add_child(orbit)
		details.append(orbit)
		var bl := _label3d(b.display_name, 20, COLOR_TEXT)
		bl.offset = Vector2(0, 16)
		node.add_child(bl)
		_add_name_label(b.id, bl)
		if Bases.owns(b.id):
			_add_base_marker(b.id)

	for s in sys.stations:
		_build_site(sys, s, _station_visual(), details)
	for z in sys.zones:
		_build_site(sys, z, _zone_visual(z), details)
	for d: Node3D in details:
		d.visible = false


## Aro verde alrededor de un cuerpo celeste con base del jugador.
func _add_base_marker(body_id: StringName) -> void:
	if _base_markers.has(body_id) or not _nodes.has(body_id):
		return
	var b := Catalog.body(body_id)
	var ring := _ring_mesh(Color(0.4, 1.0, 0.55), b.radius * 1.7, maxf(b.radius * 0.06, 0.03))
	ring.rotation_degrees = Vector3(12, 0, 0)
	_nodes[body_id].add_child(ring)
	var beacon := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = maxf(b.radius * 0.18, 0.06)
	s.height = s.radius * 2.0
	beacon.mesh = s
	beacon.material_override = Effects.glow_material(Color(0.4, 1.0, 0.55))
	beacon.position = Vector3(0, b.radius * 1.15, 0)
	ring.add_child(beacon)
	_base_markers[body_id] = ring


func _build_site(sys: StarSystemData, site: MapSiteData, node: Node3D, details: Array) -> void:
	var parent_node: Node3D = _contents[sys.id] if site.parent == &"" else _nodes[site.parent]
	var a := deg_to_rad(site.orbit_angle)
	node.position = Vector3(cos(a), 0, -sin(a)) * site.orbit_radius
	parent_node.add_child(node)
	_nodes[site.id] = node
	var color := COLOR_TEXT
	if site is ZoneData:
		color = DIFFICULTY_COLORS[(site as ZoneData).difficulty() - 1].lightened(0.25)
	else:
		color = Color(0.55, 0.9, 1.0)
	var l := _label3d(site.display_name, 18, color)
	l.offset = Vector2(0, 14)
	node.add_child(l)
	_add_name_label(site.id, l)


## Modelo de un cuerpo celeste: esfera con su material (y anillos si tiene).
func _body_visual(b: CelestialBodyData) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = b.radius
	sphere.height = b.radius * 2.0
	var asteroid := b.kind == CelestialBodyData.Kind.ASTEROID
	sphere.radial_segments = 9 if asteroid else 40
	sphere.rings = 6 if asteroid else 20
	mi.mesh = sphere
	if asteroid:
		mi.scale = Vector3(1.0, 0.72, 0.84)
		mi.rotation = Vector3(0.4, 0.8, 0.2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if b.kind == CelestialBodyData.Kind.STAR:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = b.color * 2.2
		mi.material_override = mat
		root.add_child(mi)
		root.add_child(_halo(b.color2, b.radius * 5.0))
		return root
	var sm := ShaderMaterial.new()
	sm.shader = PLANET_SHADER
	var gas := b.kind == CelestialBodyData.Kind.GAS_PLANET
	sm.set_shader_parameter(&"color_a", b.color)
	sm.set_shader_parameter(&"color_b", b.color2 if gas else b.color.darkened(0.4))
	sm.set_shader_parameter(&"gas", 1.0 if gas else 0.0)
	sm.set_shader_parameter(&"seed", float(absi(hash(b.id)) % 1000) / 37.0)
	mi.material_override = sm
	root.add_child(mi)
	if b.has_rings:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = b.radius * 1.35
		t.outer_radius = b.radius * 2.15
		t.rings = 48
		t.ring_segments = 6
		ring.mesh = t
		ring.scale = Vector3(1, 0.035, 1)
		ring.rotation_degrees = Vector3(16, 0, 9)
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(b.color2.lightened(0.2), 0.6)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.material_override = rm
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
	return root


## Estación espacial: anillo con un eje central y luces cian.
func _station_visual() -> Node3D:
	var root := Node3D.new()
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.82, 0.84, 0.88)
	hull.roughness = 0.5
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.24
	t.outer_radius = 0.34
	t.rings = 24
	t.ring_segments = 8
	ring.mesh = t
	ring.material_override = hull
	ring.rotation_degrees = Vector3(70, 0, 0)
	root.add_child(ring)
	var axis := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.06
	c.height = 0.7
	axis.mesh = c
	axis.material_override = hull
	axis.rotation_degrees = Vector3(70, 0, 0)
	root.add_child(axis)
	var light := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	light.mesh = s
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.4, 1.4, 2.0)
	light.material_override = lm
	root.add_child(light)
	return root


## Zona de enemigos: esfera translúcida y un aro del color de su dificultad. Con jefe,
## además una calavera encima.
func _zone_visual(z: ZoneData) -> Node3D:
	var root := Node3D.new()
	var color := DIFFICULTY_COLORS[z.difficulty() - 1]
	var ball := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	ball.mesh = s
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(color, 0.28)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material_override = bm
	root.add_child(ball)
	var ring := _ring_mesh(Color(color.r * 1.6, color.g * 1.6, color.b * 1.6), 0.62, 0.05)
	ring.rotation_degrees = Vector3(0, 0, 0)
	root.add_child(ring)
	if z.has_boss():
		var skull := Sprite3D.new()
		skull.texture = _skull
		skull.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		skull.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		skull.pixel_size = 0.05
		skull.position = Vector3(0, 0.95, 0)
		skull.modulate = Color(1, 0.35, 0.3) if not GameState.is_boss_defeated(z.id) else Color(0.55, 0.55, 0.55)
		skull.no_depth_test = true
		root.add_child(skull)
	return root


func _halo(color: Color, size: float) -> MeshInstance3D:
	var g := Gradient.new()
	g.set_color(0, Color(color, 0.85))
	g.set_color(1, Color(color, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Sin esto el billboard ignora la escala y el halo no crece al alejar la cámara.
	mat.billboard_keep_scale = true
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _ring_mesh(color: Color, radius: float, thickness: float) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = radius - thickness
	t.outer_radius = radius + thickness
	t.rings = 40
	t.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = t
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _orbit_line(radius: float, color: Color) -> MeshInstance3D:
	var pts := PackedVector3Array()
	for i in 97:
		var a := TAU * float(i) / 96.0
		pts.append(Vector3(cos(a), 0, sin(a)) * radius)
	return _line_mesh(pts, color, Mesh.PRIMITIVE_LINE_STRIP)


func _line_mesh(points: PackedVector3Array, color: Color, primitive: Mesh.PrimitiveType) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(primitive, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _label3d(text: String, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.outline_size = 8
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.no_depth_test = true
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


func _zone_range_text(sys: StarSystemData) -> String:
	var lo := 999
	var hi := 0
	for z in sys.zones:
		lo = mini(lo, z.distance_minutes)
		hi = maxi(hi, z.distance_minutes)
	return "%d min" % lo if lo == hi else "%d–%d min" % [lo, hi]


## Calavera en pixel art para las zonas con jefe.
func _make_skull_texture() -> ImageTexture:
	var h := SKULL_PATTERN.size()
	var w := SKULL_PATTERN[0].length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if SKULL_PATTERN[y][x] == "#":
				img.set_pixel(x, y, Color(1, 1, 1))
	return ImageTexture.create_from_image(img)


# ---------- vista previa de la ficha (imagen 2D del cuerpo) ----------

func _build_preview() -> void:
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = true
	_preview_vp.size = Vector2i(220, 220)
	_preview_vp.msaa_3d = Viewport.MSAA_4X
	_preview_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_preview_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.5)
	env.ambient_light_energy = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	_preview_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, -50, 0)
	sun.light_energy = 1.6
	_preview_vp.add_child(sun)
	_preview_cam = Camera3D.new()
	_preview_cam.fov = 30.0
	_preview_vp.add_child(_preview_cam)
	_preview_root = Node3D.new()
	_preview_vp.add_child(_preview_root)


## Pone en la vista previa una copia del cuerpo, estación o zona.
func _set_preview(id: StringName) -> void:
	if id == _preview_for:
		return
	_preview_for = id
	for c in _preview_root.get_children():
		c.queue_free()
	var node: Node3D
	var size := 1.0
	var b := Catalog.body(id)
	if b:
		node = _body_visual(b)
		size = b.radius * (2.3 if b.has_rings else 1.15)
		if b.kind == CelestialBodyData.Kind.STAR:
			size = b.radius * 1.6
	else:
		var s := Catalog.site(id)
		node = _station_visual() if s.is_station() else _zone_visual(s as ZoneData)
		size = 0.8 if s.is_station() else 1.1
	_preview_root.add_child(node)
	_preview_cam.position = Vector3(0, size * 0.9, size * 3.6)
	_preview_cam.look_at(Vector3.ZERO)


# ---------- interfaz ----------

func _build_ui() -> void:
	_input_area = Control.new()
	_input_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_area.gui_input.connect(_on_map_input)
	add_child(_input_area)

	var top := VBoxContainer.new()
	add_child(top)
	StageHud._place(top, Control.PRESET_TOP_LEFT, Rect2(20, 14, 760, 0))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_label(top, "Mapa estelar", 28, Color(0.95, 0.97, 1.0))
	_crumb = _ui_label(top, "", 17, COLOR_TEXT)
	_fuel_label = _ui_label(top, "", 15, COLOR_DIM)
	_hint = _ui_label(top, "", 14, COLOR_DIM)

	var buttons := HBoxContainer.new()
	add_child(buttons)
	StageHud._place(buttons, Control.PRESET_TOP_RIGHT, Rect2(-330, 16, 310, 40))
	buttons.alignment = BoxContainer.ALIGNMENT_END
	_back_button = Button.new()
	_back_button.text = "Volver"
	_back_button.pressed.connect(_go_up)
	buttons.add_child(_back_button)
	var close := Button.new()
	close.text = "Cerrar mapa (M)"
	close.pressed.connect(close_map)
	buttons.add_child(close)

	_side = PanelContainer.new()
	add_child(_side)
	StageHud._place(_side, Control.PRESET_BOTTOM_RIGHT, Rect2(-380, -20, 360, 0))
	_side.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_side_box = VBoxContainer.new()
	_side_box.add_theme_constant_override(&"separation", 6)
	_side.add_child(_side_box)
	_side.visible = false

	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.09, 0.94)
	style.border_color = Color(0.35, 0.5, 0.8, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_card.add_theme_stylebox_override(&"panel", style)
	_side.add_theme_stylebox_override(&"panel", style)
	add_child(_card)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override(&"separation", 5)
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_card_box)
	_card.visible = false


func _ui_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.add_theme_constant_override(&"outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _wrap_label(parent: Control, text: String, font_size: int, color: Color, width: float = 300.0) -> Label:
	var l := _ui_label(parent, text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _refresh_header() -> void:
	match _level:
		Level.GALAXY:
			_crumb.text = "Galaxia"
		Level.SYSTEM:
			_crumb.text = "Galaxia  ›  Sistema %s" % _system.display_name
		Level.FOCUS:
			var name := _name_of(_selected_id)
			_crumb.text = "Galaxia  ›  Sistema %s  ›  %s" % [_system.display_name, name]
	var here := Catalog.place_name(GameState.location)
	_fuel_label.text = "%s: alcance de %d min de combustible · Estás en %s" % [
		GameState.TANK_NAMES[GameState.fuel_tank_level], GameState.tank_minutes(),
		here if here != "" else "?"]
	match mode:
		Mode.STATION:
			_hint.text = "Elige una zona o una estación y pulsa «Saltar». Rueda: zoom · arrastrar: girar · botón derecho: volver (arrastrando, desplaza la galaxia)."
		Mode.STAGE_READY:
			_hint.text = "Combustible recargado: elige el destino del salto. Rueda: zoom · arrastrar: girar."
		_:
			_hint.text = "El combustible se está recargando: por ahora solo puedes mirar. Rueda: zoom · arrastrar: girar."
	_back_button.disabled = _level == Level.GALAXY


func _name_of(id: StringName) -> String:
	var b := Catalog.body(id)
	if b:
		return b.display_name
	var s := Catalog.site(id)
	return s.display_name if s else ""


## Rellena una ficha (la que sigue al ratón o la del panel lateral).
func _fill_card(box: VBoxContainer, id: StringName, with_actions: bool) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var sys := Catalog.system_of(id)
	if sys == null and Catalog.systems.has(id):
		_fill_system_card(box, Catalog.systems[id])
		return
	_set_preview(id)
	var img := TextureRect.new()
	img.texture = _preview_vp.get_texture()
	img.custom_minimum_size = Vector2(130, 130)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(img)
	var b := Catalog.body(id)
	if b:
		_fill_body_card(box, b, sys, with_actions)
		return
	var s := Catalog.site(id)
	if s is ZoneData:
		_fill_zone_card(box, s as ZoneData, sys, with_actions)
	else:
		_fill_station_card(box, s, sys, with_actions)


func _fill_system_card(box: VBoxContainer, sys: StarSystemData) -> void:
	_ui_label(box, "Sistema %s" % sys.display_name, 20, Color.WHITE)
	_wrap_label(box, sys.description, 14, COLOR_TEXT)
	var planets := 0
	for b in sys.bodies:
		if b.kind == CelestialBodyData.Kind.ROCKY_PLANET or b.kind == CelestialBodyData.Kind.GAS_PLANET:
			planets += 1
	_ui_label(box, "%d planetas · %d estación · %d zonas (%s)" % [planets, sys.stations.size(), sys.zones.size(),
			_zone_range_text(sys)], 14, COLOR_DIM)
	for z in sys.zones:
		if z.has_boss():
			_boss_row(box, z, false)
	_ui_label(box, "Clic para viajar al sistema", 13, COLOR_DIM)


func _fill_body_card(box: VBoxContainer, b: CelestialBodyData, sys: StarSystemData, with_actions: bool) -> void:
	_ui_label(box, b.display_name, 22, Color.WHITE)
	var where := b.kind_name()
	if b.parent != &"":
		where += " de " + Catalog.body(b.parent).display_name
	_ui_label(box, "%s · sistema %s" % [where, sys.display_name], 14, COLOR_DIM)
	_wrap_label(box, b.description, 14, COLOR_TEXT)
	if b.kind == CelestialBodyData.Kind.STAR:
		_ui_label(box, "Temperatura de la superficie: %s K" % _fmt(b.temperature), 15, COLOR_TEXT)
		_ui_label(box, "Habitable: no", 15, COLOR_BAD)
		return
	_ui_label(box, "Habitable: sí" if b.habitable else "Habitable: no", 15, COLOR_GOOD if b.habitable else COLOR_BAD)
	_ui_label(box, "Temperatura media: %d °C" % b.temperature, 15, COLOR_TEXT)
	if b.habitable and Bases.owns(b.id):
		_fill_base_status(box, b, with_actions)
		return
	if b.habitable:
		_ui_label(box, "Costo del terreno: %s créditos" % _fmt(b.land_price), 15, COLOR_MONEY)
		_ui_label(box, "%s: %d parcelas para edificios" % [_base_kind_name(b), Bases.LOTS.get(b.kind, 0)], 13, COLOR_DIM)
		if with_actions:
			var buy := Button.new()
			buy.text = "Comprar terreno (%s créditos)" % _fmt(b.land_price)
			buy.custom_minimum_size = Vector2(0, 38)
			buy.disabled = b.land_price > GameState.money
			buy.pressed.connect(_on_buy_land.bind(b.id))
			box.add_child(buy)
			if b.land_price > GameState.money:
				_ui_label(box, "No tienes dinero suficiente (tienes %s)." % _fmt(GameState.money), 13, COLOR_BAD)
			if _land_notice != "":
				_wrap_label(box, _land_notice, 13, COLOR_BAD)
			_wrap_label(box, "La base se funda cuando la nave aterriza aquí.", 12, COLOR_DIM)
		else:
			_ui_label(box, "Clic para acercarte y comprar el terreno", 13, COLOR_DIM)
		return
	else:
		_wrap_label(box, "No se puede comprar terreno: aquí no se puede vivir.", 13, COLOR_DIM)
	if not with_actions:
		_ui_label(box, "Clic para acercarte", 13, COLOR_DIM)


func _base_kind_name(b: CelestialBodyData) -> String:
	match b.kind:
		CelestialBodyData.Kind.ASTEROID:
			return "Asteroide"
		CelestialBodyData.Kind.MOON:
			return "Satélite"
	return "Planeta"


## Ficha de un cuerpo con base del jugador: su estado y el botón «Aterrizar».
func _fill_base_status(box: VBoxContainer, b: CelestialBodyData, with_actions: bool) -> void:
	var base := Bases.base_of(b.id)
	_ui_label(box, "Tu base" if base["founded"] else "Tu terreno: aterriza para fundar la base", 16, COLOR_GOOD)
	_ui_label(box, "%d de %d parcelas con edificios" % [base["buildings"].size(), Bases.lot_count(base)], 14, COLOR_TEXT)
	var here := GameState.location == b.id
	if here:
		_ui_label(box, "Estás aquí", 15, Color(0.4, 0.9, 1.0))
	if not with_actions:
		if not here:
			_ui_label(box, "Clic para elegirla como destino", 13, COLOR_DIM)
		return
	var land := Button.new()
	land.custom_minimum_size = Vector2(0, 42)
	land.add_theme_font_size_override(&"font_size", 17)
	match mode:
		Mode.STATION:
			land.text = "Aterrizar en %s" % b.display_name
		Mode.STAGE_READY:
			land.text = "Fijar destino: aterrizar en %s" % b.display_name
		_:
			land.text = "Aterrizar (el combustible se está recargando)"
	land.disabled = here or mode == Mode.VIEW
	land.pressed.connect(_choose.bind(b.id))
	box.add_child(land)


func _on_buy_land(body_id: StringName) -> void:
	_land_notice = Bases.buy_land(body_id)
	if _land_notice == "":
		_add_base_marker(body_id)
		# Se guarda solo fuera de los niveles (la partida se guarda en estaciones y bases).
		if GameState.in_station() or GameState.in_base():
			GameState.save_game()
	_fill_card(_side_box, body_id, true)


func _fill_zone_card(box: VBoxContainer, z: ZoneData, sys: StarSystemData, with_actions: bool) -> void:
	_ui_label(box, z.display_name, 22, Color.WHITE)
	_ui_label(box, "Zona de enemigos · sistema %s" % sys.display_name, 14, COLOR_DIM)
	_wrap_label(box, z.description, 14, COLOR_TEXT)
	_ui_label(box, "Duración del nivel: %d min" % z.distance_minutes, 15, COLOR_TEXT)
	var d := z.difficulty()
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	_ui_label(row, "Dificultad: ", 15, COLOR_TEXT)
	_ui_label(row, "●".repeat(d) + "○".repeat(6 - d), 15, DIFFICULTY_COLORS[d - 1])
	_ui_label(row, "  (%d de 6)" % d, 15, COLOR_DIM)
	var names: Array[String] = []
	for e in Catalog.enemies_for_difficulty(d):
		names.append(e.display_name)
	_wrap_label(box, "Enemigos: " + ", ".join(names), 14, COLOR_TEXT)
	if z.has_boss():
		_boss_row(box, z, true)
	_site_status(box, z, with_actions)


func _boss_row(box: VBoxContainer, z: ZoneData, detailed: bool) -> void:
	var defeated := GameState.is_boss_defeated(z.id)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var icon := TextureRect.new()
	icon.texture = _skull
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = Color(0.55, 0.55, 0.55) if defeated else Color(1, 0.3, 0.25)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	if defeated:
		_ui_label(text, "Jefe derrotado: %s" % z.boss_name, 15, COLOR_DIM)
	else:
		_ui_label(text, "¡Peligro! Jefe: %s" % z.boss_name, 16, COLOR_BAD)
		if detailed:
			_wrap_label(text, "Aparece al recargarse el combustible. Hay que derrotarlo para saltar (o huir y perder la recompensa).",
					12, Color(1.0, 0.7, 0.6), 250.0)


func _fill_station_card(box: VBoxContainer, s: MapSiteData, sys: StarSystemData, with_actions: bool) -> void:
	_ui_label(box, s.display_name, 22, Color.WHITE)
	var where := "Estación espacial · sistema %s" % sys.display_name
	if s.parent != &"":
		where = "Estación espacial en órbita de %s" % Catalog.body(s.parent).display_name
	_ui_label(box, where, 14, COLOR_DIM)
	_wrap_label(box, s.description, 14, COLOR_TEXT)
	_ui_label(box, "Siempre al alcance", 14, COLOR_GOOD)
	_site_status(box, s, with_actions)


## Si se puede saltar a un lugar, y el botón para hacerlo en el panel lateral.
func _site_status(box: VBoxContainer, s: MapSiteData, with_actions: bool) -> void:
	var here := s.id == GameState.location
	var reach := GameState.can_reach(s.id)
	if here:
		_ui_label(box, "Estás aquí", 15, Color(0.4, 0.9, 1.0))
	elif not reach:
		_wrap_label(box, "Fuera de alcance: necesitas un depósito de %d min (el tuyo es de %d)." % [
			(s as ZoneData).distance_minutes, GameState.tank_minutes()], 14, COLOR_BAD)
	if not with_actions:
		if not here:
			_ui_label(box, "Clic para elegirla como destino", 13, COLOR_DIM)
		return
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override(&"font_size", 17)
	match mode:
		Mode.STATION:
			b.text = "Saltar a %s" % s.display_name
		Mode.STAGE_READY:
			b.text = "Fijar destino del salto"
		_:
			b.text = "Saltar (el combustible se está recargando)"
	b.disabled = here or not reach or mode == Mode.VIEW
	b.pressed.connect(_choose.bind(s.id))
	box.add_child(b)


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ---------- navegación ----------

func _open_galaxy() -> void:
	_level = Level.GALAXY
	_focus_node = null
	# La galaxia se abre centrada en el sistema que se estaba mirando (o en el actual).
	var around := _system if _system else Catalog.system_of(GameState.location)
	_focus_pos = around.galaxy_position if around else _galaxy_center
	_dist = GALAXY_DIST
	_pitch = 1.05
	_selected_id = &""
	_set_details(&"")
	_side.visible = false
	_refresh_header()


func _open_system(sys: StarSystemData, instant: bool = false) -> void:
	if sys == null:
		_open_galaxy()
		return
	_system = sys
	_level = Level.SYSTEM
	_focus_node = _system_roots[sys.id]
	_dist = SYSTEM_DIST
	_pitch = 0.85
	_selected_id = &""
	_set_details(sys.id)
	_side.visible = false
	if instant:
		_cur_focus = _focus_node.global_position
		_cur_dist = _dist
		_cur_pitch = _pitch
	_refresh_header()


## Acerca la cámara a un cuerpo, una estación o una zona del sistema abierto y lo muestra
## en el panel lateral.
func _focus(id: StringName) -> void:
	_level = Level.FOCUS
	_land_notice = ""
	_selected_id = id
	_focus_node = _nodes[id]
	var b := Catalog.body(id)
	if b:
		_dist = maxf(b.radius * (9.0 if b.has_rings else 6.0), 3.5)
		if b.kind == CelestialBodyData.Kind.STAR:
			_dist = b.radius * 7.0
	else:
		_dist = 11.0
	_pitch = 0.45 if b else 0.75
	_side.visible = true
	_fill_card(_side_box, id, true)
	_refresh_header()


func _go_up() -> void:
	match _level:
		Level.FOCUS:
			_open_system(_system)
		Level.SYSTEM:
			_open_galaxy()


func _set_details(system_id: StringName) -> void:
	for sid in _system_details:
		for n: Node3D in _system_details[sid]:
			n.visible = sid == system_id
	for l in _galaxy_labels:
		l.visible = system_id == &""
	_routes.visible = system_id == &""


func _choose(site_id: StringName) -> void:
	destination_chosen.emit(site_id)


func close_map() -> void:
	Sfx.play(&"ui_close")
	closed.emit()
	queue_free()


# ---------- entrada ----------

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist *= 0.87
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist *= 1.15
			# Al alejarse del todo, se sube un nivel: del cuerpo al sistema y del sistema a la galaxia.
			if _level == Level.SYSTEM and _dist > SYSTEM_MAX_DIST:
				_open_galaxy()
			elif _level == Level.FOCUS and _dist > FOCUS_MAX_DIST:
				_open_system(_system)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressed = true
				_dragging = false
				_press_pos = mb.position
			else:
				if _pressed and not _dragging:
					_click(mb.position)
				_pressed = false
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rpressed = true
				_rdragging = false
				_rpress_pos = mb.position
			else:
				if _rpressed and not _rdragging:
					_go_up()
				_rpressed = false
				_rdragging = false
		_clamp_dist()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _rpressed and (_rdragging or mm.position.distance_to(_rpress_pos) > 5.0):
			_rdragging = true
			if _level == Level.GALAXY:
				_pan(mm.relative)
		if _pressed and (_dragging or mm.position.distance_to(_press_pos) > 5.0):
			_dragging = true
			_yaw -= mm.relative.x * 0.006
			_pitch = clampf(_pitch + mm.relative.y * 0.005, 0.1, 1.45)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.get_process_frames() <= _opened_frame + 1:
		return
	if event.is_action_pressed(&"star_map"):
		get_viewport().set_input_as_handled()
		close_map()
	elif event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _level == Level.GALAXY:
			close_map()
		else:
			_go_up()


## Desplaza la vista de la galaxia en el plano, según cómo mira la cámara.
func _pan(rel: Vector2) -> void:
	var right := _camera.global_basis.x
	right.y = 0.0
	var fwd := -_camera.global_basis.z
	fwd.y = 0.0
	var k := _cur_dist * 0.0015
	_focus_pos += (-right.normalized() * rel.x + fwd.normalized() * rel.y) * k


func _clamp_dist() -> void:
	match _level:
		Level.GALAXY:
			_dist = clampf(_dist, GALAXY_MIN_DIST, GALAXY_MAX_DIST)
		Level.SYSTEM:
			_dist = clampf(_dist, 10.0, SYSTEM_MAX_DIST)
		Level.FOCUS:
			_dist = clampf(_dist, 1.5, FOCUS_MAX_DIST)


func _click(pos: Vector2) -> void:
	var id := _pick(pos)
	if id == &"":
		return
	if Catalog.systems.has(id):
		_open_system(Catalog.systems[id])
	else:
		_focus(id)


## Lo que hay bajo el ratón: un sistema (en la galaxia) o un cuerpo, una estación o una zona
## del sistema abierto. Se elige lo más cercano en pantalla; estaciones y zonas tienen prioridad.
func _pick(pos: Vector2) -> StringName:
	var best := &""
	var best_score := INF
	if _level == Level.GALAXY:
		for sid in _system_roots:
			var p := _system_roots[sid].global_position
			var r := _pick_radius(p, Catalog.systems[sid].star().radius * 2.0, 22.0)
			var d := _screen_dist(p, pos)
			if d < r and d < best_score:
				best_score = d
				best = sid
		return best
	# Con el sistema visto desde muy lejos sus cuerpos están ocultos: no se pueden elegir.
	if not _contents[_system.id].visible:
		return best
	for b in _system.bodies:
		var p := _nodes[b.id].global_position
		var d := _screen_dist(p, pos)
		var r := _pick_radius(p, b.radius, 12.0)
		if d < r and d + 6.0 < best_score:
			best_score = d + 6.0
			best = b.id
	var sites: Array[MapSiteData] = []
	sites.append_array(_system.stations)
	sites.append_array(_system.zones)
	for s in sites:
		var p := _nodes[s.id].global_position
		var d := _screen_dist(p, pos)
		if d < _pick_radius(p, 0.7, 16.0) and d < best_score:
			best_score = d
			best = s.id
	return best


func _screen_dist(world: Vector3, pos: Vector2) -> float:
	if not _camera.is_position_in_frustum(world):
		return INF
	return _camera.unproject_position(world).distance_to(pos)


## Radio en pantalla de algo de radio `r` en el mundo, con un mínimo para poder apuntarle.
func _pick_radius(world: Vector3, r: float, min_px: float) -> float:
	if not _camera.is_position_in_frustum(world):
		return 0.0
	var a := _camera.unproject_position(world)
	var b := _camera.unproject_position(world + _camera.global_basis.x * r)
	return maxf(a.distance_to(b), min_px)


# ---------- cada fotograma ----------

func _process(delta: float) -> void:
	_time += delta
	for i in _pivots.size():
		_pivots[i].rotation.y += _pivot_speeds[i] * delta
	var target := _focus_node.global_position if _focus_node else _focus_pos
	var k := 1.0 - exp(-5.0 * delta)
	_cur_focus = _cur_focus.lerp(target, k)
	_cur_dist = lerpf(_cur_dist, _dist, k)
	_cur_yaw = lerp_angle(_cur_yaw, _yaw, k)
	_cur_pitch = lerpf(_cur_pitch, _pitch, k)
	var offset := Vector3(cos(_cur_pitch) * sin(_cur_yaw), sin(_cur_pitch), cos(_cur_pitch) * cos(_cur_yaw))
	_camera.position = _cur_focus + offset * _cur_dist
	_camera.look_at(_cur_focus, Vector3.UP)
	# Plano cercano según la distancia: con uno fijo muy pequeño se pierde precisión de
	# profundidad y las estrellas lejanas no se dibujan.
	_camera.near = clampf(_cur_dist * 0.01, 0.05, 20.0)
	_update_visibility()
	_update_hover()
	_update_name_labels()
	_update_rings()


## Lejos (galaxia, o un sistema visto desde muy lejos) solo se ven las estrellas.
func _update_visibility() -> void:
	var show_content := _level != Level.GALAXY and _cur_dist < CONTENT_HIDE_DIST
	for sid in _contents:
		_contents[sid].visible = show_content and _system != null and sid == _system.id
	var halo_scale := maxf(1.0, _cur_dist / 380.0)
	for h in _halos:
		h.scale = Vector3.ONE * halo_scale


func _add_name_label(id: StringName, label: Label3D) -> void:
	if not _name_labels.has(id):
		_name_labels[id] = []
	_name_labels[id].append(label)
	label.visible = false


## Muestra solo el nombre de lo que está bajo el ratón y de lo elegido. Los sistemas, solo
## en la vista de la galaxia; los cuerpos y estaciones, solo dentro de su sistema.
func _update_name_labels() -> void:
	for id in _name_labels:
		var show := id == _hover_id or id == _selected_id
		if show:
			var is_system := Catalog.systems.has(id)
			show = is_system == (_level == Level.GALAXY)
		for l: Label3D in _name_labels[id]:
			l.visible = show


func _update_hover() -> void:
	var mouse := _input_area.get_local_mouse_position()
	var id := &"" if _dragging else _pick(mouse)
	if id != _hover_id:
		_hover_id = id
		if id != &"" and id != _selected_id:
			_fill_card(_card_box, id, false)
	_card.visible = _hover_id != &"" and _hover_id != _selected_id
	if _card.visible:
		_card.reset_size()
		var vp := _input_area.size
		var pos := mouse + Vector2(22, 18)
		if pos.x + _card.size.x > vp.x - 8.0:
			pos.x = mouse.x - _card.size.x - 22.0
		pos.y = clampf(pos.y, 8.0, maxf(8.0, vp.y - _card.size.y - 8.0))
		_card.position = pos


func _update_rings() -> void:
	_place_ring(_hover_ring, _hover_id, 1.25)
	_place_ring(_select_ring, _selected_id if Catalog.site(_selected_id) != null else &"", 1.4)
	var here_ok := _level != Level.GALAXY and _system != null and Catalog.system_of(GameState.location) == _system
	_place_ring(_here_ring, GameState.location if here_ok else &"", 1.1 + 0.08 * sin(_time * 4.0))


func _place_ring(ring: MeshInstance3D, id: StringName, scale_factor: float) -> void:
	if id == &"" or not _nodes.has(id) or Catalog.systems.has(id):
		ring.visible = false
		return
	ring.visible = true
	var r := 0.75
	var b := Catalog.body(id)
	if b:
		r = b.radius * 1.3
	ring.global_position = _nodes[id].global_position
	ring.scale = Vector3.ONE * r * scale_factor
	# El aro mira a la cámara para que se vea siempre redondo.
	ring.look_at(_camera.global_position, Vector3.UP)
	ring.rotate_object_local(Vector3.RIGHT, PI / 2.0)


# ---------- pruebas ----------

## `--map-test=<carpeta>`: recorre galaxia, sistema, un planeta y una zona con jefe y guarda
## capturas (con la ficha al pasar el ratón).
func _map_test() -> void:
	var dir: String = GameState.args["map-test"]
	await _shot(dir + "/map_system.png", 1.5)
	_open_galaxy()
	await _shot(dir + "/map_galaxy.png", 2.0)
	_open_system(Catalog.systems[&"thalune"])
	await _shot(dir + "/map_thalune.png", 2.0)
	_dist = 115.0
	await _shot(dir + "/map_thalune_far.png", 2.0)
	_open_system(Catalog.systems[&"thalune"])
	_focus(&"thalune_gorm")
	await _shot(dir + "/map_planet.png", 2.0)
	_open_system(Catalog.systems[&"thalune"])
	await get_tree().create_timer(1.5).timeout
	# Simula el ratón sobre la zona del jefe para ver su ficha.
	var p := _camera.unproject_position(_nodes[&"zone_fortaleza_thalune"].global_position)
	_input_area.warp_mouse(p)
	await _shot(dir + "/map_zone_card.png", 0.6)
	_open_system(Catalog.systems[&"velora"])
	await get_tree().create_timer(1.5).timeout
	p = _camera.unproject_position(_nodes[&"velora_aurel"].global_position)
	_input_area.warp_mouse(p)
	await _shot(dir + "/map_body_card.png", 0.6)
	_focus(&"zone_paso_mareth")
	await _shot(dir + "/map_zone_selected.png", 2.0)
	# Fichas de la base: un terreno propio (botón «Aterrizar») y uno a la venta.
	_focus(&"velora_odo")
	await _shot(dir + "/map_base_card.png", 2.0)
	_focus(&"velora_aurel")
	await _shot(dir + "/map_buy_card.png", 2.0)
	get_tree().quit()


func _shot(path: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("map screenshot: ", path)
