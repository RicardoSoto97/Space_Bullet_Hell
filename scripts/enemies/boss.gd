class_name Boss
extends Enemy
## Jefe (GDD 9.1): el Acorazado. Nave enorme en anillo con seis torretas. Cambia de patrón de
## balas según la vida que le queda:
## 1) espiral de tres brazos y abanicos hacia la nave;
## 2) anillos de balas, disparos de las seis torretas y escoltas de enjambre;
## 3) dos espirales en sentidos opuestos y abanicos más anchos.
## Aparece en algunas zonas al recargarse el combustible y no vuelve a aparecer.

## Radio al que están las torretas del anillo (como en el modelo de Blender).
const TURRET_RADIUS := 3.4

var boss_name: String = ""
var phase: int = 1
var _t_spiral: float = 0.0
var _t_fan: float = 2.0
var _t_ring: float = 0.5
var _t_turrets: float = 1.0
var _t_escort: float = 6.0
var _angle: float = 0.0
var _ring_offset: bool = false


func _move(delta: float, dir: Vector3, dist: float) -> void:
	# Si la nave se aleja demasiado, el acorazado reaparece cerca: no se lo puede dejar atrás.
	if dist > 32.0:
		global_position = target.global_position - dir * 22.0
		reset_physics_interpolation()
		return
	super._move(delta, dir, dist)


func _attack(delta: float, dir: Vector3, _dist: float) -> void:
	var f := hp / max_hp
	var new_phase := 1 if f > 0.66 else (2 if f > 0.33 else 3)
	if new_phase != phase:
		phase = new_phase
		stage.on_boss_phase(self, phase)
	var spd := data.bullet_speed
	var dmg := data.bullet_damage
	match phase:
		1:
			_t_spiral -= delta
			if _t_spiral <= 0.0:
				_t_spiral = 0.12 / _fire_rate
				_angle += 0.23
				for k in 3:
					fire_bullet(_dir_at(_angle + TAU * k / 3.0), spd, dmg)
			_t_fan -= delta
			if _t_fan <= 0.0:
				_t_fan = 3.5 / _fire_rate
				fire_fan(dir, 7, 50.0, spd + 1.5, dmg)
		2:
			_t_ring -= delta
			if _t_ring <= 0.0:
				_t_ring = 1.3 / _fire_rate
				_ring_offset = not _ring_offset
				var n := 28
				for k in n:
					fire_bullet(_dir_at(TAU * (float(k) + (0.5 if _ring_offset else 0.0)) / n), spd - 1.0, dmg)
			_t_turrets -= delta
			if _t_turrets <= 0.0:
				_t_turrets = 1.0 / _fire_rate
				for p in _turret_positions():
					var d := target.global_position - p
					d.y = 0.0
					fire_bullet(d.normalized(), spd + 1.0, dmg, p)
			_t_escort -= delta
			if _t_escort <= 0.0:
				_t_escort = 9.0
				stage.spawner.spawn_split(Catalog.enemies.get(&"swarm"), global_position, 6)
		3:
			_t_spiral -= delta
			if _t_spiral <= 0.0:
				_t_spiral = 0.13 / _fire_rate
				_angle += 0.21
				for k in 3:
					fire_bullet(_dir_at(_angle + TAU * k / 3.0), spd + 0.5, dmg)
					fire_bullet(_dir_at(-_angle + TAU * k / 3.0 + 0.5), spd + 0.5, dmg)
			_t_fan -= delta
			if _t_fan <= 0.0:
				_t_fan = 2.6 / _fire_rate
				fire_fan(dir, 9, 70.0, spd + 2.0, dmg)


func _dir_at(a: float) -> Vector3:
	return Vector3(sin(a), 0, cos(a))


## Posición de las seis torretas del anillo, que giran con la nave.
func _turret_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in 6:
		var a := deg_to_rad(60.0 * i)
		# En Blender las torretas están en el plano XY; en Godot, XZ (Y de Blender = -Z).
		out.append(global_transform * Vector3(cos(a) * TURRET_RADIUS, 0.0, -sin(a) * TURRET_RADIUS))
	return out


## Al morir: varias explosiones grandes y su recompensa (GDD 9.1): tecnología alienígena
## (`special_scrap` del EnemyData) y un núcleo de energía.
func die(drop_scrap: bool) -> void:
	if _dying:
		return
	if drop_scrap:
		Sfx.play(&"huge_blast")
		stage.shake(0.9)
		for i in 6:
			var off := Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
			Effects.explosion(stage, global_position + off, Color(1.0, 0.35, 0.2), randf_range(2.5, 4.5))
		# La recompensa vuela sola hacia la nave: no se pierde aunque se salte enseguida.
		stage.drop_scrap(global_position, &"scrap_metal", data.common_scrap, true)
		stage.drop_scrap(global_position, data.special_scrap.id, data.special_amount, true)
		stage.drop_scrap(global_position, &"energy_core", 1, true)
		stage.on_enemy_killed(self)
		stage.on_boss_defeated(self)
	super.die(false)
