class_name StarSystemData
extends Resource
## Un sistema planetario del mapa estelar (GDD 5.1): su estrella (el primer cuerpo), planetas,
## satélites y asteroides, sus estaciones y sus zonas de enemigos. Se genera con
## `node tools/data/gen_universe.js .`.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Orden de lejanía desde el sistema inicial (1 = donde empieza la partida).
@export var order: int = 1
@export var galaxy_position: Vector3 = Vector3.ZERO
@export var bodies: Array[CelestialBodyData] = []
@export var stations: Array[StationData] = []
@export var zones: Array[ZoneData] = []


func star() -> CelestialBodyData:
	return bodies[0]
