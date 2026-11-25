class_name ShipStatusView
extends Control
## Miniatura de la nave con cada pieza coloreada según su daño (GDD 10.3).
## Verde = intacta, rojo = casi destruida, gris = perdida, rojo oscuro = destruida.
## Se dibuja vista desde arriba y se ajusta al tamaño del control cuando la nave crece.

## Escala máxima; si la nave no cabe, se reduce.
@export var pixels_per_meter: float = 16.0

const COLOR_LOST := Color(0.35, 0.37, 0.4, 0.6)
const COLOR_DESTROYED := Color(0.45, 0.05, 0.05, 0.8)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if GameState.blueprint.is_empty():
		return
	var bounds := GameState.ship_bounds()
	var extent := Vector2(bounds.size.x, bounds.size.z)
	var ppm := minf(pixels_per_meter, minf((size.x - 8.0) / extent.x, (size.y - 8.0) / extent.y))
	var center := Vector2(bounds.get_center().x, bounds.get_center().z)
	# Primero las piezas del plano de juego y después los accesorios de arriba.
	for pass_top in [false, true]:
		for i in GameState.blueprint.size():
			var e := GameState.blueprint[i]
			var data := Catalog.part(e["part"])
			var box: AABB = GameState.footprints(i)[0]
			var is_top := data.category == PartData.Category.ACCESSORY and box.get_center().y > 0.2
			var is_bottom := data.category == PartData.Category.ACCESSORY and box.get_center().y < -0.2
			if is_bottom or is_top != pass_top:
				continue
			var rect := Rect2((Vector2(box.position.x, box.position.z) - center) * ppm + size / 2.0,
					Vector2(box.size.x, box.size.z) * ppm)
			if is_top:
				rect = rect.grow(-rect.size.x * 0.15)
			draw_rect(rect, _color(e))
			draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.5)


func _color(e: Dictionary) -> Color:
	if e["destroyed"]:
		return COLOR_DESTROYED
	if e["lost"]:
		return COLOR_LOST
	var ratio := GameState.part_hp(e) / GameState.part_max_hp(e)
	return Color(1.0, 0.2, 0.15).lerp(Color(0.25, 0.95, 0.5), ratio)
