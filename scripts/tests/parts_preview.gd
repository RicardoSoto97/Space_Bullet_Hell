extends Node3D
## Escena de prueba: monta la nave inicial con las piezas .glb exportadas desde Blender.
## Argumentos opcionales (después de `--`):
##   --view=top | --view=angled   cámara cenital (como en el juego) o en ángulo
##   --screenshot=<ruta.png>      guarda una captura y cierra

const PARTS_DIR := "res://assets/models/parts/"

# Blender +Y (frente) = Godot -Z. Las posiciones están en metros (1 cubo de pasillo = 1 m).
const STARTER_SHIP := {
	"core": Vector3(0, 0, 0),
	"command_station": Vector3(0, 0, -1.22),
	"machine_gun": Vector3(0, 0.02, -1.66),
	"thruster_small": Vector3(0, 0, 0.98),
}


func _ready() -> void:
	var args := _parse_args()
	_build_environment()
	_build_ship()
	_build_camera(args.get("view", "top"))
	if args.has("screenshot"):
		await _save_screenshot(args["screenshot"])


func _parse_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pair := arg.substr(2).split("=", true, 1)
			result[pair[0]] = pair[1]
	return result


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.45)
	env.glow_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func _build_ship() -> void:
	var ship := Node3D.new()
	ship.name = "StarterShip"
	add_child(ship)
	for part_id: String in STARTER_SHIP:
		var scene := load(PARTS_DIR + part_id + ".glb") as PackedScene
		var part := scene.instantiate() as Node3D
		part.name = part_id.to_pascal_case()
		part.position = STARTER_SHIP[part_id]
		ship.add_child(part)


func _build_camera(view: String) -> void:
	var cam := Camera3D.new()
	if view == "angled":
		cam.position = Vector3(4.0, 3.6, 3.4)
		add_child(cam)
		cam.look_at(Vector3(0, 0, -0.3))
	else:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 5.0
		cam.position = Vector3(0, 10, -0.35)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		add_child(cam)
	cam.current = true


func _save_screenshot(path: String) -> void:
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("screenshot ", path, " -> ", error_string(err))
	get_tree().quit()
