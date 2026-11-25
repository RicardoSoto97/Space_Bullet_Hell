class_name EnemyData
extends Resource
## Un tipo de enemigo (GDD 9). Los valores numéricos son provisionales.

enum Behavior {
	CHASE,          ## Persigue a la nave (enjambre, tanque).
	KEEP_DISTANCE,  ## Se mantiene a distancia y dispara (artillero, sembrador, jefe).
	DASH,           ## Se acerca, se detiene a apuntar y embiste en línea recta (lancero).
}

## Cómo se mueve el modelo (solo lo visual, para que se note que es 3D):
## FIGHTER se inclina al girar y hace una pirueta de 360° al acercarse; HEAVY se balancea
## despacio; SPINNER se bambolea como un trompo; GLIDER se inclina mucho al rodear y ondula;
## TUMBLER da tumbos; LANCER levanta el morro al apuntar y gira sobre sí mismo al embestir;
## BOSS se balancea lentamente.
enum Motion { FIGHTER, HEAVY, SPINNER, GLIDER, TUMBLER, LANCER, BOSS }

@export var id: StringName
@export var display_name: String
@export var model: PackedScene
@export var behavior: Behavior = Behavior.CHASE
@export var motion: Motion = Motion.FIGHTER
@export_group("Combate")
@export var max_hp: float = 10.0
@export var speed: float = 5.0
@export var turn_speed: float = 4.0
@export var collision_radius: float = 0.4
## Daño al chocar con una pieza de la nave.
@export var contact_damage: float = 10.0
## Si explota al chocar (se destruye).
@export var dies_on_contact: bool = true
## Segundos entre daños de contacto si no explota.
@export var contact_interval: float = 0.5
@export_group("Disparo")
@export var preferred_distance: float = 9.0
@export var fire_interval: float = 0.0
@export var bullets_per_burst: int = 0
@export var bullet_speed: float = 9.0
@export var bullet_damage: float = 6.0
## Si dispara en abanico hacia la nave en vez de en círculo.
@export var aimed: bool = false
@export var fan_degrees: float = 40.0
@export_group("Embestida")
## Distancia a la que empieza a apuntar para embestir.
@export var dash_range: float = 9.0
@export var dash_speed: float = 20.0
@export var dash_time: float = 0.45
## Segundos quieto apuntando antes de embestir (el aviso para esquivar).
@export var dash_windup: float = 0.7
@export var dash_cooldown: float = 1.2
@export_group("Minas y división")
## Segundos entre minas (0 = no deja minas).
@export var mine_interval: float = 0.0
@export var mine_damage: float = 8.0
@export var mine_lifetime: float = 10.0
## Enemigo en el que se divide al morir (vacío = no se divide) y cuántos salen.
@export var split_into: StringName
@export var split_count: int = 0
@export_group("Aparición")
## Dificultad mínima de la zona para que aparezca (1 = zonas de 5 min; 6 = de 30 min).
@export var min_difficulty: int = 1
## Los jefes no aparecen al azar: los hace aparecer la zona.
@export var is_boss: bool = false
## Peso relativo para elegir qué enemigo aparece.
@export var spawn_weight: float = 1.0
## Segundos de nivel a partir de los que puede aparecer.
@export var min_stage_time: float = 0.0
## Segundos que tarda en llegar a su peso completo después de `min_stage_time`: aparece
## de a poco (empieza con el 10 % de su peso).
@export var spawn_ramp_seconds: float = 0.0


## Peso de aparición en un momento del nivel (0 si todavía no puede aparecer).
func weight_at(stage_time: float) -> float:
	if stage_time < min_stage_time:
		return 0.0
	if spawn_ramp_seconds <= 0.0:
		return spawn_weight
	return spawn_weight * clampf((stage_time - min_stage_time) / spawn_ramp_seconds, 0.1, 1.0)
@export_group("Botín")
## Unidades de metal común que suelta siempre.
@export var common_scrap: int = 1
## Chatarra especial que puede soltar (por ejemplo, componentes electrónicos).
@export var special_scrap: ScrapTypeData
@export var special_amount: int = 1
@export_range(0.0, 1.0) var special_chance: float = 0.5
