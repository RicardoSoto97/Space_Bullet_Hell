class_name ZoneData
extends MapSiteData
## Una zona de enemigos: un nivel (`stage`). Su distancia fija (5–30 min de combustible) es
## la duración del nivel y marca su dificultad (GDD 5.5 y 9).

## Minutos de combustible que gasta el salto = duración del nivel.
@export var distance_minutes: int = 5
## Jefe de la zona (id de un `EnemyData`), o vacío si no tiene.
@export var boss: StringName
## Nombre con el que aparece el jefe en la ficha y en el nivel.
@export var boss_name: String


## Dificultad de 1 a 6: una por cada 5 minutos de distancia.
func difficulty() -> int:
	return clampi(distance_minutes / 5, 1, 6)


func has_boss() -> bool:
	return boss != &""
