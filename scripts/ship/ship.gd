class_name Ship
extends Node3D
## La nave modular del jugador. Se monta a partir de `GameState.blueprint`.
## Se mueve en todas direcciones en el plano XZ y gira, con una velocidad limitada, hacia el
## puntero del ratón (o el stick derecho del mando). La maniobrabilidad define cuánto acelera y gira.

signal destroyed
signal parts_changed
## Una pieza recibió daño (la interfaz parpadea en rojo y la cámara tiembla un poco).
signal damaged

const BASE_SPEED := 6.0
const BASE_HANDLING := 3.0
const BASE_PICKUP_RADIUS := 4.0

## En la vista previa de la estación la nave no se mueve ni dispara.
@export var preview: bool = false
## Movimiento automático para pruebas.
var autopilot: bool = false
var input_enabled: bool = true
var is_dead: bool = false

var velocity: Vector3 = Vector3.ZERO
var max_speed: float = BASE_SPEED
var handling: float = BASE_HANDLING
var pickup_radius: float = BASE_PICKUP_RADIUS

var parts: Dictionary[int, ShipPart] = {}
var core_part: ShipPart
var _time: float = 0.0
## Con qué se apunta: el ratón o el stick derecho (el último que se usó).
var _aim_with_stick: bool = false
## Último ángulo al que se apuntó (se mantiene si el stick vuelve al centro).
var _aim_yaw: float = 0.0
## Inclinación visual (solo los modelos, no las colisiones): alabeo al girar o moverse de
## lado y cabeceo al acelerar, como un avión. Así se nota que la nave es un modelo 3D.
var tilt: Basis = Basis.IDENTITY
var _roll: float = 0.0
var _pitch: float = 0.0
var _prev_yaw: float = 0.0
## Estelas de los propulsores: se encienden al moverse (GDD 10.4).
var _trails: Array[CPUParticles3D] = []
## Escudo del generador de escudo (fase 6): una burbuja que recibe el daño antes que las piezas.
var shield: float = 0.0
var shield_max: float = 0.0
var _shield_data: PartData
## Segundos que faltan para que empiece a recargarse (o a encenderse, si se rompió).
var _shield_wait: float = 0.0
var _shield_glow: float = 0.0
var _shield_bubble: MeshInstance3D
## Para las pruebas de equilibrio: daño que recibieron las piezas y el que paró el escudo.
var damage_taken: float = 0.0
## Simulaciones (`no-death`): veces que el núcleo habría llegado a 0.
var near_deaths: int = 0
var _last_near_death: float = -10.0
## Daño por origen (balas, choques de cada enemigo). Lo fija quien hace el daño justo antes.
var damage_log: Dictionary[StringName, float] = {}
static var damage_source: StringName = &"other"
var shield_absorbed: float = 0.0


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		child.queue_free()
	parts.clear()
	_trails.clear()
	core_part = null
	for i in GameState.blueprint.size():
		var e := GameState.blueprint[i]
		if e["lost"] or e["destroyed"]:
			continue
		var part := ShipPart.new()
		part.setup(self, i)
		add_child(part)
		parts[i] = part
		if part.is_core():
			core_part = part
		if e["weapon"] != &"":
			_mount_weapon(part)
		if part.data.shield_capacity > 0.0 and not preview:
			_make_shield_bubble()
		if part.data.category == PartData.Category.ENGINE and not preview:
			var trail := Effects.thruster_trail(Color(0.35, 0.85, 1.0))
			trail.position = Vector3(0, 0, 0.5)
			part.visual.add_child(trail)
			_trails.append(trail)
	_recompute_stats()
	shield = shield_max


func _mount_weapon(part: ShipPart) -> void:
	var e := part.entry
	var weapon := ShipWeapon.new()
	# Estadística de artillero con el bono de calidad de vida de las estructuras de tripulación.
	var gunnery := GameState.effective_stat(e["crew"], "gunnery")
	weapon.setup(Catalog.weapon(e["weapon"]), e["weapon_level"], gunnery, e["level"])
	weapon.position = part.data.weapon_offset
	weapon.active = e["crew"] >= 0 and not preview
	part.visual.add_child(weapon)
	part.weapon = weapon


func _recompute_stats() -> void:
	max_speed = BASE_SPEED
	handling = BASE_HANDLING
	pickup_radius = BASE_PICKUP_RADIUS
	for part: ShipPart in parts.values():
		part.bonus_armor = 0.0
	for part: ShipPart in parts.values():
		# Una placa de blindaje protege la pieza en la que está acoplada.
		var parent: int = part.entry["attached_to"]
		if part.data.category == PartData.Category.ACCESSORY and part.data.armor > 0.0 and parts.has(parent):
			parts[parent].bonus_armor += part.data.armor
		max_speed += part.data.speed
		handling += part.data.handling
		pickup_radius += part.data.pickup_radius
	if core_part:
		var e := core_part.entry
		if e["hp"] >= 0.0:
			e["hp"] = minf(e["hp"], core_part.max_hp())
	# Escudo: el del generador intacto (solo puede haber uno).
	_shield_data = null
	shield_max = 0.0
	for part: ShipPart in parts.values():
		if part.data.shield_capacity > 0.0:
			_shield_data = part.data
			shield_max = part.data.shield_at(part.entry["level"])
	shield = minf(shield, shield_max)
	if _shield_bubble and shield_max <= 0.0:
		_shield_bubble.queue_free()
		_shield_bubble = null


## Burbuja del escudo: una elipse que envuelve la nave, con un brillo en el borde (shader
## compartido) que se enciende al recibir un golpe.
func _make_shield_bubble() -> void:
	if _shield_bubble:
		return
	var box := GameState.ship_bounds()
	_shield_bubble = MeshInstance3D.new()
	_shield_bubble.name = "ShieldBubble"
	_shield_bubble.mesh = Effects.shield_mesh()
	_shield_bubble.material_override = Effects.shield_material()
	_shield_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var center := box.get_center()
	_shield_bubble.position = Vector3(center.x, 0.0, center.z)
	_shield_bubble.scale = Vector3(box.size.x * 0.72 + 0.9, 0.9, box.size.z * 0.72 + 0.9)
	add_child(_shield_bubble)


## Lo absorbe el escudo y devuelve el daño que pasa a la pieza.
func absorb_shield(amount: float) -> float:
	if shield_max <= 0.0 or _shield_data == null:
		return amount
	if shield <= 0.0:
		return amount
	_shield_glow = 1.0
	shield_absorbed += minf(amount, shield)
	if amount < shield:
		shield -= amount
		_shield_wait = maxf(_shield_wait, _shield_data.shield_delay)
		Sfx.play(&"shield_hit")
		damaged.emit()
		return 0.0
	# Se rompe: el resto del golpe pasa a la pieza y tarda en volver a encenderse.
	var rest := amount - shield
	shield = 0.0
	_shield_wait = _shield_data.shield_break_delay
	Sfx.play(&"shield_break")
	Effects.sparks(get_parent(), global_position, Color(0.4, 0.9, 1.0), 16, 9.0)
	return rest


func _tick_shield(delta: float) -> void:
	if shield_max <= 0.0 or _shield_data == null:
		return
	if _shield_wait > 0.0:
		_shield_wait -= delta
		return
	if shield < shield_max:
		if shield <= 0.0:
			Sfx.play(&"shield_up")
			_shield_glow = 0.8
		shield = minf(shield_max, shield + _shield_data.shield_recharge * delta)


func _process(delta: float) -> void:
	if _shield_bubble == null:
		return
	_shield_glow = maxf(_shield_glow - delta * 3.5, 0.0)
	var on := shield > 0.0 and not is_dead
	_shield_bubble.visible = on
	if on:
		_shield_bubble.set_instance_shader_parameter(&"glow", _shield_glow)
		_shield_bubble.set_instance_shader_parameter(&"strength", 0.45 + 0.55 * shield / shield_max)


func _physics_process(delta: float) -> void:
	if preview or is_dead:
		return
	_time += delta
	_tick_shield(delta)
	var dir := _input_dir() if input_enabled else Vector2.ZERO
	var desired := Vector3(dir.x, 0.0, dir.y) * max_speed
	var accel := 4.0 + handling * 2.0
	velocity = velocity.move_toward(desired, accel * delta)
	position += velocity * delta
	position.y = 0.0
	if input_enabled:
		_aim_yaw = _target_yaw()
	rotation.y = rotate_toward(rotation.y, _aim_yaw, turn_speed() * delta)
	_update_tilt(delta)
	var thrusting := velocity.length() > max_speed * 0.25
	for t in _trails:
		if is_instance_valid(t):
			t.emitting = thrusting


## Alabeo hacia el lado del giro y del movimiento lateral; cabeceo al acelerar o frenar.
## Se aplica a los modelos de cada pieza (`ShipPart.visual`) girando alrededor del centro de la nave.
func _update_tilt(delta: float) -> void:
	var yaw_rate := angle_difference(_prev_yaw, rotation.y) / maxf(delta, 0.0001)
	_prev_yaw = rotation.y
	var local_v := global_basis.inverse() * velocity
	var speed_ref := maxf(max_speed, 1.0)
	var target_roll := clampf(yaw_rate * 0.28 - local_v.x / speed_ref * 0.4, -0.6, 0.6)
	var target_pitch := clampf(local_v.z / speed_ref * 0.22, -0.25, 0.25)
	# Un vaivén suave aunque la nave esté quieta.
	target_roll += sin(_time * 1.3) * 0.04
	target_pitch += sin(_time * 0.9 + 1.0) * 0.03
	var k := 1.0 - exp(-6.0 * delta)
	_roll = lerpf(_roll, target_roll, k)
	_pitch = lerpf(_pitch, target_pitch, k)
	tilt = Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.FORWARD, _roll)
	for part: ShipPart in parts.values():
		part.apply_tilt(tilt)


## Velocidad de giro en radianes por segundo: no es instantánea y sube con la maniobrabilidad.
func turn_speed() -> float:
	return 1.2 + handling * 0.45


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_aim_with_stick = false
	elif event is InputEventJoypadMotion and (event.axis == JOY_AXIS_RIGHT_X or event.axis == JOY_AXIS_RIGHT_Y) \
			and absf(event.axis_value) > 0.3:
		_aim_with_stick = true


## Ángulo hacia el que quiere mirar la nave: el puntero del ratón o el stick derecho.
func _target_yaw() -> float:
	if autopilot:
		return _autopilot_yaw()
	if _aim_with_stick:
		var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
		return atan2(-stick.x, -stick.y) if stick.length() > 0.3 else _aim_yaw
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return _aim_yaw
	# El punto del plano del juego (Y = 0) que está bajo el ratón (la cámara está inclinada).
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var ray := camera.project_ray_normal(mouse)
	if absf(ray.y) < 0.001:
		return _aim_yaw
	var target := origin + ray * (-origin.y / ray.y)
	var to := Vector2(target.x - global_position.x, target.z - global_position.z)
	return atan2(-to.x, -to.y) if to.length() > 0.3 else _aim_yaw


func _input_dir() -> Vector2:
	if autopilot:
		return _autopilot_dir()
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


## Piloto automático de las pruebas: apunta al enemigo más cercano y se mueve para
## mantener la distancia (se aparta si se acerca demasiado y lo rodea si no). Además esquiva
## las balas que se le acercan y a los enemigos pegados, como un jugador cuidadoso.
func _autopilot_dir() -> Vector2:
	var base := Vector2(cos(_time * 0.6), sin(_time * 1.2) * 0.8).limit_length(1.0)
	var nearest := _nearest_enemy()
	if nearest:
		var to := Vector2(nearest.global_position.x - global_position.x, nearest.global_position.z - global_position.z)
		var dist := to.length()
		if dist < 6.0:
			base = -to.normalized().rotated(0.5)
		elif dist > 10.0:
			base = to.normalized() * 0.6
		else:
			base = to.normalized().orthogonal() * 0.7
	return (base + _autopilot_avoid() * 2.2).limit_length(1.0)


## Hacia dónde apartarse de las balas enemigas que vienen hacia la nave y de los enemigos cercanos.
func _autopilot_avoid() -> Vector2:
	var avoid := Vector2.ZERO
	var me := Vector2(global_position.x, global_position.z)
	var stage := get_parent() as Stage
	if stage and stage.projectiles:
		for child in stage.projectiles.get_children():
			var p := child as Projectile
			if p == null or not p.active or p.from_player:
				continue
			var d := me - Vector2(p.global_position.x, p.global_position.z)
			var v := Vector2(p.velocity().x, p.velocity().z)
			var speed2 := v.length_squared()
			if speed2 < 0.01 or d.length_squared() > 100.0:
				continue
			# Cuándo pasa más cerca de la nave y a qué distancia: solo esquiva las que van a darle.
			var t := d.dot(v) / speed2
			if t <= 0.0 or t > 1.4:
				continue
			var miss := d - v * t
			var miss_len := miss.length()
			if miss_len > 1.8:
				continue
			# Se aparta de lado respecto a la trayectoria, hacia donde ya iba a pasar la bala de largo.
			var side := miss / miss_len if miss_len > 0.01 else v.orthogonal().normalized()
			avoid += side * (1.8 - miss_len) / 1.8 / (t + 0.25)
	for e: Node3D in get_tree().get_nodes_in_group(&"enemies"):
		var d := me - Vector2(e.global_position.x, e.global_position.z)
		var dist := d.length()
		if dist < 3.2 and dist > 0.01:
			avoid += d / dist * (3.2 - dist) / 3.2 * 1.5
	return avoid


func _autopilot_yaw() -> float:
	var nearest := _nearest_enemy()
	if nearest == null:
		return _aim_yaw
	var to := nearest.global_position - global_position
	return atan2(-to.x, -to.z)


func _nearest_enemy() -> Node3D:
	var nearest: Node3D = null
	var best := INF
	for e: Node3D in get_tree().get_nodes_in_group(&"enemies"):
		var d := global_position.distance_squared_to(e.global_position)
		if d < best:
			best = d
			nearest = e
	return nearest


## Simulaciones (`no-death`): el núcleo queda con 1 de vida y se cuenta un «casi muere»
## (como mucho uno cada 5 s).
func on_near_death() -> void:
	if _time - _last_near_death > 5.0:
		near_deaths += 1
	_last_near_death = _time


func on_part_damaged(_part: ShipPart) -> void:
	parts_changed.emit()
	damaged.emit()


## Una pieza llegó a 0 de vida: queda totalmente destruida (GDD 3.4).
func on_part_hp_zero(part: ShipPart) -> void:
	if part == core_part:
		_die()
		return
	part.entry["destroyed"] = true
	Sfx.play(&"part_lost")
	_remove_part(part)
	_drop_disconnected()
	_recompute_stats()
	parts_changed.emit()


## Toda pieza que queda desconectada del núcleo se pierde (se puede reconstruir al 50 %).
func _drop_disconnected() -> void:
	if core_part == null:
		return
	var neighbors: Dictionary[int, Array] = {}
	for i: int in parts:
		neighbors[i] = []
	for i: int in parts:
		var parent: int = parts[i].entry["attached_to"]
		if parts.has(parent):
			neighbors[i].append(parent)
			neighbors[parent].append(i)
	var reached: Dictionary[int, bool] = {core_part.index: true}
	var queue: Array[int] = [core_part.index]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for n: int in neighbors[current]:
			if not reached.has(n):
				reached[n] = true
				queue.append(n)
	for i: int in parts.keys():
		if not reached.has(i):
			parts[i].entry["lost"] = true
			_remove_part(parts[i])


func _remove_part(part: ShipPart) -> void:
	parts.erase(part.index)
	Effects.explosion(get_parent(), part.global_position, Color(1.0, 0.6, 0.2), 2.0)
	part.queue_free()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	Sfx.play(&"huge_blast")
	for part: ShipPart in parts.values():
		Effects.explosion(get_parent(), part.global_position, Color(1.0, 0.55, 0.15), 3.0)
	visible = false
	destroyed.emit()
