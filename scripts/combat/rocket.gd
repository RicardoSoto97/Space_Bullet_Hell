class_name Rocket
extends Area3D
## Cohete del lanzacohetes: vuela lento y explota al chocar o al llegar a su alcance,
## dañando a todos los enemigos dentro del radio de la explosión.

static var _mesh: CapsuleMesh

var damage: float = 0.0
var radius: float = 2.0
var _velocity: Vector3 = Vector3.ZERO
var _distance_left: float = 0.0
var _color: Color = Color(1.0, 0.55, 0.15)
var _exploded: bool = false


func launch(pos: Vector3, dir: Vector3, speed: float, p_damage: float, p_radius: float,
		max_distance: float, color: Color, visual_scale: float = 1.0) -> void:
	damage = p_damage
	radius = p_radius
	_color = color
	_velocity = dir * speed
	_distance_left = max_distance
	# Capas: 3 balas del jugador; detecta la capa 2 (enemigos).
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25 * visual_scale
	shape.shape = sphere
	add_child(shape)
	if _mesh == null:
		_mesh = CapsuleMesh.new()
		_mesh.radius = 0.12
		_mesh.height = 0.6
		_mesh.radial_segments = 6
		_mesh.rings = 1
	var mesh := MeshInstance3D.new()
	mesh.mesh = _mesh
	mesh.rotation.x = -PI / 2.0
	mesh.material_override = Effects.glow_material(color)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.scale = Vector3.ONE * visual_scale
	add_child(mesh)
	global_position = pos
	rotation = Vector3(0, atan2(-dir.x, -dir.z), 0)
	reset_physics_interpolation()
	area_entered.connect(func(_a: Area3D) -> void: _explode())


func _physics_process(delta: float) -> void:
	var step := _velocity * delta
	position += step
	_distance_left -= step.length()
	if _distance_left <= 0.0:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var pos := global_position
	for e: Node3D in get_tree().get_nodes_in_group(&"enemies"):
		var extra: float = e.radius() if e.has_method(&"radius") else 0.5
		var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
		if d <= radius + extra:
			e.take_damage(damage)
	Effects.explosion(get_parent(), pos, _color, radius * 2.0)
	Effects.sparks(get_parent(), pos, _color, 6 if radius < 4.0 else 16, radius * 2.5)
	if radius >= 4.0:
		Sfx.play(&"big_blast")
		var stage := get_tree().get_first_node_in_group(&"stage") as Stage
		if stage:
			stage.shake(0.35)
	else:
		Sfx.play(&"rocket_blast")
	queue_free()
