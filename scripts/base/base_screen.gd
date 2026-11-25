class_name BaseScreen
extends Station
## Una base del jugador (GDD 7): vista 3D con los edificios en sus parcelas y una ventana para
## cada edificio (lo que hace, su nivel y sus tripulantes). La base hace de estación solo con
## los edificios adecuados: el hangar (con un ingeniero) es el taller de la nave, el puerto
## comercial vende, la academia recluta y el cargador reposta. Hereda de `Station` el taller.

const COLOR_GOOD := Color(0.45, 1.0, 0.6)
const BUILDING_TAB := 0
const HANGAR_TAB := 1
const CREW_TAB := 2

var _base_view: BaseView
var _base_box: VBoxContainer
var _crew_box: VBoxContainer
var _toggle_button: Button
var _center_button: Button
var _tools_hint: Label
var _showing_ship: bool = false
## Etiqueta de la ventana abierta que cambia con el tiempo (investigación, curación…).
var _live_label: Label
var _live_text: Callable
var _live_timer: float = 0.0


func _base() -> Dictionary:
	return Bases.current()


func _title_text() -> String:
	var base := _base()
	return "Base de %s" % Catalog.place_name(GameState.location) if not base.is_empty() else "Base"


func _build_view_area(stack: Control) -> void:
	super(stack)
	_base_view = BaseView.new()
	_base_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_base_view)
	_base_view.setup(GameState.location)
	_base_view.lot_selected.connect(_on_lot_selected)
	_base_view.deselected.connect(func() -> void: refresh_panels())
	_base_view.ship_clicked.connect(func() -> void: _set_ship_view(true))
	_mechanic_tab = HANGAR_TAB


func _build_tools(tools: HBoxContainer) -> void:
	_toggle_button = _button(tools, "Ver la nave (hangar)", func() -> void: _set_ship_view(not _showing_ship))
	_view_button = _button(tools, "Ver desde abajo", _on_toggle_view)
	_center_button = _button(tools, "Centrar", _on_center)
	_tools_hint = _wrap(tools, "", 12, COLOR_DIM)
	_tools_hint.custom_minimum_size = Vector2(0, 0)
	_tools_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build_tabs() -> void:
	_base_box = _tab("Base")
	_mechanic_box = _tab("Hangar")
	_crew_box = _tab("Tripulación")
	Bases.event.connect(_on_base_event)


func _ready() -> void:
	await super()
	_set_ship_view(false)


func _set_ship_view(on: bool) -> void:
	_showing_ship = on
	_editor.visible = on
	_status_view.visible = on
	_base_view.visible = not on
	_view_button.visible = on
	_toggle_button.text = "Ver la base" if on else "Ver la nave (hangar)"
	_tools_hint.text = "Arrastra: girar · rueda: zoom · azul: ranura lateral · naranja: arriba/abajo" if on else \
			"Arrastra: girar · rueda: zoom · clic en una parcela (+) para construir, en un edificio para abrirlo o en la nave para ver el hangar"
	if on:
		_show_tab(HANGAR_TAB)


func _on_center() -> void:
	if _showing_ship:
		_on_reset_view()
	else:
		_base_view.reset_view()


func _on_lot_selected(_lot: int) -> void:
	_notice = ""
	_show_tab(BUILDING_TAB)
	refresh_panels()


func _on_base_event(text: String) -> void:
	GameState.last_report = text
	refresh_panels()


func refresh() -> void:
	super()
	if _base_view:
		_base_view.refresh()


func _fill_panels() -> void:
	_live_label = null
	_fill_base_panel()
	_fill_mechanic()
	_fill_crew()


func _map_mode() -> StarMap.Mode:
	return StarMap.Mode.STATION if Bases.can_take_off() else StarMap.Mode.VIEW


func _process(delta: float) -> void:
	super(delta)
	_live_timer -= delta
	if _live_timer > 0.0:
		return
	_live_timer = 0.5
	if Bases.can_take_off():
		_jump_button.text = "Abrir el mapa estelar y despegar (M)"
	else:
		var left := int(Bases.fuel_wait)
		_jump_button.text = "Recargando combustible %d:%02d · construye un cargador para repostar al instante" % [
			left / 60, left % 60]
	if _live_label and is_instance_valid(_live_label) and _live_text.is_valid():
		_live_label.text = _live_text.call()


func _live(parent: Control, text_fn: Callable, color: Color = COLOR_TEXT) -> void:
	_live_text = text_fn
	_live_label = _wrap(parent, text_fn.call(), 14, color)


static func _clock(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 3600:
		return "%d h %02d min" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]


# ---------- ventana de la base y de los edificios ----------

func _fill_base_panel() -> void:
	_clear(_base_box)
	if _notice != "":
		_text(_base_box, _notice, 14, COLOR_WARN)
	var base := _base()
	var lot := _base_view.selected_lot
	if lot < 0:
		_fill_overview(base)
		return
	var b := Bases.building_at(base, lot)
	if b.is_empty():
		_fill_build_menu(base, lot)
	else:
		_fill_building(base, b)


func _fill_overview(base: Dictionary) -> void:
	_title(_base_box, "%s · %s" % [Catalog.place_name(base["body"]), Bases.kind_name(base)], 20)
	_text(_base_box, "%d de %d parcelas con edificios" % [base["buildings"].size(), Bases.lot_count(base)], 14, COLOR_DIM)
	_live(_base_box, _fuel_text)
	_separator(_base_box)
	_title(_base_box, "Guardado en tus bases", 16)
	_storage_lines(_base_box)
	_separator(_base_box)
	_title(_base_box, "Producción (solo con el juego abierto)", 16)
	_wrap(_base_box, _production_text(), 14, COLOR_TEXT)
	if Bases.bases.size() > 1:
		_separator(_base_box)
		_title(_base_box, "Tus bases", 16)
		for other in Bases.bases:
			_text(_base_box, "%s (%s): %d edificios%s" % [Catalog.place_name(other["body"]), Bases.kind_name(other),
					other["buildings"].size(), "" if other["founded"] else " · sin fundar"], 14, COLOR_TEXT)
	_separator(_base_box)
	_wrap(_base_box, "Haz clic en una parcela libre (+) para construir, o en un edificio para abrir su ventana. Cada base admite un edificio de cada tipo.", 14, COLOR_DIM)


func _fuel_text() -> String:
	if Bases.can_take_off():
		return "Combustible: listo para despegar."
	return "Combustible: recargando, faltan %s. Con un cargador de combustible se rellena al aterrizar." % _clock(Bases.fuel_wait)


func _storage_lines(parent: Control) -> void:
	if Bases.storage.is_empty():
		_text(parent, "Nada todavía. La chatarra se descarga al aterrizar si tienes una refinería o un puerto comercial.", 13, COLOR_DIM)
		return
	for id in Bases.storage:
		var n: int = Bases.storage[id]
		var s := Catalog.scrap(id)
		if s:
			_text(parent, "%s: %d (chatarra, %d créditos c/u)" % [s.display_name, n, s.price], 14, s.color.lightened(0.3))
	for m in Catalog.sorted_minerals():
		if Bases.storage.has(m.id):
			_text(parent, "%s: %d (mineral, %d créditos c/u)" % [m.display_name, Bases.storage[m.id], m.price], 14, m.color)


func _production_text() -> String:
	var bits: Array[String] = []
	var r := Bases.research_rate()
	if Bases.research_current != &"":
		bits.append("Investigando %s: %d/%d puntos (%.1f por minuto)." % [Bases.research_name(Bases.research_current),
				int(Bases.research_progress), Bases.research_cost(Bases.research_current), r])
	elif Bases.has_anywhere(&"research_center"):
		bits.append("Centro de investigación sin investigación en curso (%.1f puntos por minuto)." % r)
	if Bases.has_anywhere(&"refinery"):
		bits.append("Refinerías: %d créditos de chatarra por minuto." % int(Bases.refinery_rate()))
	for base in Bases.bases:
		var m := Bases.mine_rate(base)
		if m > 0.0:
			bits.append("Mina de %s: %.1f créditos de minerales por minuto." % [Catalog.place_name(base["body"]), m])
	if bits.is_empty():
		return "Ningún edificio produce todavía."
	return "\n".join(bits)


func _fill_build_menu(base: Dictionary, lot: int) -> void:
	_title(_base_box, "Parcela libre: elige qué construir", 18)
	for data in Catalog.sorted_buildings():
		var built := not Bases.find_building(base, data.id).is_empty()
		var label := "%s — %d créditos" % [data.display_name, data.price]
		if built:
			label = "%s — ya está en esta base" % data.display_name
		var b := _button(_base_box, label, _on_build.bind(data.id, lot))
		b.disabled = built or data.price > GameState.money
		_wrap(_base_box, data.description, 13, COLOR_DIM)


func _fill_building(base: Dictionary, b: Dictionary) -> void:
	var data := Catalog.building(b["type"])
	_title(_base_box, data.display_name + (" (nivel %d)" % b["level"] if data.has_levels else ""), 20)
	_wrap(_base_box, data.description, 13, COLOR_DIM)
	var cost := Bases.upgrade_cost(b)
	if cost > 0:
		var up := _button(_base_box, "Mejorar al nivel %d (%d créditos): %s" % [b["level"] + 1, cost, _level_bonus(data)],
				_on_upgrade_building.bind(b))
		up.disabled = cost > GameState.money
	elif data.has_levels:
		_text(_base_box, "Nivel máximo.", 13, COLOR_DIM)
	if data.crew_stat != "":
		_separator(_base_box)
		_fill_building_crew(base, b, data)
	_separator(_base_box)
	match b["type"]:
		&"research_center":
			_fill_research(base)
		&"hangar":
			_fill_hangar(base, b)
		&"refinery":
			_live(_base_box, func() -> String:
				return "Refina %d créditos de chatarra por minuto en minerales que valen un 50 %% más. Chatarra guardada: %d créditos." % [
					int(Bases.rate(b)), Bases.stored_scrap_value()])
			_storage_lines(_base_box)
		&"mine":
			_live(_base_box, func() -> String:
				var next := Catalog.mineral(base["mine_next"])
				return "Extrae %.1f créditos de minerales por minuto%s. Próximo: %s (%d%%)." % [Bases.mine_rate(base),
					" (bono de asteroide)" if Bases.kind_name(base) == "Asteroide" else "",
					next.display_name if next else "?", int(100.0 * base["mine_acc"] / maxf(next.price if next else 1.0, 1.0))])
		&"academy":
			_fill_academy(base)
		&"infirmary":
			_fill_infirmary(base)
		&"trade_port":
			_fill_trade_port()
		&"fuel_charger":
			_wrap(_base_box, "Rellena el depósito al aterrizar en esta base: puedes despegar enseguida.", 14, COLOR_GOOD)


func _level_bonus(data: BuildingData) -> String:
	match data.id:
		&"hangar":
			return "reconstruir cuesta un 2 % menos"
		&"research_center":
			return "+10 % de puntos"
		&"refinery":
			return "+20 % de refinado"
		&"mine":
			return "+25 % de minerales"
		&"academy":
			return "más candidatos y plazas en los niveles 4 y 7"
		&"infirmary":
			return "cura un 10 % más rápido"
		&"trade_port":
			return "+2 % al precio de la chatarra"
	return "mejora"


func _fill_building_crew(base: Dictionary, b: Dictionary, data: BuildingData) -> void:
	var stat := data.crew_stat
	var slots := data.crew_slots_at(b["level"])
	var working := Bases.workers(base["body"], b["type"])
	_title(_base_box, "Tripulantes (%d/%d) · usan su estadística de %s" % [working.size(), slots,
			GameState.CREW_STAT_NAMES[stat].to_lower()], 16)
	if working.is_empty():
		_wrap(_base_box, "Sin tripulantes este edificio no funciona. Asigna uno con la lista de abajo.", 13, COLOR_WARN)
	for i in working:
		var m := Bases.crew[i]
		var row := HBoxContainer.new()
		_base_box.add_child(row)
		_text(row, "%s — %s %d   " % [m["name"], GameState.CREW_STAT_NAMES[stat], m[stat]], 15, COLOR_TEXT)
		_button(row, "Quitar", _on_unassign.bind(i))
	if working.size() >= slots:
		return
	var opt := OptionButton.new()
	opt.add_item("Asignar un tripulante…", 0)
	var choices: Array = []
	for i in Bases.members_at(base["body"]):
		var m := Bases.crew[i]
		if Bases.is_available(i) and m["job"] != b["type"]:
			var where := "en reserva" if m["job"] == &"" else "ahora en " + Catalog.building(m["job"]).display_name
			opt.add_item("%s — %s %d (%s)" % [m["name"], GameState.CREW_STAT_NAMES[stat], m[stat], where], choices.size() + 1)
			choices.append(["base", i])
	for i in GameState.crew.size():
		var m := GameState.crew[i]
		opt.add_item("%s — %s %d (en la nave)" % [m["name"], GameState.CREW_STAT_NAMES[stat], m[stat]], choices.size() + 1)
		choices.append(["ship", i])
	opt.fit_to_longest_item = false
	opt.clip_text = true
	opt.custom_minimum_size = Vector2(200, 0)
	opt.item_selected.connect(func(item: int) -> void:
		if item > 0:
			_on_assign(choices[item - 1], b["type"]))
	_base_box.add_child(opt)
	if choices.is_empty():
		_wrap(_base_box, "No hay tripulantes libres aquí: recluta en la academia o en el bar de una estación.", 13, COLOR_DIM)


func _fill_research(base: Dictionary) -> void:
	_live(_base_box, func() -> String:
		var r := Bases.research_rate()
		if Bases.research_current == &"":
			return "Sin investigación en curso. Todos tus centros suman %.1f puntos por minuto." % r
		var cost := Bases.research_cost(Bases.research_current)
		var left := (cost - Bases.research_progress) / maxf(r, 0.001) * 60.0
		return "Investigando %s: %d/%d puntos · %.1f por minuto · %s" % [Bases.research_name(Bases.research_current),
			int(Bases.research_progress), cost, r, "falta %s" % _clock(left) if r > 0.0 else "sin investigadores"],
			COLOR_GOOD)
	if Catalog.body(base["body"]).kind == CelestialBodyData.Kind.MOON:
		_text(_base_box, "En un satélite: +30 % de puntos (telescopio).", 13, COLOR_GOOD)
	_title(_base_box, "Investigar", 16)
	_wrap(_base_box, "Lo investigado queda desbloqueado para siempre y se fabrica en el hangar. Cambiar de investigación pierde lo avanzado.", 13, COLOR_DIM)
	var r := Bases.research_rate()
	for opt in Bases.research_options():
		var t := "%s (%s) — %d puntos" % [opt["name"], opt["desc"], opt["points"]]
		if r > 0.0:
			t += " · ~%s" % _clock(opt["points"] / r * 60.0)
		var b := _button(_base_box, t, _on_research.bind(opt["id"]))
		b.disabled = opt["id"] == Bases.research_current
	if not Bases.researched.is_empty():
		var names: Array[String] = []
		for id in Bases.researched:
			names.append(Bases.research_name(id))
		_wrap(_base_box, "Investigado: " + ", ".join(names), 13, COLOR_GOOD)


func _fill_hangar(base: Dictionary, h: Dictionary) -> void:
	if Bases.hangar_ready(base):
		_wrap(_base_box, "Con un ingeniero, el hangar repara, vende, mejora y evoluciona piezas como el mecánico de una estación, y fabrica las piezas investigadas.", 14, COLOR_GOOD)
		_button(_base_box, "Abrir el taller (ver la nave)", func() -> void: _set_ship_view(true))
	else:
		_wrap(_base_box, "Asigna un ingeniero para construir, reconstruir o reparar la nave.", 14, COLOR_WARN)
	_title(_base_box, "Planos (%d/%d)" % [Bases.plans.size(), Bases.max_plans()], 16)
	_wrap(_base_box, "Construir un plano reemplaza tu nave: la actual se desarma y devuelve el 50 %% de su valor. Cuesta el %d %% del valor del plano." % roundi(Bases.rate(h) * 100.0), 13, COLOR_DIM)
	if not Bases.auto_plan.is_empty():
		_plan_row(base, Bases.auto_plan, -1)
	for i in Bases.plans.size():
		_plan_row(base, Bases.plans[i], i)
	var save := _button(_base_box, "Guardar la nave actual como plano", _on_save_plan)
	save.disabled = Bases.plans.size() >= Bases.max_plans()


func _plan_row(base: Dictionary, plan: Dictionary, index: int) -> void:
	var cost := Bases.plan_cost(plan, base)
	var title := "%s — %d piezas, vale %d créditos" % [plan["name"], plan["blueprint"].size(), int(plan["value"])]
	_text(_base_box, title, 14, COLOR_TEXT)
	var row := HFlowContainer.new()
	_base_box.add_child(row)
	var b := _button(row, "Construir (%d créditos)" % cost, _on_build_plan.bind(plan))
	b.disabled = not Bases.hangar_ready(base) or cost > GameState.money + GameState.sell_value(0)
	if index >= 0:
		_button(row, "Borrar", _on_delete_plan.bind(index))
	else:
		_text(row, "  (se guarda sola al despegar)", 12, COLOR_DIM)


func _fill_academy(base: Dictionary) -> void:
	_title(_base_box, "Candidatos", 16)
	_wrap(_base_box, "Cambian cada vez que aterrizas. Se quedan en la base, en reserva: súbelos a la nave o asígnalos a un edificio.", 13, COLOR_DIM)
	for i in Bases.academy_candidates.size():
		var c := Bases.academy_candidates[i]
		var best := GameState.best_stat(c)
		_text(_base_box, "%s (%s) — %s %d" % [c["name"], c["personality"], GameState.CREW_STAT_NAMES[best], c[best]], 15, COLOR_TEXT)
		_wrap(_base_box, _stats_line(c), 13, COLOR_DIM)
		var b := _small_button(_base_box, "Contratar (%d créditos)" % c["price"], _on_hire_academy.bind(i))
		b.disabled = c["price"] > GameState.money
	_separator(_base_box)
	var slots := Bases.training_slots(base)
	_title(_base_box, "Entrenamiento (%d/%d plazas)" % [Bases.trainees(base["body"]), slots], 16)
	_wrap(_base_box, "+%d a una estadística en %d minutos. Cuesta %d créditos por cada punto que ya tiene." % [
		Bases.TRAINING_POINTS, int(Bases.TRAINING_SECONDS / 60.0), Bases.TRAINING_COST_PER_POINT], 13, COLOR_DIM)
	var any := false
	for i in Bases.members_at(base["body"]):
		var m := Bases.crew[i]
		if m["training"] != "":
			any = true
			_text(_base_box, "%s entrena %s (faltan %s)" % [m["name"], GameState.CREW_STAT_NAMES[m["training"]].to_lower(),
					_clock(m["train_left"])], 14, COLOR_GOOD)
			continue
		if not Bases.is_available(i):
			continue
		any = true
		var row := HBoxContainer.new()
		_base_box.add_child(row)
		_text(row, "%s  " % m["name"], 14, COLOR_TEXT)
		var opt := OptionButton.new()
		for s in GameState.CREW_STATS:
			opt.add_item("%s %d (%d créditos)" % [GameState.CREW_STAT_NAMES[s], m[s], Bases.training_cost(i, s)])
		opt.selected = GameState.CREW_STATS.find(GameState.best_stat(m))
		opt.fit_to_longest_item = false
		opt.clip_text = true
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(opt)
		var b := _button(row, "Entrenar", func() -> void: _on_train(i, GameState.CREW_STATS[opt.selected]))
		b.disabled = Bases.trainees(base["body"]) >= slots
	if not any:
		_wrap(_base_box, "No hay tripulantes en esta base. Bájalos de la nave en la pestaña Tripulación.", 13, COLOR_DIM)


func _fill_infirmary(base: Dictionary) -> void:
	var minutes := Bases.heal_minutes(base)
	if minutes > 0.0:
		_text(_base_box, "Cada herido tarda unos %d minutos en curarse." % ceili(minutes), 14, COLOR_TEXT)
	var any := false
	for i in Bases.members_at(base["body"]):
		var m := Bases.crew[i]
		if m["wounded"]:
			any = true
	if not any:
		_text(_base_box, "No hay heridos en esta enfermería.", 14, COLOR_DIM)
		return
	_live(_base_box, func() -> String:
		var lines: Array[String] = []
		for i in Bases.members_at(base["body"]):
			var m := Bases.crew[i]
			if m["wounded"]:
				lines.append("%s: herido, %d %% curado" % [m["name"], int(m["heal"] * 100.0)])
		return "\n".join(lines))


func _fill_trade_port() -> void:
	var f := Bases.port_factor()
	_text(_base_box, "Paga la chatarra al %d %% de su precio y los minerales al 100 %%." % roundi(f * 100.0), 14, COLOR_TEXT)
	_storage_lines(_base_box)
	var scrap_value := int(Bases.stored_scrap_value() * f)
	var b := _button(_base_box, "Vender la chatarra guardada (+%d créditos)" % scrap_value, _on_sell_stored_scrap)
	b.disabled = scrap_value <= 0
	var minerals := Bases.stored_mineral_value()
	var m := _button(_base_box, "Vender los minerales (+%d créditos)" % minerals, _on_sell_minerals)
	m.disabled = minerals <= 0
	if Bases.has_anywhere(&"refinery") and scrap_value > 0:
		_wrap(_base_box, "Consejo: si esperas a que la refinería convierta la chatarra en minerales, ganas más.", 13, COLOR_DIM)


# ---------- tripulación ----------

func _fill_crew() -> void:
	_clear(_crew_box)
	var base := _base()
	_title(_crew_box, "En la nave (%d/%d plazas)" % [GameState.crew.size(), GameState.crew_capacity()], 18)
	for i in GameState.crew.size():
		var m := GameState.crew[i]
		_text(_crew_box, "%s — %s" % [m["name"], _post_name(GameState.crew_post(i))], 15, COLOR_TEXT)
		_wrap(_crew_box, _stats_line(m), 13, COLOR_DIM)
		_small_button(_crew_box, "Bajar a la base", _on_crew_down.bind(i))
	_separator(_crew_box)
	var here := Bases.members_at(base["body"])
	_title(_crew_box, "En esta base (%d)" % here.size(), 18)
	if here.is_empty():
		_wrap(_crew_box, "Nadie. Baja tripulantes de la nave o recluta en la academia.", 13, COLOR_DIM)
	for i in here:
		var m := Bases.crew[i]
		_text(_crew_box, "%s — %s" % [m["name"], _base_status(m)], 15, COLOR_TEXT)
		_wrap(_crew_box, _stats_line(m), 13, COLOR_DIM)
		var row := HBoxContainer.new()
		_crew_box.add_child(row)
		var up := _button(row, "Subir a la nave", _on_crew_up.bind(i))
		up.disabled = not Bases.is_available(i) or GameState.crew.size() >= GameState.crew_capacity()
		var d := _button(row, "Despedir", _on_dismiss_base.bind(i))
		d.add_theme_color_override(&"font_color", COLOR_WARN)
	var others := Bases.crew.size() - here.size()
	if others > 0:
		_separator(_crew_box)
		_text(_crew_box, "En tus otras bases: %d tripulantes." % others, 14, COLOR_DIM)


func _base_status(m: Dictionary) -> String:
	if m["wounded"]:
		return "herido (%d %% curado)" % int(m["heal"] * 100.0)
	if m["training"] != "":
		return "entrenando %s" % GameState.CREW_STAT_NAMES[m["training"]].to_lower()
	if m["job"] != &"":
		return "trabaja en " + Catalog.building(m["job"]).display_name
	return "en reserva"


# ---------- taller (hangar) ----------

func _fill_mechanic() -> void:
	if not Bases.hangar_ready(_base()):
		_clear(_mechanic_box)
		var text := "Construye un hangar en una parcela libre" if Bases.find_building(_base(), &"hangar").is_empty() \
				else "Asigna un tripulante ingeniero al hangar"
		_wrap(_mechanic_box, "%s para reparar, construir, mejorar o reconstruir tu nave aquí. Mientras tanto, usa una estación espacial." % text,
				15, COLOR_WARN)
		_wrap(_mechanic_box, _ship_summary(), 13, COLOR_DIM)
		return
	super()


func _parts_for_sale() -> Array[PartData]:
	var out := super()
	for d: PartData in Catalog.parts.values():
		if not d.for_sale and Bases.can_fabricate(d.id):
			out.append(d)
	return out


func _weapons_sorted() -> Array[WeaponData]:
	var out := super()
	for w: WeaponData in Catalog.weapons.values():
		if not w.for_sale and Bases.can_fabricate(w.id):
			out.append(w)
	return out


## En el hangar se fabrican los depósitos ya investigados (GDD 5.4).
func _fill_tank_row() -> void:
	var lvl := GameState.fuel_tank_level
	var row := HFlowContainer.new()
	_mechanic_box.add_child(row)
	_text(row, "%s (alcance %d min)   " % [GameState.TANK_NAMES[lvl], GameState.tank_minutes()], 14, COLOR_TEXT)
	if lvl + 1 >= GameState.TANK_PRICES.size():
		return
	if Bases.is_researched(Bases.tank_research_id(lvl + 1)):
		var price: int = GameState.TANK_PRICES[lvl + 1]
		var b := _button(row, "Fabricar %s: %d min (%d créditos)" % [GameState.TANK_NAMES[lvl + 1], 5 * (lvl + 2), price],
				_on_buy_tank.bind(lvl + 1))
		b.disabled = price > GameState.money
	else:
		_text(row, "Investiga el %s para fabricarlo aquí." % GameState.TANK_NAMES[lvl + 1], 13, COLOR_DIM)


# ---------- acciones ----------

func _on_build(type: StringName, lot: int) -> void:
	_notice = Bases.build(_base(), type, lot)
	if _notice == "":
		GameState.last_report = "Construiste: %s." % Catalog.building(type).display_name
		if type == &"fuel_charger":
			GameState.last_report += " El depósito ya está lleno: puedes despegar."
	GameState.save_game()
	refresh()


func _on_upgrade_building(b: Dictionary) -> void:
	Bases.upgrade(b)
	refresh()


func _on_assign(choice: Array, type: StringName) -> void:
	var i: int = choice[1]
	if choice[0] == "ship":
		i = Bases.move_to_base(i)
	_notice = Bases.assign(i, type)
	refresh()


func _on_unassign(i: int) -> void:
	Bases.unassign(i)
	refresh()


func _on_research(id: StringName) -> void:
	Bases.start_research(id)
	refresh_panels()


func _on_save_plan() -> void:
	_notice = Bases.save_plan("Plano %d" % (Bases.plans.size() + 1))
	refresh_panels()


func _on_delete_plan(i: int) -> void:
	Bases.plans.remove_at(i)
	refresh_panels()


func _on_build_plan(plan: Dictionary) -> void:
	_notice = Bases.build_plan(plan)
	if _notice == "":
		GameState.last_report = "El hangar construyó «%s»." % plan["name"]
		_editor.clear_selection()
	refresh()


func _on_hire_academy(i: int) -> void:
	_notice = Bases.hire(i)
	refresh_panels()


func _on_train(i: int, stat: String) -> void:
	_notice = Bases.start_training(i, stat)
	refresh_panels()


func _on_sell_stored_scrap() -> void:
	var n := Bases.sell_stored_scrap()
	GameState.last_report = "Vendiste la chatarra guardada por %d créditos." % n
	refresh_panels()


func _on_sell_minerals() -> void:
	var n := Bases.sell_stored_minerals()
	GameState.last_report = "Vendiste los minerales por %d créditos." % n
	refresh_panels()


func _on_crew_down(i: int) -> void:
	Bases.move_to_base(i)
	refresh()


func _on_crew_up(i: int) -> void:
	_notice = Bases.move_to_ship(i)
	refresh()


func _on_dismiss_base(i: int) -> void:
	Bases.dismiss(i)
	refresh_panels()


# ---------- pruebas automáticas ----------

## `--base-test` (con `--money=N` y `--base-speed=N`): construye la base con la misma interfaz
## que usaría el jugador, asigna tripulantes, investiga, refina y guarda capturas
## (`--station-screenshot=<png>`: la base, el edificio elegido y el hangar).
func _run_tests() -> void:
	if GameState.args.has("map-test"):
		_open_map()
		return
	# `--base-jump=<zona>`: despega una vez hacia esa zona (con `--destroy-at` se prueba perder la nave).
	if GameState.args.has("base-jump"):
		var zone := StringName(GameState.args["base-jump"])
		GameState.args.erase("base-jump")
		await get_tree().create_timer(0.5).timeout
		_on_destination(zone)
		return
	# `--rebuild-test`: reconstruye la última nave desde su plano en el hangar.
	if GameState.args.has("rebuild-test"):
		await get_tree().create_timer(0.5).timeout
		print("[base-test] report: %s" % GameState.last_report)
		await _save_screenshot("-destroyed")
		print("[base-test] auto_plan=%d parts, wounded=%d, rebuild: '%s' parts=%d money=%d" % [
			Bases.auto_plan.get("blueprint", []).size(), Bases.crew.filter(func(m: Dictionary) -> bool: return m["wounded"]).size(),
			Bases.build_plan(Bases.auto_plan) if not Bases.auto_plan.is_empty() else "sin plano",
			GameState.blueprint.size(), GameState.money])
		refresh()
		_base_view.pick(_base_view.lot_screen_position(mini(5, Bases.lot_count(_base()) - 1)))
		await _save_screenshot("-rebuilt")
		get_tree().quit()
		return
	if not GameState.args.has("base-test"):
		if GameState.args.has("station-screenshot"):
			await _save_screenshot()
			if GameState.args.has("quit-after-station"):
				get_tree().quit()
		return
	var say := func(msg: String) -> void: print("[base-test] ", msg)
	await get_tree().create_timer(0.6).timeout
	var base := _base()
	say.call("base %s lots=%d fuel_wait=%.0f money=%d" % [base["body"], Bases.lot_count(base), Bases.fuel_wait, GameState.money])
	# 1) Construir con clics en las parcelas.
	var plan: Array[StringName] = [&"fuel_charger", &"hangar", &"research_center", &"trade_port", &"refinery", &"infirmary"]
	for k in mini(plan.size(), Bases.lot_count(base)):
		_base_view.pick(_base_view.lot_screen_position(k))
		say.call("lot %d selected=%d" % [k, _base_view.selected_lot])
		_on_build(plan[k], _base_view.selected_lot)
		say.call("build %s: '%s'" % [plan[k], _notice])
	say.call("fuel_wait after charger=%.0f" % Bases.fuel_wait)
	# 2) Tripulantes: el artillero de la nave baja a investigar y se contrata en la academia… sin
	# academia: se usan candidatos del bar como si llegaran por la academia.
	for k in 2:
		var c := GameState.random_candidate("Test%d" % k)
		c["engineering"] = 60
		c["research"] = 70
		c["first_aid"] = 50
		Bases.crew.append(Bases._base_member(c, base["body"]))
	say.call("assign engineer: '%s'" % Bases.assign(0, &"hangar"))
	say.call("assign researcher: '%s'" % Bases.assign(1, &"research_center"))
	say.call("hangar_ready=%s research_rate=%.1f" % [Bases.hangar_ready(base), Bases.research_rate()])
	Bases.start_research(&"particle_cannon")
	Bases.storage[&"scrap_metal"] = 200
	Bases.storage[&"electronics"] = 30
	refresh()
	# 3) Captura de la base con el centro de investigación elegido.
	_base_view.pick(_base_view.lot_screen_position(2))
	await _save_screenshot()
	# 4) Deja correr el tiempo (con --base-speed) y revisa la producción.
	await get_tree().create_timer(3.0).timeout
	say.call("research=%s progress=%.0f researched=%s storage=%s" % [Bases.research_current, Bases.research_progress,
			str(Bases.researched), str(Bases.storage)])
	var hangar_weapons: Array[String] = []
	for w in _weapons_sorted():
		hangar_weapons.append(String(w.id))
	say.call("hangar weapons: %s" % ", ".join(hangar_weapons))
	# 5) Hangar: guarda un plano, la ventana del hangar y el taller con las piezas investigadas.
	say.call("save plan: '%s' value=%d" % [Bases.save_plan("Prueba"), Bases.plans[0]["value"] if not Bases.plans.is_empty() else -1])
	_base_view.pick(_base_view.lot_screen_position(1))
	await _save_screenshot("-hangar")
	_set_ship_view(true)
	_click_slot(0, 3)
	refresh_panels()
	await _save_screenshot("-workshop")
	_set_ship_view(false)
	# 6) Puerto comercial: vender minerales.
	_base_view.pick(_base_view.lot_screen_position(3))
	await _save_screenshot("-port")
	say.call("sell minerals: +%d" % Bases.sell_stored_minerals())
	_show_tab(CREW_TAB)
	await _save_screenshot("-crew")
	GameState.save_game()
	say.call("saved; money=%d" % GameState.money)
	if GameState.args.has("quit-after-station"):
		get_tree().quit()
