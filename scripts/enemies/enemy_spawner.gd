class_name EnemySpawner
extends Node
## Hace aparecer enemigos fuera de la pantalla. La presión sube con el tiempo del nivel (GDD 9).
## Calendario (nivel cercano): solo enjambres hasta 1:30; luego artilleros, de a poco y cada vez
## más (`EnemyData.min_stage_time` y `spawn_ramp_seconds`); los tanques desde el minuto 4.
## Los valores son provisionales y se ajustarán jugando.

## Enemigos por segundo al empezar y cuánto suben por minuto.
## Calibrado para que la nave inicial (una metralleta, ~55 de daño por segundo) aguante un nivel
## cercano de 5 minutos esquivando, con más presión al final.
@export var base_rate: float = 1.1
@export var rate_per_minute: float = 0.4
@export var max_alive: int = 160
## Multiplicador de vida que suma por minuto.
@export var hp_per_minute: float = 0.12
## Probabilidad de élite a partir del minuto 1.
@export var elite_chance: float = 0.04
## Segundos hasta la primera oleada de enjambre.
@export var wave_interval: float = 50.0
## Cada oleada tarda estos segundos más que la anterior en llegar: las del final van más
## espaciadas (5 min: oleadas en 0:50, 1:55, 3:15 y 4:50).
@export var wave_interval_growth: float = 15.0
## Drones de cada oleada de enjambre: `wave_size` + `wave_size_per_minute` por minuto de presión.
## Fase 6: bajado de 12 + 4 a 10 + 3 (el primer nivel era muy difícil con la nave inicial).
@export var wave_size: int = 10
@export var wave_size_per_minute: float = 3.0

var stage: Stage
var _accum: float = 0.0
var _next_wave: float = 0.0
var _current_interval: float = 0.0
## Pruebas (`-- --spawn-log`): cuántos de cada tipo aparecieron en cada tramo de 30 s.
var _log_counts: Dictionary[StringName, int] = {}
var _next_log: float = 30.0


func _ready() -> void:
	_current_interval = wave_interval
	_next_wave = wave_interval


## Las zonas lejanas (más dificultad) tienen enemigos con más vida, que aparecen más seguido
## y disparan más rápido; y tipos nuevos (`EnemyData.min_difficulty`). GDD 9.
func _difficulty() -> int:
	return stage.difficulty if stage else 1


## Minutos de «presión»: en los niveles largos (zonas lejanas) la presión sigue subiendo
## después del minuto 5, pero más despacio, para que un nivel de 30 min no se desborde.
func _pressure_minutes(stage_time: float) -> float:
	var m := stage_time / 60.0
	return m if m <= 5.0 else 5.0 + (m - 5.0) * 0.35


func tick(delta: float, stage_time: float) -> void:
	var minutes := _pressure_minutes(stage_time)
	var d := float(_difficulty() - 1)
	var rate := (base_rate + rate_per_minute * minutes) * (1.0 + 0.15 * d)
	# Con el jefe en pantalla aparecen menos enemigos normales.
	if stage and stage.boss_active():
		rate *= 0.4
	_accum += rate * delta
	var alive := get_tree().get_node_count_in_group(&"enemies")
	while _accum >= 1.0:
		_accum -= 1.0
		if alive < max_alive:
			_spawn(_pick_type(stage_time), stage_time)
			alive += 1
	if GameState.args.has("spawn-log") and stage_time >= _next_log:
		print("spawn-log %d:%02d %s" % [int(_next_log) / 60, int(_next_log) % 60, str(_log_counts)])
		_log_counts.clear()
		_next_log += 30.0
	if stage_time >= _next_wave:
		if GameState.args.has("spawn-log"):
			print("spawn-log wave at %d:%02d (%d drones)" % [int(stage_time) / 60, int(stage_time) % 60, _wave_count(minutes)])
		_current_interval += wave_interval_growth
		_next_wave += _current_interval
		var swarm := Catalog.enemies.get(&"swarm") as EnemyData
		for i in _wave_count(minutes):
			if alive >= max_alive:
				break
			_spawn(swarm, stage_time)
			alive += 1


func _wave_count(minutes: float) -> int:
	return wave_size + int(minutes * wave_size_per_minute)


func _pick_type(stage_time: float) -> EnemyData:
	var total := 0.0
	var options: Array[EnemyData] = []
	for e: EnemyData in Catalog.enemies.values():
		if e.is_boss or e.min_difficulty > _difficulty():
			continue
		if e.weight_at(stage_time) > 0.0:
			options.append(e)
			total += e.weight_at(stage_time)
	var roll := randf() * total
	for e in options:
		roll -= e.weight_at(stage_time)
		if roll <= 0.0:
			return e
	return options.back()


## Enemigos que salen de un divisor al morir.
func spawn_split(data: EnemyData, pos: Vector3, count: int) -> void:
	if data == null:
		return
	for i in count:
		var enemy := Enemy.new()
		enemy.setup(data, stage, 1.0 + 0.45 * float(_difficulty() - 1), false)
		var a := TAU * float(i) / float(count) + randf() * 0.5
		enemy.position = pos + Vector3(cos(a), 0, sin(a)) * 0.9
		stage.enemy_root.add_child.call_deferred(enemy)
		enemy.ready.connect(enemy.reset_physics_interpolation, CONNECT_ONE_SHOT)


func _spawn(data: EnemyData, stage_time: float) -> void:
	if data == null:
		return
	_log_counts[data.id] = _log_counts.get(data.id, 0) + 1
	var enemy := Enemy.new()
	var d := float(_difficulty() - 1)
	var hp_mult := (1.0 + hp_per_minute * _pressure_minutes(stage_time)) * (1.0 + 0.45 * d)
	var elite := stage_time > 60.0 and randf() < elite_chance + 0.01 * d
	enemy.setup(data, stage, hp_mult, elite)
	var angle := randf() * TAU
	var dist := stage.spawn_distance()
	enemy.position = stage.ship.global_position + Vector3(cos(angle), 0, sin(angle)) * dist
	stage.enemy_root.add_child(enemy)
	enemy.reset_physics_interpolation()
