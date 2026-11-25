class_name CelestialBodyData
extends Resource
## Un cuerpo celeste del mapa estelar (GDD 5.1): estrella, planeta, satélite o asteroide.
## Los habitables tienen precio de terreno (se compra en la fase 4, con la base).

enum Kind { STAR, ROCKY_PLANET, GAS_PLANET, MOON, ASTEROID }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.ROCKY_PLANET
@export_multiline var description: String
## Cuerpo alrededor del que orbita (vacío = la estrella del sistema; la estrella no orbita).
@export var parent: StringName
@export_group("Mapa")
## Radio y ángulo de la órbita, en unidades del mapa y grados.
@export var orbit_radius: float = 0.0
@export var orbit_angle: float = 0.0
## Grados por segundo que avanza en su órbita (solo visual).
@export var orbit_speed: float = 1.0
@export var radius: float = 1.0
@export var color: Color = Color.WHITE
## Color de las bandas (planetas gaseosos) o de la corona (estrellas).
@export var color2: Color = Color.WHITE
@export var has_rings: bool = false
@export_group("Ficha")
@export var habitable: bool = false
## Temperatura media en grados Celsius.
@export var temperature: int = 0
## Costo del terreno para la base (0 si no es habitable). GDD 7.3.
@export var land_price: int = 0


func kind_name() -> String:
	match kind:
		Kind.STAR: return "Estrella"
		Kind.ROCKY_PLANET: return "Planeta rocoso"
		Kind.GAS_PLANET: return "Planeta gaseoso"
		Kind.MOON: return "Satélite"
		_: return "Asteroide"
