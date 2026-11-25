class_name StageHud
extends CanvasLayer
## Interfaz del nivel: carga del combustible interestelar, casco, chatarra y estado de la nave.
## También el menú de pausa, la pantalla de nave destruida y los avisos de daño (GDD 10.4 y 10.6).

const VIGNETTE_SHADER := preload("res://scripts/stage/damage_vignette.gdshader")
const LOW_HULL := 0.3

var stage: Stage
var _fuel_bar: ProgressBar
var _fuel_label: Label
var _hull_bar: ProgressBar
## Escudo (solo con generador de escudo).
var _shield_box: VBoxContainer
var _shield_bar: ProgressBar
var _scrap_label: Label
var _kills_label: Label
var _status_view: ShipStatusView
var _center_label: Label
var _zone_label: Label
var _alert: VBoxContainer
var _alert_title: Label
var _alert_sub: Label
var _alert_left: float = 0.0
var _boss_box: VBoxContainer
var _boss_label: Label
var _boss_bar: ProgressBar
var _boss: Boss
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
## Intensidad del parpadeo rojo al recibir daño (baja sola).
var _hurt: float = 0.0
var _flash: ColorRect
var _pause_menu: Control
var _game_over: Control
var _game_over_text: Label
var _respawn_button: Button
var _confirm_exit: ConfirmationDialog
var _options: OptionsMenu
var _was_fuel_ready: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Combustible interestelar (arriba, al centro)
	var top := VBoxContainer.new()
	root.add_child(top)
	_place(top, Control.PRESET_CENTER_TOP, Rect2(-330, 12, 660, 0))
	_fuel_label = _label(top, "", 18, HORIZONTAL_ALIGNMENT_CENTER)
	_fuel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fuel_bar = _bar(top, Color(0.15, 0.8, 1.0))

	# Casco y chatarra (arriba, a la izquierda)
	var left := VBoxContainer.new()
	left.position = Vector2(16, 12)
	left.custom_minimum_size = Vector2(260, 0)
	root.add_child(left)
	_label(left, "Integridad del casco", 14)
	_hull_bar = _bar(left, Color(0.3, 0.95, 0.5))
	_shield_box = VBoxContainer.new()
	_shield_box.add_theme_constant_override(&"separation", 0)
	left.add_child(_shield_box)
	_label(_shield_box, "Escudo", 14)
	_shield_bar = _bar(_shield_box, Color(0.35, 0.85, 1.0))
	_shield_box.visible = false
	_zone_label = _label(left, "", 14)
	_scrap_label = _label(left, "", 16)
	_kills_label = _label(left, "", 14)

	# Miniatura de la nave (abajo, a la izquierda)
	var panel := PanelContainer.new()
	root.add_child(panel)
	_place(panel, Control.PRESET_BOTTOM_LEFT, Rect2(16, -176, 150, 160))
	_status_view = ShipStatusView.new()
	_status_view.custom_minimum_size = Vector2(150, 160)
	panel.add_child(_status_view)

	# Jefe: nombre y barra de vida (arriba, debajo del combustible)
	_boss_box = VBoxContainer.new()
	root.add_child(_boss_box)
	_place(_boss_box, Control.PRESET_CENTER_TOP, Rect2(-320, 100, 640, 0))
	_boss_label = _label(_boss_box, "", 18, HORIZONTAL_ALIGNMENT_CENTER)
	_boss_label.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.4))
	_boss_bar = _bar(_boss_box, Color(0.95, 0.15, 0.2))
	_boss_bar.custom_minimum_size = Vector2(0, 18)
	_boss_box.visible = false

	# Alerta de peligro en el centro de la pantalla
	_alert = VBoxContainer.new()
	root.add_child(_alert)
	_place(_alert, Control.PRESET_CENTER, Rect2(-500, -120, 1000, 140))
	_alert_title = _label(_alert, "", 54, HORIZONTAL_ALIGNMENT_CENTER)
	_alert_title.add_theme_color_override(&"font_color", Color(1.0, 0.2, 0.2))
	_alert_title.add_theme_constant_override(&"outline_size", 10)
	_alert_sub = _label(_alert, "", 24, HORIZONTAL_ALIGNMENT_CENTER)
	_alert_sub.add_theme_color_override(&"font_color", Color(1.0, 0.75, 0.6))
	_alert.visible = false

	# Borde rojo al recibir daño o con el casco bajo
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = VIGNETTE_SHADER
	_vignette.material = _vignette_mat
	root.add_child(_vignette)
	root.move_child(_vignette, 0)

	# Destello blanco al saltar
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0.85, 0.95, 1.0, 0.0)
	root.add_child(_flash)

	# Mensajes en el centro
	_center_label = _label(root, "", 30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_center_label, Control.PRESET_CENTER, Rect2(-450, -170, 900, 120))
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_build_pause_menu()
	_build_game_over()
	stage.ship.damaged.connect(func() -> void: _hurt = minf(_hurt + 0.45, 0.8))


func _overlay() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	dim.add_to_group(&"gamepad_menu")
	add_child(dim)
	return dim


func _menu_box(parent: Control, title: String) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override(&"panel", OptionsMenu.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)
	var t := _label(box, title, 34, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override(&"font_color", Color(0.95, 0.97, 1.0))
	return box


func _menu_button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override(&"font_size", 20)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _build_pause_menu() -> void:
	_pause_menu = _overlay()
	var box := _menu_box(_pause_menu, "Pausa")
	_menu_button(box, "Continuar", set_paused.bind(false))
	_menu_button(box, "Opciones", _open_options)
	_menu_button(box, "Salir al menú", func() -> void:
		_confirm_exit.popup_centered()
		_confirm_exit.get_cancel_button().grab_focus.call_deferred())
	_confirm_exit = ConfirmationDialog.new()
	_confirm_exit.title = "Salir al menú"
	_confirm_exit.dialog_text = "Saldrás sin guardar: pierdes lo de este nivel (la chatarra que juntaste).\nTu partida queda como estaba al llegar a la última estación."
	_confirm_exit.ok_button_text = "Salir"
	_confirm_exit.cancel_button_text = "Seguir jugando"
	_confirm_exit.process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_exit.add_to_group(&"gamepad_menu")
	_confirm_exit.confirmed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file.call_deferred(GameState.MENU_SCENE))
	add_child(_confirm_exit)


func _build_game_over() -> void:
	_game_over = _overlay()
	var box := _menu_box(_game_over, "Tu nave fue destruida")
	box.get_child(0).add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.4))
	_game_over_text = _label(box, "", 18, HORIZONTAL_ALIGNMENT_CENTER)
	_game_over_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over_text.add_theme_color_override(&"font_color", Color(0.85, 0.9, 1.0))
	_respawn_button = _menu_button(box, "Reaparecer en la estación más cercana", func() -> void:
		_respawn_button.disabled = true
		stage.respawn())


func set_paused(paused: bool) -> void:
	if paused == get_tree().paused and _pause_menu.visible == paused:
		return
	get_tree().paused = paused
	_pause_menu.visible = paused
	Sfx.play(&"ui_open" if paused else &"ui_close")
	if paused:
		_pause_menu.get_child(0).get_child(0).get_child(0).get_child(1).grab_focus.call_deferred()


func _open_options() -> void:
	_options = OptionsMenu.new()
	_options.closed.connect(func() -> void:
		_options = null
		_pause_menu.get_child(0).get_child(0).get_child(0).get_child(2).grab_focus.call_deferred())
	add_child(_options)


## La nave se destruyó: el resumen y el botón para reaparecer (GDD 7.4).
func show_game_over(scrap_value: int) -> void:
	_center_label.text = ""
	var sys := Catalog.system_of(GameState.location)
	var station := sys.stations[0].display_name if sys and not sys.stations.is_empty() else "la estación"
	var lost := "Perdiste la chatarra sin vender (valía %d créditos)." % scrap_value if scrap_value > 0 \
			else "No llevabas chatarra sin vender."
	_game_over_text.text = "Conservas tus %s créditos. %s\nReaparecerás en %s." % [Station.thousands(GameState.money), lost, station]
	_game_over.visible = true
	_respawn_button.grab_focus.call_deferred()
	Sfx.play(&"game_over")


## Destello al saltar con el motor interestelar.
## Pruebas: `--ui-test=<carpeta>` guarda capturas del menú de pausa y de las opciones.
func ui_test(folder: String) -> void:
	set_paused(true)
	await get_tree().create_timer(0.4).timeout
	await _shot(folder + "/pause.png")
	_open_options()
	await get_tree().create_timer(0.4).timeout
	await _shot(folder + "/options.png")
	var scroll := _options.get_child(0).get_child(0).get_child(0).get_child(1) as ScrollContainer
	scroll.scroll_vertical = 2000
	await get_tree().create_timer(0.3).timeout
	await _shot(folder + "/options_controls.png")
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("ui shot: ", path)


func jump_flash() -> void:
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.75, 0.45).set_ease(Tween.EASE_IN)
	t.tween_property(_flash, "color:a", 0.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if stage == null or stage.is_ending() or stage.star_map != null or _options != null:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		set_paused(not get_tree().paused)
	elif event.is_action_pressed(&"ui_cancel") and _pause_menu.visible:
		get_viewport().set_input_as_handled()
		set_paused(false)


## Ancla un control y fija su rectángulo relativo al punto de anclaje.
static func _place(c: Control, preset: Control.LayoutPreset, r: Rect2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


func _label(parent: Control, text: String, font_size: int,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.add_theme_constant_override(&"outline_size", 4)
	parent.add_child(l)
	return l


func _bar(parent: Control, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, 14)
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	b.add_theme_stylebox_override(&"fill", fill)
	b.add_theme_stylebox_override(&"background", bg)
	parent.add_child(b)
	return b


## La tecla o el botón de una acción, como lo eligió el jugador.
func _key(action: StringName) -> String:
	return Settings.control_name(action).to_upper() if not Settings.using_gamepad else Settings.control_name(action)


## Borde rojo: un golpe lo enciende y se apaga solo; con el casco bajo, late despacio.
func _update_warnings(delta: float) -> void:
	if not get_tree().paused:
		_hurt = maxf(_hurt - delta * 1.6, 0.0)
	var low := 0.0
	var core := stage.ship.core_part
	if core and not stage.ship.is_dead and core.hp() / core.max_hp() < LOW_HULL:
		low = 0.22 + 0.14 * sin(stage.time * 4.0)
	_vignette_mat.set_shader_parameter(&"intensity", maxf(_hurt, low))


func refresh_ship() -> void:
	_status_view.refresh()


func show_message(text: String) -> void:
	_center_label.text = text


## Alerta grande y parpadeante en el centro (por ejemplo, «¡PELIGRO INMINENTE!»).
func show_alert(title: String, subtitle: String, seconds: float) -> void:
	_alert_title.text = title
	_alert_sub.text = subtitle
	_alert_left = seconds
	_alert.visible = true


func show_boss(b: Boss) -> void:
	_boss = b
	_boss_label.text = b.boss_name
	_boss_box.visible = true


func _process(delta: float) -> void:
	if stage == null:
		return
	if _alert_left > 0.0 and not get_tree().paused:
		_alert_left -= delta
		_alert.modulate.a = 0.55 + 0.45 * absf(sin(_alert_left * 6.0))
		_alert.visible = _alert_left > 0.0
	if _boss_box.visible:
		if is_instance_valid(_boss) and _boss.hp > 0.0:
			_boss_bar.value = 100.0 * _boss.hp / _boss.max_hp
			_boss_label.text = "%s · fase %d" % [_boss.boss_name, _boss.phase]
		else:
			_boss_box.visible = false
	_update_warnings(delta)
	if stage.fuel_ready and not _was_fuel_ready:
		_was_fuel_ready = true
		Sfx.play(&"fuel_ready")
		var pulse := create_tween()
		pulse.tween_property(_fuel_bar, "modulate", Color(2.2, 2.2, 2.2), 0.15)
		pulse.tween_property(_fuel_bar, "modulate", Color.WHITE, 0.6)
	var left := maxf(stage.duration - stage.time, 0.0)
	_fuel_bar.value = 100.0 * clampf(stage.time / stage.duration, 0.0, 1.0)
	if stage.fuel_ready and stage.jump_hold > 0.0 and not stage.is_ending():
		_fuel_bar.value = 100.0 * clampf(stage.jump_hold / stage.jump_hold_needed(), 0.0, 1.0)
		_fuel_label.text = "Huyendo del jefe…" if stage.boss_pending else "Preparando el salto…"
	elif stage.fuel_ready and stage.boss_pending:
		var how := "elige destino (%s) y mantén" % _key(&"star_map") if stage.destination == &"" else "mantén"
		_fuel_label.text = "Derrota al jefe para saltar, o %s %s %d s para huir sin recompensa" % [
			how, _key(&"jump"), int(stage.jump_hold_needed())]
		_fuel_label.add_theme_color_override(&"font_color", Color(1.0, 0.6, 0.45))
	elif stage.fuel_ready and stage.destination == &"":
		_fuel_label.text = "Combustible recargado: pulsa %s para elegir el destino del salto" % _key(&"star_map")
		_fuel_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.6))
	elif stage.fuel_ready:
		_fuel_label.text = "Destino: %s — mantén %s para saltar (%s para cambiarlo)" % [
			Catalog.place_name(stage.destination), _key(&"jump"), _key(&"star_map")]
		_fuel_label.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.6))
	else:
		_fuel_label.text = "Recargando combustible interestelar  %d:%02d" % [int(left) / 60, int(left) % 60]
	var core := stage.ship.core_part
	if core:
		_hull_bar.value = 100.0 * core.hp() / core.max_hp()
		# Con el casco bajo, la barra parpadea.
		_hull_bar.modulate = Color.WHITE if _hull_bar.value > LOW_HULL * 100.0 \
				else Color(1.0, 0.5 + 0.5 * absf(sin(stage.time * 5.0)), 0.5 + 0.5 * absf(sin(stage.time * 5.0)))
	var ship := stage.ship
	_shield_box.visible = ship.shield_max > 0.0
	if _shield_box.visible:
		_shield_bar.value = 100.0 * ship.shield / ship.shield_max
		# Roto: la barra queda tenue hasta que se vuelve a encender.
		_shield_bar.modulate = Color.WHITE if ship.shield > 0.0 else Color(1, 1, 1, 0.35)
	var units := 0
	for n: int in GameState.scrap.values():
		units += n
	_scrap_label.text = "Chatarra: %d (vale %d créditos)" % [units, GameState.scrap_value()]
	_kills_label.text = "Enemigos destruidos: %d" % stage.kills
	if stage.zone:
		_zone_label.text = "%s · dificultad %d de 6" % [stage.zone.display_name, stage.difficulty]
