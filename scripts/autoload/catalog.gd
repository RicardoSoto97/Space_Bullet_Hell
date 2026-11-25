extends Node
## Carga los datos del juego (`Resource` en `res://data/`) y los entrega por identificador.

var parts: Dictionary[StringName, PartData] = {}
var weapons: Dictionary[StringName, WeaponData] = {}
var enemies: Dictionary[StringName, EnemyData] = {}
var scrap_types: Dictionary[StringName, ScrapTypeData] = {}
## La base (GDD 7): edificios y minerales puros.
var buildings: Dictionary[StringName, BuildingData] = {}
var minerals: Dictionary[StringName, MineralData] = {}
## Equilibrio de los niveles (aparición, presión y dificultad por zona).
var balance: StageBalanceData
## Mapa estelar: sistemas, y sus cuerpos, estaciones y zonas por id.
var systems: Dictionary[StringName, StarSystemData] = {}
var bodies: Dictionary[StringName, CelestialBodyData] = {}
var sites: Dictionary[StringName, MapSiteData] = {}
## id de cuerpo, estación o zona -> id de su sistema.
var _system_of: Dictionary[StringName, StringName] = {}


func _ready() -> void:
	_load_dir("res://data/parts/", parts)
	_load_dir("res://data/weapons/", weapons)
	_load_dir("res://data/enemies/", enemies)
	_load_dir("res://data/scrap/", scrap_types)
	_load_dir("res://data/buildings/", buildings)
	_load_dir("res://data/minerals/", minerals)
	_load_dir("res://data/universe/", systems)
	balance = load("res://data/balance/stage_balance.tres") as StageBalanceData
	# Pruebas de equilibrio: `-- --balance-set=hp_per_difficulty:0.3,rate_per_difficulty:0.1`
	# cambia valores solo en esta ejecución (sin tocar el .tres).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--balance-set="):
			balance = balance.duplicate()
			for pair in arg.trim_prefix("--balance-set=").split(","):
				var kv := pair.split(":")
				if kv.size() == 2 and kv[0] in balance:
					balance.set(kv[0], float(kv[1]) if typeof(balance.get(kv[0])) == TYPE_FLOAT else int(kv[1]))
					print("balance-set %s = %s" % [kv[0], balance.get(kv[0])])
	for sys: StarSystemData in systems.values():
		for b in sys.bodies:
			bodies[b.id] = b
			_system_of[b.id] = sys.id
		for s in sys.stations:
			sites[s.id] = s
			_system_of[s.id] = sys.id
		for z in sys.zones:
			sites[z.id] = z
			_system_of[z.id] = sys.id


func part(id: StringName) -> PartData:
	return parts.get(id)


func weapon(id: StringName) -> WeaponData:
	return weapons.get(id)


func scrap(id: StringName) -> ScrapTypeData:
	return scrap_types.get(id)


func building(id: StringName) -> BuildingData:
	return buildings.get(id)


func mineral(id: StringName) -> MineralData:
	return minerals.get(id)


## Edificios en el orden en que se muestran (del más útil al principio al más avanzado).
func sorted_buildings() -> Array[BuildingData]:
	var order: Array[StringName] = [&"fuel_charger", &"trade_port", &"refinery", &"mine", &"hangar",
			&"research_center", &"academy", &"infirmary"]
	var out: Array[BuildingData] = []
	for id in order:
		if buildings.has(id):
			out.append(buildings[id])
	for b: BuildingData in buildings.values():
		if not b in out:
			out.append(b)
	return out


## Minerales de más caro a más barato.
func sorted_minerals() -> Array[MineralData]:
	var out: Array[MineralData] = []
	out.assign(minerals.values())
	out.sort_custom(func(a: MineralData, b: MineralData) -> bool: return a.price > b.price)
	return out


## Nombre de cualquier lugar del mapa: estación, zona o cuerpo celeste (una base).
func place_name(id: StringName) -> String:
	var s := site(id)
	if s:
		return s.display_name
	var b := body(id)
	return b.display_name if b else ""


func site(id: StringName) -> MapSiteData:
	return sites.get(id)


func zone(id: StringName) -> ZoneData:
	return sites.get(id) as ZoneData


func body(id: StringName) -> CelestialBodyData:
	return bodies.get(id)


func system_of(id: StringName) -> StarSystemData:
	return systems.get(_system_of.get(id, &""))


## Sistemas ordenados de más cercano a más lejano al sistema inicial.
func sorted_systems() -> Array[StarSystemData]:
	var out: Array[StarSystemData] = []
	out.assign(systems.values())
	out.sort_custom(func(a: StarSystemData, b: StarSystemData) -> bool: return a.order < b.order)
	return out


## Estación donde empieza la partida: la primera del primer sistema (GDD 5.1).
func start_station() -> StringName:
	var first := sorted_systems()
	if first.is_empty() or first[0].stations.is_empty():
		return &""
	return first[0].stations[0].id


## Tipos de enemigo que pueden aparecer en una zona de esa dificultad (sin jefes).
func enemies_for_difficulty(difficulty: int) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for e: EnemyData in enemies.values():
		if not e.is_boss and e.min_difficulty <= difficulty:
			out.append(e)
	out.sort_custom(func(a: EnemyData, b: EnemyData) -> bool:
		return a.min_difficulty < b.min_difficulty or (a.min_difficulty == b.min_difficulty and a.min_stage_time < b.min_stage_time))
	return out


func _load_dir(path: String, target: Dictionary) -> void:
	for file in DirAccess.get_files_at(path):
		# En los juegos exportados los .tres aparecen como .tres.remap.
		file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var res := load(path + file)
		if res == null or not ("id" in res):
			push_warning("Catalog: no se pudo cargar %s" % (path + file))
			continue
		target[res.id] = res
