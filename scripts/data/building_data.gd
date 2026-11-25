class_name BuildingData
extends Resource
## Un edificio de la base (GDD 7.3). Los .tres se generan con `tools/data/gen_data.js`.
## Los números son propuestas del GDD v0.29 y se ajustarán jugando.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var model: PackedScene
@export var price: int = 1000
## El cargador de combustible no tiene niveles; el resto llega al nivel 10.
@export var has_levels: bool = true
@export var max_level: int = 10
## Subir al nivel 2 cuesta `price × upgrade_factor`; cada nivel, `upgrade_growth` veces el anterior.
@export var upgrade_factor: float = 0.5
@export var upgrade_growth: float = 1.4
@export_group("Tripulantes")
## Estadística de los tripulantes que trabajan aquí ("" = no necesita tripulantes).
@export var crew_stat: String = ""
## Plazas de tripulantes en el nivel 1.
@export var crew_slots: int = 0
## Niveles en los que gana una plaza más: de tripulantes (centro de investigación, enfermería),
## de entrenamiento y candidatos (academia) o de planos (hangar).
@export var extra_slot_levels: PackedInt32Array
@export_group("Producción")
## Valor del nivel 1: créditos por minuto (refinería, mina), porcentaje del precio (puerto),
## factor de reconstrucción (hangar) o multiplicador (investigación, enfermería).
@export var base_rate: float = 0.0
## Lo que suma cada nivel a `base_rate` (relativo en refinería y mina; absoluto en el resto).
@export var rate_per_level: float = 0.0


## Costo de subir desde `level` al siguiente, o -1 si no tiene niveles o ya está al máximo.
func upgrade_cost(level: int) -> int:
	if not has_levels or level >= max_level:
		return -1
	return int(round(price * upgrade_factor * pow(upgrade_growth, level - 1)))


## Plazas extra que da el nivel (ver `extra_slot_levels`).
func extra_slots(level: int) -> int:
	var n := 0
	for l in extra_slot_levels:
		if level >= l:
			n += 1
	return n


## Plazas de tripulantes en ese nivel.
func crew_slots_at(level: int) -> int:
	if crew_stat == "":
		return 0
	# En el hangar, las plazas extra son planos guardados, no tripulantes.
	return crew_slots if id == &"hangar" else crew_slots + extra_slots(level)
