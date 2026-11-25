class_name ShipWeapon
extends Node3D
## Arma montada en una estación de mando. Dispara sola al enemigo más cercano que esté
## dentro de su cono, hacia el frente de la estación: para apuntar hay que girar la nave.
## Necesita un tripulante; su estadística de artillero sube el daño y la cadencia.

var data: WeaponData
var level: int = 1
## Sin tripulante, el arma no dispara.
var active: bool = true
var damage: float = 0.0
var interval: float = 0.2
var area_radius: float = 0.0
var _cooldown: float = 0.0
var _model: Node3D
var _pool: ProjectilePool
var _beam: MeshInstance3D
var _cone_cos: float = 0.0


## `crew_multiplier` reúne la estadística de artillero y los bonos de calidad de vida.
func setup(p_data: WeaponData, p_level: int, gunnery: float, station_level: int) -> void:
	data = p_data
	level = p_level
	var crew_bonus := 1.0 + gunnery / 200.0
	var station_bonus := 1.0 + 0.05 * float(station_level - 1)
	damage = data.damage_at(level) * crew_bonus * station_bonus
	interval = data.fire_interval / crew_bonus
	if data.kind == WeaponData.Kind.BEAM:
		# El rayo no tiene cadencia: el bono de cadencia también se aplica al daño.
		damage *= crew_bonus
	area_radius = data.area_at(level)
	_cone_cos = cos(deg_to_rad(data.aim_cone_degrees))
	_model = data.model.instantiate() as Node3D
	add_child(_model)


func _physics_process(delta: float) -> void:
	if not active:
		return
	if _pool == null:
		_pool = get_tree().get_first_node_in_group(&"projectile_pool") as ProjectilePool
		if _pool == null:
			return
	_cooldown -= delta
	var target := _find_target()
	if target == null:
		_model.rotation = Vector3.ZERO
		_set_beam(false)
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dir := to.normalized()
	var local := global_basis.inverse() * dir
	_model.rotation = Vector3(0, atan2(-local.x, -local.z), 0)
	if data.kind == WeaponData.Kind.BEAM:
		_fire_beam(dir, delta)
	elif _cooldown <= 0.0:
		_cooldown = interval
		_fire(dir)


## Frente de la estación de mando en el plano (las armas miran hacia -Z).
func forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized()


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_d := data.weapon_range * data.weapon_range
	var fw := forward()
	for e: Node3D in get_tree().get_nodes_in_group(&"enemies"):
		var to := e.global_position - global_position
		to.y = 0.0
		var d := to.length_squared()
		if d >= best_d or d < 0.0001:
			continue
		if fw.dot(to / sqrt(d)) < _cone_cos:
			continue
		best_d = d
		best = e
	return best


func _fire(dir: Vector3) -> void:
	var spread := deg_to_rad(randf_range(-data.spread_degrees, data.spread_degrees))
	dir = dir.rotated(Vector3.UP, spread)
	var muzzle := global_position + dir * 1.0
	_play_shot()
	if data.kind == WeaponData.Kind.ROCKET:
		var rocket := Rocket.new()
		_pool.add_child(rocket)
		rocket.launch(muzzle, dir, data.projectile_speed, damage, area_radius, data.weapon_range + 2.0,
				data.projectile_color, data.projectile_scale)
		return
	# Varios cañones: proyectiles paralelos separados 0,24 m. Varios perdigones: en abanico.
	var side := Vector3(-dir.z, 0, dir.x)
	for b in data.barrels:
		var offset := side * 0.24 * (float(b) - float(data.barrels - 1) / 2.0)
		for k in data.pellets:
			var t := 0.0 if data.pellets == 1 else float(k) / float(data.pellets - 1) - 0.5
			var d := dir.rotated(Vector3.UP, deg_to_rad(data.pellet_spread_degrees) * t)
			_pool.spawn(true, muzzle + offset, d, data.projectile_speed, damage, data.weapon_range + 2.0,
					data.projectile_color, data.pierce)


## Rayo continuo: daña cada tick a todos los enemigos que toca a lo largo de la línea.
## Sonido del disparo según el tipo de arma.
func _play_shot() -> void:
	if data.kind == WeaponData.Kind.ROCKET:
		Sfx.play(&"rocket_launch", 0.0, 0.8 if area_radius > 4.0 else 1.0)
	elif data.pellets > 1:
		Sfx.play(&"shot_flak")
	elif data.pierce > 0:
		Sfx.play(&"shot_heavy")
	else:
		Sfx.play(&"shot_gun", 0.0, 0.9 if data.barrels > 1 else 1.0)


func _fire_beam(dir: Vector3, delta: float) -> void:
	var origin := global_position + dir * 0.9
	var length := data.weapon_range
	var half_width := data.beam_width * 0.5
	for e: Node3D in get_tree().get_nodes_in_group(&"enemies"):
		var rel := e.global_position - origin
		rel.y = 0.0
		var along := rel.dot(dir)
		if along < 0.0 or along > length:
			continue
		var radius: float = e.radius() if e.has_method(&"radius") else 0.5
		if (rel - dir * along).length() <= half_width + radius:
			e.take_damage(damage * delta)
	_set_beam(true)
	Sfx.beam_on()
	_beam.global_transform = Transform3D(Basis.looking_at(dir), origin + dir * length * 0.5)
	_beam.scale = Vector3(data.beam_width, 0.12, length)


func _set_beam(on: bool) -> void:
	if not on:
		if _beam:
			_beam.visible = false
		return
	if _beam == null:
		_beam = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		_beam.mesh = box
		_beam.material_override = Effects.glow_material(data.projectile_color)
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beam.top_level = true
		_beam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_beam)
	_beam.visible = true
