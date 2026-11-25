class_name PartData
extends Resource
## Una pieza de la nave (GDD 3 y 4). Los valores numéricos son provisionales.
## Los archivos .tres de las piezas y armas se generan con `tools/data/gen_data.js`.

enum Category { CORE, STRUCTURE, COMMAND_STATION, CREW_STRUCTURE, ENGINE, ACCESSORY }
## SIDE: cara lateral (en el plano de juego); admite cualquier pieza.
## FACE: cara de arriba o de abajo; solo admite accesorios (GDD 3.3).
enum SlotKind { SIDE, FACE }

@export var id: StringName
@export var display_name: String
@export var category: Category = Category.STRUCTURE
@export var model: PackedScene
@export var price: int = 100
## Si el mecánico de la estación la vende (los depósitos solo se consiguen investigando).
@export var for_sale: bool = true
## Estructuras con función: suben de nivel hasta el 10 (GDD 8.1). Los pasillos no.
@export var has_levels: bool = false
## Puntos de investigación para desbloquearla (0 = no se investiga). Las investigadas se
## fabrican en el hangar de la base (GDD 7.6).
@export var research_points: int = 0
@export_group("Vida")
@export var max_hp: float = 50.0
## Integridad del casco que suma al núcleo (los pasillos dan + casco).
@export var hull_bonus: float = 0.0
## Reduce el daño que recibe esta pieza (puntos por impacto). Una placa de blindaje
## también se lo da a la pieza en la que está acoplada.
@export var armor: float = 0.0
@export_group("Estadísticas de la nave")
## Suma a la maniobrabilidad (aceleración y giro).
@export var handling: float = 0.0
## Suma a la velocidad máxima.
@export var speed: float = 0.0
## Suma al radio de recogida de chatarra.
@export var pickup_radius: float = 0.0
## Plazas para tripulantes.
@export var crew_capacity: int = 0
## Bono de calidad de vida a las estadísticas de los tripulantes, por nivel (0.01 = +1 %).
@export var crew_bonus_per_level: float = 0.0
@export_group("Niveles")
## Costo de subir al nivel 2 y cuánto crece en cada nivel. 0 = la curva general de las
## estructuras (`GameState.STRUCTURE_UPGRADE_BASE` y `_GROWTH`).
@export var upgrade_base_cost: int = 0
@export var upgrade_growth: float = 0.0
## Vida extra por nivel, en fracción de `max_hp` (0.25 = +25 % de la vida base por nivel).
@export var hp_per_level: float = 0.0
## Plazas de tripulantes extra por nivel.
@export var crew_per_level: int = 0
@export_group("Escudo")
## Generador de escudo (fase 6): capacidad en el nivel 1 y fracción extra por nivel.
@export var shield_capacity: float = 0.0
@export var shield_per_level: float = 0.0
## Puntos por segundo que recarga, tras `shield_delay` segundos sin recibir daño.
@export var shield_recharge: float = 0.0
@export var shield_delay: float = 0.0
## Segundos que tarda en volver a encenderse si se rompe.
@export var shield_break_delay: float = 0.0
@export_group("Montaje")
## Solo se puede montar una en la nave.
@export var unique: bool = false
## Solo va en las caras de arriba o de abajo (no en las laterales).
@export var face_only: bool = false
@export_group("Forma")
## Tamaño de la caja de colisión en metros (X ancho, Z largo; Y alto).
@export var collision_size: Vector3 = Vector3(1, 1, 1)
## Centro de la caja de colisión, relativo a la pieza.
@export var collision_offset: Vector3 = Vector3.ZERO
## Dónde va el arma, relativo a la pieza (solo estaciones de mando).
@export var weapon_offset: Vector3 = Vector3.ZERO
@export_group("Ranuras")
## Ranuras (acopladores) de la pieza: posición, dirección hacia afuera y tipo (`SlotKind`).
@export var slot_positions: PackedVector3Array
@export var slot_normals: PackedVector3Array
@export var slot_kinds: PackedInt32Array
## Ranura con la que la pieza se une a su padre (-1 en el núcleo).
@export var mount_slot: int = -1


func slot_count() -> int:
	return slot_positions.size()


## Vida base en un nivel (sin el casco que suman los pasillos).
func hp_at(level: int) -> float:
	return max_hp * (1.0 + hp_per_level * (level - 1))


## Plazas de tripulantes en un nivel.
func crew_at(level: int) -> int:
	return crew_capacity + crew_per_level * (level - 1)


## Capacidad del escudo en un nivel.
func shield_at(level: int) -> float:
	return shield_capacity * (1.0 + shield_per_level * (level - 1))


## Si la pieza se puede acoplar en una ranura de ese tipo.
func fits_slot_kind(kind: int) -> bool:
	if category == Category.CORE:
		return false
	if category == Category.ACCESSORY:
		return kind == SlotKind.FACE or not face_only
	return kind == SlotKind.SIDE


## Ranuras propias que puede usar para unirse a su padre. Las estructuras con varias caras
## laterales se pueden girar (unirse por otra cara); el resto usa siempre `mount_slot`.
func mount_options() -> Array[int]:
	var out: Array[int] = []
	if mount_slot < 0:
		return out
	out.append(mount_slot)
	if category == Category.STRUCTURE:
		for i in slot_count():
			if i != mount_slot and slot_kinds[i] == SlotKind.SIDE:
				out.append(i)
	return out
