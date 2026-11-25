class_name ProjectilePool
extends Node3D
## Reutiliza los proyectiles en vez de crearlos y destruirlos (habrá cientos a la vez).

const ENEMY_BULLET_COLOR := Color(1.0, 0.15, 0.35)

var _free_player: Array[Projectile] = []
var _free_enemy: Array[Projectile] = []
var _player_mesh: CapsuleMesh
var _enemy_mesh: SphereMesh


func _ready() -> void:
	add_to_group(&"projectile_pool")
	_player_mesh = CapsuleMesh.new()
	_player_mesh.radius = 0.07
	_player_mesh.height = 0.55
	_player_mesh.radial_segments = 6
	_player_mesh.rings = 1
	_enemy_mesh = SphereMesh.new()
	_enemy_mesh.radius = 0.2
	_enemy_mesh.height = 0.4
	_enemy_mesh.radial_segments = 8
	_enemy_mesh.rings = 4


func spawn(from_player: bool, pos: Vector3, dir: Vector3, speed: float, damage: float,
		max_distance: float, color: Color = ENEMY_BULLET_COLOR, pierce: int = 0) -> void:
	var free_list := _free_player if from_player else _free_enemy
	var p: Projectile
	if free_list.is_empty():
		p = Projectile.new()
		add_child(p)
		p.init(self, from_player, _player_mesh if from_player else _enemy_mesh, 0.15 if from_player else 0.2)
	else:
		p = free_list.pop_back()
	p.activate(pos, dir, speed, damage, max_distance, color, pierce)


func release(p: Projectile) -> void:
	if not p.active:
		return
	p.deactivate()
	(_free_player if p.from_player else _free_enemy).append(p)


## Desactiva todas las balas enemigas (por ejemplo, al terminar el nivel).
func clear_enemy_bullets() -> void:
	for child in get_children():
		var p := child as Projectile
		if p and p.active and not p.from_player:
			release(p)
