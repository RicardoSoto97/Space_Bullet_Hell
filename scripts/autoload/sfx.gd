extends Node
## Efectos de sonido (GDD 10.5): los packs de Kenney (CC0) de `assets/audio/Effects/`.
## `Sfx.play(&"enemy_death")` toca una variante al azar del sonido, con un poco de tono al azar.
## Cada sonido tiene un intervalo mínimo y un máximo de copias a la vez, para que cien
## disparos por segundo no se conviertan en ruido. También pone sonido a todos los botones.

const DIR_DIGITAL := "res://assets/audio/Effects/Audio Digital/"
const DIR_UI := "res://assets/audio/Effects/Audio interface/"
const DIR_SCIFI := "res://assets/audio/Effects/Audio sci-fi/"
const PLAYERS := 24

## nombre: [archivos, bus, volumen en dB, tono mínimo, tono máximo, intervalo mínimo (s), copias a la vez]
const SOUNDS := {
	# Armas de la nave
	&"shot_gun": [[DIR_SCIFI + "laserSmall_000", DIR_SCIFI + "laserSmall_001"], "SFX", -17.0, 0.95, 1.12, 0.07, 3],
	&"shot_flak": [[DIR_SCIFI + "laserRetro_000", DIR_SCIFI + "laserRetro_002"], "SFX", -13.0, 0.85, 1.0, 0.12, 2],
	&"shot_heavy": [[DIR_SCIFI + "laserLarge_000", DIR_SCIFI + "laserLarge_002"], "SFX", -12.0, 0.9, 1.05, 0.15, 2],
	&"rocket_launch": [[DIR_DIGITAL + "phaserDown1", DIR_DIGITAL + "phaserDown3"], "SFX", -16.0, 0.55, 0.7, 0.1, 2],
	&"rocket_blast": [[DIR_SCIFI + "explosionCrunch_000"], "SFX", -11.0, 0.95, 1.15, 0.08, 3],
	&"big_blast": [[DIR_SCIFI + "lowFrequency_explosion_001"], "SFX", -5.0, 0.9, 1.05, 0.2, 2],
	# Enemigos
	&"enemy_shot": [[DIR_DIGITAL + "phaserUp4", DIR_DIGITAL + "phaserUp5"], "SFX", -25.0, 0.8, 1.0, 0.11, 2],
	&"enemy_death": [[DIR_SCIFI + "explosionCrunch_000", DIR_SCIFI + "explosionCrunch_001"], "SFX", -13.0, 0.9, 1.25, 0.05, 5],
	&"elite_death": [[DIR_SCIFI + "lowFrequency_explosion_001"], "SFX", -6.0, 1.0, 1.15, 0.2, 2],
	&"boss_alert": [[DIR_DIGITAL + "lowThreeTone"], "SFX", -4.0, 1.0, 1.0, 0.8, 1],
	&"boss_phase": [[DIR_DIGITAL + "zapThreeToneDown"], "SFX", -6.0, 0.8, 0.8, 0.5, 1],
	&"boss_defeated": [[DIR_DIGITAL + "zapThreeToneUp"], "SFX", -5.0, 1.0, 1.0, 0.5, 1],
	&"huge_blast": [[DIR_SCIFI + "lowFrequency_explosion_000"], "SFX", -3.0, 0.95, 1.0, 0.3, 1],
	# La nave
	&"hull_hit": [[DIR_SCIFI + "impactMetal_002", DIR_SCIFI + "impactMetal_004"], "SFX", -10.0, 0.9, 1.1, 0.09, 2],
	&"shield_hit": [[DIR_SCIFI + "forceField_000", DIR_SCIFI + "forceField_002"], "SFX", -14.0, 1.0, 1.2, 0.1, 2],
	&"shield_break": [[DIR_DIGITAL + "zapTwoTone"], "SFX", -6.0, 0.8, 0.8, 0.3, 1],
	&"shield_up": [[DIR_SCIFI + "forceField_004"], "SFX", -9.0, 1.1, 1.1, 0.3, 1],
	&"part_lost": [[DIR_SCIFI + "explosionCrunch_002"], "SFX", -6.0, 0.75, 0.85, 0.2, 2],
	&"scrap": [[DIR_UI + "drop_001"], "SFX", -15.0, 1.0, 1.0, 0.04, 3],
	&"fuel_ready": [[DIR_DIGITAL + "powerUp2"], "SFX", -7.0, 1.0, 1.0, 0.5, 1],
	&"jump_charge": [[DIR_DIGITAL + "phaserUp1"], "SFX", -10.0, 0.7, 0.7, 0.3, 1],
	&"jump": [[DIR_DIGITAL + "phaseJump1"], "SFX", -5.0, 0.8, 0.8, 0.5, 1],
	&"evolve": [[DIR_DIGITAL + "powerUp3"], "UI", -6.0, 1.0, 1.0, 0.5, 1],
	&"game_over": [[DIR_DIGITAL + "lowDown"], "SFX", -6.0, 0.8, 0.8, 0.5, 1],
	# Interfaz
	&"ui_hover": [[DIR_UI + "select_001", DIR_UI + "select_002"], "UI", -20.0, 1.0, 1.08, 0.04, 2],
	&"ui_click": [[DIR_UI + "click_001"], "UI", -10.0, 0.95, 1.05, 0.04, 2],
	&"ui_confirm": [[DIR_UI + "confirmation_001"], "UI", -9.0, 1.0, 1.0, 0.1, 1],
	&"ui_error": [[DIR_UI + "error_004"], "UI", -8.0, 1.0, 1.0, 0.1, 1],
	&"ui_money": [[DIR_UI + "confirmation_002"], "UI", -8.0, 1.0, 1.0, 0.2, 1],
	&"ui_install": [[DIR_SCIFI + "impactMetal_000", DIR_SCIFI + "impactMetal_003"], "UI", -11.0, 1.1, 1.25, 0.1, 1],
	&"ui_tab": [[DIR_UI + "toggle_002"], "UI", -12.0, 1.0, 1.0, 0.05, 1],
	&"ui_open": [[DIR_UI + "maximize_003"], "UI", -10.0, 1.0, 1.0, 0.1, 1],
	&"ui_close": [[DIR_UI + "minimize_003"], "UI", -10.0, 1.0, 1.0, 0.1, 1],
	&"ui_back": [[DIR_UI + "back_001"], "UI", -10.0, 1.0, 1.0, 0.05, 1],
	&"station_arrive": [[DIR_SCIFI + "doorOpen_000"], "UI", -8.0, 0.9, 0.9, 0.5, 1],
}

var _streams: Dictionary[StringName, Array] = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_played: Dictionary[StringName, int] = {}
## Racha de chatarra recogida: cada trozo seguido suena un poco más agudo.
var _scrap_streak: int = 0
var _scrap_last: int = 0
## Sonido continuo del rayo láser: suena mientras algún rayo esté encendido.
var _beam_player: AudioStreamPlayer
var _beam_ms: int = -100000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id: StringName in SOUNDS:
		var list: Array[AudioStream] = []
		for path: String in SOUNDS[id][0]:
			var s := load(path + ".ogg") as AudioStream
			if s:
				list.append(s)
		_streams[id] = list
	for i in PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_beam_player = AudioStreamPlayer.new()
	var beam := (load(DIR_SCIFI + "forceField_001.ogg") as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	beam.loop = true
	_beam_player.stream = beam
	_beam_player.bus = &"SFX"
	_beam_player.volume_db = -22.0
	add_child(_beam_player)
	get_tree().node_added.connect(_on_node_added)


func _process(_delta: float) -> void:
	# El rayo avisa cada fotograma con `beam_on()`; si deja de avisar, se apaga.
	var on := Time.get_ticks_msec() - _beam_ms < 90 and not get_tree().paused
	if on and not _beam_player.playing:
		_beam_player.play()
	elif not on and _beam_player.playing:
		_beam_player.stop()


## Toca un sonido. `volume` suma decibelios (por ejemplo, para un enemigo de élite).
func play(id: StringName, volume: float = 0.0, pitch: float = 1.0) -> void:
	var def: Array = SOUNDS.get(id, [])
	var list: Array = _streams.get(id, [])
	if def.is_empty() or list.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_played.get(id, -100000) < int(def[5] * 1000.0):
		return
	var playing := 0
	for p in _players:
		if p.playing and p.get_meta(&"id", &"") == id:
			playing += 1
	if playing >= int(def[6]):
		return
	_last_played[id] = now
	var player := _free_player()
	player.stream = list[randi() % list.size()]
	player.bus = StringName(def[1])
	player.volume_db = float(def[2]) + volume
	player.pitch_scale = randf_range(def[3], def[4]) * pitch
	player.set_meta(&"id", id)
	player.play()


## Chatarra recogida: suena más aguda en una racha, como monedas.
func play_scrap() -> void:
	var now := Time.get_ticks_msec()
	_scrap_streak = _scrap_streak + 1 if now - _scrap_last < 600 else 0
	_scrap_last = now
	play(&"scrap", 0.0, 1.0 + 0.04 * float(mini(_scrap_streak, 15)))


func beam_on() -> void:
	_beam_ms = Time.get_ticks_msec()


func _free_player() -> AudioStreamPlayer:
	for i in _players.size():
		var p := _players[(_next + i) % _players.size()]
		if not p.playing:
			_next = (_next + i + 1) % _players.size()
			return p
	# Todos ocupados: se reutiliza el más antiguo.
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	return p


## Todos los botones suenan al pasar por encima (o al elegirlos con el mando) y al pulsarlos.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var b := node as BaseButton
		b.mouse_entered.connect(func() -> void:
			if not b.disabled:
				play(&"ui_hover"))
		b.focus_entered.connect(func() -> void:
			if Settings.using_gamepad:
				play(&"ui_hover"))
		b.pressed.connect(func() -> void: play(&"ui_click"))
	elif node is TabContainer:
		(node as TabContainer).tab_changed.connect(func(_t: int) -> void: play(&"ui_tab"))
