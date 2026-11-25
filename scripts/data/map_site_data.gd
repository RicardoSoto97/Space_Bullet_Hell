class_name MapSiteData
extends Resource
## Un lugar al que se puede saltar en el mapa estelar: una estación espacial o una zona de
## enemigos. Orbita alrededor de un cuerpo celeste de su sistema.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Cuerpo alrededor del que orbita (vacío = la estrella del sistema).
@export var parent: StringName
@export var orbit_radius: float = 1.0
@export var orbit_angle: float = 0.0


func is_station() -> bool:
	return false
