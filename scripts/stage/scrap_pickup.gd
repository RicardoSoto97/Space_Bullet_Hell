class_name ScrapPickup
extends MeshInstance3D
## Un trozo de chatarra suelto en el nivel. La nave lo atrae dentro de su radio de recogida.

static var _meshes: Dictionary[StringName, Mesh] = {}
static var _materials: Dictionary[StringName, StandardMaterial3D] = {}

var type_id: StringName
var attracted: bool = false
var speed: float = 0.0
var _spin: Vector3


func setup(p_type: ScrapTypeData) -> void:
	type_id = p_type.id
	mesh = _mesh_for(p_type)
	material_override = _material_for(p_type)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_spin = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))


func _process(delta: float) -> void:
	rotation += _spin * delta


static func _mesh_for(t: ScrapTypeData) -> Mesh:
	if not _meshes.has(t.id):
		var m: Mesh
		match t.id:
			&"electronics":
				var b := BoxMesh.new()
				b.size = Vector3(0.32, 0.06, 0.24)
				m = b
			&"heavy_plating":
				var b := BoxMesh.new()
				b.size = Vector3(0.36, 0.12, 0.36)
				m = b
			&"energy_core", &"alien_tech":
				var s := SphereMesh.new()
				s.radius = 0.2
				s.height = 0.4
				s.radial_segments = 8
				s.rings = 4
				m = s
			_:
				var p := PrismMesh.new()
				p.size = Vector3(0.28, 0.24, 0.2)
				m = p
		_meshes[t.id] = m
	return _meshes[t.id]


static func _material_for(t: ScrapTypeData) -> StandardMaterial3D:
	if not _materials.has(t.id):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = t.color
		mat.roughness = 0.5
		mat.emission_enabled = true
		mat.emission = t.color
		mat.emission_energy_multiplier = 2.5 if t.glows else 0.35
		_materials[t.id] = mat
	return _materials[t.id]
