extends SceneTree
## Comprobación rápida de los datos del universo: `godot --headless -s res://scripts/tests/universe_check.gd`.

func _init() -> void:
	await process_frame
	var cat: Node = root.get_node("Catalog")
	for sys: StarSystemData in cat.sorted_systems():
		var zones := []
		for z in sys.zones:
			zones.append("%s %dmin%s" % [z.display_name, z.distance_minutes, " JEFE" if z.has_boss() else ""])
		print("%d %s: %d cuerpos, %d estaciones, zonas: %s" % [sys.order, sys.display_name, sys.bodies.size(),
				sys.stations.size(), ", ".join(zones)])
	print("start: ", cat.start_station(), " bodies=", cat.bodies.size(), " sites=", cat.sites.size())
	quit()
