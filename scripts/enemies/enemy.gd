class_name Enemy
extends Area3D
## Un enemigo (GDD 9). Según su `EnemyData`: persigue a la nave, se mantiene a distancia y
## dispara, o embiste en línea recta. Algunos dejan minas o se dividen al morir.

const ELITE_SCRAP := &"energy_core"
const MINE_COLOR := Color(1.0, 0.55, 0.1)

var data: EnemyData
var target: Ship
var stage: Stage
var elite: bool = false
var hp: float = 1.0
var max_hp: float = 1.0
var _dying: bool = false
var _fire_timer: float = 0.0
var _mine_timer: float = 0.0
var _contact_timer: float = 0.0
var _spiral: float = 0.0
var _meshes: Array[MeshInstance3D] = []
var _flash_left: float = 0.0
## Lado hacia el que rodea a la nave (artilleros).
var _strafe_sign: float = 1.0
## Las zonas lejanas disparan más rápido (+12 % de cadencia por punto de dificultad).
var _fire_rate: float = 1.0
## Embestida (lanceros): 0 acercarse, 1 apuntar, 2 embestir, 3 recuperarse.
var _dash_state: int = 0
var _dash_timer: float = 0.0
var _dash_dir: Vector3 = Vector3.FORWARD
var _model: Node3D
# Movimiento del modelo (visual): alabeo al girar, piruetas y bamboleos.
var _prev_yaw: float = 0.0
var _bank: float = 0.0
var _flip: float = 0.0
var _flip_cd: float = 0.0
var _flipped_close: bool = false
var _anim_time: float = 0.0


func setup(p_data: EnemyData, p_stage: Stage, hp_multiplier: float, p_elite: bool) -> void:
	data = p_data
	stage = p_stage
	target = stage.ship
	elite = p_elite
	hp = data.max_hp * hp_multiplier * (4.0 if elite else 1.0)
	max_hp = hp
	add_to_group(&"enemies")
	# Capa 2 (enemigos); detecta la capa 1 (piezas de la nave) para el daño por contacto.
	collision_layer = 2
	collision_mask = 1
	_model = data.model.instantiate() as Node3D
	add_child(_model)
	if elite:
		_model.scale = Vector3.ONE * 1.35
	_meshes = Effects.find_meshes(_model)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = data.collision_radius * (1.35 if elite else 1.0)
	shape.shape = sphere
	add_child(shape)
	_fire_rate = 1.0 + Catalog.balance.fire_rate_per_difficulty * float(stage.difficulty - 1)
	_fire_timer = randf_range(0.5, data.fire_interval) if data.fire_interval > 0.0 else 0.0
	_mine_timer = randf_range(0.5, data.mine_interval) if data.mine_interval > 0.0 else 0.0
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_flip_cd = randf_range(2.0, 7.0)
	_anim_time = randf() * 10.0
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _dying or target == null or target.is_dead:
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	_move(delta, dir, dist)
	_animate(delta, dist)
	_attack(delta, dir, dist)

	if not data.dies_on_contact:
		_contact_timer -= delta
		if _contact_timer <= 0.0:
			for area in get_overlapping_areas():
				if area is ShipPart:
					Ship.damage_source = StringName("contact_" + data.id)
					area.take_damage(data.contact_damage)
					_contact_timer = data.contact_interval
					break

	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			for m in _meshes:
				m.material_overlay = null


func _move(delta: float, dir: Vector3, dist: float) -> void:
	var move := dir
	var speed := data.speed
	match data.behavior:
		EnemyData.Behavior.KEEP_DISTANCE:
			var tangent := Vector3(-dir.z, 0, dir.x) * _strafe_sign
			if dist > data.preferred_distance + 1.5:
				move = dir
			elif dist < data.preferred_distance - 1.5:
				move = -dir
			else:
				move = tangent
		EnemyData.Behavior.DASH:
			_dash_timer -= delta
			match _dash_state:
				0:  # se acerca hasta tener a la nave a tiro
					if dist < data.dash_range:
						_dash_state = 1
						_dash_timer = data.dash_windup
				1:  # se frena y apunta: avisa de la embestida
					speed = 0.0
					move = dir
					_model.scale = Vector3.ONE * (1.0 + 0.12 * sin(_dash_timer * 40.0)) * (1.35 if elite else 1.0)
					if _dash_timer <= 0.0:
						_dash_state = 2
						_dash_timer = data.dash_time
						_dash_dir = dir
						_model.scale = Vector3.ONE * (1.35 if elite else 1.0)
				2:  # embiste en línea recta
					move = _dash_dir
					speed = data.dash_speed
					if _dash_timer <= 0.0:
						_dash_state = 3
						_dash_timer = data.dash_cooldown
				3:  # se recupera alejándose un poco
					speed = data.speed * 0.5
					move = -dir
					if _dash_timer <= 0.0:
						_dash_state = 0
	global_position += move * speed * delta
	var face := _dash_dir if _dash_state == 2 else move
	rotation.y = rotate_toward(rotation.y, atan2(-face.x, -face.z), data.turn_speed * delta)


## Mueve el modelo (no la colisión, que es una esfera) para que se note que es 3D.
func _animate(delta: float, dist: float) -> void:
	_anim_time += delta
	var yaw_rate := angle_difference(_prev_yaw, rotation.y) / maxf(delta, 0.0001)
	_prev_yaw = rotation.y
	var k := 1.0 - exp(-5.0 * delta)
	var t := _anim_time
	var pitch := 0.0
	var roll := 0.0
	var spin := 0.0
	match data.motion:
		EnemyData.Motion.FIGHTER:
			_bank = lerpf(_bank, clampf(yaw_rate * 0.3, -0.8, 0.8), k)
			roll = _bank
			# Pirueta de 360° al acercarse a la nave, y de vez en cuando.
			_flip_cd -= delta
			if _flip <= 0.0 and ((dist < 7.0 and not _flipped_close) or _flip_cd <= 0.0):
				_flipped_close = _flipped_close or dist < 7.0
				_flip = TAU
				_flip_cd = randf_range(4.0, 9.0)
			roll += _advance_flip(delta, 0.55)
		EnemyData.Motion.HEAVY:
			_bank = lerpf(_bank, clampf(yaw_rate * 0.2, -0.3, 0.3), k)
			roll = _bank + sin(t * 1.4) * 0.08
			pitch = sin(t * 1.1) * 0.1
		EnemyData.Motion.SPINNER:
			# Como un trompo: el disco gira y su eje describe un círculo.
			pitch = sin(t * 2.6) * 0.38
			roll = cos(t * 2.6) * 0.38
			spin = t * 2.0
		EnemyData.Motion.GLIDER:
			_bank = lerpf(_bank, clampf(yaw_rate * 0.7, -0.9, 0.9), k)
			roll = _bank
			pitch = sin(t * 2.2) * 0.15
		EnemyData.Motion.TUMBLER:
			pitch = t * 1.7
			roll = sin(t * 0.9) * 0.9
		EnemyData.Motion.LANCER:
			_bank = lerpf(_bank, clampf(yaw_rate * 0.3, -0.8, 0.8), k)
			roll = _bank
			if _dash_state == 1:
				pitch = 0.35  # levanta el morro antes de embestir
			elif _dash_state == 2 and _flip <= 0.0:
				_flip = TAU
			roll += _advance_flip(delta, data.dash_time)
		EnemyData.Motion.BOSS:
			pitch = sin(t * 0.7) * 0.12
			roll = cos(t * 0.5) * 0.12
	_model.rotation = Vector3(pitch, spin, roll)


## Avanza la pirueta en curso (`_flip` = ángulo que falta) y devuelve el giro a sumar.
func _advance_flip(delta: float, seconds: float) -> float:
	if _flip <= 0.0:
		return 0.0
	_flip = maxf(_flip - delta * TAU / maxf(seconds, 0.1), 0.0)
	return TAU - _flip


## Disparo y minas. Los jefes lo reemplazan por sus patrones.
func _attack(delta: float, dir: Vector3, dist: float) -> void:
	if data.bullets_per_burst > 0 and dist < data.preferred_distance + 6.0:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = data.fire_interval / _fire_rate
			if data.aimed:
				fire_fan(dir, data.bullets_per_burst, data.fan_degrees, data.bullet_speed, data.bullet_damage)
			else:
				_fire_burst()
	if data.mine_interval > 0.0 and dist < data.preferred_distance + 8.0:
		_mine_timer -= delta
		if _mine_timer <= 0.0:
			_mine_timer = data.mine_interval / _fire_rate
			_lay_mine()


## Ráfaga en círculo que gira un poco cada vez: forma espirales de balas.
func _fire_burst() -> void:
	var n := data.bullets_per_burst
	_spiral += 0.35
	for i in n:
		var angle := _spiral + TAU * float(i) / float(n)
		fire_bullet(Vector3(sin(angle), 0, cos(angle)), data.bullet_speed, data.bullet_damage)


## Abanico de `n` balas hacia `dir`, repartidas en `degrees` grados.
func fire_fan(dir: Vector3, n: int, degrees: float, speed: float, damage: float, from: Vector3 = Vector3.INF) -> void:
	for i in n:
		var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5
		fire_bullet(dir.rotated(Vector3.UP, deg_to_rad(degrees) * t), speed, damage, from)


func fire_bullet(d: Vector3, speed: float, damage: float, from: Vector3 = Vector3.INF) -> void:
	var origin := global_position if from == Vector3.INF else from
	stage.projectiles.spawn(false, origin + d * radius() * 0.8, d, speed, damage, 26.0)
	Sfx.play(&"enemy_shot")


## Mina: una bala casi quieta que dura varios segundos detrás del sembrador.
func _lay_mine() -> void:
	var back := global_basis.z
	back.y = 0.0
	var drift := back.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
	stage.projectiles.spawn(false, global_position + back.normalized() * radius(), drift, 0.35,
			data.mine_damage, 0.35 * data.mine_lifetime, MINE_COLOR)


func _on_area_entered(area: Area3D) -> void:
	if _dying or not (area is ShipPart):
		return
	if data.dies_on_contact:
		Ship.damage_source = StringName("contact_" + data.id)
		area.take_damage(data.contact_damage)
		die(false)


## Radio de la colisión (para el daño en área y los rayos).
func radius() -> float:
	return data.collision_radius * (1.35 if elite else 1.0)


func take_damage(amount: float) -> void:
	if _dying:
		return
	hp -= amount
	if _flash_left <= 0.0:
		for m in _meshes:
			m.material_overlay = Effects.hit_flash()
	_flash_left = 0.06
	if hp <= 0.0:
		die(true)


func die(drop_scrap: bool) -> void:
	if _dying:
		return
	_dying = true
	remove_from_group(&"enemies")
	Effects.explosion(stage, global_position, Color(1.0, 0.35, 0.2), 1.6 if not elite else 3.0)
	Effects.sparks(stage, global_position, Color(1.0, 0.92, 0.65), 7 if not elite else 14, 7.0)
	if elite:
		Sfx.play(&"elite_death")
		stage.shake(0.2)
	else:
		Sfx.play(&"enemy_death")
	if drop_scrap:
		stage.drop_scrap(global_position, &"scrap_metal", data.common_scrap)
		if data.special_scrap and randf() < data.special_chance:
			stage.drop_scrap(global_position, data.special_scrap.id, data.special_amount)
		if elite:
			stage.drop_scrap(global_position, ELITE_SCRAP, 1)
		stage.on_enemy_killed(self)
		# Divisores: se separan en enemigos más pequeños.
		if data.split_into != &"" and data.split_count > 0:
			stage.spawner.spawn_split(Catalog.enemies.get(data.split_into), global_position, data.split_count)
	queue_free()
