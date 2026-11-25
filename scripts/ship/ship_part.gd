class_name ShipPart
extends Area3D
## Una pieza montada en la nave. Recibe daño por separado (GDD 3.4).

const LAYER_PLAYER_PARTS := 1

## Entrada del plano de la nave en GameState (se modifica en el sitio).
var entry: Dictionary
var index: int = -1
var data: PartData
var ship: Ship
var weapon: ShipWeapon
## Blindaje extra que le dan las placas acopladas a esta pieza.
var bonus_armor: float = 0.0
## Modelo y arma de la pieza. Se inclina con la nave (`apply_tilt`); la colisión no.
var visual: Node3D
var _meshes: Array[MeshInstance3D] = []
var _flash_left: float = 0.0


func setup(p_ship: Ship, p_index: int) -> void:
	ship = p_ship
	index = p_index
	entry = GameState.blueprint[index]
	data = Catalog.part(entry["part"])
	name = "%s_%d" % [String(data.id).to_pascal_case(), index]
	transform = entry["transform"]
	collision_layer = LAYER_PLAYER_PARTS
	collision_mask = 0
	monitoring = false

	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var model := data.model.instantiate() as Node3D
	visual.add_child(model)
	_meshes = Effects.find_meshes(model)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = data.collision_size
	shape.shape = box
	shape.position = data.collision_offset
	add_child(shape)


## Inclina el modelo como si toda la nave girara `tilt` alrededor de su centro.
func apply_tilt(tilt: Basis) -> void:
	visual.transform = transform.affine_inverse() * Transform3D(tilt, Vector3.ZERO) * transform


func is_core() -> bool:
	return data.category == PartData.Category.CORE


func hp() -> float:
	return GameState.part_hp(entry)


func max_hp() -> float:
	return GameState.part_max_hp(entry)


## `through_shield`: el daño no pasa por el escudo (solo las pruebas que destruyen la nave).
func take_damage(amount: float, through_shield: bool = false) -> void:
	if entry["destroyed"] or entry["lost"] or ship == null or ship.is_dead:
		return
	if GameState.args.has("invulnerable"):  # solo pruebas automáticas
		_flash()
		return
	# El escudo de la nave recibe el daño antes que las piezas (fase 6).
	if not through_shield:
		amount = ship.absorb_shield(amount)
		if amount <= 0.0:
			return
	# El blindaje resta daño, pero cada golpe hace al menos un 25 %.
	var damage := maxf(amount - data.armor - bonus_armor, amount * 0.25)
	var new_hp := maxf(hp() - damage, 0.0)
	entry["hp"] = new_hp
	ship.damage_taken += damage
	ship.damage_log[Ship.damage_source] = ship.damage_log.get(Ship.damage_source, 0.0) + damage
	Ship.damage_source = &"other"
	_flash()
	Sfx.play(&"hull_hit")
	ship.on_part_damaged(self)
	if new_hp <= 0.0:
		ship.on_part_hp_zero(self)


func _flash() -> void:
	if _flash_left <= 0.0:
		for m in _meshes:
			m.material_overlay = Effects.hit_flash()
	_flash_left = 0.07


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			for m in _meshes:
				m.material_overlay = null
