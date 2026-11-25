class_name EnemySpawner
extends Node
## Hace aparecer enemigos fuera de la pantalla. La presión sube con el tiempo del nivel (GDD 9).
## Calendario (nivel cercano): solo enjambres hasta 1:30; luego artilleros, de a poco y cada vez
## más (`EnemyData.min_stage_time` y `spawn_ramp_seconds`); los tanques desde el minuto 4.
## Los números están en `Catalog.balance` (`data/balance/stage_balance.tres`).

var stage: Stage
var _accum: float = 0.0
var _next_wave: float = 0.0
var _current_interval: float = 0.0
## Pruebas (`-- --spawn-log`): cuántos de cada tipo aparecieron en cada tramo de 30 s.
var _log_counts: Dictionary[StringName, int] = {}
var _next_log: float = 30.0


func _ready() -> void:
	_current_interval = Catalog.balance.wave_interval
	_next_wave = _current_interval


## Las zonas lejanas (más dificultad) tienen enemigos con más vida, que aparecen más seguido
## y disparan más rápido; y tipos nuevos (`EnemyData.min_difficulty`). GDD 9.
func _difficulty() -> int:
	return stage.difficulty if stage else 1


## Multiplicador de vida de los enemigos en este momento del nivel.
func hp_multiplier(stage_time: float) -> float:
	var b := Catalog.balance
	return (1.0 + b.hp_per_minute * b.pressure_minutes(stage_time)) * (1.0 + b.hp_per_difficulty * float(_difficulty() - 1))


func tick(delta: float, stage_time: float) -> void:
	var b := Catalog.balance
	var minutes := b.pressure_minutes(stage_time)
	var d := float(_difficulty() - 1)
	var rate := (b.base_rate + b.rate_per_minute * minutes) * (1.0 + b.rate_per_difficulty * d)
	# Con el jefe en pantalla aparecen menos enemigos normales.
	if stage and stage.boss_active():
		rate *= 0.4
	_accum += rate * delta
	var alive := get_tree().get_node_count_in_group(&"enemies")
	while _accum >= 1.0:
		_accum -= 1.0
		if alive < b.max_alive:
			_spawn(_pick_type(stage_time), stage_time)
			alive += 1
	if GameState.args.has("spawn-log") and stage_time >= _next_log:
		print("spawn-log %d:%02d %s" % [int(_next_log) / 60, int(_next_log) % 60, str(_log_counts)])
		_log_counts.clear()
		_next_log += 30.0
	if stage_time >= _next_wave:
		if GameState.args.has("spawn-log"):
			print("spawn-log wave at %d:%02d (%d drones)" % [int(stage_time) / 60, int(stage_time) % 60, _wave_count(minutes)])
		_current_interval += b.wave_interval_growth
		_next_wave += _current_interval
		var swarm := Catalog.enemies.get(&"swarm") as EnemyData
		for i in _wave_count(minutes):
			if alive >= b.max_alive:
				break
			_spawn(swarm, stage_time)
			alive += 1


func _wave_count(minutes: float) -> int:
	return Catalog.balance.wave_size + int(minutes * Catalog.balance.wave_size_per_minute)


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
		enemy.setup(data, stage, 1.0 + Catalog.balance.hp_per_difficulty * float(_difficulty() - 1), false)
		var a := TAU * float(i) / float(count) + randf() * 0.5
		enemy.position = pos + Vector3(cos(a), 0, sin(a)) * 0.9
		stage.enemy_root.add_child.call_deferred(enemy)
		enemy.ready.connect(enemy.reset_physics_interpolation, CONNECT_ONE_SHOT)


func _spawn(data: EnemyData, stage_time: float) -> void:
	if data == null:
		return
	_log_counts[data.id] = _log_counts.get(data.id, 0) + 1
	var enemy := Enemy.new()
	var b := Catalog.balance
	var elite := stage_time > 60.0 and randf() < b.elite_chance + b.elite_chance_per_difficulty * float(_difficulty() - 1)
	enemy.setup(data, stage, hp_multiplier(stage_time), elite)
	var angle := randf() * TAU
	var dist := stage.spawn_distance()
	enemy.position = stage.ship.global_position + Vector3(cos(angle), 0, sin(angle)) * dist
	stage.enemy_root.add_child(enemy)
	enemy.reset_physics_interpolation()
