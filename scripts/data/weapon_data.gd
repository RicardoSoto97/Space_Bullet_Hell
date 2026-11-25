class_name WeaponData
extends Resource
## Un arma (GDD 4.4 y 8). Se acopla a una estación de mando y sube de nivel hasta el 10.
## Dispara en un cono hacia el frente de su estación: para apuntar hay que girar la nave.

## BULLET: proyectiles (metralleta). ROCKET: cohete lento que explota con daño en área.
## BEAM: rayo continuo que atraviesa a los enemigos en línea (`damage` es daño por segundo).
enum Kind { BULLET, ROCKET, BEAM }

@export var id: StringName
@export var display_name: String
@export var model: PackedScene
@export var kind: Kind = Kind.BULLET
## Precio en el mecánico de la estación.
@export var price: int = 250
## Las evoluciones no se venden: el mecánico las crea desde un arma al nivel máximo.
@export var for_sale: bool = true
## Puntos de investigación para desbloquearla (0 = no se investiga). Las investigadas se
## fabrican en el hangar de la base (GDD 7.6).
@export var research_points: int = 0
@export_group("Disparo")
@export var damage: float = 10.0
## Segundos entre disparos (no se usa en los rayos).
@export var fire_interval: float = 0.2
@export var projectile_speed: float = 30.0
@export var weapon_range: float = 14.0
@export var projectile_color: Color = Color(1.0, 0.75, 0.3)
## Desviación aleatoria de cada disparo, en grados.
@export var spread_degrees: float = 3.0
## Medio ángulo del cono de disparo, en grados, a cada lado del frente de la estación.
@export var aim_cone_degrees: float = 50.0
## Cañones paralelos: proyectiles que salen a la vez, uno al lado del otro.
@export var barrels: int = 1
## Tamaño visual del proyectil (cohetes).
@export var projectile_scale: float = 1.0
## Enemigos que atraviesa cada bala antes de desaparecer (cañón de partículas).
@export var pierce: int = 0
## Perdigones por disparo, repartidos en abanico (escopeta de fragmentos).
@export var pellets: int = 1
@export var pellet_spread_degrees: float = 0.0
@export_group("Área y rayo")
## Radio de la explosión (cohetes).
@export var area_radius: float = 0.0
## Radio extra por nivel (0.05 = +5 % por nivel).
@export var area_per_level: float = 0.0
## Grosor del rayo en metros (rayos).
@export var beam_width: float = 0.3
@export_group("Niveles")
@export var max_level: int = 10
## Daño extra por nivel (0.15 = +15 % por nivel).
@export var damage_per_level: float = 0.15
## Costo de subir del nivel 1 al 2. Cada nivel cuesta `upgrade_growth` veces el anterior (GDD 8.1, propuesta).
@export var upgrade_base_cost: int = 200
@export var upgrade_growth: float = 1.6
## Arma en la que evoluciona al llegar al nivel máximo (GDD 8.3).
@export var evolves_into: StringName


func damage_at(level: int) -> float:
	return damage * (1.0 + damage_per_level * float(level - 1))


func area_at(level: int) -> float:
	return area_radius * (1.0 + area_per_level * float(level - 1))


## Costo de subir desde `level` al siguiente nivel. Devuelve -1 si ya está al máximo.
func upgrade_cost(level: int) -> int:
	if level >= max_level:
		return -1
	return int(round(upgrade_base_cost * pow(upgrade_growth, level - 1)))
