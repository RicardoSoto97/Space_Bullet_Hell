class_name StageBalanceData
extends Resource
## Números de equilibrio de los niveles (GDD 9): cuántos enemigos aparecen, cómo sube la presión
## con el tiempo y cuánto más difícil es cada punto de dificultad de la zona (1 a 6).
## Está en `data/balance/stage_balance.tres`. Los valores son provisionales (fase 6).

@export_group("Aparición")
## Enemigos por segundo al empezar y cuánto suben por minuto de presión.
@export var base_rate: float = 1.1
@export var rate_per_minute: float = 0.4
## Tope de enemigos vivos a la vez (rendimiento).
@export var max_alive: int = 160
## Multiplicador de vida que suma cada minuto de presión.
@export var hp_per_minute: float = 0.12
## Probabilidad de élite a partir del minuto 1, y lo que suma cada punto de dificultad.
@export var elite_chance: float = 0.04
@export var elite_chance_per_difficulty: float = 0.01

@export_group("Oleadas de enjambre")
## Segundos hasta la primera oleada; cada una tarda `wave_interval_growth` s más que la anterior.
@export var wave_interval: float = 50.0
@export var wave_interval_growth: float = 15.0
## Drones de cada oleada: `wave_size` + `wave_size_per_minute` por minuto de presión.
@export var wave_size: int = 10
@export var wave_size_per_minute: float = 3.0

@export_group("Presión en niveles largos")
## Después de este minuto la presión sigue subiendo más despacio (niveles de zonas lejanas).
@export var pressure_full_minutes: float = 5.0
@export var pressure_slope_after: float = 0.35

@export_group("Por punto de dificultad")
## Lo que suma cada punto de dificultad por encima de 1 (0.3 = +30 %).
@export var hp_per_difficulty: float = 0.3
@export var rate_per_difficulty: float = 0.1
@export var fire_rate_per_difficulty: float = 0.12
@export var boss_hp_per_difficulty: float = 0.5


## Minutos de «presión»: en los niveles largos la presión sigue subiendo, pero más despacio.
func pressure_minutes(stage_time: float) -> float:
	var m := stage_time / 60.0
	return m if m <= pressure_full_minutes else pressure_full_minutes + (m - pressure_full_minutes) * pressure_slope_after
