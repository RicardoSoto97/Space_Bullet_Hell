class_name BalanceCareer
extends Node
## Simulación de una partida entera (fase 6, `-- --balance-career`): un «jugador cuidadoso»
## juega niveles con el piloto automático y, en cada estación, vende, repara y compra según una
## lista fija. Anota en qué minuto de juego llega a cada hito del GDD (2.4).
##
## El piloto automático esquiva peor que una persona, así que la nave recibe solo una parte del
## daño (`--player-damage`, por defecto 0,08: con eso pasa el primer nivel perdiendo el 30–50 % del
## casco, dentro de lo que pide el GDD 2.4) y el núcleo no llega a 0 (`no-death`): cada vez
## que habría muerto se cuenta un «casi muere». Mide el ritmo de la economía suponiendo que el
## jugador no pierde la nave; las pruebas a mano dicen si cada zona se puede sobrevivir.
##
## Opciones: `--career-hours=N` (tope de horas de juego, 16 por defecto), `--time-scale=N`,
## `--career-out=user://x.csv` (para correr varias a la vez, con `--save-path` distintos).
## Escribe el informe en `user://balance_career.csv` y lo imprime con el prefijo `career`.

## Minutos de juego que se cuentan por cada visita a una estación (vender, comprar, mirar).
const STATION_MINUTES := 1.0
## Precio de una primera base útil (terreno de asteroide, cargador, refinería y puerto; GDD 7).
## No se construye: el dinero se aparta, para medir cuándo se podría pagar.
const BASE_COST := 12500
## Distancia máxima a la que se anima según lo que ya compró (paso de la lista de compras):
## un jugador cuidadoso mejora la nave antes de ir más lejos.
const TIER_STEPS := {10: 7, 15: 10, 20: 14, 25: 16, 30: 17}

var game_seconds: float = 0.0
var milestones: Dictionary[String, float] = {}
var _lines: PackedStringArray = []
var _tier: int = 5
var _confidence: int = 0
var _step: int = 0
var _stage: Stage
var _last: Dictionary = {}
var _boss_watch: float = 0.0
var _max_hours: float = 16.0
var _base_bought: bool = false
var abandons: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var a := GameState.args
	for k in ["autopilot", "auto-jump", "no-death"]:
		a[k] = "true"
	if not a.has("player-damage"):
		a["player-damage"] = "0.08"
	if not a.has("time-scale"):
		a["time-scale"] = "10"
	_max_hours = float(a.get("career-hours", "16"))
	get_tree().node_added.connect(_on_node_added)
	_log("career start money=%d player_damage=%s" % [GameState.money, a["player-damage"]])
	_lines.append("game_min,zone,minutes,difficulty,survived,near_deaths,hull_left,kills,scrap_value,repair_cost,broken,money_after,tank,core_level,weapons")


func _on_node_added(node: Node) -> void:
	if node is Stage:
		_stage = node
		_boss_watch = 0.0
		node.tree_exiting.connect(_on_stage_exit.bind(node), CONNECT_ONE_SHOT)
	elif node is Station:
		node.ready.connect(_on_station.bind(node), CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	# Si el jefe no cae en 4 minutos, el jugador huye (mantiene el salto el doble de tiempo).
	if is_instance_valid(_stage) and _stage.fuel_ready and _stage.boss_pending:
		_boss_watch += delta
		if _boss_watch > 240.0:
			_stage._boss_fled = true
			_stage.boss_pending = false
			_log("career fled from boss in %s" % _stage.zone.id)


func _on_stage_exit(stage: Stage) -> void:
	var ship := stage.ship
	game_seconds += stage.time
	var core_left := 0.0
	if ship.core_part:
		core_left = ship.core_part.hp() / ship.core_part.max_hp()
	_last = {"zone": stage.zone.id if stage.zone else &"-", "minutes": stage.duration / 60.0,
			"difficulty": stage.difficulty, "survived": not ship.is_dead, "near": ship.near_deaths,
			"hull": roundi(core_left * 100.0), "kills": stage.kills, "boss": stage._boss_killed_here,
			"damage": _damage_text(ship)}
	_stage = null


func _on_station(station: Station) -> void:
	await get_tree().process_frame
	var scrap_value := GameState.scrap_value()
	var repair := GameState.repair_cost()
	if not _last.is_empty():
		_after_stage(scrap_value, repair)
	GameState.sell_all_scrap()
	var repaired := GameState.repair_all()
	if not repaired:
		GameState.repair_affordable()
	# Las armas sin artillero (murió al destruirse su estación) necesitan uno nuevo antes que nada.
	while GameState.has_unmanned_station() and GameState.crew.size() < GameState.crew_capacity():
		var before := GameState.crew.size()
		_hire_gunner()
		if GameState.crew.size() == before:
			break
	if not GameState.has_working_weapon():
		# Sin un arma con artillero (ni dinero para arreglarlo): vuelve gratis a la nave inicial (GDD 6).
		GameState.abandon_ship()
		_step = 0
		abandons += 1
		_log("career abandon ship (repaired=%s)" % repaired)
	# Aparta una reserva para la próxima reparación antes de comprar.
	var reserve := mini(GameState.money, 300 + int(Bases.blueprint_value(GameState.serialize_blueprint(true)) * 0.05))
	GameState.money -= reserve
	# Con la nave a medio reparar no compra nada: primero junta para dejarla entera.
	if repaired:
		_shop()
	GameState.money += reserve
	game_seconds += STATION_MINUTES * 60.0
	if game_seconds / 3600.0 >= _max_hours or milestones.has("last_boss"):
		_finish()
		return
	var zone := _choose_zone()
	_log("career go %s (tier %d, money %d, step %d, parts %d, crew %d/%d)" % [zone, _tier, GameState.money, _step,
			GameState.blueprint.size(), GameState.crew.size(), GameState.crew_capacity()])
	GameState.travel_to(zone)


func _after_stage(scrap_value: int, repair: int) -> void:
	var ok: bool = _last["survived"] and _last["near"] == 0
	if _last["boss"] and _last["zone"] == &"zone_velo_nyxar":
		_milestone("last_boss")
	_lines.append("%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d,%d,%s" % [game_seconds / 60.0, _last["zone"], _last["minutes"],
			_last["difficulty"], int(_last["survived"]), _last["near"], _last["hull"], _last["kills"], scrap_value,
			repair, _broken_text(), GameState.money + scrap_value, GameState.fuel_tank_level, GameState.blueprint[0]["level"],
			_weapons_text()])
	_log("career %s t=%s near_deaths=%d hull_left=%d%% kills=%d scrap=%d repair=%d broken=%s money=%d damage=%s" % [
			_last["zone"], _clock(game_seconds), _last["near"], _last["hull"], _last["kills"], scrap_value, repair,
			_broken_text(), GameState.money + scrap_value, _last["damage"]])
	if _last["minutes"] == 5 and not milestones.has("first_stage") and ok and _last["hull"] >= 40:
		_milestone("first_stage")
	# Sube de distancia tras dos niveles limpios con margen; baja si casi muere.
	if not ok:
		_confidence = 0
		_tier = maxi(5, _tier - 5)
	elif _last["hull"] >= 50:
		_confidence += 1
		if _confidence >= 2 and _tier + 5 <= GameState.tank_minutes():
			_tier += 5
			_confidence = 0


# ---------- compras del jugador cuidadoso ----------

## Lista de compras en orden. Cada paso devuelve true cuando está cumplido.
func _shop() -> void:
	var steps: Array[Callable] = [
		_core_to.bind(2),
		_add_weapon.bind(&"machine_gun", "first_extra_weapon"),
		_weapons_to.bind(3),
		_tank.bind(1, "tank_1"),
		_core_to.bind(4),
		_add_weapon.bind(&"laser", ""),
		_weapons_to.bind(5),
		_buy_base,
		_tank.bind(2, ""),
		_evolve_main,
		_tank.bind(3, ""),
		_core_to.bind(6),
		_add_weapon.bind(&"rocket_launcher", ""),
		_weapons_to.bind(7),
		_tank.bind(4, ""),
		_weapons_to.bind(10),
		_tank.bind(5, "tank_5"),
		_core_to.bind(10),
	]
	# Desde el Depósito I protege con placas de blindaje los pasillos y el núcleo (las armas extra
	# van sobre pasillos, que son lo primero que se rompe).
	if _step > 3:
		_armor_up()
	while _step < steps.size():
		if not steps[_step].call():
			break
		_step += 1


func _armor_up() -> void:
	var price := Catalog.part(&"armor_plate").price
	var bought := true
	while bought and GameState.money >= price:
		bought = false
		for s in GameState.free_slots():
			var part := String(GameState.blueprint[s["part_index"]]["part"])
			if s["kind"] != PartData.SlotKind.FACE or not (part == "core" or part.begins_with("corridor")):
				continue
			if GameState.check_placement(&"armor_plate", s["part_index"], s["slot"])["ok"] 					and GameState.buy_part(&"armor_plate", s["part_index"], s["slot"]) == "":
				bought = true
				break


func _core_to(level: int) -> bool:
	var core := GameState.blueprint[0]
	while core["level"] < level:
		if not GameState.upgrade_structure(core):
			return false
	return true


## Estación de mando con su arma y un artillero, mirando al frente (al lado del núcleo,
## sobre un pasillo si hace falta).
func _add_weapon(weapon: StringName, milestone: String) -> bool:
	var w := Catalog.weapon(weapon)
	var hire := _cheapest_gunner_price()
	if GameState.crew.size() >= GameState.crew_capacity() or hire < 0:
		return false
	var slot := _front_slot()
	var cost := Catalog.part(&"command_station").price + w.price + hire
	if slot.is_empty():
		cost += Catalog.part(&"corridor_1x1").price
	if GameState.money < cost:
		return false
	if slot.is_empty():
		var side := _side_slot_of(0)
		if side < 0 or GameState.buy_part(&"corridor_1x1", 0, side) != "":
			return false
		slot = _front_slot()
		if slot.is_empty():
			return false
	if GameState.buy_part(&"command_station", slot["part_index"], slot["slot"]) != "":
		return false
	var entry := GameState.blueprint[GameState.blueprint.size() - 1]
	GameState.buy_weapon(entry, weapon)
	_hire_gunner()
	if milestone != "":
		_milestone(milestone)
	return true


func _weapons_to(level: int) -> bool:
	var done := true
	for e in GameState.blueprint:
		if e["weapon"] == &"" or e["lost"] or e["destroyed"]:
			continue
		var w := Catalog.weapon(e["weapon"])
		while e["weapon_level"] < mini(level, w.max_level):
			if not GameState.upgrade_weapon(e):
				done = false
				break
	return done


func _tank(level: int, milestone: String) -> bool:
	if GameState.fuel_tank_level >= level:
		return true
	if GameState.buy_fuel_tank(level) != "":
		return false
	if milestone != "":
		_milestone(milestone)
	return true


func _buy_base() -> bool:
	if _base_bought:
		return true
	if not GameState.spend(BASE_COST):
		return false
	_base_bought = true
	_milestone("first_base")
	return true


## Sube el arma principal (la de la nave inicial) al nivel 10 y la evoluciona.
func _evolve_main() -> bool:
	var e := GameState.blueprint[1]
	if e["weapon"] == &"":
		return true
	if Catalog.weapon(e["weapon"]).evolves_into == &"":
		return true  # ya evolucionada
	var w := Catalog.weapon(e["weapon"])
	while e["weapon_level"] < w.max_level:
		if not GameState.upgrade_weapon(e):
			return false
	if not GameState.evolve_weapon(e):
		return false
	_milestone("first_evolution")
	return true


func _front_slot() -> Dictionary:
	for s in GameState.free_slots():
		if s["kind"] == PartData.SlotKind.SIDE and s["normal"].z < -0.5 \
				and GameState.check_placement(&"command_station", s["part_index"], s["slot"])["ok"]:
			return s
	return {}


func _side_slot_of(index: int) -> int:
	for s in GameState.free_slots():
		if s["part_index"] == index and s["kind"] == PartData.SlotKind.SIDE and absf(s["normal"].x) > 0.5 \
				and GameState.check_placement(&"corridor_1x1", index, s["slot"])["ok"]:
			return s["slot"]
	return -1


func _cheapest_gunner_price() -> int:
	var best := -1
	for c in GameState.bar_candidates:
		if best < 0 or c["price"] < best:
			best = c["price"]
	return best


## Contrata al mejor artillero que puede pagar (se asigna solo a la estación sin tripulante).
func _hire_gunner() -> void:
	var pick := -1
	for i in GameState.bar_candidates.size():
		var c := GameState.bar_candidates[i]
		if c["price"] > GameState.money:
			continue
		if pick < 0 or c["gunnery"] > GameState.bar_candidates[pick]["gunnery"]:
			pick = i
	if pick >= 0:
		GameState.hire_candidate(pick)


# ---------- a dónde ir ----------

func _choose_zone() -> StringName:
	var reach := GameState.tank_minutes()
	for t: int in TIER_STEPS:
		if _step < TIER_STEPS[t]:
			reach = mini(reach, t - 5)
			break
	var tier := mini(_tier, reach)
	var options: Array[ZoneData] = []
	var boss_zone: ZoneData
	for site in Catalog.sites.values():
		var z := site as ZoneData
		if z == null or z.distance_minutes != tier:
			continue
		if z.has_boss() and not GameState.is_boss_defeated(z.id):
			boss_zone = z
		else:
			options.append(z)
	# Va por el jefe con confianza en esa distancia y la nave que pide la distancia siguiente.
	if boss_zone and _confidence >= 1 and _step >= TIER_STEPS.get(tier + 5, 99):
		return boss_zone.id
	if options.is_empty():
		return boss_zone.id if boss_zone else Catalog.start_station()
	return options.pick_random().id


# ---------- informe ----------

func _milestone(id: String) -> void:
	if milestones.has(id):
		return
	milestones[id] = game_seconds
	_log("career milestone %s at %s (money %d)" % [id, _clock(game_seconds), GameState.money])


## Daño recibido por origen (ya escalado por `--player-damage`), de mayor a menor.
func _damage_text(ship: Ship) -> String:
	var keys := ship.damage_log.keys()
	keys.sort_custom(func(a, b): return ship.damage_log[a] > ship.damage_log[b])
	var bits: PackedStringArray = []
	for k in keys.slice(0, 4):
		bits.append("%s:%d" % [k, roundi(ship.damage_log[k])])
	return "|".join(bits)


## Piezas destruidas (D) o perdidas (L) al volver del nivel, separadas por «|».
func _broken_text() -> String:
	var bits: PackedStringArray = []
	for e in GameState.blueprint:
		if e["destroyed"] or e["lost"]:
			bits.append("%s:%s" % [e["part"], "D" if e["destroyed"] else "L"])
	return "|".join(bits) if not bits.is_empty() else "-"


func _weapons_text() -> String:
	var bits: PackedStringArray = []
	for e in GameState.blueprint:
		if e["weapon"] != &"" and not e["lost"] and not e["destroyed"]:
			bits.append("%s:%d" % [e["weapon"], e["weapon_level"]])
	return " ".join(bits)


static func _clock(seconds: float) -> String:
	var m := int(seconds / 60.0)
	return "%d:%02d" % [m / 60, m % 60]


func _log(text: String) -> void:
	print(text)


func _finish() -> void:
	_lines.append("")
	_lines.append("milestone,game_time")
	for id in milestones:
		_lines.append("%s,%s" % [id, _clock(milestones[id])])
	var f := FileAccess.open(GameState.args.get("career-out", "user://balance_career.csv"), FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines) + "\n")
	_log("career end at %s money=%d step=%d abandons=%d milestones=%s" % [_clock(game_seconds), GameState.money, _step,
			abandons, str(milestones.keys())])
	get_tree().quit()
