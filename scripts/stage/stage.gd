class_name Stage
extends Node3D
## Un nivel: una zona de enemigos. Dura lo que tarda en recargarse el combustible
## interestelar (GDD 5.4). Con el combustible lleno, el jugador decide cuándo saltar.

const CAMERA_HEIGHT := 40.0
## La cámara no mira justo desde arriba: se inclina unos grados para que se vean los
## costados de las naves y se note que son modelos 3D. La cámara sigue siendo ortográfica.
const CAMERA_TILT_DEG := 10.0
## Metros visibles en vertical con la cámara ortográfica.
const CAMERA_SIZE := 24.0
## Segundos que hay que mantener la tecla de salto para saltar.
const JUMP_HOLD_SECONDS := 2.0
## Segundos entre la recarga del combustible y la llegada del jefe (GDD 9.1).
const BOSS_DELAY := 5.0
const STAR_SHADER := preload("res://scripts/stage/star_background.gdshader")

var ship: Ship
var projectiles: ProjectilePool
var enemy_root: Node3D
var scrap_root: Node3D
var spawner: EnemySpawner
var hud: StageHud
var camera: Camera3D

var time: float = 0.0
var duration: float = 300.0
## Zona de enemigos de este nivel y su dificultad (1–6).
var zone: ZoneData
var difficulty: int = 1
## Destino del salto, elegido en el mapa estelar cuando el combustible está recargado.
var destination: StringName = &""
var star_map: StarMap
var _map_closed_frame: int = -10
## Jefe de la zona: `boss_pending` mientras no esté derrotado (aunque todavía no haya llegado).
## Mientras tanto, saltar es huir: hay que mantener la tecla el doble de tiempo.
var boss: Boss
var boss_pending: bool = false
var boss_timer: float = -1.0
var _boss_fled: bool = false
var _boss_killed_here: bool = false
var fuel_ready: bool = false
## Cuánto lleva el jugador manteniendo la tecla de salto (segundos).
var jump_hold: float = 0.0
var kills: int = 0
var collected: int = 0
var _ending: bool = false
var _star_material: ShaderMaterial
var _cleanup_timer: float = 0.0
var _screenshot_done: bool = false
## Sacudida de la cámara (0–1): sube con los golpes y las explosiones grandes y baja sola.
var _trauma: float = 0.0
var _cam_base: Vector3
var _scrap_lost_value: int = 0
## Pruebas automáticas: al destruirse la nave, se reaparece sin pulsar el botón.
var _auto_respawn: bool = false


func _ready() -> void:
	add_to_group(&"stage")
	_auto_respawn = GameState.args.has("destroy-at") or GameState.args.has("autopilot") or GameState.args.has("auto-jump")
	# Pruebas de equilibrio: `--time-scale=N` acelera el tiempo (con más ticks de física para
	# que las balas no atraviesen nada).
	if GameState.args.has("time-scale"):
		var ts := float(GameState.args["time-scale"])
		Engine.time_scale = ts
		Engine.physics_ticks_per_second = roundi(60 * ts)
		Engine.max_physics_steps_per_frame = roundi(8 * ts)
	# Se apunta con el ratón: cursor en forma de mira mientras dura el nivel.
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	tree_exiting.connect(func() -> void: Input.set_default_cursor_shape(Input.CURSOR_ARROW))
	duration = GameState.stage_duration
	zone = GameState.current_zone()
	difficulty = zone.difficulty() if zone else 1
	boss_pending = zone != null and zone.has_boss() and not GameState.is_boss_defeated(zone.id)
	_build_environment()

	ship = Ship.new()
	ship.name = "Ship"
	ship.autopilot = GameState.args.has("autopilot")
	add_child(ship)
	ship.destroyed.connect(_on_ship_destroyed)

	projectiles = ProjectilePool.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	enemy_root = Node3D.new()
	enemy_root.name = "Enemies"
	add_child(enemy_root)
	scrap_root = Node3D.new()
	scrap_root.name = "Scrap"
	add_child(scrap_root)

	spawner = EnemySpawner.new()
	spawner.stage = self
	add_child(spawner)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.far = 200.0
	camera.rotation_degrees = Vector3(-90.0 + CAMERA_TILT_DEG, 0, 0)
	camera.position = camera_offset()
	_cam_base = camera.position
	# La cámara se mueve en _process siguiendo la posición interpolada de la nave.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	camera.make_current()

	hud = StageHud.new()
	hud.stage = self
	add_child(hud)
	ship.parts_changed.connect(hud.refresh_ship)
	ship.damaged.connect(func() -> void: shake(0.12))
	Sfx.play(&"jump", -4.0, 1.3)
	# Compila el material de las explosiones con una explosión diminuta, para que la primera
	# de verdad no se dibuje rota en su primer fotograma.
	Effects.explosion(self, ship.global_position, Color(1.0, 0.35, 0.2), 0.02)


func _build_environment() -> void:
	# El fondo 2D (capas de canvas por debajo de 0) se dibuja detrás del mundo 3D.
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.42, 0.5)
	env.ambient_light_energy = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -35, 0)
	sun.light_energy = 1.3
	add_child(sun)

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_star_material = ShaderMaterial.new()
	_star_material.shader = STAR_SHADER
	rect.material = _star_material
	bg_layer.add_child(rect)


func _physics_process(delta: float) -> void:
	if _ending:
		return
	time += delta
	# Pruebas: `--destroy-at=N` destruye la nave a los N segundos.
	if GameState.args.has("destroy-at") and time >= float(GameState.args["destroy-at"]) and ship.core_part:
		GameState.args.erase("destroy-at")
		ship.core_part.take_damage(1.0e9, true)
	spawner.tick(delta, time)
	# Pruebas: `--perf-log` imprime cada 10 s los FPS y cuántos enemigos y balas hay.
	if GameState.args.has("perf-log") and int(time / 10.0) != int((time - delta) / 10.0):
		var bullets := 0
		for p in projectiles.get_children():
			if p is Projectile and (p as Projectile).active:
				bullets += 1
		print("perf t=%d fps=%d enemies=%d bullets=%d scrap=%d nodes=%d" % [time, Engine.get_frames_per_second(),
				get_tree().get_node_count_in_group(&"enemies"), bullets, scrap_root.get_child_count(),
				get_tree().get_node_count()])
	if not fuel_ready and time >= duration:
		fuel_ready = true
		if GameState.args.has("balance-run"):
			_balance_report(true)
		if boss_pending:
			boss_timer = BOSS_DELAY
			hud.show_alert("¡PELIGRO INMINENTE!", "Se acerca %s" % zone.boss_name, BOSS_DELAY)
			Sfx.play(&"boss_alert")
	if boss_timer > 0.0:
		boss_timer -= delta
		if boss_timer <= 0.0:
			_spawn_boss()
	_update_scrap(delta)
	_cleanup_timer -= delta
	if _cleanup_timer <= 0.0:
		_cleanup_timer = 1.0
		_despawn_far_enemies()


func _process(delta: float) -> void:
	# Con la interpolación física, la nave se dibuja entre dos ticks: la cámara sigue esa
	# posición interpolada para que la nave no tiemble al moverse.
	var target := ship.get_global_transform_interpolated().origin + camera_offset()
	_cam_base = _cam_base.lerp(target, 1.0 - exp(-8.0 * delta))
	camera.position = _cam_base + _shake_offset(delta)
	var px_per_m := get_viewport().get_visible_rect().size.y / camera.size
	_star_material.set_shader_parameter(&"offset", Vector2(camera.position.x, camera.position.z) * px_per_m)

	if star_map == null and not _ending and not ship.is_dead and Input.is_action_just_pressed(&"star_map") \
			and not get_tree().paused and Engine.get_process_frames() > _map_closed_frame + 1:
		open_star_map()
	if fuel_ready and not _ending and star_map == null:
		if GameState.args.has("auto-jump"):
			if not boss_pending:
				destination = _auto_destination()
				_leave_stage()
		elif Input.is_action_pressed(&"jump") and not get_tree().paused:
			if destination == &"":
				# Sin destino, mantener el salto abre el mapa para elegirlo.
				open_star_map()
			else:
				if jump_hold <= 0.0 and jump_hold + delta > 0.0:
					Sfx.play(&"jump_charge")
				jump_hold += delta
				if jump_hold >= jump_hold_needed():
					_boss_fled = boss_pending
					_leave_stage()
		else:
			jump_hold = 0.0
	_debug_screenshot()
	if GameState.args.has("ui-test") and time > 3.0 and not get_tree().paused and not has_meta(&"ui_tested"):
		set_meta(&"ui_tested", true)
		hud.ui_test(GameState.args["ui-test"])


## Sacude la cámara (GDD 10.4: sutil). Se puede desactivar en las opciones.
func shake(amount: float) -> void:
	if Settings.camera_shake:
		_trauma = minf(_trauma + amount, 1.0)


func _shake_offset(delta: float) -> Vector3:
	if _trauma <= 0.0:
		return Vector3.ZERO
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	var k := _trauma * _trauma * 0.7
	var t := Time.get_ticks_msec() * 0.001
	return Vector3(sin(t * 47.0) + sin(t * 31.0) * 0.5, 0.0, cos(t * 41.0) + cos(t * 23.0) * 0.5) * k


## Posición de la cámara respecto de la nave: arriba y un poco hacia atrás (inclinada).
func camera_offset() -> Vector3:
	var t := deg_to_rad(CAMERA_TILT_DEG)
	return Vector3(0, CAMERA_HEIGHT * cos(t), CAMERA_HEIGHT * sin(t))


## Distancia a la que aparecen los enemigos: justo fuera de la pantalla.
func spawn_distance() -> float:
	var vp := get_viewport().get_visible_rect().size
	# Con la cámara inclinada, la pantalla abarca más suelo en vertical.
	var half_h := camera.size / 2.0 / cos(deg_to_rad(CAMERA_TILT_DEG))
	var half_w := half_h * vp.x / vp.y
	return Vector2(half_w, half_h).length() + 2.0


func drop_scrap(pos: Vector3, type_id: StringName, amount: int, attracted: bool = false) -> void:
	var type := Catalog.scrap(type_id)
	if type == null:
		return
	for i in amount:
		var p := ScrapPickup.new()
		p.setup(type)
		p.position = Vector3(pos.x + randf_range(-0.6, 0.6), 0.0, pos.z + randf_range(-0.6, 0.6))
		p.attracted = attracted
		scrap_root.add_child(p)
		p.reset_physics_interpolation()


func is_ending() -> bool:
	return _ending


func on_enemy_killed(_enemy: Enemy) -> void:
	kills += 1


func _update_scrap(delta: float) -> void:
	if ship.is_dead:
		return
	var radius := ship.pickup_radius
	for node in scrap_root.get_children():
		var p := node as ScrapPickup
		var d := p.position.distance_to(ship.position)
		if p.attracted or d < radius:
			p.attracted = true
			p.speed += 40.0 * delta
			p.position = p.position.move_toward(ship.position, (6.0 + p.speed) * delta)
			if d < 0.9:
				GameState.add_scrap(p.type_id)
				Sfx.play_scrap()
				collected += 1
				p.queue_free()


func _despawn_far_enemies() -> void:
	var max_d := spawn_distance() * 2.0
	for e: Node3D in get_tree().get_nodes_in_group(&"enemies"):
		if e is Boss:
			continue
		if e.global_position.distance_to(ship.global_position) > max_d:
			e.queue_free()


## Segundos que hay que mantener el salto: el doble si hay un jefe sin derrotar (huir).
func jump_hold_needed() -> float:
	return JUMP_HOLD_SECONDS * (2.0 if boss_pending else 1.0)


func boss_active() -> bool:
	return boss != null and is_instance_valid(boss)


func _spawn_boss() -> void:
	var data := Catalog.enemies.get(zone.boss) as EnemyData
	if data == null:
		boss_pending = false
		return
	boss = Boss.new()
	boss.boss_name = zone.boss_name
	boss.setup(data, self, 1.0 + Catalog.balance.boss_hp_per_difficulty * float(difficulty - 1), false)
	var a := randf() * TAU
	boss.position = ship.global_position + Vector3(cos(a), 0, sin(a)) * (spawn_distance() + 2.0)
	enemy_root.add_child(boss)
	boss.reset_physics_interpolation()
	hud.show_boss(boss)


func on_boss_phase(_b: Boss, phase: int) -> void:
	Sfx.play(&"boss_phase")
	shake(0.3)
	hud.show_alert("¡%s se enfurece!" % zone.boss_name, "Fase %d de 3" % phase, 2.0)


func on_boss_defeated(_b: Boss) -> void:
	_boss_killed_here = true
	boss_pending = false
	boss = null
	if zone and not GameState.is_boss_defeated(zone.id):
		GameState.defeated_bosses.append(zone.id)
	hud.show_alert("¡Jefe derrotado!", "%s no volverá a aparecer" % zone.boss_name, 3.0)
	Sfx.play(&"boss_defeated")
	print("boss defeated at t=%.1f" % time)


## Abre el mapa estelar con el nivel en pausa. Con el combustible recargado sirve para elegir
## el destino del salto; antes, solo para mirar.
func open_star_map() -> void:
	if star_map != null:
		return
	jump_hold = 0.0
	star_map = StarMap.new()
	star_map.setup(StarMap.Mode.STAGE_READY if fuel_ready else StarMap.Mode.VIEW)
	star_map.destination_chosen.connect(_on_destination_chosen)
	star_map.closed.connect(_on_star_map_closed)
	get_tree().paused = true
	add_child(star_map)


func _on_destination_chosen(site_id: StringName) -> void:
	destination = site_id
	star_map.close_map()


func _on_star_map_closed() -> void:
	star_map = null
	_map_closed_frame = Engine.get_process_frames()
	get_tree().paused = false
	# La tecla de salto que abrió el mapa no cuenta para saltar.
	jump_hold = -0.3


## Pruebas (`--auto-jump`): `--auto-dest=<id>`, o la estación del sistema.
func _auto_destination() -> StringName:
	if GameState.args.has("auto-dest"):
		return StringName(GameState.args["auto-dest"])
	var sys := Catalog.system_of(GameState.location)
	return sys.stations[0].id if sys and not sys.stations.is_empty() else Catalog.start_station()


func _leave_stage() -> void:
	_ending = true
	ship.input_enabled = false
	projectiles.clear_enemy_bullets()
	GameState.on_stage_survived(collected)
	# La recompensa del jefe que aún vuela hacia la nave también cuenta.
	for node in scrap_root.get_children():
		var p := node as ScrapPickup
		if p.attracted and not ship.is_dead:
			GameState.add_scrap(p.type_id)
			collected += 1
			p.queue_free()
	if _boss_fled:
		GameState.last_report += " Huiste de %s: sigue esperando en %s." % [zone.boss_name, zone.display_name]
	elif _boss_killed_here:
		GameState.last_report += " ¡Derrotaste a %s!" % zone.boss_name
	var place := Catalog.place_name(destination)
	hud.show_message("Saltando a %s…" % (place if place != "" else "la estación"))
	Sfx.play(&"jump")
	hud.jump_flash()
	var tween := ship.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(ship, "scale", Vector3(0.2, 0.2, 3.0), 0.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(GameState.travel_to.bind(destination))


func _on_ship_destroyed() -> void:
	_ending = true
	projectiles.clear_enemy_bullets()
	print("ship destroyed at t=%.1f kills=%d scrap=%d" % [time, kills, collected])
	if GameState.args.has("balance-run"):
		_balance_report(false)
		return
	hud.refresh_ship()
	shake(1.0)
	_scrap_lost_value = GameState.scrap_value()
	await get_tree().create_timer(1.8).timeout
	hud.show_game_over(_scrap_lost_value)
	# Pruebas automáticas: reaparece solo.
	if _auto_respawn:
		await get_tree().create_timer(1.0).timeout
		respawn()


## Pruebas de equilibrio (`--balance-run`): una línea con el resultado del nivel y se cierra.
func _balance_report(survived: bool) -> void:
	var core_left := 0.0
	if ship.core_part and not ship.is_dead:
		core_left = ship.core_part.hp() / ship.core_part.max_hp()
	var lost := 0
	for e in GameState.blueprint:
		if e["lost"] or e["destroyed"]:
			lost += 1
	print("balance zone=%s diff=%d survived=%d t=%.0f hull_left=%d%% damage=%d shield_absorbed=%d parts_lost=%d kills=%d scrap_value=%d" % [
			zone.id if zone else &"-", difficulty, int(survived), time, roundi(core_left * 100.0),
			roundi(ship.damage_taken), roundi(ship.shield_absorbed), lost, kills, GameState.scrap_value()])
	var sources: Array[String] = []
	for k: StringName in ship.damage_log:
		sources.append("%s=%d" % [k, roundi(ship.damage_log[k])])
	print("balance damage_by " + " ".join(sources))
	get_tree().quit()


## Botón «Reaparecer en la estación más cercana» de la pantalla de nave destruida.
func respawn() -> void:
	if GameState.args.has("game-over-screenshot"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(GameState.args["game-over-screenshot"])
	GameState.on_ship_destroyed()
	GameState.go_to_station()


## Pruebas: `--burst=N` guarda N fotogramas seguidos
## (a media resolución) en una sola imagen en cuadrícula, para revisar efectos que duran muy poco.
func _burst_capture(frames: int) -> void:
	var cols := 4 if frames <= 24 else 6
	var cell := Vector2i(640, 360) if frames <= 24 else Vector2i(427, 240)
	var sheet: Image = null
	for i in frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		if sheet == null:
			sheet = Image.create(cell.x * cols, cell.y * ceili(float(frames) / cols), false, img.get_format())
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), Vector2i((i % cols) * cell.x, (i / cols) * cell.y))
	sheet.save_png(GameState.args["screenshot"])
	print("burst saved: %d frames at t=%.1f" % [frames, time])
	if GameState.args.has("quit-after-screenshot"):
		get_tree().quit()


## Pruebas: `-- --screenshot=<ruta.png> --screenshot-at=<segundos>` guarda una captura.
func _debug_screenshot() -> void:
	if _screenshot_done or not GameState.args.has("screenshot"):
		return
	if time < float(GameState.args.get("screenshot-at", "5")):
		return
	_screenshot_done = true
	if GameState.args.has("burst"):
		await _burst_capture(int(GameState.args["burst"]))
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(GameState.args["screenshot"])
	print("screenshot saved at t=%.1f enemies=%d kills=%d scrap=%d hull=%.0f" % [
		time, get_tree().get_node_count_in_group(&"enemies"), kills, collected,
		ship.core_part.hp() if ship.core_part else 0.0])
	if GameState.args.has("quit-after-screenshot"):
		get_tree().quit()
