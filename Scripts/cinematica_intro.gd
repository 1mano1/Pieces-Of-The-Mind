extends Node

# ── Nodos de la escena principal ──
@onready var jugador       = $"../Jugador"
var barra_tareas: Node = null

# ── Nodos UI dentro del jugador ──
@onready var canvas        = $"../Jugador/CanvasLayer"
@onready var color_rect    = $"../Jugador/CanvasLayer/ColorRect"
@onready var blur_rect     = $"../Jugador/CanvasLayer/BlurRect"
@onready var parpado       = $"../Jugador/CanvasLayer/ParpadeoShader"
@onready var dialogo_label = $"../Jugador/CanvasLayer/DialogoLabel"
@onready var wasd_panel    = $"../Jugador/CanvasLayer/WASDPanel"

# ── Audio respiracion (ya existia) ──
@onready var audio_player  = $"../Jugador/AudioRespiracion"

# ── Audio de intro (musica/ambiente al despertar) ──
# Agrega un nodo AudioStreamPlayer en el Jugador llamado "AudioIntro"
# y asignale tu archivo de audio. Si no existe, simplemente no suena.
var audio_intro: Node = null

# POSICION DE LA CAMA
const POS_CAMA = Vector3(5.44, 0.91, 0.58)

var _tw: Tween
var _skip_requested := false
var _cinematica_finalizada := false

func _buscar_barra_tareas() -> void:
	var root = get_parent()
	if root == null:
		return
	for nombre in ["BarraTarea", "BarraTareas", "Barra_Tarea", "barra_tarea", "barra_tareas"]:
		var n = root.get_node_or_null(nombre)
		if n != null:
			barra_tareas = n
			return
	barra_tareas = get_tree().get_first_node_in_group("barra_tareas")

func _ready():
	_skip_requested = false
	_cinematica_finalizada = false

	# Buscar audio de intro
	audio_intro = jugador.get_node_or_null("AudioIntro")
	_buscar_barra_tareas()

	if GameState.saltar_intro_una_vez:
		GameState.saltar_intro_una_vez = false
		_aplicar_estado_sin_intro()
		return

	GameState.intro_terminada = false
	if not GameState.transicion_desde_cocina:
		GameState.tarea_hija_completa = false

	if jugador.has_signal("cinematic_skip_requested") and not jugador.cinematic_skip_requested.is_connected(_on_jugador_cinematic_skip_requested):
		jugador.cinematic_skip_requested.connect(_on_jugador_cinematic_skip_requested)

	if barra_tareas == null:
		push_warning("cinematica_intro: No se encontro BarraTarea.")

	jugador.iniciar_cinematica()
	jugador.global_position = POS_CAMA
	jugador.velocity        = Vector3.ZERO

	color_rect.color         = Color(0, 0, 0, 1)
	color_rect.visible       = true
	blur_rect.color          = Color(0.55, 0.55, 0.55, 0.65)
	blur_rect.visible        = true
	parpado.material.set_shader_parameter("apertura", 0.0)
	parpado.visible          = true
	dialogo_label.visible    = false
	dialogo_label.modulate.a = 0.0
	wasd_panel.visible       = false
	wasd_panel.modulate.a    = 0.0

	# Audio de respiracion
	if audio_player.stream != null:
		audio_player.play()
	# Audio de intro (musica ambiente al despertar)
	_play_audio(audio_intro)

	await get_tree().process_frame
	color_rect.visible = false
	await _secuencia()

func _aplicar_estado_sin_intro() -> void:
	if audio_player.stream != null:
		audio_player.stop()
		audio_player.volume_db = 0.0
	if audio_intro != null and audio_intro.has_method("stop"):
		audio_intro.stop()
		audio_intro.volume_db = 0.0

	color_rect.visible = false
	blur_rect.visible = false
	parpado.visible = false
	dialogo_label.visible = false
	wasd_panel.visible = false
	dialogo_label.modulate.a = 0.0
	wasd_panel.modulate.a = 0.0

	jugador.velocity = Vector3.ZERO
	jugador.activar_control()

	GameState.intro_terminada = true

func _secuencia():
	await _parpadear(0.10, 1.6, 0.18)
	if _check_skip():
		return
	await _esperar(0.35)
	if _check_skip():
		return
	await _parpadear(0.10, 2.0, 0.48)
	if _check_skip():
		return
	await _esperar(0.45)
	if _check_skip():
		return
	await _parpadear(0.10, 2.8, 1.0)
	if _check_skip():
		return

	await _quitar_blur(1.2)
	if _check_skip():
		return

	await _dialogo("...Me siento como si estuviera muerto.", 3.5)
	if _check_skip():
		return
	await _mirar_lados()
	if _check_skip():
		return
	await _levantarse()
	if _check_skip():
		return
	await _dialogo("Ire a ver si mi hija ya se levanto.", 3.2)
	if _check_skip():
		return

	# Apagar respiracion
	if audio_player.stream != null:
		_tw = create_tween()
		_tw.tween_property(audio_player, "volume_db", -40.0, 1.5)
		await _tw.finished
		audio_player.stop()
		audio_player.volume_db = 0.0
	# Apagar audio intro
	_fade_out_audio(audio_intro, 2.0)
	if _check_skip():
		return

	parpado.visible = false
	await _mostrar_wasd()
	if _check_skip():
		return

	terminar_cinematica()

func _on_jugador_cinematic_skip_requested() -> void:
	_skip_requested = true
	if _tw != null:
		_tw.kill()
	terminar_cinematica()

func _check_skip() -> bool:
	if _skip_requested:
		terminar_cinematica()
		return true
	return false

func terminar_cinematica() -> void:
	if _cinematica_finalizada:
		return
	_cinematica_finalizada = true
	_skip_requested = true

	if audio_player.stream != null:
		audio_player.stop()
		audio_player.volume_db = 0.0
	if audio_intro != null and audio_intro.has_method("stop"):
		audio_intro.stop()
		audio_intro.volume_db = 0.0

	parpado.visible = false
	blur_rect.visible = false
	color_rect.visible = false
	dialogo_label.visible = false
	wasd_panel.visible = false

	jugador.velocity = Vector3.ZERO
	jugador.terminar_cinematica()
	GameState.intro_terminada = true

	if barra_tareas != null:
		barra_tareas.deslizar_entrar()
	else:
		push_error("cinematica_intro: barra_tareas es null al final.")

# ─── Helpers ────────────────────────────────────────────────────────────────────

func _play_audio(player: Node) -> void:
	if player == null:
		return
	if player.has_method("play"):
		if player.get("stream") != null:
			player.play()

func _fade_out_audio(player: Node, dur: float) -> void:
	if player == null:
		return
	if not player.has_method("play"):
		return
	var tw = create_tween()
	tw.tween_property(player, "volume_db", -40.0, dur)
	await tw.finished
	if player.has_method("stop"):
		player.stop()
	player.volume_db = 0.0

func _parpadear(t_cierre: float, t_apertura: float, max_ap: float) -> void:
	if _skip_requested:
		return
	var actual = parpado.material.get_shader_parameter("apertura")
	_tw = create_tween().set_trans(Tween.TRANS_SINE)
	_tw.tween_method(func(v): parpado.material.set_shader_parameter("apertura", v),
		actual, 0.0, t_cierre)
	await _tw.finished
	if _skip_requested:
		return
	await _esperar(0.18)
	if _skip_requested:
		return
	_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.tween_method(func(v): parpado.material.set_shader_parameter("apertura", v),
		0.0, max_ap, t_apertura)
	await _tw.finished

func _quitar_blur(dur: float) -> void:
	if _skip_requested:
		return
	_tw = create_tween().set_trans(Tween.TRANS_SINE)
	_tw.tween_property(blur_rect, "color", Color(0.55, 0.55, 0.55, 0.0), dur)
	await _tw.finished
	blur_rect.visible = false

func _dialogo(texto: String, dur: float) -> void:
	var lineas_dialogo: Array[String] = [texto]
	await jugador.reproducir_dialogo(lineas_dialogo, 60.0, dur)

func _mirar_lados() -> void:
	if _skip_requested:
		return
	var head = jugador.get_node("Head")
	var ry   = head.rotation.y
	_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(head, "rotation:y", deg_to_rad(28),  0.9)
	_tw.tween_property(head, "rotation:y", deg_to_rad(-28), 1.2)
	_tw.tween_property(head, "rotation:y", ry, 0.7)
	await _tw.finished

func _levantarse() -> void:
	if _skip_requested:
		return
	var head = jugador.get_node("Head")
	var p0   = jugador.position
	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(jugador, "position", p0 + Vector3(0, 0.3, 0), 1.3)
	_tw.parallel().tween_property(head, "rotation:x", deg_to_rad(-8), 1.3)
	await _tw.finished
	await _esperar(0.6)
	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(jugador, "position", p0 + Vector3(0, 0.65, 0), 1.1)
	_tw.parallel().tween_property(head, "rotation:x", 0.0, 1.1)
	await _tw.finished

func _mostrar_wasd() -> void:
	if _skip_requested:
		return
	wasd_panel.visible = true
	_tw = create_tween()
	_tw.tween_property(wasd_panel, "modulate:a", 1.0, 0.8)
	await _tw.finished
	var ok = false
	while not ok and not _skip_requested:
		await get_tree().process_frame
		if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down") or
			Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right") or
			Input.is_action_just_pressed("ui_accept")):
			ok = true
	if _skip_requested:
		wasd_panel.visible = false
		return
	_tw = create_tween()
	_tw.tween_property(wasd_panel, "modulate:a", 0.0, 0.5)
	await _tw.finished
	wasd_panel.visible = false

func _esperar(seg: float) -> void:
	var transcurrido := 0.0
	while transcurrido < seg and not _skip_requested:
		await get_tree().process_frame
		transcurrido += get_process_delta_time()
