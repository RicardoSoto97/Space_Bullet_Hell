extends Node
## Estado de la partida que se conserva entre el nivel y la estación:
## dinero, chatarra sin vender, plano de la nave, vida de cada pieza y tripulantes.

signal money_changed(value: int)
signal scrap_changed

const STAGE_SCENE := "res://scenes/stage/stage.tscn"
const STATION_SCENE := "res://scenes/station/station.tscn"
const BASE_SCENE := "res://scenes/base/base.tscn"
const MENU_SCENE := "res://scenes/main.tscn"
## Una sola partida guardada. Las pruebas automáticas (con argumentos) usan otro archivo
## para no pisar la partida del jugador.
const SAVE_PATH := "user://save.json"
const TEST_SAVE_PATH := "user://save_test.json"
const SAVE_VERSION := 2

## Duración del nivel = recarga del depósito básico (GDD 5.4): 5 minutos.
const BASIC_TANK_SECONDS := 300.0
## Depósitos de combustible interestelar (GDD 5.4). Cada nivel suma 5 minutos de alcance.
## Mientras no exista la base se compran en la estación a precio de fabricación; cada uno
## reemplaza al anterior.
const TANK_NAMES: Array[String] = ["Depósito básico", "Depósito I", "Depósito II", "Depósito III",
		"Depósito IV", "Depósito V"]
const TANK_PRICES: Array[int] = [0, 1500, 4000, 10000, 25000, 60000]
## Dinero al empezar una partida nueva (decisión del usuario para la 0.1.0, 20/11/2026).
## `--money=N` lo cambia en las pruebas.
const STARTING_MONEY := 1000
## Reparar cuesta 2 créditos por punto de vida.
const REPAIR_COST_PER_HP := 2
## Reconstruir una pieza perdida por desconexión cuesta el 50 % de su precio (GDD 3.4).
const REBUILD_FACTOR := 0.5
## Vender una pieza o un arma devuelve la mitad de su precio (propuesta).
const SELL_FACTOR := 0.5
## Mejora de estructuras con función: misma curva que las armas (GDD 8.1, propuesta).
const STRUCTURE_MAX_LEVEL := 10
const STRUCTURE_UPGRADE_BASE := 200
const STRUCTURE_UPGRADE_GROWTH := 1.6
## Evolucionar un arma al nivel 10 (GDD 8.3, provisional).
const EVOLUTION_COST := 12000
## Margen para decidir si dos piezas se solapan (metros).
const OVERLAP_MARGIN := 0.06
## Las cinco estadísticas de profesión de los tripulantes (GDD 4.6).
const CREW_STATS: Array[String] = ["gunnery", "engineering", "research", "repair", "first_aid"]
const CREW_STAT_NAMES := {"gunnery": "Artillero", "engineering": "Ingeniero", "research": "Investigador",
		"repair": "Reparador", "first_aid": "Primeros auxilios"}
const CREW_NAMES: Array[String] = ["Vega", "Ito", "Marlow", "Okafor", "Brenna", "Sato", "Ruiz", "Kowal",
		"Nadia", "Teo", "Imani", "Lars", "Petra", "Davi", "Yuna", "Odile", "Hask", "Mirela", "Quill", "Zane"]
const PERSONALITIES: Array[String] = ["Tranquilo", "Temerario", "Meticuloso", "Bromista", "Gruñón",
		"Optimista", "Callado", "Curioso", "Orgulloso", "Leal"]

var money: int = 0
## Chatarra sin vender: id del tipo -> unidades.
var scrap: Dictionary[StringName, int] = {}
## Plano de la nave. Cada entrada es un Dictionary (ver `_entry`). Un padre siempre va
## antes que sus hijos.
var blueprint: Array[Dictionary] = []
## Tripulantes: {name, personality, gunnery, engineering, research, repair, first_aid}.
var crew: Array[Dictionary] = []
## Candidatos del bar de la estación: tripulante + `price`.
var bar_candidates: Array[Dictionary] = []
var stage_duration: float = BASIC_TANK_SECONDS
var stages_survived: int = 0
## Resultado del último nivel, para mostrarlo en la estación.
var last_report: String = ""
## Depósito de combustible interestelar: 0 = básico (5 min); cada nivel suma 5 min (GDD 5.4).
var fuel_tank_level: int = 0
## Dónde está la nave: id de una estación, de una zona de enemigos o del cuerpo celeste de una
## base del jugador.
var location: StringName = &""
## Zonas cuyo jefe ya fue derrotado (no vuelve a aparecer).
var defeated_bosses: Array[StringName] = []

## Argumentos de línea de comandos después de `--` (pruebas automáticas).
var args: Dictionary = {}


func _ready() -> void:
	_parse_args()
	_setup_input()
	if args.has("stage-seconds"):
		stage_duration = float(args["stage-seconds"])
	new_game()
	# Simulación de una partida entera (fase 6).
	if args.has("balance-career"):
		get_tree().root.add_child.call_deferred(BalanceCareer.new())


## Empieza una partida nueva: nave inicial, sin dinero, en la estación del primer sistema.
func new_game() -> void:
	money = int(args.get("money", str(STARTING_MONEY)))
	scrap.clear()
	reset_to_starter_ship()
	refresh_bar()
	stages_survived = 0
	fuel_tank_level = 0
	location = Catalog.start_station()
	defeated_bosses.clear()
	last_report = ""
	Bases.reset()


# ---------- guardado ----------

func save_path() -> String:
	if args.has("save-path"):
		return args["save-path"]
	return TEST_SAVE_PATH if not args.is_empty() else SAVE_PATH


func has_save() -> bool:
	return FileAccess.file_exists(save_path())


## Guarda la partida en JSON. Las posiciones de las piezas no se guardan: se recalculan
## a partir de las ranuras al cargar.
func save_game() -> bool:
	var bp := serialize_blueprint()
	var scrap_out := {}
	for k in scrap:
		scrap_out[String(k)] = scrap[k]
	var bosses: Array[String] = []
	for b in defeated_bosses:
		bosses.append(String(b))
	var data := {
		"version": SAVE_VERSION, "money": money, "scrap": scrap_out, "blueprint": bp, "crew": crew,
		"bar": bar_candidates, "stages_survived": stages_survived, "fuel_tank_level": fuel_tank_level,
		"location": String(location), "defeated_bosses": bosses, "last_report": last_report,
		"bases": Bases.to_dict(),
	}
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f == null:
		push_warning("No se pudo guardar la partida en %s" % save_path())
		return false
	f.store_string(JSON.stringify(data, "	"))
	return true


## Carga la partida guardada. Devuelve false (y no cambia nada) si no existe o está dañada.
func load_game() -> bool:
	var f := FileAccess.open(save_path(), FileAccess.READ)
	if f == null:
		return false
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("blueprint"):
		push_warning("La partida guardada está dañada.")
		return false
	if not load_blueprint(data["blueprint"]):
		return false
	crew.clear()
	for m: Dictionary in data.get("crew", []):
		crew.append(crew_from_dict(m))
	bar_candidates.clear()
	for m: Dictionary in data.get("bar", []):
		var c := crew_from_dict(m)
		c["price"] = int(m.get("price", 0))
		bar_candidates.append(c)
	money = int(data.get("money", 0))
	scrap.clear()
	for k: String in data.get("scrap", {}):
		scrap[StringName(k)] = int(data["scrap"][k])
	stages_survived = int(data.get("stages_survived", 0))
	fuel_tank_level = int(data.get("fuel_tank_level", 0))
	Bases.from_dict(data.get("bases", {}))
	location = StringName(data.get("location", ""))
	# Se guarda siempre en una estación o una base; si el lugar ya no existe, se vuelve a la inicial.
	var site := Catalog.site(location)
	if not Bases.is_base(location) and (site == null or not site.is_station()):
		location = Catalog.start_station()
	defeated_bosses.clear()
	for b: String in data.get("defeated_bosses", []):
		defeated_bosses.append(StringName(b))
	last_report = data.get("last_report", "")
	money_changed.emit(money)
	scrap_changed.emit()
	return true


# ---------- plano de la nave ----------

## El plano en un formato que se puede guardar en JSON. Con `clean`, como un plano del hangar:
## todas las piezas intactas y sin tripulantes.
func serialize_blueprint(clean: bool = false) -> Array:
	var bp: Array = []
	for e in blueprint:
		var d := e.duplicate()
		d.erase("transform")
		d["part"] = String(e["part"])
		d["weapon"] = String(e["weapon"])
		if clean:
			d.merge({"hp": -1.0, "crew": -1, "lost": false, "destroyed": false}, true)
		bp.append(d)
	return bp


## Reemplaza el plano de la nave por uno guardado. Devuelve false si está dañado.
func load_blueprint(data: Array) -> bool:
	var bp: Array[Dictionary] = []
	for d: Dictionary in data:
		var part_id := StringName(d.get("part", ""))
		if Catalog.part(part_id) == null:
			push_warning("Plano guardado: pieza desconocida %s" % part_id)
			return false
		var e := _entry(part_id, int(d["attached_to"]), int(d["parent_slot"]), int(d["mount_slot"]))
		e["hp"] = float(d.get("hp", -1.0))
		e["level"] = int(d.get("level", 1))
		var weapon_id := StringName(d.get("weapon", ""))
		e["weapon"] = weapon_id if Catalog.weapon(weapon_id) != null else &""
		e["weapon_level"] = int(d.get("weapon_level", 1))
		e["crew"] = int(d.get("crew", -1))
		e["lost"] = bool(d.get("lost", false))
		e["destroyed"] = bool(d.get("destroyed", false))
		bp.append(e)
	blueprint = bp
	update_transforms()
	for e in blueprint:
		if e["crew"] >= crew.size():
			e["crew"] = -1
	return true

## Una pieza del plano. Se une a la ranura `parent_slot` de la pieza `attached_to` usando
## su propia ranura `mount_slot`. `transform` se calcula a partir de las ranuras.
func _entry(part_id: StringName, attached_to: int, parent_slot: int, mount_slot: int = -2) -> Dictionary:
	var data := Catalog.part(part_id)
	return {
		"part": part_id,
		"attached_to": attached_to,
		"parent_slot": parent_slot,
		"mount_slot": data.mount_slot if mount_slot == -2 else mount_slot,
		"transform": Transform3D.IDENTITY,
		"hp": -1.0,          # -1 = vida completa
		"level": 1,          # nivel de la estructura (si tiene función)
		"weapon": &"",
		"weapon_level": 1,
		"crew": -1,          # índice del tripulante que la opera
		"lost": false,       # se perdió por quedar desconectada: se reconstruye al 50 %
		"destroyed": false,  # su vida llegó a 0: hay que comprarla de nuevo
	}


func reset_to_starter_ship() -> void:
	blueprint.clear()
	crew.clear()
	blueprint.append(_entry(&"core", -1, -1))
	var station := _entry(&"command_station", 0, 0)  # ranura frontal del núcleo
	# Pruebas: `--starter-weapon=<id>` monta otra arma en la nave inicial.
	station["weapon"] = StringName(args.get("starter-weapon", "machine_gun"))
	blueprint.append(station)
	blueprint.append(_entry(&"thruster_small", 0, 1))  # ranura trasera del núcleo
	# Pruebas: `--starter-shield` monta un generador de escudo arriba del núcleo.
	if args.has("starter-shield"):
		blueprint.append(_entry(&"shield_generator", 0, 4))
	update_transforms()
	crew.append(_new_crew_member("Rook", "Leal", {"gunnery": 40, "engineering": 20, "research": 15,
			"repair": 20, "first_aid": 10}))
	station["crew"] = 0


## Tripulante leído de una partida guardada.
func crew_from_dict(m: Dictionary) -> Dictionary:
	return _new_crew_member(m.get("name", "?"), m.get("personality", ""), m)


func _new_crew_member(member_name: String, personality: String, stats: Dictionary) -> Dictionary:
	var m := {"name": member_name, "personality": personality}
	for s in CREW_STATS:
		m[s] = int(stats.get(s, 10))
	return m


## Transformación de una pieza que se une con su ranura `mount` a la ranura `parent_slot`
## de una pieza padre que está en `parent_xf`. Las ranuras quedan enfrentadas.
static func attach_transform(parent_xf: Transform3D, parent_data: PartData, parent_slot: int,
		child_data: PartData, mount: int) -> Transform3D:
	var slot_pos := parent_xf * parent_data.slot_positions[parent_slot]
	var target := -(parent_xf.basis * parent_data.slot_normals[parent_slot]).normalized()
	var m_n := child_data.slot_normals[mount]
	var basis: Basis
	if absf(m_n.y) < 0.01 and absf(target.y) < 0.01:
		basis = Basis(Vector3.UP, m_n.signed_angle_to(target, Vector3.UP))
	elif m_n.dot(target) < -0.999:
		basis = Basis(Vector3.FORWARD, PI)
	else:
		basis = Basis(Quaternion(m_n, target))
	# Todas las piezas giran en múltiplos de 90°: se redondea para no acumular errores.
	basis = Basis(basis.x.round(), basis.y.round(), basis.z.round())
	var pos := slot_pos - basis * child_data.slot_positions[mount]
	return Transform3D(basis, pos.snappedf(0.001))


## Recalcula la posición y el giro de todas las piezas a partir de sus ranuras.
func update_transforms() -> void:
	for e in blueprint:
		var parent: int = e["attached_to"]
		if parent < 0:
			e["transform"] = Transform3D.IDENTITY
			continue
		var p := blueprint[parent]
		e["transform"] = attach_transform(p["transform"], Catalog.part(p["part"]), e["parent_slot"],
				Catalog.part(e["part"]), e["mount_slot"])


## Cajas que ocupa una pieza en el espacio de la nave. La estación de mando reserva
## además el espacio de su arma, delante.
static func footprints_for(xf: Transform3D, data: PartData) -> Array[AABB]:
	var out: Array[AABB] = [xf * AABB(data.collision_offset - data.collision_size / 2.0, data.collision_size)]
	if data.category == PartData.Category.COMMAND_STATION:
		out.append(xf * AABB(data.weapon_offset + Vector3(-0.2, -0.2, -1.0), Vector3(0.4, 0.4, 1.0)))
	return out


func footprints(index: int) -> Array[AABB]:
	var e := blueprint[index]
	return footprints_for(e["transform"], Catalog.part(e["part"]))


func _overlaps(xf: Transform3D, data: PartData, ignore: Array[int]) -> bool:
	var mine := footprints_for(xf, data)
	for i in blueprint.size():
		if i in ignore:
			continue
		for a in footprints(i):
			for b in mine:
				if _shrink(a).intersects(_shrink(b)):
					return true
	return false


## Caja que envuelve a toda la nave (para encuadrar la cámara y la miniatura).
func ship_bounds() -> AABB:
	var out := AABB()
	var first := true
	for i in blueprint.size():
		for box in footprints(i):
			out = box if first else out.merge(box)
			first = false
	return out


## Encoge una caja el margen de solape sin dejarla con tamaño negativo (piezas finas).
static func _shrink(box: AABB) -> AABB:
	var m := Vector3(minf(OVERLAP_MARGIN, box.size.x * 0.4), minf(OVERLAP_MARGIN, box.size.y * 0.4),
			minf(OVERLAP_MARGIN, box.size.z * 0.4))
	return AABB(box.position + m, box.size - m * 2.0)


func is_alive(index: int) -> bool:
	var e := blueprint[index]
	return not e["lost"] and not e["destroyed"]


func children_of(index: int) -> Array[int]:
	var out: Array[int] = []
	for i in blueprint.size():
		if blueprint[i]["attached_to"] == index:
			out.append(i)
	return out


## Ranuras de una pieza que ya están en uso (por su padre o por sus hijos).
func used_slots(index: int) -> Dictionary[int, bool]:
	var out: Dictionary[int, bool] = {}
	var e := blueprint[index]
	if e["attached_to"] >= 0:
		out[e["mount_slot"]] = true
	for c in children_of(index):
		out[blueprint[c]["parent_slot"]] = true
	return out


## Posición y dirección de una ranura en el espacio de la nave.
func slot_world(index: int, slot: int) -> Dictionary:
	var e := blueprint[index]
	var data := Catalog.part(e["part"])
	var xf: Transform3D = e["transform"]
	return {"position": xf * data.slot_positions[slot],
			"normal": (xf.basis * data.slot_normals[slot]).normalized(),
			"kind": data.slot_kinds[slot]}


## Ranuras libres de las piezas intactas. Se descartan las que dan contra otra pieza.
func free_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in blueprint.size():
		if not is_alive(i):
			continue
		var data := Catalog.part(blueprint[i]["part"])
		var used := used_slots(i)
		for s in data.slot_count():
			if used.has(s):
				continue
			var w := slot_world(i, s)
			if _point_blocked(w["position"] + w["normal"] * 0.3, i):
				continue
			w["part_index"] = i
			w["slot"] = s
			out.append(w)
	return out


func _point_blocked(point: Vector3, ignore: int) -> bool:
	for i in blueprint.size():
		if i == ignore:
			continue
		for box in footprints(i):
			if _shrink(box).has_point(point):
				return true
	return false


## Comprueba si una pieza cabe en una ranura. Devuelve {ok, reason, mount, transform}.
## Con `mount` = -1 prueba las caras de la pieza hasta encontrar una que quepa.
func check_placement(part_id: StringName, parent: int, parent_slot: int, mount: int = -1,
		ignore_self: int = -1) -> Dictionary:
	var data := Catalog.part(part_id)
	var result := {"ok": false, "reason": "", "mount": -1, "transform": Transform3D.IDENTITY}
	if parent < 0 or parent >= blueprint.size() or not is_alive(parent):
		result["reason"] = "La pieza de destino no está intacta."
		return result
	var parent_data := Catalog.part(blueprint[parent]["part"])
	if not data.fits_slot_kind(parent_data.slot_kinds[parent_slot]):
		result["reason"] = "Solo va arriba o abajo de una pieza." if data.face_only \
				else "Arriba y abajo solo caben accesorios."
		return result
	if data.unique:
		for i in blueprint.size():
			if i != ignore_self and blueprint[i]["part"] == part_id and not blueprint[i]["destroyed"]:
				result["reason"] = "La nave solo puede llevar uno."
				return result
	var options: Array[int] = data.mount_options()
	if mount >= 0:
		options = [mount]
	var ignore: Array[int] = [parent, ignore_self]
	for m in options:
		var xf := attach_transform(blueprint[parent]["transform"], parent_data, parent_slot, data, m)
		if not _overlaps(xf, data, ignore):
			result.merge({"ok": true, "mount": m, "transform": xf}, true)
			return result
	result["reason"] = "No cabe: chocaría con otra pieza."
	return result


## Compra una pieza y la acopla. Devuelve "" si salió bien o el motivo del fallo.
func buy_part(part_id: StringName, parent: int, parent_slot: int) -> String:
	var data := Catalog.part(part_id)
	if data.price > money:
		return "No tienes dinero suficiente."
	if used_slots(parent).has(parent_slot):
		return "Esa ranura ya está ocupada."
	var check := check_placement(part_id, parent, parent_slot)
	if not check["ok"]:
		return check["reason"]
	spend(data.price)
	var e := _entry(part_id, parent, parent_slot, check["mount"])
	e["transform"] = check["transform"]
	blueprint.append(e)
	return ""


## Gira una pieza sin hijos: la une a su ranura por otra de sus caras.
func rotate_part(index: int) -> bool:
	var e := blueprint[index]
	var data := Catalog.part(e["part"])
	var options := data.mount_options()
	if options.size() < 2 or not children_of(index).is_empty() or e["attached_to"] < 0:
		return false
	var start := options.find(e["mount_slot"])
	for k in range(1, options.size()):
		var m := options[(start + k) % options.size()]
		var check := check_placement(e["part"], e["attached_to"], e["parent_slot"], m, index)
		if check["ok"]:
			e["mount_slot"] = m
			e["transform"] = check["transform"]
			return true
	return false


## Índices de una pieza y de todo lo que cuelga de ella.
func subtree(index: int) -> Array[int]:
	var out: Array[int] = [index]
	var k := 0
	while k < out.size():
		out.append_array(children_of(out[k]))
		k += 1
	return out


## Lo que se recupera al vender una pieza y todo lo que cuelga de ella.
func sell_value(index: int) -> int:
	var total := 0.0
	for i in subtree(index):
		var e := blueprint[i]
		if e["destroyed"]:
			continue
		var factor := SELL_FACTOR * (REBUILD_FACTOR if e["lost"] else 1.0)
		total += Catalog.part(e["part"]).price * factor
		if e["weapon"] != &"":
			total += Catalog.weapon(e["weapon"]).price * factor
	return int(total)


## Motivo por el que no se puede quitar una pieza, o "" si se puede.
func remove_block_reason(index: int) -> String:
	if blueprint[index]["attached_to"] < 0:
		return "El núcleo no se puede quitar."
	var capacity_lost := 0
	for i in subtree(index):
		if is_alive(i):
			capacity_lost += Catalog.part(blueprint[i]["part"]).crew_at(blueprint[i]["level"])
	if crew.size() > crew_capacity() - capacity_lost:
		return "Faltarían plazas para tus tripulantes: despide a alguien primero."
	return ""


## Quita una pieza y todo lo que cuelga de ella, y devuelve la mitad de su precio.
## Los tripulantes que operaban esas piezas quedan sin puesto.
func sell_part(index: int) -> int:
	if remove_block_reason(index) != "":
		return 0
	var refund := sell_value(index)
	var remove := subtree(index)
	remove.sort()
	var new_index: Dictionary[int, int] = {}
	var kept: Array[Dictionary] = []
	for i in blueprint.size():
		if i in remove:
			continue
		new_index[i] = kept.size()
		kept.append(blueprint[i])
	for e in kept:
		if e["attached_to"] >= 0:
			e["attached_to"] = new_index[e["attached_to"]]
	blueprint = kept
	add_money(refund)
	return refund


func part_max_hp(entry: Dictionary) -> float:
	var data := Catalog.part(entry["part"])
	var hp := data.hp_at(entry["level"])
	if data.category == PartData.Category.CORE:
		for e in blueprint:
			if not e["lost"] and not e["destroyed"]:
				hp += Catalog.part(e["part"]).hull_bonus
	return hp


func part_hp(entry: Dictionary) -> float:
	return part_max_hp(entry) if entry["hp"] < 0.0 else entry["hp"]


## Si la nave tiene al menos un arma intacta y con tripulante.
func has_working_weapon() -> bool:
	for e in blueprint:
		if e["weapon"] != &"" and not e["lost"] and not e["destroyed"] and e["crew"] >= 0:
			return true
	return false


## Abandona la nave actual y vuelve a la nave inicial, gratis (sin hangar, GDD 7.4).
## Evita quedarse atascado sin armas y sin dinero. Se conservan el dinero y la chatarra.
func abandon_ship() -> void:
	reset_to_starter_ship()
	last_report = "Abandonaste la nave. Vuelves a la nave inicial con un artillero nuevo."


func has_unmanned_station() -> bool:
	for e in blueprint:
		if e["weapon"] != &"" and not e["lost"] and not e["destroyed"] and e["crew"] < 0:
			return true
	return false


# ---------- mapa estelar y viajes ----------

## Minutos de combustible que caben en el depósito: el alcance de un salto.
func tank_minutes() -> int:
	return 5 * (fuel_tank_level + 1)


## Si se puede saltar a un lugar del mapa. Las estaciones siempre están al alcance: sus
## cargadores rellenan el combustible al llegar (GDD 5.4).
func can_reach(site_id: StringName) -> bool:
	# Las bases propias, como las estaciones, siempre están al alcance.
	if Bases.is_base(site_id):
		return true
	var s := Catalog.site(site_id)
	if s == null:
		return false
	if s.is_station():
		return true
	return (s as ZoneData).distance_minutes <= tank_minutes()


## Compra el depósito de ese nivel (reemplaza al actual). Devuelve "" o el motivo del fallo.
func buy_fuel_tank(level: int) -> String:
	if level <= fuel_tank_level or level >= TANK_PRICES.size():
		return "Ya tienes un depósito igual o mejor."
	if not spend(TANK_PRICES[level]):
		return "No tienes dinero suficiente."
	fuel_tank_level = level
	return ""


func in_station() -> bool:
	var s := Catalog.site(location)
	return s != null and s.is_station()


## Si la nave está aterrizada en una base propia.
func in_base() -> bool:
	return Bases.is_base(location)


## Zona de enemigos donde está la nave, o null si está en una estación.
func current_zone() -> ZoneData:
	return Catalog.zone(location)


func is_boss_defeated(zone_id: StringName) -> bool:
	return zone_id in defeated_bosses


## Salta a un lugar del mapa: a una zona (empieza un nivel que dura lo que tarda en
## recargarse el combustible gastado) o a una estación.
func travel_to(site_id: StringName) -> void:
	var from := location
	if Bases.is_base(from) and site_id != from:
		Bases.on_takeoff(from)
	if Bases.is_base(site_id):
		location = site_id
		var notes := Bases.on_land(site_id)
		if last_report == "":
			last_report = "Aterrizaste en tu base de %s." % Catalog.place_name(site_id)
		if notes != "":
			last_report += " " + notes
		go_to_station()
		return
	var s := Catalog.site(site_id)
	if s == null:
		return
	location = site_id
	if s.is_station():
		if site_id != from:
			refresh_bar()
			if last_report == "":
				last_report = "Llegaste a %s." % s.display_name
		go_to_station()
		return
	stage_duration = float((s as ZoneData).distance_minutes) * 60.0
	if args.has("stage-seconds"):
		stage_duration = float(args["stage-seconds"])
	go_to_stage()


# ---------- mejoras y armas ----------

## Costo de subir de nivel una estructura con función, o -1 si no tiene niveles o está al máximo.
func structure_upgrade_cost(entry: Dictionary) -> int:
	if not Catalog.part(entry["part"]).has_levels or entry["level"] >= STRUCTURE_MAX_LEVEL:
		return -1
	return level_cost(Catalog.part(entry["part"]), entry["level"])


## Costo de subir una estructura del nivel `level` al siguiente. Cada pieza puede tener su
## propia curva (el núcleo); si no, la general de las estructuras.
static func level_cost(data: PartData, level: int) -> int:
	var base := data.upgrade_base_cost if data.upgrade_base_cost > 0 else STRUCTURE_UPGRADE_BASE
	var growth := data.upgrade_growth if data.upgrade_growth > 0.0 else STRUCTURE_UPGRADE_GROWTH
	return int(round(base * pow(growth, level - 1)))


func upgrade_structure(entry: Dictionary) -> bool:
	var cost := structure_upgrade_cost(entry)
	if cost < 0 or not spend(cost):
		return false
	# Si la mejora sube la vida (el núcleo), la pieza gana esa vida también si estaba dañada.
	var old_max := part_max_hp(entry)
	entry["level"] += 1
	if entry["hp"] >= 0.0:
		entry["hp"] += part_max_hp(entry) - old_max
	return true


func upgrade_weapon(entry: Dictionary) -> bool:
	var w := Catalog.weapon(entry["weapon"])
	var cost := w.upgrade_cost(entry["weapon_level"])
	if cost < 0 or not spend(cost):
		return false
	entry["weapon_level"] += 1
	return true


## Evoluciona el arma de una estación de mando: el arma al nivel máximo se cambia por su
## evolución, que vuelve al nivel 1. La estación de mando se conserva (GDD 8.3).
func can_evolve_weapon(entry: Dictionary) -> bool:
	if entry["weapon"] == &"":
		return false
	var w := Catalog.weapon(entry["weapon"])
	return w.evolves_into != &"" and Catalog.weapon(w.evolves_into) != null and entry["weapon_level"] >= w.max_level


func evolve_weapon(entry: Dictionary) -> bool:
	if not can_evolve_weapon(entry) or not spend(EVOLUTION_COST):
		return false
	entry["weapon"] = Catalog.weapon(entry["weapon"]).evolves_into
	entry["weapon_level"] = 1
	return true


func buy_weapon(entry: Dictionary, weapon_id: StringName) -> bool:
	if entry["weapon"] != &"" or not spend(Catalog.weapon(weapon_id).price):
		return false
	entry["weapon"] = weapon_id
	entry["weapon_level"] = 1
	return true


func sell_weapon(entry: Dictionary) -> int:
	if entry["weapon"] == &"":
		return 0
	var refund := int(Catalog.weapon(entry["weapon"]).price * SELL_FACTOR)
	entry["weapon"] = &""
	entry["weapon_level"] = 1
	add_money(refund)
	return refund


# ---------- tripulantes ----------

## Plazas para tripulantes de las piezas intactas (núcleo + habitaciones).
func crew_capacity() -> int:
	var total := 0
	for i in blueprint.size():
		if is_alive(i):
			total += Catalog.part(blueprint[i]["part"]).crew_at(blueprint[i]["level"])
	return total


## Bono de calidad de vida: +1 % por nivel de cada estructura de tripulación (GDD 4.3).
func crew_quality_bonus() -> float:
	var total := 0.0
	for i in blueprint.size():
		if is_alive(i):
			total += Catalog.part(blueprint[i]["part"]).crew_bonus_per_level * blueprint[i]["level"]
	return total


## Estadística de un tripulante con el bono de calidad de vida aplicado.
func effective_stat(crew_index: int, stat: String) -> float:
	if crew_index < 0 or crew_index >= crew.size():
		return 0.0
	return float(crew[crew_index][stat]) * (1.0 + crew_quality_bonus())


## Pieza en la que trabaja un tripulante, o -1.
func crew_post(crew_index: int) -> int:
	for i in blueprint.size():
		if blueprint[i]["crew"] == crew_index:
			return i
	return -1


## Pone a un tripulante en una estación de mando (lo quita de su puesto anterior).
func assign_crew(crew_index: int, part_index: int) -> void:
	for e in blueprint:
		if e["crew"] == crew_index:
			e["crew"] = -1
	if part_index >= 0:
		blueprint[part_index]["crew"] = crew_index


func dismiss_crew(crew_index: int) -> void:
	_remove_crew(crew_index)


## Saca a un tripulante de la nave (por ejemplo, para que baje a la base) y lo devuelve.
func remove_crew_member(crew_index: int) -> Dictionary:
	var m := crew[crew_index]
	_remove_crew(crew_index)
	return m


## Sube un tripulante a la nave y lo pone en un arma sin tripulante, si hay.
func add_crew_member(m: Dictionary) -> void:
	crew.append(m)
	auto_assign_gunners()


## Pone a los tripulantes sin puesto en las estaciones de mando que no tienen tripulante.
func auto_assign_gunners() -> void:
	for e in blueprint:
		if e["weapon"] == &"" or e["crew"] >= 0 or e["destroyed"] or e["lost"]:
			continue
		for i in crew.size():
			if crew_post(i) < 0:
				e["crew"] = i
				break


func _remove_crew(crew_index: int) -> void:
	crew.remove_at(crew_index)
	for e in blueprint:
		if e["crew"] == crew_index:
			e["crew"] = -1
		elif e["crew"] > crew_index:
			e["crew"] -= 1


## Nuevos candidatos en el bar: cambian cada vez que la nave vuelve a la estación (GDD 4.6).
func refresh_bar() -> void:
	bar_candidates.clear()
	var names := CREW_NAMES.duplicate()
	names.shuffle()
	for i in randi_range(3, 5):
		bar_candidates.append(random_candidate(names[i]))


## Candidato al azar con las cifras propuestas en el GDD: estadísticas de 1 a 100, mejor
## estadística 20–50 (70–100 si es excepcional, raro); ingeniero y reparador van juntos
## (como mucho 15 puntos de diferencia); precio = mejor estadística² ÷ 2.
func random_candidate(member_name: String) -> Dictionary:
	var best_stat: String = CREW_STATS.pick_random()
	var best := randi_range(70, 100) if randf() < 0.1 else randi_range(20, 50)
	var stats: Dictionary = {}
	for s in CREW_STATS:
		stats[s] = randi_range(5, maxi(6, int(best * 0.7)))
	stats[best_stat] = best
	if best_stat == "engineering" or best_stat == "repair":
		var other := "repair" if best_stat == "engineering" else "engineering"
		stats[other] = clampi(best - randi_range(0, 15), 1, best)
	else:
		stats["repair"] = clampi(stats["engineering"] + randi_range(-15, 15), 5, best)
	var m := _new_crew_member(member_name, PERSONALITIES.pick_random(), stats)
	m["price"] = int(best * best / 2.0)
	return m


## Mejor estadística de un tripulante: su «profesión».
func best_stat(member: Dictionary) -> String:
	var best := CREW_STATS[0]
	for s in CREW_STATS:
		if member[s] > member[best]:
			best = s
	return best


## Contrata a un candidato del bar. Devuelve "" si salió bien o el motivo del fallo.
func hire_candidate(index: int) -> String:
	var c := bar_candidates[index]
	if crew.size() >= crew_capacity():
		return "No hay plazas: instala habitaciones de tripulantes."
	if not spend(c["price"]):
		return "No tienes dinero suficiente."
	var m := c.duplicate()
	m.erase("price")
	crew.append(m)
	bar_candidates.remove_at(index)
	for e in blueprint:
		if e["weapon"] != &"" and e["crew"] < 0 and not e["destroyed"] and not e["lost"]:
			e["crew"] = crew.size() - 1
			break
	return ""


# ---------- economía ----------

func add_scrap(type_id: StringName, amount: int = 1) -> void:
	scrap[type_id] = scrap.get(type_id, 0) + amount
	scrap_changed.emit()


func scrap_value() -> int:
	var total := 0
	for type_id in scrap:
		total += scrap[type_id] * Catalog.scrap(type_id).price
	return total


func sell_all_scrap() -> int:
	var earned := scrap_value()
	scrap.clear()
	add_money(earned)
	scrap_changed.emit()
	return earned


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func spend(amount: int) -> bool:
	if amount > money:
		return false
	add_money(-amount)
	return true


## Costo de dejar la nave como nueva: vida, piezas perdidas (50 %) y destruidas (100 %).
## Si la estación de mando se perdió o se destruyó, su arma también.
func repair_cost() -> int:
	var cost := 0.0
	for e in blueprint:
		var data := Catalog.part(e["part"])
		var weapon_price := Catalog.weapon(e["weapon"]).price if e["weapon"] != &"" else 0
		if e["destroyed"]:
			cost += data.price + weapon_price
		elif e["lost"]:
			cost += (data.price + weapon_price) * REBUILD_FACTOR
		elif e["hp"] >= 0.0:
			cost += (part_max_hp(e) - e["hp"]) * REPAIR_COST_PER_HP
	return int(ceil(cost))


func repair_all() -> bool:
	if not spend(repair_cost()):
		return false
	for e in blueprint:
		e["hp"] = -1.0
		e["lost"] = false
		e["destroyed"] = false
	return true


## Repara lo que alcanza el dinero (fase 6): primero la vida de las piezas que siguen en pie,
## empezando por el núcleo, y después reconstruye las perdidas o destruidas desde el núcleo hacia
## afuera (una pieza solo si su padre ya está en pie). Devuelve lo gastado.
func repair_affordable() -> int:
	var spent := 0
	for e in blueprint:
		if e["lost"] or e["destroyed"] or e["hp"] < 0.0:
			continue
		var missing: float = part_max_hp(e) - float(e["hp"])
		var cost := int(ceil(missing * REPAIR_COST_PER_HP))
		if cost <= money:
			e["hp"] = -1.0
		else:
			cost = money
			e["hp"] += float(cost) / REPAIR_COST_PER_HP
		spent += cost
		money -= cost
		if money <= 0:
			break
	var changed := true
	while changed:
		changed = false
		for e in blueprint:
			if not (e["lost"] or e["destroyed"]):
				continue
			var parent: int = e["attached_to"]
			if parent >= 0 and (blueprint[parent]["lost"] or blueprint[parent]["destroyed"]):
				continue
			var data := Catalog.part(e["part"])
			var weapon_price := Catalog.weapon(e["weapon"]).price if e["weapon"] != &"" else 0
			var cost := int(ceil((data.price + weapon_price) * (1.0 if e["destroyed"] else REBUILD_FACTOR)))
			if cost > money:
				continue
			money -= cost
			spent += cost
			e["hp"] = -1.0
			e["lost"] = false
			e["destroyed"] = false
			changed = true
	money_changed.emit(money)
	return spent


# ---------- fin del nivel ----------

func on_stage_survived(scrap_collected: int) -> void:
	stages_survived += 1
	_resolve_injuries()
	refresh_bar()
	var zone := current_zone()
	var zone_name := zone.display_name if zone else "la zona"
	last_report = "Sobreviviste en %s y recogiste %d trozos de chatarra." % [zone_name, scrap_collected] + last_report


## La nave se destruyó por completo (GDD 7.4): el dinero se mantiene, la chatarra se pierde
## y, sin enfermería, los tripulantes heridos mueren. Sin hangar se vuelve a la nave inicial.
func on_ship_destroyed() -> void:
	scrap.clear()
	scrap_changed.emit()
	var wounded: Array[Dictionary] = []
	wounded.assign(crew)
	var saved := Bases.injure(wounded)
	reset_to_starter_ship()
	refresh_bar()
	last_report = "Tu nave fue destruida. Perdiste la chatarra sin vender y vuelves con la nave inicial."
	if saved > 0:
		last_report += " %d tripulante(s) heridos fueron evacuados a la enfermería." % saved
	elif not wounded.is_empty():
		last_report += " Tus tripulantes murieron: no tienes enfermería."
	# Se reaparece en la estación más cercana: la del sistema donde estaba la nave (GDD 10.6).
	# Con hangar, la nave se reconstruye desde su plano yendo a esa base.
	var base := Bases.respawn_base()
	if base != &"":
		last_report += " Tu base de %s puede reconstruir tu nave desde su plano en el hangar." % Catalog.place_name(base)
	var sys := Catalog.system_of(location)
	location = sys.stations[0].id if sys and not sys.stations.is_empty() else Catalog.start_station()


## Los tripulantes de piezas perdidas o destruidas quedan heridos: van a la enfermería de una
## base; sin enfermería mueren.
func _resolve_injuries() -> void:
	last_report = ""
	var hurt: Array[int] = []
	for e in blueprint:
		if (e["lost"] or e["destroyed"]) and e["crew"] >= 0:
			hurt.append(e["crew"])
	if hurt.is_empty():
		return
	hurt.sort()
	hurt.reverse()
	var members: Array[Dictionary] = []
	for idx in hurt:
		members.append(remove_crew_member(idx))
	if Bases.injure(members) > 0:
		last_report = " %d tripulante(s) heridos fueron evacuados a la enfermería de tu base." % members.size()
	else:
		last_report = " %d tripulante(s) murieron: no tienes enfermería." % members.size()


func go_to_stage() -> void:
	# Pruebas: `--zone=<id>` elige la zona; si no se está en una zona, se usa la primera.
	if args.has("zone") and Catalog.zone(StringName(args["zone"])) != null and current_zone() == null:
		location = StringName(args["zone"])
		stage_duration = float(current_zone().distance_minutes) * 60.0
		if args.has("stage-seconds"):
			stage_duration = float(args["stage-seconds"])
	if current_zone() == null:
		var first := Catalog.sorted_systems()
		if not first.is_empty() and not first[0].zones.is_empty():
			location = first[0].zones[0].id
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(STAGE_SCENE)


## Va a la estación o a la base donde está la nave.
func go_to_station() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(BASE_SCENE if in_base() else STATION_SCENE)


# ---------- configuración ----------

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var pair := arg.substr(2).split("=", true, 1)
		args[pair[0]] = pair[1] if pair.size() > 1 else "true"


func _setup_input() -> void:
	_add_action(&"move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action(&"move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action(&"move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action(&"move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_action(&"aim_left", [], JOY_AXIS_RIGHT_X, -1.0)
	_add_action(&"aim_right", [], JOY_AXIS_RIGHT_X, 1.0)
	_add_action(&"aim_up", [], JOY_AXIS_RIGHT_Y, -1.0)
	_add_action(&"aim_down", [], JOY_AXIS_RIGHT_Y, 1.0)
	_add_action(&"jump", [KEY_SPACE], -1, 0.0, JOY_BUTTON_A)
	_add_action(&"pause", [KEY_ESCAPE], -1, 0.0, JOY_BUTTON_START)
	_add_action(&"star_map", [KEY_M], -1, 0.0, JOY_BUTTON_BACK)
	# Cambiar de pestaña en la estación y la base (mando).
	_add_action(&"tab_prev", [], -1, 0.0, JOY_BUTTON_LEFT_SHOULDER)
	_add_action(&"tab_next", [], -1, 0.0, JOY_BUTTON_RIGHT_SHOULDER)


func _add_action(action: StringName, keys: Array, axis: int = -1, axis_dir: float = 0.0,
		button: int = -1) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for key: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	if axis >= 0:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis
		jm.axis_value = axis_dir
		InputMap.action_add_event(action, jm)
	if button >= 0:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button
		InputMap.action_add_event(action, jb)
