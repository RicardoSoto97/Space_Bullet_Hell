class_name Station
extends Control
## La estación espacial (GDD 6): vender chatarra, construir y reparar la nave con el
## mecánico, reclutar tripulantes en el bar y saltar a otra zona de enemigos.
## La base (`BaseScreen`) hereda de aquí y reutiliza el taller (mecánico) para su hangar.

const STAR_SHADER := preload("res://scripts/stage/star_background.gdshader")
const COLOR_TEXT := Color(0.85, 0.9, 1.0)
const COLOR_DIM := Color(0.65, 0.7, 0.8)
const COLOR_WARN := Color(1.0, 0.6, 0.4)
const COLOR_MONEY := Color(1.0, 0.85, 0.3)

var _money_label: Label
var _report_label: Label
var _editor: ShipEditorView
var _view_button: Button
var _tabs: TabContainer
var _mechanic_box: VBoxContainer
var _bar_box: VBoxContainer
var _scrap_box: VBoxContainer
var _abandon_button: Button
var _status_view: ShipStatusView
var _map: StarMap
var _options: OptionsMenu
var _jump_button: Button
## Pestaña que se abre al elegir una ranura o una pieza de la nave.
var _mechanic_tab: int = 0
## Mensaje de la última acción (por ejemplo, por qué no se pudo comprar algo).
var _notice: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Con mando, el stick mueve el puntero (ver GamepadCursor).
	add_to_group(&"gamepad_pointer")
	_build_ui()
	Sfx.play(&"station_arrive")
	GameState.money_changed.connect(func(_v: int) -> void: _money_label.text = _money_text())
	_editor.slot_selected.connect(func(_p: int, _s: int) -> void: _on_editor_selection(true))
	_editor.part_selected.connect(func(_p: int) -> void: _on_editor_selection(true))
	_editor.deselected.connect(func() -> void: _on_editor_selection(false))
	# Guardado automático al llegar a la estación.
	GameState.save_game()
	await get_tree().process_frame
	refresh()
	_run_tests()


## Pruebas automáticas con argumentos (la base las reemplaza por las suyas).
func _run_tests() -> void:
	# `--rebuild-test`: tras reaparecer en la estación, va a la base para reconstruir la nave.
	if GameState.args.has("rebuild-test") and not Bases.bases.is_empty():
		await get_tree().create_timer(0.5).timeout
		print("[rebuild-test] station report: %s" % GameState.last_report)
		GameState.travel_to(Bases.bases[0]["body"])
		return
	if GameState.args.has("build-test") and GameState.stages_survived == 0:
		_build_test()
	elif GameState.args.has("auto-station"):
		_auto_test()
	elif GameState.args.has("map-test"):
		_open_map()
	elif GameState.args.has("pad-test"):
		_pad_test()
	elif GameState.args.has("station-screenshot"):
		await _save_screenshot()
		if GameState.args.has("quit-after-station"):
			get_tree().quit()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = STAR_SHADER
	bg.material = mat
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 20)
	margin.add_child(columns)

	# Columna izquierda: la nave en el editor
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(600, 0)
	columns.add_child(left)
	var header := HBoxContainer.new()
	left.add_child(header)
	var title := _title(header, _title_text(), 28)
	# Un nombre largo (por ejemplo, el de una base) se recorta en vez de ensanchar la columna.
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_stretch_ratio = 20.0
	var hs := Control.new()
	hs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hs)
	_money_label = _text(header, _money_text(), 22, COLOR_MONEY)
	_button(header, "Opciones", _open_options)
	var exit := _button(header, "Salir al menú", _on_menu)
	exit.tooltip_text = "Guarda la partida y vuelve al menú principal"

	var editor_frame := PanelContainer.new()
	editor_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(editor_frame)
	var editor_stack := Control.new()
	editor_frame.add_child(editor_stack)
	_build_view_area(editor_stack)

	var tools := HBoxContainer.new()
	left.add_child(tools)
	_build_tools(tools)

	# Columna derecha: servicios
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 8)
	columns.add_child(right)
	_report_label = _text(right, "", 15, Color(0.8, 0.9, 1.0))
	_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_tabs)
	_build_tabs()

	_abandon_button = _button(right, "Tu nave no tiene armas útiles: volver a la nave inicial (gratis)", _on_abandon)
	_abandon_button.add_theme_color_override(&"font_color", COLOR_WARN)
	_jump_button = _button(right, "", _open_map)
	_update_jump_text()
	Settings.changed.connect(_update_jump_text)
	_jump_button.custom_minimum_size = Vector2(0, 50)
	_jump_button.add_theme_font_size_override(&"font_size", 19)


func _update_jump_text() -> void:
	_jump_button.text = "Abrir el mapa estelar y elegir a dónde saltar (%s)" % Settings.control_name(&"star_map")


func _title_text() -> String:
	var here := Catalog.site(GameState.location)
	return here.display_name if here else "Estación espacial"


## La vista de la nave (la base añade la suya encima).
func _build_view_area(stack: Control) -> void:
	_editor = ShipEditorView.new()
	_editor.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_editor)
	_status_view = ShipStatusView.new()
	_status_view.pixels_per_meter = 10.0
	stack.add_child(_status_view)
	StageHud._place(_status_view, Control.PRESET_BOTTOM_RIGHT, Rect2(-110, -110, 100, 100))


func _build_tools(tools: HBoxContainer) -> void:
	_view_button = _button(tools, "Ver desde abajo", _on_toggle_view)
	_button(tools, "Centrar", _on_reset_view)
	var hint := _wrap(tools, "Arrastra: girar · rueda: zoom · azul: ranura lateral · naranja: arriba/abajo", 12, COLOR_DIM)
	hint.custom_minimum_size = Vector2(0, 0)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build_tabs() -> void:
	_mechanic_box = _tab("Mecánico")
	_bar_box = _tab("Bar")
	_scrap_box = _tab("Chatarra")


func _tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 6)
	scroll.add_child(box)
	return box


func _on_editor_selection(show_mechanic: bool) -> void:
	_notice = ""
	if show_mechanic:
		_show_tab(_mechanic_tab)
	refresh_panels()


func _show_tab(i: int) -> void:
	_tabs.current_tab = i


func _money_text() -> String:
	return "%s créditos" % thousands(GameState.money)


## Actualiza todo después de un cambio en el plano de la nave.
func refresh() -> void:
	_editor.refresh()
	refresh_panels()


func refresh_panels() -> void:
	_money_label.text = _money_text()
	_report_label.text = GameState.last_report if GameState.last_report != "" else \
			"Bienvenido. Haz clic en la nave para construirla, recluta tripulantes en el bar y salta a una zona de enemigos."
	_status_view.refresh()
	_abandon_button.visible = not GameState.has_working_weapon()
	_fill_panels()


func _fill_panels() -> void:
	_fill_mechanic()
	_fill_bar()
	_fill_scrap()


# ---------- mecánico ----------

func _fill_mechanic() -> void:
	_clear(_mechanic_box)
	var cost := GameState.repair_cost()
	var repair := _button(_mechanic_box, "Reparar la nave (%d créditos)" % cost if cost > 0 else "La nave está intacta",
			_on_repair)
	repair.disabled = cost <= 0 or cost > GameState.money
	_wrap(_mechanic_box, _ship_summary(), 13, COLOR_DIM)
	if _notice != "":
		_text(_mechanic_box, _notice, 14, COLOR_WARN)
	_fill_tank_row()
	_separator(_mechanic_box)
	if not _editor.selected_slot.is_empty():
		_fill_slot_panel(_editor.selected_slot["part_index"], _editor.selected_slot["slot"])
	elif _editor.selected_part >= 0:
		_fill_part_panel(_editor.selected_part)
	else:
		_wrap(_mechanic_box, "Haz clic en una ranura libre (círculo) para acoplar una pieza, o en una pieza para verla, mejorarla o venderla.", 15, COLOR_TEXT)


## Depósitos de combustible interestelar: por ahora se compran aquí (GDD 5.4). Cada uno
## reemplaza al anterior y da 5 minutos más de alcance.
func _fill_tank_row() -> void:
	var lvl := GameState.fuel_tank_level
	var row := HFlowContainer.new()
	_mechanic_box.add_child(row)
	_text(row, "%s (alcance %d min)   " % [GameState.TANK_NAMES[lvl], GameState.tank_minutes()], 14, COLOR_TEXT)
	if lvl + 1 < GameState.TANK_PRICES.size():
		var price: int = GameState.TANK_PRICES[lvl + 1]
		var b := _button(row, "Comprar %s: %d min (%d créditos)" % [GameState.TANK_NAMES[lvl + 1], 5 * (lvl + 2), price],
				_on_buy_tank.bind(lvl + 1))
		b.disabled = price > GameState.money


func _on_buy_tank(level: int) -> void:
	_notice = GameState.buy_fuel_tank(level)
	refresh_panels()


func _ship_summary() -> String:
	var speed := Ship.BASE_SPEED
	var handling := Ship.BASE_HANDLING
	var pickup := Ship.BASE_PICKUP_RADIUS
	for i in GameState.blueprint.size():
		if GameState.is_alive(i):
			var d := Catalog.part(GameState.blueprint[i]["part"])
			speed += d.speed
			handling += d.handling
			pickup += d.pickup_radius
	var core := GameState.blueprint[0]
	return "Casco %d · Velocidad %.1f · Maniobrabilidad %.1f · Recogida %.1f m · Tripulantes %d/%d · Calidad de vida +%d %%" % [
		GameState.part_max_hp(core), speed, handling, pickup, GameState.crew.size(), GameState.crew_capacity(),
		roundi(GameState.crew_quality_bonus() * 100.0)]


func _fill_slot_panel(part_index: int, slot: int) -> void:
	var parent := Catalog.part(GameState.blueprint[part_index]["part"])
	var w := GameState.slot_world(part_index, slot)
	var where := "lateral" if w["kind"] == PartData.SlotKind.SIDE else ("de abajo" if w["normal"].y < 0.0 else "de arriba")
	_title(_mechanic_box, "Ranura %s de: %s" % [where, parent.display_name], 18)
	if w["kind"] == PartData.SlotKind.FACE:
		_wrap(_mechanic_box, "Las caras de arriba y de abajo solo admiten accesorios.", 13, COLOR_DIM)
	for data: PartData in _parts_for_sale():
		if not data.fits_slot_kind(w["kind"]):
			continue
		var check := GameState.check_placement(data.id, part_index, slot)
		var label := "%s — %d créditos   (%s)" % [data.display_name, data.price, _part_stats(data)]
		if not check["ok"]:
			label += "  · " + check["reason"]
		var b := _button(_mechanic_box, label, _on_buy_part.bind(data.id, part_index, slot))
		b.disabled = not check["ok"] or data.price > GameState.money


func _parts_for_sale() -> Array[PartData]:
	var out: Array[PartData] = []
	for d: PartData in Catalog.parts.values():
		if d.for_sale:
			out.append(d)
	out.sort_custom(func(a: PartData, b: PartData) -> bool: return a.category < b.category or \
			(a.category == b.category and a.price < b.price))
	return out


func _part_stats(d: PartData, level: int = 1) -> String:
	var bits: Array[String] = ["vida %d" % d.hp_at(level)]
	if d.hull_bonus > 0.0: bits.append("+%d casco" % d.hull_bonus)
	if d.armor > 0.0: bits.append("+%d blindaje a su pieza" % d.armor)
	if d.speed > 0.0: bits.append("+%.1f velocidad" % d.speed)
	if d.handling > 0.0: bits.append("+%.1f maniobrabilidad" % d.handling)
	if d.pickup_radius > 0.0: bits.append("+%.1f m de recogida" % d.pickup_radius)
	if d.crew_at(level) > 0: bits.append("%d plazas" % d.crew_at(level))
	if d.shield_capacity > 0.0:
		bits.append("escudo de %d que se recarga %d por segundo" % [d.shield_at(level), d.shield_recharge])
	if d.unique: bits.append("solo uno por nave")
	if d.category == PartData.Category.COMMAND_STATION: bits.append("lleva un arma")
	return ", ".join(bits)


## Lo que gana una pieza al subir del nivel `level` al siguiente (núcleo y escudo).
func _level_gain(d: PartData, level: int) -> String:
	var bits: Array[String] = []
	if d.hp_per_level > 0.0: bits.append("+%d casco" % roundi(d.hp_at(level + 1) - d.hp_at(level)))
	if d.crew_per_level > 0: bits.append("+%d plaza" % d.crew_per_level)
	if d.shield_per_level > 0.0: bits.append("+%d escudo" % roundi(d.shield_at(level + 1) - d.shield_at(level)))
	return "" if bits.is_empty() else ": " + ", ".join(bits)


func _fill_part_panel(index: int) -> void:
	var e := GameState.blueprint[index]
	var data := Catalog.part(e["part"])
	var title := data.display_name
	if data.has_levels:
		title += " (nivel %d)" % e["level"]
	_title(_mechanic_box, title, 18)
	if e["destroyed"]:
		_wrap(_mechanic_box, "Totalmente destruida: al reparar se compra de nuevo.", 14, COLOR_WARN)
	elif e["lost"]:
		_wrap(_mechanic_box, "Perdida: al reparar se reconstruye al 50 % de su precio.", 14, COLOR_WARN)
	else:
		_text(_mechanic_box, "Vida %d / %d · %s" % [GameState.part_hp(e), GameState.part_max_hp(e), _part_stats(data, e["level"])],
				14, COLOR_TEXT)

	var row := HFlowContainer.new()
	_mechanic_box.add_child(row)
	var up := GameState.structure_upgrade_cost(e)
	if up > 0 and GameState.is_alive(index):
		var b := _button(row, "Mejorar al nivel %d (%d créditos)%s" % [e["level"] + 1, up, _level_gain(data, e["level"])],
				_on_upgrade_structure.bind(index))
		b.disabled = up > GameState.money
	if data.mount_options().size() > 1 and GameState.children_of(index).is_empty() and e["attached_to"] >= 0:
		_button(row, "Girar", _on_rotate.bind(index))
	if e["attached_to"] >= 0:
		var reason := GameState.remove_block_reason(index)
		var extra := GameState.subtree(index).size() - 1
		var label := "Vender (+%d créditos)" % GameState.sell_value(index)
		if extra > 0:
			label = "Vender con las %d piezas que cuelgan de ella (+%d créditos)" % [extra, GameState.sell_value(index)]
		var b := _button(row, label, _on_sell_part.bind(index))
		b.disabled = reason != ""
		if reason != "":
			_wrap(_mechanic_box, reason, 13, COLOR_WARN)

	if data.category == PartData.Category.COMMAND_STATION and GameState.is_alive(index):
		_separator(_mechanic_box)
		_fill_weapon_panel(index)
		_fill_crew_selector(index)


func _fill_weapon_panel(index: int) -> void:
	var e := GameState.blueprint[index]
	if e["weapon"] == &"":
		_title(_mechanic_box, "Arma: ninguna. Compra una:", 16)
		for w: WeaponData in _weapons_sorted():
			var b := _button(_mechanic_box, "%s — %d créditos   (%s)" % [w.display_name, w.price, _weapon_desc(w)],
					_on_buy_weapon.bind(index, w.id))
			b.disabled = w.price > GameState.money
		return
	var w := Catalog.weapon(e["weapon"])
	var level: int = e["weapon_level"]
	_title(_mechanic_box, "Arma: %s (nivel %d)" % [w.display_name, level], 16)
	_wrap(_mechanic_box, _weapon_desc(w), 13, COLOR_DIM)
	var row := HFlowContainer.new()
	_mechanic_box.add_child(row)
	var cost := w.upgrade_cost(level)
	if cost < 0 and GameState.can_evolve_weapon(e):
		var evo := Catalog.weapon(w.evolves_into)
		var b := _button(row, "Evolucionar a %s (%d créditos)" % [evo.display_name, GameState.EVOLUTION_COST],
				_on_evolve_weapon.bind(index))
		b.disabled = GameState.EVOLUTION_COST > GameState.money
		b.add_theme_color_override(&"font_color", COLOR_MONEY)
		_wrap(_mechanic_box, "Evolución: %s. Vuelve al nivel 1 y puede mejorarse hasta el 10." % _weapon_desc(evo),
				13, COLOR_DIM)
	elif cost < 0:
		var b := _button(row, "Nivel máximo", func() -> void: pass)
		b.disabled = true
	else:
		var b := _button(row, "Mejorar arma al nivel %d (%d créditos)" % [level + 1, cost], _on_upgrade_weapon.bind(index))
		b.disabled = cost > GameState.money
	_button(row, "Vender arma (+%d)" % int(w.price * GameState.SELL_FACTOR), _on_sell_weapon.bind(index))


func _weapons_sorted() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for w: WeaponData in Catalog.weapons.values():
		if w.for_sale:
			out.append(w)
	out.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.price < b.price)
	return out


func _weapon_desc(w: WeaponData) -> String:
	match w.kind:
		WeaponData.Kind.ROCKET:
			return "cohetes lentos con daño %d en un área de %.1f m" % [w.damage, w.area_radius]
		WeaponData.Kind.BEAM:
			return "rayo continuo de %.1f m de grosor y %d de daño por segundo que atraviesa enemigos" % [
				w.beam_width, w.damage]
		_:
			if w.pellets > 1:
				return "abanico de %d perdigones de %d de daño, de corto alcance" % [w.pellets, w.damage]
			if w.pierce > 0:
				return "disparos lentos de %d de daño que atraviesan hasta %d enemigos" % [w.damage, w.pierce + 1]
			if w.barrels > 1:
				return "%d cañones: ráfagas de %d balas de %d de daño" % [w.barrels, w.barrels, w.damage]
			return "ráfaga rápida de %d de daño por bala" % w.damage


func _fill_crew_selector(index: int) -> void:
	var e := GameState.blueprint[index]
	var row := HBoxContainer.new()
	_mechanic_box.add_child(row)
	_text(row, "Tripulante: ", 15, COLOR_TEXT)
	var opt := OptionButton.new()
	opt.add_item("Sin tripulante (el arma no dispara)", 0)
	for i in GameState.crew.size():
		var m := GameState.crew[i]
		var post := GameState.crew_post(i)
		var where := "" if post < 0 or post == index else "  [ahora %s]" % _post_name(post)
		opt.add_item("%s — artillero %d%s" % [m["name"], m["gunnery"], where], i + 1)
	opt.selected = e["crew"] + 1
	# Sin esto, el texto más largo de la lista ensancha todo el panel.
	opt.fit_to_longest_item = false
	opt.clip_text = true
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.custom_minimum_size = Vector2(200, 0)
	opt.item_selected.connect(_on_crew_selected.bind(index))
	row.add_child(opt)
	if GameState.crew.is_empty():
		_wrap(_mechanic_box, "No tienes tripulantes: recluta uno en el bar.", 13, COLOR_WARN)


# ---------- bar ----------

func _fill_bar() -> void:
	_clear(_bar_box)
	_title(_bar_box, "Tu tripulación (%d/%d plazas)" % [GameState.crew.size(), GameState.crew_capacity()], 18)
	if GameState.crew.is_empty():
		_text(_bar_box, "No tienes tripulantes: tus armas no dispararán.", 14, COLOR_WARN)
	for i in GameState.crew.size():
		var m := GameState.crew[i]
		var post := GameState.crew_post(i)
		_text(_bar_box, "%s (%s) — %s" % [m["name"], m["personality"], _post_name(post)], 15, COLOR_TEXT)
		_wrap(_bar_box, _stats_line(m), 13, COLOR_DIM)
		var b := _small_button(_bar_box, "Despedir", _on_dismiss.bind(i))
		b.add_theme_color_override(&"font_color", COLOR_WARN)
	_separator(_bar_box)
	_title(_bar_box, "Candidatos en el bar", 18)
	_wrap(_bar_box, "Cambian cada vez que vuelves a la estación. Cuanto mejores son, más cuestan.", 13, COLOR_DIM)
	var full := GameState.crew.size() >= GameState.crew_capacity()
	if full:
		_wrap(_bar_box, "No hay plazas libres: instala habitaciones de tripulantes con el mecánico.", 13, COLOR_WARN)
	for i in GameState.bar_candidates.size():
		var c := GameState.bar_candidates[i]
		var best := GameState.best_stat(c)
		_text(_bar_box, "%s (%s) — %s %d" % [c["name"], c["personality"], GameState.CREW_STAT_NAMES[best], c[best]],
				15, COLOR_TEXT)
		_wrap(_bar_box, _stats_line(c), 13, COLOR_DIM)
		var b := _small_button(_bar_box, "Contratar (%d créditos)" % c["price"], _on_hire.bind(i))
		b.disabled = full or c["price"] > GameState.money


func _post_name(post: int) -> String:
	if post < 0:
		return "sin puesto"
	var e := GameState.blueprint[post]
	var text := "en " + Catalog.part(e["part"]).display_name
	if e["weapon"] != &"":
		text += " (%s)" % Catalog.weapon(e["weapon"]).display_name
	return text


## Botón que ocupa solo lo que mide su texto, alineado a la izquierda.
func _small_button(parent: Control, text: String, callback: Callable) -> Button:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return _button(row, text, callback)


func _stats_line(m: Dictionary) -> String:
	var bits: Array[String] = []
	for s in GameState.CREW_STATS:
		bits.append("%s %d" % [GameState.CREW_STAT_NAMES[s], m[s]])
	return " · ".join(bits)


# ---------- chatarra ----------

func _fill_scrap() -> void:
	_clear(_scrap_box)
	if GameState.scrap.is_empty():
		_text(_scrap_box, "No llevas chatarra.", 15, COLOR_DIM)
	for type_id in GameState.scrap:
		var t := Catalog.scrap(type_id)
		var n: int = GameState.scrap[type_id]
		_text(_scrap_box, "%s: %d × %d = %d créditos" % [t.display_name, n, t.price, n * t.price], 15, t.color.lightened(0.3))
	var value := GameState.scrap_value()
	var b := _button(_scrap_box, "Vender toda la chatarra (+%d créditos)" % value, _on_sell)
	b.disabled = value <= 0


# ---------- acciones ----------

func _on_sell() -> void:
	Sfx.play(&"ui_money" if GameState.sell_all_scrap() > 0 else &"ui_error")
	refresh_panels()


func _on_repair() -> void:
	_ok(GameState.repair_all(), &"ui_install")
	refresh()


func _on_buy_part(part_id: StringName, parent: int, slot: int) -> void:
	_notice = GameState.buy_part(part_id, parent, slot)
	_ok(_notice == "", &"ui_install")
	if _notice == "":
		_editor.selected_slot = {}
		_editor.selected_part = GameState.blueprint.size() - 1
	refresh()


func _on_rotate(index: int) -> void:
	_notice = "" if GameState.rotate_part(index) else "No hay otra forma de girarla sin chocar con otra pieza."
	_ok(_notice == "", &"ui_install")
	refresh()


func _on_sell_part(index: int) -> void:
	GameState.sell_part(index)
	Sfx.play(&"ui_money")
	_editor.clear_selection()
	refresh()


func _on_upgrade_structure(index: int) -> void:
	_ok(GameState.upgrade_structure(GameState.blueprint[index]))
	refresh()


func _on_buy_weapon(index: int, weapon_id: StringName) -> void:
	_ok(GameState.buy_weapon(GameState.blueprint[index], weapon_id), &"ui_install")
	refresh()


func _on_upgrade_weapon(index: int) -> void:
	_ok(GameState.upgrade_weapon(GameState.blueprint[index]))
	refresh_panels()


func _on_evolve_weapon(index: int) -> void:
	_ok(GameState.evolve_weapon(GameState.blueprint[index]), &"evolve")
	refresh()


func _on_sell_weapon(index: int) -> void:
	GameState.sell_weapon(GameState.blueprint[index])
	Sfx.play(&"ui_money")
	refresh()


func _on_crew_selected(item: int, index: int) -> void:
	if item > 0:
		GameState.assign_crew(item - 1, index)
	else:
		GameState.assign_crew(GameState.blueprint[index]["crew"], -1)
	refresh()


func _on_hire(index: int) -> void:
	_notice = GameState.hire_candidate(index)
	_ok(_notice == "")
	refresh_panels()


func _on_dismiss(index: int) -> void:
	Sfx.play(&"ui_back")
	GameState.dismiss_crew(index)
	refresh_panels()


func _on_toggle_view() -> void:
	_editor.set_from_below(not _editor.from_below)
	_view_button.text = "Ver desde arriba" if _editor.from_below else "Ver desde abajo"


func _on_reset_view() -> void:
	_editor.reset_view()
	_view_button.text = "Ver desde abajo"


func _process(_delta: float) -> void:
	# Si el jugador gira la nave con el ratón, el botón dice hacia dónde puede pasar.
	_view_button.text = "Ver desde arriba" if _editor.from_below else "Ver desde abajo"


func _on_abandon() -> void:
	GameState.abandon_ship()
	_editor.clear_selection()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _map != null or _options != null:
		return
	if event.is_action_pressed(&"star_map"):
		get_viewport().set_input_as_handled()
		_open_map()
	elif event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_open_options()
	elif event.is_action_pressed(&"tab_prev") or event.is_action_pressed(&"tab_next"):
		get_viewport().set_input_as_handled()
		var step := -1 if event.is_action_pressed(&"tab_prev") else 1
		_tabs.current_tab = posmod(_tabs.current_tab + step, _tabs.get_tab_count())


func _open_options() -> void:
	if _options != null:
		return
	_options = OptionsMenu.new()
	_options.closed.connect(func() -> void: _options = null)
	add_child(_options)


func _open_map() -> void:
	if _map != null:
		return
	_map = StarMap.new()
	_map.setup(_map_mode())
	_map.destination_chosen.connect(_on_destination)
	_map.closed.connect(func() -> void: _map = null)
	add_child(_map)


func _map_mode() -> StarMap.Mode:
	return StarMap.Mode.STATION


func _on_destination(site_id: StringName) -> void:
	GameState.last_report = ""
	GameState.save_game()
	GameState.travel_to(site_id)


## Pruebas automáticas: salta a la primera zona de 5 minutos del sistema.
func _on_jump() -> void:
	var sys := Catalog.system_of(GameState.location)
	var target := sys.zones[0].id if sys and not sys.zones.is_empty() else &""
	for z in sys.zones:
		if GameState.can_reach(z.id):
			target = z.id
			break
	if GameState.args.has("zone"):
		target = StringName(GameState.args["zone"])
	_on_destination(target)


func _on_menu() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file.call_deferred(GameState.MENU_SCENE)


# ---------- helpers de interfaz ----------

## 100000 → «100.000».
static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Sonido de una acción: el de éxito o el de error.
func _ok(success: bool, sound: StringName = &"ui_confirm") -> void:
	Sfx.play(sound if success else &"ui_error")


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _title(parent: Control, text: String, font_size: int) -> Label:
	return _text(parent, text, font_size, Color(0.95, 0.97, 1.0))


func _text(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	parent.add_child(l)
	return l


func _wrap(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l := _text(parent, text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	return l


func _separator(parent: Control) -> void:
	parent.add_child(HSeparator.new())


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# En una columna, los textos largos se recortan para no ensanchar el panel.
	if parent is VBoxContainer:
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


# ---------- pruebas automáticas ----------

## Prueba del mando (`--pad-test`): RB cambia de pestaña y A hace clic donde está el puntero.
func _pad_test() -> void:
	await get_tree().create_timer(0.5).timeout
	var before := _tabs.current_tab
	for pressed: bool in [true, false]:
		var rb := InputEventJoypadButton.new()
		rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
		rb.pressed = pressed
		Input.parse_input_event(rb)
		await get_tree().process_frame
	print("[pad-test] RB: tab %d -> %d" % [before, _tabs.current_tab])
	# A sobre la pestaña «Chatarra»: el puntero va allí y A hace clic.
	var bar := _tabs.get_tab_bar()
	var rect := bar.get_tab_rect(2)
	var vp_pos := bar.get_global_transform_with_canvas() * rect.get_center()
	var win_pos := get_viewport().get_final_transform() * vp_pos
	Input.warp_mouse(win_pos)
	await get_tree().create_timer(0.2).timeout
	GamepadCursor._pos = win_pos
	for pressed: bool in [true, false]:
		var a := InputEventJoypadButton.new()
		a.button_index = JOY_BUTTON_A
		a.pressed = pressed
		Input.parse_input_event(a)
		await get_tree().process_frame
	print("[pad-test] A on tab 2: tab = %d, pointer mode = %s" % [_tabs.current_tab, GamepadCursor.pointer_active()])
	# Start abre las opciones; ahí el mando navega con el foco.
	for pressed: bool in [true, false]:
		var st := InputEventJoypadButton.new()
		st.button_index = JOY_BUTTON_START
		st.pressed = pressed
		Input.parse_input_event(st)
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var f1 := get_viewport().gui_get_focus_owner()
	for pressed: bool in [true, false]:
		var down := InputEventJoypadButton.new()
		down.button_index = JOY_BUTTON_DPAD_DOWN
		down.pressed = pressed
		Input.parse_input_event(down)
		await get_tree().process_frame
	var f2 := get_viewport().gui_get_focus_owner()
	print("[pad-test] options open = %s, pointer mode = %s, focus %s -> %s" % [_options != null,
			GamepadCursor.pointer_active(), f1.get_class() if f1 else "none", (f2.get_class() + (" (moved)" if f2 != f1 else " (same)")) if f2 else "none"])
	await _save_screenshot("-pad")
	get_tree().quit()


## Prueba automática del bucle: vende, repara, mejora, guarda una captura y vuelve a saltar.
func _auto_test() -> void:
	await get_tree().create_timer(0.8).timeout
	_on_sell()
	_on_repair()
	for i in GameState.blueprint.size():
		if GameState.blueprint[i]["weapon"] != &"" and GameState.is_alive(i):
			_on_upgrade_weapon(i)
	await _save_screenshot()
	if GameState.args.has("quit-after-station"):
		get_tree().quit()
	else:
		_on_jump()


## Prueba del editor (`-- --build-test --money=20000`): construye una nave más grande con
## la misma interfaz que usaría el jugador, contrata tripulantes y guarda capturas.
func _build_test() -> void:
	await get_tree().create_timer(0.5).timeout
	var say := func(msg: String) -> void: print("[build-test] ", msg)
	# 1) Pasillo a la derecha del núcleo, elegido con un clic en su ranura.
	_click_slot(0, 3)
	say.call("slot selected: %s" % str(_editor.selected_slot))
	_on_buy_part(&"corridor_1x2", 0, 3)
	say.call("corridor: notice='%s' parts=%d" % [_notice, GameState.blueprint.size()])
	var corridor := GameState.blueprint.size() - 1
	# 2) Estación de mando con lanzacohetes al final del pasillo (mira a la derecha).
	_on_buy_part(&"command_station", corridor, 0)
	var rocket_station := GameState.blueprint.size() - 1
	_on_buy_weapon(rocket_station, &"rocket_launcher")
	# 3) Habitación pequeña a la izquierda del núcleo y estación con láser en un lado del pasillo.
	_on_buy_part(&"crew_quarters_small", 0, 2)
	say.call("quarters: notice='%s' capacity=%d" % [_notice, GameState.crew_capacity()])
	var free := GameState.free_slots()
	for s in free:
		if s["part_index"] == corridor and s["kind"] == PartData.SlotKind.SIDE and s["normal"].z < -0.5:
			_on_buy_part(&"command_station", corridor, s["slot"])
			break
	var laser_station := GameState.blueprint.size() - 1
	_on_buy_weapon(laser_station, &"laser")
	# 4) Accesorios: placa arriba del núcleo y recolector arriba del pasillo; propulsor mediano.
	_on_buy_part(&"armor_plate", 0, 4)
	for s in GameState.free_slots():
		if s["part_index"] == corridor and s["kind"] == PartData.SlotKind.FACE and s["normal"].y > 0.0:
			_on_buy_part(&"scrap_magnet", corridor, s["slot"])
			break
	for s in GameState.free_slots():
		if s["part_index"] == corridor and s["kind"] == PartData.SlotKind.SIDE and s["normal"].z > 0.5:
			_on_buy_part(&"thruster_medium", corridor, s["slot"])
			break
	# 5) Bar: contrata a los dos candidatos más baratos y los pone en las estaciones nuevas.
	for k in 2:
		var cheapest := 0
		for i in GameState.bar_candidates.size():
			if GameState.bar_candidates[i]["price"] < GameState.bar_candidates[cheapest]["price"]:
				cheapest = i
		_on_hire(cheapest)
		say.call("hire: notice='%s' crew=%d" % [_notice, GameState.crew.size()])
	GameState.assign_crew(1, rocket_station)
	GameState.assign_crew(2, laser_station)
	# 6) Fase 6: mejora del núcleo (casco y plazas) y reglas del generador de escudo.
	var cap_before := GameState.crew_capacity()
	var hp_before := GameState.part_max_hp(GameState.blueprint[0])
	var cost := GameState.structure_upgrade_cost(GameState.blueprint[0])
	_on_upgrade_structure(0)
	say.call("core upgrade: cost=%d level=%d hull %d->%d capacity %d->%d" % [cost, GameState.blueprint[0]["level"],
			hp_before, GameState.part_max_hp(GameState.blueprint[0]), cap_before, GameState.crew_capacity()])
	say.call("shield on side slot: %s" % GameState.check_placement(&"shield_generator", 0, 2)["reason"])
	say.call("shield on top of corridor: ok=%s" % GameState.check_placement(&"shield_generator", corridor, 4)["ok"])
	refresh()
	# 6) Con `--evolve-test`: sube las armas al nivel 10 y las evoluciona.
	if GameState.args.has("evolve-test"):
		for i in GameState.blueprint.size():
			var e := GameState.blueprint[i]
			if e["weapon"] != &"":
				e["weapon_level"] = 10
				GameState.add_money(GameState.EVOLUTION_COST)
				_on_evolve_weapon(i)
				say.call("evolve %d: %s level %d" % [i, e["weapon"], e["weapon_level"]])
	for i in GameState.blueprint.size():
		var e := GameState.blueprint[i]
		say.call("%d %s parent=%d slot=%d mount=%d pos=%s weapon=%s crew=%d" % [i, e["part"], e["attached_to"],
				e["parent_slot"], e["mount_slot"], str(e["transform"].origin), e["weapon"], e["crew"]])
	say.call("money=%d crew=%d/%d free_slots=%d" % [GameState.money, GameState.crew.size(),
			GameState.crew_capacity(), GameState.free_slots().size()])
	# Captura con la estación de mando del láser elegida.
	_editor.selected_part = 0 if GameState.args.has("core-shot") else laser_station
	_editor.refresh()
	refresh_panels()
	await _save_screenshot()
	# Vista desde abajo: se ven y se pueden elegir las ranuras de la cara inferior.
	_editor.set_from_below(true)
	await get_tree().create_timer(1.0).timeout
	_click_slot(0, 5)
	say.call("below: slot selected %s" % str(_editor.selected_slot))
	await _save_screenshot("-below")
	_editor.reset_view()
	_show_tab(1)
	await _save_screenshot("-bar")
	GameState.save_game()
	if GameState.args.has("quit-after-station"):
		get_tree().quit()
	else:
		_on_jump()


func _click_slot(part_index: int, slot: int) -> void:
	var pos := _editor.slot_screen_position(part_index, slot)
	_editor.pick(pos)


func _save_screenshot(suffix: String = "") -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	if GameState.args.has("station-screenshot"):
		var path: String = GameState.args["station-screenshot"]
		path = path.get_basename() + suffix + "." + path.get_extension()
		get_viewport().get_texture().get_image().save_png(path)
		print("station screenshot saved: %s money=%d" % [path, GameState.money])
