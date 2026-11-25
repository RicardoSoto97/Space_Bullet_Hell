extends Control
## Pantalla de inicio: «Continuar» (si hay partida guardada), «Nueva partida», «Opciones» y «Salir».
## Las pruebas automáticas se la saltan: `-- --start-stage` va directo a un nivel y las
## pruebas de la estación empiezan una partida nueva.

const STAR_SHADER := preload("res://scripts/stage/star_background.gdshader")
const TEST_ARGS: Array[String] = ["build-test", "auto-station", "station-screenshot", "auto-jump", "map-test", "pad-test"]

var _confirm: ConfirmationDialog


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.args.has("start-stage"):
		GameState.go_to_stage()
		return
	if GameState.args.has("continue") and GameState.load_game():
		GameState.go_to_station()
		return
	# Pruebas de la base: `--base-test [--base-body=<id>]` compra el terreno y aterriza allí.
	if GameState.args.has("base-test"):
		var body := StringName(GameState.args.get("base-body", "velora_odo"))
		GameState.add_money(Catalog.body(body).land_price)
		print("[base-test] buy land: '%s'" % Bases.buy_land(body))
		GameState.travel_to(body)
		return
	for a in TEST_ARGS:
		if GameState.args.has(a):
			GameState.go_to_station()
			return
	_build_ui()
	if GameState.args.has("menu-screenshot"):
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(GameState.args["menu-screenshot"])
		get_tree().quit()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = STAR_SHADER
	bg.material = mat
	add_child(bg)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	box.add_to_group(&"gamepad_menu")
	add_child(box)
	StageHud._place(box, Control.PRESET_CENTER, Rect2(-220, -220, 440, 440))

	var title := Label.new()
	title.text = "Bullet Hell Survivor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 46)
	title.add_theme_color_override(&"font_color", Color(0.95, 0.97, 1.0))
	title.add_theme_color_override(&"font_outline_color", Color(0.1, 0.3, 0.6))
	title.add_theme_constant_override(&"outline_size", 8)
	box.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	box.add_child(gap)

	var has_save := GameState.has_save()
	var cont := _menu_button(box, "Continuar", _on_continue)
	cont.disabled = not has_save
	if has_save:
		cont.grab_focus.call_deferred()
	var new_b := _menu_button(box, "Nueva partida", _on_new_game)
	if not has_save:
		new_b.grab_focus.call_deferred()
	_menu_button(box, "Opciones", _open_options)
	_menu_button(box, "Salir", func() -> void: get_tree().quit())

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Nueva partida"
	_confirm.dialog_text = "Ya tienes una partida guardada.\nSi empiezas una nueva, se borrará. ¿Seguir?"
	_confirm.ok_button_text = "Empezar de nuevo"
	_confirm.cancel_button_text = "Cancelar"
	_confirm.confirmed.connect(_start_new_game)
	_confirm.add_to_group(&"gamepad_menu")
	add_child(_confirm)


func _menu_button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override(&"font_size", 22)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _open_options() -> void:
	var options := OptionsMenu.new()
	var focused := get_viewport().gui_get_focus_owner()
	options.closed.connect(func() -> void:
		if is_instance_valid(focused):
			focused.grab_focus())
	add_child(options)


func _on_continue() -> void:
	if GameState.load_game():
		GameState.go_to_station()


func _on_new_game() -> void:
	if GameState.has_save():
		_confirm.popup_centered()
		_confirm.get_cancel_button().grab_focus.call_deferred()
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameState.new_game()
	GameState.go_to_station()
