extends Node
## Las bases del jugador (GDD 7): terrenos, edificios, lo guardado en ellas (chatarra y
## minerales), los tripulantes que trabajan allí, la investigación, los planos del hangar y la
## producción, que avanza solo con el juego abierto. Se guarda con la partida (`GameState`).

## Algo terminó (investigación, curación, entrenamiento…): texto para mostrar al jugador.
signal event(text: String)

## Parcelas para edificios según el tipo de cuerpo (GDD 7.2).
const LOTS := {
	CelestialBodyData.Kind.ASTEROID: 4,
	CelestialBodyData.Kind.MOON: 6,
	CelestialBodyData.Kind.ROCKY_PLANET: 9,
}
const ASTEROID_MINE_BONUS := 1.5
const MOON_RESEARCH_BONUS := 1.3
## Entrenar en la academia: +5 a una estadística en 10 minutos, 10 créditos por punto que ya tiene.
const TRAINING_SECONDS := 600.0
const TRAINING_POINTS := 5
const TRAINING_COST_PER_POINT := 10
## Curar a un herido tarda 1.000 ÷ primeros auxilios minutos (GDD 7.4).
const HEAL_FACTOR_MINUTES := 1000.0
## Puntos para investigar cada depósito de combustible (GDD 5.4); el índice es su nivel.
const TANK_RESEARCH: Array[int] = [0, 400, 1200, 3000, 6000, 12000]
## Planos con nombre que guarda el hangar en el nivel 1 (más en los niveles 4, 7 y 10).
const PLAN_BASE_SLOTS := 2

## Cada base: {body, founded, buildings: [{type, lot, level}], mine_acc, mine_next}.
var bases: Array[Dictionary] = []
## Lo guardado en las bases (común a todas): chatarra y minerales, id -> unidades.
var storage: Dictionary[StringName, int] = {}
## Tripulantes que están en una base: los datos del tripulante más {base, job, wounded, heal,
## training, train_left}. Los de la nave siguen en `GameState.crew`.
var crew: Array[Dictionary] = []
var research_current: StringName = &""
var research_progress: float = 0.0
var researched: Array[StringName] = []
## Planos con nombre: {name, blueprint, value}. `auto_plan` es el de la última nave que despegó
## de una base con hangar.
var plans: Array[Dictionary] = []
var auto_plan: Dictionary = {}
var academy_candidates: Array[Dictionary] = []
## Segundos que faltan para que se recargue el combustible en una base sin cargador.
var fuel_wait: float = 0.0
## Multiplicador del tiempo de la base (pruebas: `--base-speed=N`).
var speed: float = 1.0
var _refine_acc: float = 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--base-speed="):
			speed = float(a.get_slice("=", 1))


func reset() -> void:
	bases.clear()
	storage.clear()
	crew.clear()
	research_current = &""
	research_progress = 0.0
	researched.clear()
	plans.clear()
	auto_plan = {}
	academy_candidates.clear()
	fuel_wait = 0.0
	_refine_acc = 0.0


# ---------- bases y terrenos ----------

func base_of(body_id: StringName) -> Dictionary:
	for b in bases:
		if b["body"] == body_id:
			return b
	return {}


func owns(body_id: StringName) -> bool:
	return not base_of(body_id).is_empty()


## Si un lugar del mapa es una base del jugador.
func is_base(id: StringName) -> bool:
	return Catalog.body(id) != null and owns(id)


## La base donde está aterrizada la nave, o vacío.
func current() -> Dictionary:
	return base_of(GameState.location)


func lot_count(base: Dictionary) -> int:
	return LOTS.get(Catalog.body(base["body"]).kind, 0)


func kind_name(base: Dictionary) -> String:
	match Catalog.body(base["body"]).kind:
		CelestialBodyData.Kind.ASTEROID:
			return "Asteroide"
		CelestialBodyData.Kind.MOON:
			return "Satélite"
	return "Planeta"


## Compra el terreno de un cuerpo habitable. Devuelve "" o el motivo del fallo.
func buy_land(body_id: StringName) -> String:
	var b := Catalog.body(body_id)
	if b == null or not b.habitable or not LOTS.has(b.kind):
		return "Aquí no se puede construir una base."
	if owns(body_id):
		return "Ya tienes este terreno."
	if not GameState.spend(b.land_price):
		return "No tienes dinero suficiente."
	bases.append({"body": body_id, "founded": false, "buildings": [] as Array[Dictionary], "mine_acc": 0.0,
			"mine_next": &""})
	return ""


func building_at(base: Dictionary, lot: int) -> Dictionary:
	for b: Dictionary in base["buildings"]:
		if b["lot"] == lot:
			return b
	return {}


func find_building(base: Dictionary, type: StringName) -> Dictionary:
	if base.is_empty():
		return {}
	for b: Dictionary in base["buildings"]:
		if b["type"] == type:
			return b
	return {}


## Todos los edificios de un tipo, en todas las bases: [{base, building}].
func all_of(type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for base in bases:
		var b := find_building(base, type)
		if not b.is_empty():
			out.append({"base": base, "building": b})
	return out


func has_anywhere(type: StringName) -> bool:
	return not all_of(type).is_empty()


## Construye un edificio en una parcela libre. Devuelve "" o el motivo del fallo.
func build(base: Dictionary, type: StringName, lot: int) -> String:
	var data := Catalog.building(type)
	if data == null:
		return "Edificio desconocido."
	if not find_building(base, type).is_empty():
		return "Cada base admite un solo edificio de cada tipo."
	if lot < 0 or lot >= lot_count(base) or not building_at(base, lot).is_empty():
		return "Esa parcela no está libre."
	if not GameState.spend(data.price):
		return "No tienes dinero suficiente."
	base["buildings"].append({"type": type, "lot": lot, "level": 1})
	# Un cargador nuevo rellena el depósito de la nave aterrizada aquí.
	if type == &"fuel_charger" and current() == base:
		fuel_wait = 0.0
	if type == &"academy" and current() == base:
		refresh_academy()
	return ""


func upgrade_cost(b: Dictionary) -> int:
	return Catalog.building(b["type"]).upgrade_cost(b["level"])


func upgrade(b: Dictionary) -> bool:
	var cost := upgrade_cost(b)
	if cost < 0 or not GameState.spend(cost):
		return false
	b["level"] += 1
	return true


## Valor de producción de un edificio en su nivel (ver `BuildingData.base_rate`).
func rate(b: Dictionary) -> float:
	var data := Catalog.building(b["type"])
	var lvl := float(b["level"] - 1)
	match b["type"]:
		&"refinery", &"mine":
			return data.base_rate * (1.0 + data.rate_per_level * lvl)
	return data.base_rate + data.rate_per_level * lvl


# ---------- tripulantes en la base ----------

func members_at(body_id: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in crew.size():
		if crew[i]["base"] == body_id:
			out.append(i)
	return out


## Tripulantes que trabajan en un edificio de una base.
func workers(body_id: StringName, type: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in crew.size():
		var m := crew[i]
		if m["base"] == body_id and m["job"] == type and is_available(i):
			out.append(i)
	return out


func is_available(i: int) -> bool:
	return not crew[i]["wounded"] and crew[i]["training"] == ""


func free_crew_slots(base: Dictionary, b: Dictionary) -> int:
	var data := Catalog.building(b["type"])
	return data.crew_slots_at(b["level"]) - workers(base["body"], b["type"]).size()


func assign(i: int, type: StringName) -> String:
	var base := base_of(crew[i]["base"])
	var b := find_building(base, type)
	if b.is_empty() or not is_available(i):
		return "Ese tripulante no puede trabajar ahora."
	if crew[i]["job"] != type and free_crew_slots(base, b) <= 0:
		return "No quedan plazas en este edificio: quita a alguien o mejóralo."
	crew[i]["job"] = type
	return ""


func unassign(i: int) -> void:
	crew[i]["job"] = &""


func _base_member(m: Dictionary, body_id: StringName) -> Dictionary:
	var out := m.duplicate()
	out.erase("price")
	out.merge({"base": body_id, "job": &"", "wounded": false, "heal": 0.0, "training": "", "train_left": 0.0}, true)
	return out


## Baja un tripulante de la nave a la base donde está aterrizada. Devuelve su índice en `crew`.
func move_to_base(ship_index: int) -> int:
	var base := current()
	if base.is_empty():
		return -1
	crew.append(_base_member(GameState.remove_crew_member(ship_index), base["body"]))
	return crew.size() - 1


## Sube un tripulante de la base a la nave (con la nave aterrizada en esa base).
func move_to_ship(i: int) -> String:
	if crew[i]["base"] != GameState.location or not is_available(i):
		return "Ese tripulante no puede subir ahora."
	if GameState.crew.size() >= GameState.crew_capacity():
		return "No hay plazas en la nave: instala habitaciones de tripulantes."
	var m := crew[i].duplicate()
	for k in ["base", "job", "wounded", "heal", "training", "train_left"]:
		m.erase(k)
	crew.remove_at(i)
	GameState.add_crew_member(m)
	return ""


func dismiss(i: int) -> void:
	crew.remove_at(i)


## Tripulantes heridos al perder una sección o la nave: van a la enfermería de una base. Sin
## ninguna enfermería, mueren. Devuelve cuántos se salvaron.
func injure(members: Array[Dictionary]) -> int:
	var target := current() if not find_building(current(), &"infirmary").is_empty() else {}
	if target.is_empty():
		var all := all_of(&"infirmary")
		if all.is_empty():
			return 0
		target = all[0]["base"]
	for m in members:
		var bm := _base_member(m, target["body"])
		bm["wounded"] = true
		crew.append(bm)
	return members.size()


# ---------- hangar y planos ----------

func hangar_ready(base: Dictionary) -> bool:
	return not base.is_empty() and not find_building(base, &"hangar").is_empty() \
			and not workers(base["body"], &"hangar").is_empty()


## Planos con nombre que caben: 2, y uno más en los niveles 4, 7 y 10 del mejor hangar.
func max_plans() -> int:
	var best := 0
	for h in all_of(&"hangar"):
		best = maxi(best, Catalog.building(&"hangar").extra_slots(h["building"]["level"]))
	return PLAN_BASE_SLOTS + best if has_anywhere(&"hangar") else 0


## Lo que se pagó por una nave: piezas, armas y sus mejoras.
static func blueprint_value(bp: Array) -> int:
	var total := 0
	for e: Dictionary in bp:
		var data := Catalog.part(StringName(e["part"]))
		if data == null:
			continue
		total += data.price
		var lvl := int(e.get("level", 1))
		for l in range(1, lvl):
			total += GameState.level_cost(data, l)
		var w := Catalog.weapon(StringName(e.get("weapon", "")))
		if w:
			total += w.price
			for l in range(1, int(e.get("weapon_level", 1))):
				total += w.upgrade_cost(l)
	return total


func make_plan(plan_name: String) -> Dictionary:
	var bp := GameState.serialize_blueprint(true)
	return {"name": plan_name, "blueprint": bp, "value": blueprint_value(bp)}


func save_plan(plan_name: String) -> String:
	if plans.size() >= max_plans():
		return "No caben más planos: borra uno o mejora el hangar."
	plans.append(make_plan(plan_name))
	return ""


## Lo que cuesta construir un plano en el hangar de una base: un 80 % de su valor, un 2 %
## menos por cada nivel del hangar.
func plan_cost(plan: Dictionary, base: Dictionary) -> int:
	var h := find_building(base, &"hangar")
	var factor := rate(h) if not h.is_empty() else 1.0
	return int(round(plan["value"] * factor))


## Construye la nave de un plano en el hangar de la base actual. La nave actual se desarma y
## devuelve el 50 % de su valor. Solo hay una nave a la vez (GDD 7.4).
func build_plan(plan: Dictionary) -> String:
	var base := current()
	if not hangar_ready(base):
		return "Hace falta un ingeniero en el hangar."
	var cost := plan_cost(plan, base)
	var refund := GameState.sell_value(0)
	if GameState.money + refund < cost:
		return "No tienes dinero suficiente."
	GameState.add_money(refund)
	GameState.spend(cost)
	GameState.load_blueprint(plan["blueprint"])
	# Los tripulantes que no caben en la nave nueva se quedan en la base.
	while GameState.crew.size() > GameState.crew_capacity():
		move_to_base(GameState.crew.size() - 1)
	GameState.auto_assign_gunners()
	return ""


# ---------- investigación ----------

func is_researched(id: StringName) -> bool:
	return id in researched


func tank_research_id(level: int) -> StringName:
	return StringName("fuel_tank_%d" % level)


## Investigaciones posibles (sin las ya hechas): {id, name, points, desc}. De los depósitos
## solo aparece el siguiente.
func research_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: PartData in Catalog.parts.values():
		if p.research_points > 0 and not is_researched(p.id):
			out.append({"id": p.id, "name": p.display_name, "points": p.research_points, "desc": "pieza"})
	for w: WeaponData in Catalog.weapons.values():
		if w.research_points > 0 and not is_researched(w.id):
			out.append({"id": w.id, "name": w.display_name, "points": w.research_points, "desc": "arma"})
	for lvl in range(1, TANK_RESEARCH.size()):
		var id := tank_research_id(lvl)
		if not is_researched(id):
			out.append({"id": id, "name": GameState.TANK_NAMES[lvl], "points": TANK_RESEARCH[lvl],
					"desc": "depósito de %d min" % (5 * (lvl + 1))})
			break
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["points"] < b["points"])
	return out


func research_cost(id: StringName) -> int:
	if Catalog.part(id):
		return Catalog.part(id).research_points
	if Catalog.weapon(id):
		return Catalog.weapon(id).research_points
	for lvl in range(1, TANK_RESEARCH.size()):
		if tank_research_id(lvl) == id:
			return TANK_RESEARCH[lvl]
	return 0


func research_name(id: StringName) -> String:
	if Catalog.part(id):
		return Catalog.part(id).display_name
	if Catalog.weapon(id):
		return Catalog.weapon(id).display_name
	for lvl in range(1, TANK_RESEARCH.size()):
		if tank_research_id(lvl) == id:
			return GameState.TANK_NAMES[lvl]
	return String(id)


## Empieza (o cambia) la investigación en curso. Lo avanzado en otra se pierde.
func start_research(id: StringName) -> void:
	if id != research_current:
		research_current = id
		research_progress = 0.0


## Puntos de investigación por minuto de todos los centros de todas las bases.
func research_rate() -> float:
	var total := 0.0
	for r in all_of(&"research_center"):
		var base: Dictionary = r["base"]
		var sum := 0.0
		for i in workers(base["body"], &"research_center"):
			sum += float(crew[i]["research"]) / 5.0
		if Catalog.body(base["body"]).kind == CelestialBodyData.Kind.MOON:
			sum *= MOON_RESEARCH_BONUS
		total += sum * rate(r["building"])
	return total


## Si una pieza o arma se puede fabricar en el hangar (vendida en la estación o investigada).
func can_fabricate(id: StringName) -> bool:
	return is_researched(id)


# ---------- comercio y refinería ----------

## Porcentaje del precio de la chatarra que paga el mejor puerto comercial (0 si no hay).
func port_factor() -> float:
	var best := 0.0
	for p in all_of(&"trade_port"):
		best = maxf(best, rate(p["building"]))
	return best


func stored_scrap_value() -> int:
	var total := 0
	for id in storage:
		var s := Catalog.scrap(id)
		if s:
			total += storage[id] * s.price
	return total


func stored_mineral_value() -> int:
	var total := 0
	for id in storage:
		var m := Catalog.mineral(id)
		if m:
			total += storage[id] * m.price
	return total


func sell_stored_scrap() -> int:
	var earned := int(stored_scrap_value() * port_factor())
	for id in storage.keys():
		if Catalog.scrap(id):
			storage.erase(id)
	GameState.add_money(earned)
	return earned


func sell_stored_minerals() -> int:
	if port_factor() <= 0.0:
		return 0
	var earned := stored_mineral_value()
	for id in storage.keys():
		if Catalog.mineral(id):
			storage.erase(id)
	GameState.add_money(earned)
	return earned


## Al aterrizar, la chatarra de la nave se descarga si alguna base puede refinarla o venderla.
func unload_ship_scrap() -> int:
	if not has_anywhere(&"refinery") and not has_anywhere(&"trade_port"):
		return 0
	var n := 0
	for id in GameState.scrap:
		storage[id] = storage.get(id, 0) + GameState.scrap[id]
		n += GameState.scrap[id]
	GameState.scrap.clear()
	GameState.scrap_changed.emit()
	return n


func refinery_rate() -> float:
	var total := 0.0
	for r in all_of(&"refinery"):
		total += rate(r["building"])
	return total


func mine_rate(base: Dictionary) -> float:
	var m := find_building(base, &"mine")
	if m.is_empty():
		return 0.0
	var bonus := ASTEROID_MINE_BONUS if Catalog.body(base["body"]).kind == CelestialBodyData.Kind.ASTEROID else 1.0
	return rate(m) * bonus


# ---------- academia ----------

func refresh_academy() -> void:
	academy_candidates.clear()
	var a := find_building(current(), &"academy")
	if a.is_empty():
		return
	var names := GameState.CREW_NAMES.duplicate()
	names.shuffle()
	var n := randi_range(3, 5) + Catalog.building(&"academy").extra_slots(a["level"])
	for i in mini(n, names.size()):
		academy_candidates.append(GameState.random_candidate(names[i]))


func hire(i: int) -> String:
	var base := current()
	if find_building(base, &"academy").is_empty():
		return "Aquí no hay academia."
	var c := academy_candidates[i]
	if not GameState.spend(c["price"]):
		return "No tienes dinero suficiente."
	crew.append(_base_member(c, base["body"]))
	academy_candidates.remove_at(i)
	return ""


func training_slots(base: Dictionary) -> int:
	var a := find_building(base, &"academy")
	return 0 if a.is_empty() else 1 + Catalog.building(&"academy").extra_slots(a["level"])


func trainees(body_id: StringName) -> int:
	var n := 0
	for i in members_at(body_id):
		if crew[i]["training"] != "":
			n += 1
	return n


func training_cost(i: int, stat: String) -> int:
	return int(crew[i][stat]) * TRAINING_COST_PER_POINT


func start_training(i: int, stat: String) -> String:
	var base := base_of(crew[i]["base"])
	if not is_available(i):
		return "Ese tripulante no puede entrenar ahora."
	if int(crew[i][stat]) >= 100:
		return "Esa estadística ya está al máximo."
	if trainees(base["body"]) >= training_slots(base):
		return "No quedan plazas de entrenamiento: mejora la academia."
	if not GameState.spend(training_cost(i, stat)):
		return "No tienes dinero suficiente."
	crew[i]["job"] = &""
	crew[i]["training"] = stat
	crew[i]["train_left"] = TRAINING_SECONDS
	return ""


# ---------- combustible y viajes ----------

## La nave aterriza en una base: se funda, descarga la chatarra y reposta si hay cargador.
func on_land(body_id: StringName) -> String:
	var base := base_of(body_id)
	var notes: Array[String] = []
	if not base["founded"]:
		base["founded"] = true
		notes.append("Fundaste tu base en %s." % Catalog.body(body_id).display_name)
	var n := unload_ship_scrap()
	if n > 0:
		notes.append("Descargaste %d trozos de chatarra en la base." % n)
	if find_building(base, &"fuel_charger").is_empty():
		fuel_wait = GameState.tank_minutes() * 60.0
		notes.append("Sin cargador de combustible: el depósito tarda %d min en recargarse." % GameState.tank_minutes())
	else:
		fuel_wait = 0.0
	refresh_academy()
	return " ".join(notes)


## La nave despega de una base: si tiene hangar, se guarda solo el plano de la nave.
func on_takeoff(body_id: StringName) -> void:
	var base := base_of(body_id)
	if not find_building(base, &"hangar").is_empty():
		auto_plan = make_plan("Última nave")
	fuel_wait = 0.0


func can_take_off() -> bool:
	return fuel_wait <= 0.0


## Base con hangar donde reaparecer al perder la nave (la que tenga ingeniero, si hay).
func respawn_base() -> StringName:
	var best: StringName = &""
	for h in all_of(&"hangar"):
		var base: Dictionary = h["base"]
		if hangar_ready(base):
			return base["body"]
		if best == &"":
			best = base["body"]
	return best


# ---------- producción (con el juego abierto) ----------

func _process(delta: float) -> void:
	if bases.is_empty():
		return
	var dt := delta * speed
	if fuel_wait > 0.0:
		fuel_wait = maxf(fuel_wait - dt, 0.0)
	_tick_research(dt)
	_tick_refinery(dt)
	_tick_mines(dt)
	_tick_crew(dt)


func _tick_research(dt: float) -> void:
	if research_current == &"":
		return
	research_progress += research_rate() / 60.0 * dt
	var cost := research_cost(research_current)
	if research_progress >= cost:
		researched.append(research_current)
		var done := research_name(research_current)
		research_current = &""
		research_progress = 0.0
		event.emit("Investigación terminada: %s. Ya se puede fabricar en el hangar." % done)


func _tick_refinery(dt: float) -> void:
	var r := refinery_rate()
	if r <= 0.0:
		return
	_refine_acc += r / 60.0 * dt
	while true:
		var next: MineralData = null
		for m in Catalog.sorted_minerals():
			if storage.get(m.source_scrap, 0) >= m.source_amount:
				next = m
				break
		if next == null:
			_refine_acc = 0.0  # sin chatarra no se acumula trabajo
			return
		var cost := next.source_amount * Catalog.scrap(next.source_scrap).price
		if _refine_acc < cost:
			return
		_refine_acc -= cost
		storage[next.source_scrap] -= next.source_amount
		if storage[next.source_scrap] <= 0:
			storage.erase(next.source_scrap)
		storage[next.id] = storage.get(next.id, 0) + 1


func _tick_mines(dt: float) -> void:
	for base in bases:
		var r := mine_rate(base)
		if r <= 0.0:
			continue
		base["mine_acc"] += r / 60.0 * dt
		if base["mine_next"] == &"" or Catalog.mineral(base["mine_next"]) == null:
			base["mine_next"] = _roll_mineral()
		var next := Catalog.mineral(base["mine_next"])
		while next and base["mine_acc"] >= next.price:
			base["mine_acc"] -= next.price
			storage[next.id] = storage.get(next.id, 0) + 1
			base["mine_next"] = _roll_mineral()
			next = Catalog.mineral(base["mine_next"])


func _roll_mineral() -> StringName:
	var total := 0.0
	for m: MineralData in Catalog.minerals.values():
		total += m.mine_weight
	var x := randf() * total
	for m: MineralData in Catalog.minerals.values():
		x -= m.mine_weight
		if x <= 0.0 and m.mine_weight > 0.0:
			return m.id
	return &"titanium"


func _tick_crew(dt: float) -> void:
	# Entrenamiento.
	for m in crew:
		if m["training"] == "":
			continue
		m["train_left"] -= dt
		if m["train_left"] <= 0.0:
			var stat: String = m["training"]
			m[stat] = mini(int(m[stat]) + TRAINING_POINTS, 100)
			m["training"] = ""
			event.emit("%s terminó su entrenamiento: %s %d." % [m["name"], GameState.CREW_STAT_NAMES[stat], m[stat]])
	# Curación: cada tripulante de la enfermería cura a un herido a la vez.
	for inf in all_of(&"infirmary"):
		var base: Dictionary = inf["base"]
		var medics := workers(base["body"], &"infirmary")
		var patients: Array[int] = []
		for i in members_at(base["body"]):
			if crew[i]["wounded"]:
				patients.append(i)
		for k in mini(medics.size(), patients.size()):
			var p := crew[patients[k]]
			var minutes := HEAL_FACTOR_MINUTES / maxf(float(crew[medics[k]]["first_aid"]), 1.0) / rate(inf["building"])
			p["heal"] += dt / (minutes * 60.0)
			if p["heal"] >= 1.0:
				p["wounded"] = false
				p["heal"] = 0.0
				p["job"] = &""
				event.emit("%s se recuperó en la enfermería." % p["name"])


## Minutos que tarda en curarse un herido con el mejor tripulante de la enfermería de la base.
func heal_minutes(base: Dictionary) -> float:
	var inf := find_building(base, &"infirmary")
	var medics := workers(base["body"], &"infirmary")
	if inf.is_empty() or medics.is_empty():
		return -1.0
	var best := 1.0
	for i in medics:
		best = maxf(best, float(crew[i]["first_aid"]))
	return HEAL_FACTOR_MINUTES / best / rate(inf)


# ---------- guardado ----------

func to_dict() -> Dictionary:
	var bs: Array = []
	for b in bases:
		var builds: Array = []
		for x: Dictionary in b["buildings"]:
			builds.append({"type": String(x["type"]), "lot": x["lot"], "level": x["level"]})
		bs.append({"body": String(b["body"]), "founded": b["founded"], "buildings": builds,
				"mine_acc": b["mine_acc"], "mine_next": String(b["mine_next"])})
	var st := {}
	for k in storage:
		st[String(k)] = storage[k]
	var cr: Array = []
	for m in crew:
		var d := m.duplicate()
		d["base"] = String(m["base"])
		d["job"] = String(m["job"])
		cr.append(d)
	var res: Array[String] = []
	for r in researched:
		res.append(String(r))
	return {"bases": bs, "storage": st, "crew": cr, "research_current": String(research_current),
			"research_progress": research_progress, "researched": res, "plans": plans, "auto_plan": auto_plan,
			"academy": academy_candidates, "fuel_wait": fuel_wait, "refine_acc": _refine_acc}


func from_dict(d: Dictionary) -> void:
	reset()
	for b: Dictionary in d.get("bases", []):
		var body_id := StringName(b.get("body", ""))
		if Catalog.body(body_id) == null:
			continue
		var builds: Array[Dictionary] = []
		for x: Dictionary in b.get("buildings", []):
			if Catalog.building(StringName(x.get("type", ""))):
				builds.append({"type": StringName(x["type"]), "lot": int(x["lot"]), "level": int(x.get("level", 1))})
		bases.append({"body": body_id, "founded": bool(b.get("founded", true)), "buildings": builds,
				"mine_acc": float(b.get("mine_acc", 0.0)), "mine_next": StringName(b.get("mine_next", ""))})
	for k: String in d.get("storage", {}):
		storage[StringName(k)] = int(d["storage"][k])
	for m: Dictionary in d.get("crew", []):
		var c := GameState.crew_from_dict(m)
		c.merge({"base": StringName(m.get("base", "")), "job": StringName(m.get("job", "")),
				"wounded": bool(m.get("wounded", false)), "heal": float(m.get("heal", 0.0)),
				"training": String(m.get("training", "")), "train_left": float(m.get("train_left", 0.0))}, true)
		crew.append(c)
	research_current = StringName(d.get("research_current", ""))
	research_progress = float(d.get("research_progress", 0.0))
	for r: String in d.get("researched", []):
		researched.append(StringName(r))
	for p: Dictionary in d.get("plans", []):
		plans.append(p)
	auto_plan = d.get("auto_plan", {})
	for c: Dictionary in d.get("academy", []):
		var m := GameState.crew_from_dict(c)
		m["price"] = int(c.get("price", 0))
		academy_candidates.append(m)
	fuel_wait = float(d.get("fuel_wait", 0.0))
	_refine_acc = float(d.get("refine_acc", 0.0))
