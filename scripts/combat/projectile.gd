class_name Projectile
extends Area3D
## Un proyectil reutilizable. Lo crea y recicla `ProjectilePool`.

var from_player: bool = true
var active: bool = false
var damage: float = 0.0
## Enemigos que aún puede atravesar (cañón de partículas).
var pierce: int = 0
var _hit: Array[Area3D] = []
var _velocity: Vector3 = Vector3.ZERO
var _distance_left: float = 0.0
var _pool: ProjectilePool
var _mesh: MeshInstance3D


func velocity() -> Vector3:
	return _velocity


func init(pool: ProjectilePool, p_from_player: bool, mesh: Mesh, radius: float) -> void:
	_pool = pool
	from_player = p_from_player
	monitorable = false
	# Capas: 1 piezas del jugador, 2 enemigos, 3 balas del jugador, 4 balas enemigas.
	collision_layer = 4 if from_player else 8
	collision_mask = 2 if from_player else 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if from_player:
		_mesh.rotation.x = -PI / 2.0  # la cápsula queda a lo largo de la dirección de vuelo
	add_child(_mesh)
	area_entered.connect(_on_area_entered)
	deactivate()


func activate(pos: Vector3, dir: Vector3, speed: float, p_damage: float, max_distance: float,
		color: Color, p_pierce: int = 0) -> void:
	active = true
	pierce = p_pierce
	_hit.clear()
	global_position = pos
	rotation = Vector3(0, atan2(-dir.x, -dir.z), 0)
	_velocity = dir * speed
	_distance_left = max_distance
	damage = p_damage
	reset_physics_interpolation()
	_mesh.material_override = Effects.glow_material(color)
	visible = true
	set_deferred(&"monitoring", true)
	set_physics_process(true)


func deactivate() -> void:
	active = false
	visible = false
	set_deferred(&"monitoring", false)
	set_physics_process(false)
	position = Vector3(0, -500, 0)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var step := _velocity * delta
	position += step
	_distance_left -= step.length()
	if _distance_left <= 0.0:
		_pool.release(self)


func _on_area_entered(area: Area3D) -> void:
	if not active:
		return
	if area in _hit:
		return
	if area.has_method(&"take_damage"):
		if not from_player:
			Ship.damage_source = &"bullets"
		area.take_damage(damage)
	if pierce > 0:
		pierce -= 1
		_hit.append(area)
		return
	_pool.release(self)
