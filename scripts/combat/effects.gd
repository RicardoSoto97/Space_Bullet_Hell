class_name Effects
extends RefCounted
## Efectos visuales simples y materiales compartidos.

static var _materials: Dictionary[Color, StandardMaterial3D] = {}
static var _hit_flash: StandardMaterial3D
static var _sphere: SphereMesh
static var _explosion_materials: Dictionary[Color, StandardMaterial3D] = {}


## Material emisivo sin sombreado, compartido por color.
static func glow_material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
		_materials[color] = m
	return _materials[color]


## Capa blanca que se pone sobre una pieza cuando recibe un golpe.
static func hit_flash() -> StandardMaterial3D:
	if _hit_flash == null:
		_hit_flash = StandardMaterial3D.new()
		_hit_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hit_flash.albedo_color = Color(1, 1, 1, 0.65)
		_hit_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _hit_flash


## Explosión: una esfera luminosa que crece y se desvanece.
static func explosion(parent: Node, pos: Vector3, color: Color, size: float = 1.5) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radial_segments = 12
		_sphere.rings = 6
	var mesh := MeshInstance3D.new()
	mesh.mesh = _sphere
	# Un material compartido por color: crear uno nuevo en cada explosión hacía que su primer
	# fotograma se dibujara roto (los «destellos rojos»). Se desvanece con la transparencia
	# de la instancia, no con el material.
	mesh.material_override = _explosion_material(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Se anima con un tween fuera de los ticks de física: sin interpolación.
	mesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mesh.top_level = true
	mesh.transform = Transform3D(Basis.from_scale(Vector3.ONE * size * 0.25), pos)
	parent.add_child(mesh)
	var tween := mesh.create_tween().set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3.ONE * size, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "transparency", 1.0, 0.3)
	tween.chain().tween_callback(mesh.queue_free)


## Chispas: trocitos luminosos que salen disparados en el plano y se apagan (GDD 10.4).
static func sparks(parent: Node, pos: Vector3, color: Color, count: int = 8, speed: float = 7.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh()
	p.material_override = glow_material(color)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p.top_level = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = 0.35
	p.local_coords = false
	p.direction = Vector3(1, 0, 0)
	p.spread = 180.0
	p.flatness = 1.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.2
	p.damping_max = speed * 1.8
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _fade_curve()
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Estela de un propulsor: puntos que salen hacia atrás y se encogen. Se enciende con
## `emitting` según la velocidad de la nave.
static func thruster_trail(color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh()
	p.material_override = glow_material(color)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p.amount = 18
	p.lifetime = 0.32
	p.local_coords = false
	p.direction = Vector3(0, 0, 1)
	p.spread = 9.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 4.0
	p.scale_amount_min = 0.9
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _fade_curve()
	p.emitting = false
	return p


static var _spark: BoxMesh
static var _curve: Curve
static var _shield_mesh: SphereMesh
static var _shield_material: ShaderMaterial


## Esfera para la burbuja del escudo (se escala a la forma de la nave).
static func shield_mesh() -> SphereMesh:
	if _shield_mesh == null:
		_shield_mesh = SphereMesh.new()
		_shield_mesh.radial_segments = 32
		_shield_mesh.rings = 12
		_shield_mesh.radius = 0.5
		_shield_mesh.height = 1.0
	return _shield_mesh


## Material compartido del escudo: brillo cian en el borde; cada burbuja usa sus parámetros
## de instancia `glow` (golpe) y `strength` (cuánto escudo queda).
static func shield_material() -> ShaderMaterial:
	if _shield_material == null:
		_shield_material = ShaderMaterial.new()
		_shield_material.shader = load("res://scripts/combat/shield.gdshader")
	return _shield_material


static func _spark_mesh() -> BoxMesh:
	if _spark == null:
		_spark = BoxMesh.new()
		_spark.size = Vector3(0.09, 0.09, 0.09)
	return _spark


static func _fade_curve() -> Curve:
	if _curve == null:
		_curve = Curve.new()
		_curve.add_point(Vector2(0.0, 1.0))
		_curve.add_point(Vector2(1.0, 0.0))
	return _curve


static func _explosion_material(color: Color) -> StandardMaterial3D:
	if not _explosion_materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
		_explosion_materials[color] = mat
	return _explosion_materials[color]


## Devuelve todos los MeshInstance3D debajo de un nodo.
static func find_meshes(node: Node, out: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		find_meshes(child, out)
	return out
