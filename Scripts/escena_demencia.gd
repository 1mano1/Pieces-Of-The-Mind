extends Node

# ── Exporta en el Inspector ──
@export var jugador_path: NodePath
@export var nodo_hija_path: NodePath
@export var nodo_hija2_path: NodePath
@export var animacion_hija_player_path: NodePath
@export var animacion_hija_nombre: StringName = &""
@export var audio_demencia_path: NodePath
@export_file("*.tscn") var escena_bosque_path: String = "res://Escenas/nivel_bosque.tscn"
@export var spawn_bosque_pos: Vector3 = Vector3(0.0, 1.2, 0.0)
@export_range(-180.0, 180.0, 1.0) var spawn_bosque_rot_y_deg: float = 0.0
@export_range(0.2, 2.0, 0.05) var fade_transicion_segundos: float = 0.8
@export_range(200.0, 900.0, 10.0) var ancho_barra_carga: float = 420.0
@export_range(12.0, 72.0, 1.0) var alto_barra_carga: float = 22.0
@export_range(0.25, 2.0, 0.05) var escala_tiempos: float = 0.5
@export_range(0.4, 2.5, 0.05) var distancia_hija_cara: float = 1.2
@export_range(1.0, 20.0, 0.5) var velocidad_mirada_hija: float = 8.0

# ── Resueltos en _ready ──
var jugador: CharacterBody3D
var head: Node3D
var parpado: ColorRect
var demencia_rect: ColorRect
var dialogo_label: Label
var nodo_hija: Node3D = null
var animacion_hija_player: AnimationPlayer = null
var audio_demencia: Node = null
var _hija_transform_inicial: Transform3D = Transform3D.IDENTITY
var _hija_visible_inicial: bool = false
var _hija_inicial_capturada: bool = false

var _activado    := false
var _agitando    := false
var _t_agitacion := 0.0
var _t_shader    := 0.0
var _skip_requested := false
var _demencia_finalizada := false
var _hija_mirando_jugador := false
var _busqueda_hija_realizada := false
var _transicion_iniciada := false

func _ready():
	jugador       = get_node(jugador_path)
	head          = jugador.get_node("Head")
	var canvas    = jugador.get_node("CanvasLayer")
	parpado       = canvas.get_node("ParpadeoShader")
	demencia_rect = canvas.get_node("DemenciaRect")
	dialogo_label = canvas.get_node("DialogoLabel")

	_resolver_nodo_hija(true)
	_resolver_animacion_hija()
	if nodo_hija != null:
		_hija_transform_inicial = nodo_hija.global_transform
		_hija_visible_inicial = false
		_hija_inicial_capturada = true
		nodo_hija.visible = false
		_verificar_rutas_animacion_hija()
	else:
		push_warning("escena_demencia: No se encontro nodo Hija2/Hija.")

	if audio_demencia_path and not audio_demencia_path.is_empty():
		audio_demencia = get_node_or_null(audio_demencia_path)

	demencia_rect.material.set_shader_parameter("intensidad", 0.0)
	demencia_rect.material.set_shader_parameter("tiempo", 0.0)
	demencia_rect.visible = false

	if jugador.has_signal("cinematic_skip_requested") and not jugador.cinematic_skip_requested.is_connected(_on_jugador_cinematic_skip_requested):
		jugador.cinematic_skip_requested.connect(_on_jugador_cinematic_skip_requested)

func _resolver_nodo_hija(force_rescan: bool = false) -> void:
	if not force_rescan and is_instance_valid(nodo_hija):
		return
	if not force_rescan and _busqueda_hija_realizada and nodo_hija == null:
		return

	nodo_hija = null
	if nodo_hija2_path and not nodo_hija2_path.is_empty():
		nodo_hija = get_node_or_null(nodo_hija2_path) as Node3D
	if nodo_hija == null and nodo_hija_path and not nodo_hija_path.is_empty():
		nodo_hija = get_node_or_null(nodo_hija_path) as Node3D
	if nodo_hija == null:
		nodo_hija = _buscar_hija_optimizado(get_tree().current_scene, "Hija2")
	if nodo_hija == null:
		nodo_hija = _buscar_hija_optimizado(get_tree().current_scene, "Hija")
	_busqueda_hija_realizada = true

func _buscar_hija_optimizado(nodo_actual: Node, nombre_buscado: String) -> Node3D:
	if nodo_actual == null:
		return null
	if nodo_actual.name == nombre_buscado and nodo_actual is Node3D:
		return nodo_actual as Node3D
	for hijo in nodo_actual.get_children():
		var nombre_hijo := String(hijo.name)
		# Ignorar ramas enormes para evitar el lag de 5-6 segundos
		if "Terrain" in nombre_hijo or "NavigationRegion" in nombre_hijo or "StaticBody" in nombre_hijo:
			continue
		var resultado = _buscar_hija_optimizado(hijo, nombre_buscado)
		if resultado != null:
			return resultado
	return null

func _resolver_animacion_hija() -> void:
	if animacion_hija_player_path and not animacion_hija_player_path.is_empty():
		animacion_hija_player = get_node_or_null(animacion_hija_player_path) as AnimationPlayer

	if animacion_hija_player == null and nodo_hija != null:
		# Solo buscar localmente dentro del modelo de la Hija, sin buscar en toda la escena
		for hijo in nodo_hija.get_children(true):
			if hijo is AnimationPlayer:
				animacion_hija_player = hijo
				break
			for subhijo in hijo.get_children(true):
				if subhijo is AnimationPlayer:
					animacion_hija_player = subhijo
					break

func _preparar_hija_para_cinematica() -> void:
	_resolver_nodo_hija()
	_resolver_animacion_hija()
	if nodo_hija == null:
		push_warning("escena_demencia: No se pudo preparar Hija2/Hija para la cinemática.")
		return

	if _hija_inicial_capturada:
		nodo_hija.global_transform = _hija_transform_inicial
	else:
		_hija_transform_inicial = nodo_hija.global_transform
		_hija_visible_inicial = nodo_hija.visible
		_hija_inicial_capturada = true

	nodo_hija.visible = false
	_hija_mirando_jugador = false
	if animacion_hija_player != null and animacion_hija_player.is_playing():
		animacion_hija_player.stop()

func _mostrar_hija_susto() -> void:
	if nodo_hija == null:
		return

	if _hija_inicial_capturada:
		nodo_hija.global_transform = _hija_transform_inicial
	nodo_hija.visible = true

	if is_instance_valid(jugador):
		var frente_jugador := -jugador.global_transform.basis.z
		frente_jugador.y = 0.0
		if frente_jugador.length_squared() < 0.0001 and is_instance_valid(head):
			frente_jugador = -head.global_transform.basis.z
			frente_jugador.y = 0.0
		if frente_jugador.length_squared() > 0.0001:
			frente_jugador = frente_jugador.normalized()
			var base_pos := head.global_position + (frente_jugador * distancia_hija_cara)
			base_pos.y = nodo_hija.global_position.y
			nodo_hija.global_position = base_pos

			var tw_susto := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw_susto.tween_property(nodo_hija, "global_position", base_pos - (frente_jugador * 0.45), _duracion(0.18))
			tw_susto.tween_property(nodo_hija, "global_position", base_pos, _duracion(0.20))

	_hija_mirando_jugador = true
	_reproducir_animacion_hija_susto()

func _reproducir_animacion_hija_susto() -> void:
	if animacion_hija_player == null:
		return

	var anim_a_reproducir: StringName = &""
	if animacion_hija_nombre != &"" and animacion_hija_player.has_animation(animacion_hija_nombre):
		anim_a_reproducir = animacion_hija_nombre
	else:
		for anim_name in animacion_hija_player.get_animation_list():
			var lower_name := String(anim_name).to_lower()
			if ("asust" in lower_name or "susto" in lower_name or "scare" in lower_name or
				"attack" in lower_name or "appear" in lower_name):
				anim_a_reproducir = anim_name
				break

	if anim_a_reproducir == &"":
		for anim_name in animacion_hija_player.get_animation_list():
			if String(anim_name).to_upper() != "RESET":
				anim_a_reproducir = anim_name
				break

	if anim_a_reproducir != &"":
		animacion_hija_player.play(anim_a_reproducir)

func _verificar_rutas_animacion_hija() -> void:
	if nodo_hija == null or animacion_hija_player == null:
		return

	var hay_track_hija := false
	var hay_track_roto := false
	for anim_name in animacion_hija_player.get_animation_list():
		var anim = animacion_hija_player.get_animation(anim_name)
		if anim == null:
			continue
		for i in anim.get_track_count():
			var ruta_track := String(anim.track_get_path(i))
			if "Hija2" in ruta_track or "Hija" in ruta_track:
				hay_track_hija = true
				var ruta_nodo := ruta_track.get_slice(":", 0)
				if ruta_nodo != "" and animacion_hija_player.get_node_or_null(NodePath(ruta_nodo)) == null:
					hay_track_roto = true

	if not hay_track_hija:
		push_warning("escena_demencia: AnimationPlayer sin pistas para Hija2/Hija.")
	elif hay_track_roto:
		push_warning("escena_demencia: Se detectaron pistas de animacion rotas hacia Hija2/Hija.")

func _duracion(segundos: float) -> float:
	return maxf(segundos * escala_tiempos, 0.05)

func _actualizar_mirada_hija(delta: float) -> void:
	if not _hija_mirando_jugador or nodo_hija == null or not nodo_hija.visible:
		return
	if not is_instance_valid(head):
		return

	var dir := head.global_position - nodo_hija.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return

	var objetivo_y := atan2(dir.x, dir.z)
	nodo_hija.rotation.y = lerp_angle(
		nodo_hija.rotation.y,
		objetivo_y,
		clampf(delta * velocidad_mirada_hija, 0.0, 1.0)
	)

func _process(delta: float) -> void:
	_actualizar_mirada_hija(delta)
	if not _agitando:
		return
	_t_agitacion += delta
	_t_shader    += delta
	var fuerza = clamp(_t_agitacion / 4.0, 0.0, 1.0)
	head.rotation.x = sin(_t_agitacion * 7.0) * deg_to_rad(5) * fuerza
	head.rotation.z = cos(_t_agitacion * 5.3) * deg_to_rad(3) * fuerza
	head.rotation.y = sin(_t_agitacion * 3.1) * deg_to_rad(4) * fuerza
	demencia_rect.material.set_shader_parameter("tiempo", _t_shader * 3.0)

func activar_demencia() -> void:
	if _activado:
		return
	_activado = true
	_skip_requested = false
	_demencia_finalizada = false
	_preparar_hija_para_cinematica()
	jugador.iniciar_cinematica()
	await _secuencia_demencia()
	if not _demencia_finalizada:
		terminar_cinematica()

func _on_jugador_cinematic_skip_requested() -> void:
	# Ignorar skips de otras cinemáticas (ej. intro); solo aplica a demencia activa.
	if not _activado:
		return
	if _transicion_iniciada:
		return
	if _demencia_finalizada:
		return
	_skip_requested = true
	call_deferred("_transicionar_a_bosque")

func _check_skip() -> bool:
	if _skip_requested:
		terminar_cinematica()
		return true
	return false

func terminar_cinematica() -> void:
	if _demencia_finalizada:
		return
	_demencia_finalizada = true
	_skip_requested = true
	_agitando = false
	_hija_mirando_jugador = false

	head.rotation = Vector3.ZERO
	parpado.visible = false
	dialogo_label.visible = false
	demencia_rect.material.set_shader_parameter("intensidad", 0.0)
	demencia_rect.visible = false

	if audio_demencia != null and audio_demencia.has_method("stop"):
		audio_demencia.stop()
	if animacion_hija_player != null and animacion_hija_player.is_playing():
		animacion_hija_player.stop()
	if nodo_hija != null and _hija_inicial_capturada:
		nodo_hija.global_transform = _hija_transform_inicial
		nodo_hija.visible = _hija_visible_inicial

	jugador.terminar_cinematica()

func _mostrar_pantalla_negra_pregunta() -> void:
	if not is_instance_valid(jugador):
		return
	var canvas := jugador.get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas == null:
		return

	var overlay := canvas.get_node_or_null("TransicionBosque") as Control
	if overlay == null:
		overlay = Control.new()
		overlay.name = "TransicionBosque"
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(overlay)

		var fondo := ColorRect.new()
		fondo.name = "Fondo"
		fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
		fondo.color = Color(0, 0, 0, 0)
		overlay.add_child(fondo)

		var txt := Label.new()
		txt.name = "Texto"
		txt.set_anchors_preset(Control.PRESET_FULL_RECT)
		txt.text = "????"
		txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		txt.modulate = Color(1, 1, 1, 0)
		txt.add_theme_font_size_override("font_size", 74)
		overlay.add_child(txt)

		var barra := ProgressBar.new()
		barra.name = "BarraCarga"
		barra.min_value = 0.0
		barra.max_value = 100.0
		barra.value = 0.0
		barra.show_percentage = false
		barra.anchor_left = 0.5
		barra.anchor_right = 0.5
		barra.anchor_top = 1.0
		barra.anchor_bottom = 1.0
		barra.offset_left = -ancho_barra_carga * 0.5
		barra.offset_right = ancho_barra_carga * 0.5
		barra.offset_top = -130.0
		barra.offset_bottom = barra.offset_top + alto_barra_carga
		barra.modulate = Color(1, 1, 1, 0)
		overlay.add_child(barra)

		var porcentaje := Label.new()
		porcentaje.name = "TextoPorcentaje"
		porcentaje.text = "0%"
		porcentaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		porcentaje.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		porcentaje.anchor_left = 0.5
		porcentaje.anchor_right = 0.5
		porcentaje.anchor_top = 1.0
		porcentaje.anchor_bottom = 1.0
		porcentaje.offset_left = -90.0
		porcentaje.offset_right = 90.0
		porcentaje.offset_top = -98.0
		porcentaje.offset_bottom = -70.0
		porcentaje.add_theme_font_size_override("font_size", 24)
		porcentaje.modulate = Color(1, 1, 1, 0)
		overlay.add_child(porcentaje)

	var fondo_nodo := overlay.get_node_or_null("Fondo") as ColorRect
	var txt_nodo := overlay.get_node_or_null("Texto") as Label
	var barra_nodo := overlay.get_node_or_null("BarraCarga") as ProgressBar
	var porcentaje_nodo := overlay.get_node_or_null("TextoPorcentaje") as Label
	if fondo_nodo == null or txt_nodo == null or barra_nodo == null or porcentaje_nodo == null:
		return

	barra_nodo.value = 0.0
	porcentaje_nodo.text = "0%"

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(fondo_nodo, "color:a", 1.0, fade_transicion_segundos)
	tw.parallel().tween_property(txt_nodo, "modulate:a", 1.0, fade_transicion_segundos * 0.65)
	tw.parallel().tween_property(barra_nodo, "modulate:a", 1.0, fade_transicion_segundos * 0.85)
	tw.parallel().tween_property(porcentaje_nodo, "modulate:a", 1.0, fade_transicion_segundos * 0.85)
	await tw.finished

func _actualizar_progreso_carga(valor_normalizado: float) -> void:
	if not is_instance_valid(jugador):
		return
	var canvas := jugador.get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas == null:
		return
	var overlay := canvas.get_node_or_null("TransicionBosque") as Control
	if overlay == null:
		return

	var barra_nodo := overlay.get_node_or_null("BarraCarga") as ProgressBar
	var porcentaje_nodo := overlay.get_node_or_null("TextoPorcentaje") as Label
	if barra_nodo == null or porcentaje_nodo == null:
		return

	var clamped := clampf(valor_normalizado, 0.0, 1.0)
	var porcentaje := int(round(clamped * 100.0))
	barra_nodo.value = porcentaje
	porcentaje_nodo.text = "%d%%" % porcentaje

func _marcar_transicion_bosque() -> void:
	GameState.saltar_intro_una_vez = true
	GameState.transicion_desde_cocina = true
	GameState.tiene_spawn_bosque = true
	GameState.spawn_bosque_pos = spawn_bosque_pos
	GameState.spawn_bosque_rot_y = deg_to_rad(spawn_bosque_rot_y_deg)

func _cargar_escena_bosque_async() -> void:
	if escena_bosque_path.is_empty():
		push_error("escena_demencia: escena_bosque_path vacia.")
		return
	_actualizar_progreso_carga(0.0)

	var req_err := ResourceLoader.load_threaded_request(escena_bosque_path, "PackedScene", false)
	if req_err != OK:
		push_warning("escena_demencia: load_threaded_request fallo, usando change_scene_to_file.")
		_actualizar_progreso_carga(1.0)
		_marcar_transicion_bosque()
		get_tree().change_scene_to_file(escena_bosque_path)
		return

	while true:
		var progreso: Array = []
		var status := ResourceLoader.load_threaded_get_status(escena_bosque_path, progreso)

		var progreso_norm := 0.0
		if not progreso.is_empty():
			var valor_raw := float(progreso[0])
			if valor_raw > 1.0:
				progreso_norm = clampf(valor_raw / 100.0, 0.0, 1.0)
			else:
				progreso_norm = clampf(valor_raw, 0.0, 1.0)
		_actualizar_progreso_carga(progreso_norm)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("escena_demencia: carga asíncrona falló, usando change_scene_to_file.")
			_actualizar_progreso_carga(1.0)
			_marcar_transicion_bosque()
			get_tree().change_scene_to_file(escena_bosque_path)
			return
		await get_tree().process_frame

	var packed := ResourceLoader.load_threaded_get(escena_bosque_path) as PackedScene
	if packed == null:
		push_warning("escena_demencia: PackedScene nulo, usando change_scene_to_file.")
		_actualizar_progreso_carga(1.0)
		_marcar_transicion_bosque()
		get_tree().change_scene_to_file(escena_bosque_path)
		return

	_actualizar_progreso_carga(1.0)
	await get_tree().process_frame
	_marcar_transicion_bosque()
	var change_err := get_tree().change_scene_to_packed(packed)
	if change_err != OK:
		push_warning("escena_demencia: change_scene_to_packed falló, usando change_scene_to_file.")
		get_tree().change_scene_to_file(escena_bosque_path)

func _transicionar_a_bosque() -> void:
	if _transicion_iniciada:
		return
	_transicion_iniciada = true
	terminar_cinematica()
	await _mostrar_pantalla_negra_pregunta()
	await _cargar_escena_bosque_async()

func _secuencia_demencia() -> void:

	# ── 1. Dialogo inicial ──
	await _dialogo("No me siento bien...", 2.2)
	if _check_skip():
		return
	_play_audio(audio_demencia)

	# ── 2. Estatica sube + cabeza tambalea (acelerado) ──
	demencia_rect.visible = true
	_t_agitacion = 0.0
	_t_shader    = 0.0
	_agitando    = true
	var tw_estatica = create_tween().set_trans(Tween.TRANS_SINE)
	tw_estatica.tween_method(
		func(v): demencia_rect.material.set_shader_parameter("intensidad", v),
		0.0, 1.0, _duracion(3.2))
	await tw_estatica.finished
	if _check_skip():
		return
	_agitando = false
	head.rotation = Vector3.ZERO

	# ── 3. Caida al suelo ──
	await _caer()
	if _check_skip():
		return

	# ── 4. Abre ojos desde el suelo ──
	parpado.visible = true
	parpado.material.set_shader_parameter("apertura", 0.0)
	await _parpado(0.0, 1.0, 0.5)
	if _check_skip():
		return
	await _esperar(0.4)
	if _check_skip():
		return

	# ── 5. Mira hacia abajo (pies de la Hija) ──
	var tw_mirar = create_tween().set_trans(Tween.TRANS_SINE)
	tw_mirar.tween_property(head, "rotation:x", deg_to_rad(38), 0.7)
	await tw_mirar.finished
	if _check_skip():
		return

	_mostrar_hija_susto()

	await _dialogo("Que... que esta pasando? Que es eso...?", 3.0)
	if _check_skip():
		return

	# ── 6. Parpadea — sube mirada un poco (tweens SEPARADOS, sin compartir variable) ──
	await _parpado(1.0, 0.0, 0.09)
	if _check_skip():
		return
	await _esperar(0.12)
	if _check_skip():
		return
	# Tween de cabeza con variable local — no interfiere con _parpado
	var tw_subir = create_tween().set_trans(Tween.TRANS_SINE)
	tw_subir.tween_property(head, "rotation:x", deg_to_rad(12), 1.3)
	# Parpadea mientras la cabeza sube (en paralelo, cada uno con su variable local)
	await _parpado(0.0, 1.0, 0.35)
	if _check_skip():
		return
	await tw_subir.finished
	if _check_skip():
		return
	await _esperar(0.7)
	if _check_skip():
		return

	# ── 7. Parpadea rapido — Hija desaparece ──
	await _parpado(1.0, 0.0, 0.07)
	if _check_skip():
		return
	await _esperar(0.1)
	if _check_skip():
		return
	if nodo_hija != null:
		_hija_mirando_jugador = false
		nodo_hija.visible = false
	await _parpado(0.0, 1.0, 0.18)
	if _check_skip():
		return
	await _esperar(0.4)
	if _check_skip():
		return

	# ── 8. Estatica baja ──
	var tw_bajar = create_tween().set_trans(Tween.TRANS_SINE)
	tw_bajar.tween_method(
		func(v): demencia_rect.material.set_shader_parameter("intensidad", v),
		1.0, 0.0, _duracion(2.0))
	await tw_bajar.finished
	if _check_skip():
		return
	demencia_rect.visible = false

	# ── 9. Levantarse mareado ──
	await _levantarse_mareado()
	if _check_skip():
		return

	# Parpado se cierra y desaparece
	await _parpado(1.0, 0.0, 0.9)
	if _check_skip():
		return
	parpado.visible = false

	# ── 10. Dialogos finales + busqueda 360 ──
	head.rotation = Vector3.ZERO
	await _dialogo("Que me sucede...?", 2.5)
	if _check_skip():
		return
	await _buscar_hija_360()
	if _check_skip():
		return
	await _dialogo("Hija... hija, donde estas?", 3.5)
	if _check_skip():
		return

	# ── 11. Fundido a negro, "????" y carga del bosque ──
	await _transicionar_a_bosque()

# ─── Helpers — cada uno usa variable LOCAL, nunca compartida ────────────────────

func _caer() -> void:
	if _skip_requested:
		return
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(head, "rotation:z", deg_to_rad(12),  0.28)
	tw.tween_property(head, "rotation:z", deg_to_rad(-8),  0.22)
	tw.tween_property(head, "rotation:z", deg_to_rad(0),   0.18)
	await tw.finished
	tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(jugador, "position", jugador.position + Vector3(0, -0.5, 0), 0.7)
	tw.parallel().tween_property(head, "rotation:x", deg_to_rad(55), 0.7)
	tw.parallel().tween_property(head, "rotation:z", deg_to_rad(15), 0.7)
	await tw.finished

func _levantarse_mareado() -> void:
	if _skip_requested:
		return
	var p0 = jugador.position
	await _parpado(1.0, 0.0, 0.12)
	if _skip_requested:
		return
	await _esperar(0.18)
	if _skip_requested:
		return
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(jugador, "position", p0 + Vector3(0, 0.22, 0), 0.9)
	tw.tween_property(head, "rotation:x", deg_to_rad(18), 0.9)
	tw.tween_property(head, "rotation:z", deg_to_rad(4),  0.9)
	await _parpado(0.0, 1.0, 0.28)
	if _skip_requested:
		return
	await tw.finished
	if _skip_requested:
		return
	await _esperar(0.25)
	if _skip_requested:
		return
	await _parpado(1.0, 0.0, 0.10)
	if _skip_requested:
		return
	await _esperar(0.14)
	if _skip_requested:
		return
	await _parpado(0.0, 1.0, 0.22)
	if _skip_requested:
		return
	await _esperar(0.18)
	if _skip_requested:
		return
	tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(jugador, "position", p0 + Vector3(0, 0.5, 0), 1.2)
	tw.tween_property(head, "rotation:x", deg_to_rad(4), 1.2)
	tw.tween_property(head, "rotation:z", deg_to_rad(0), 1.2)
	await tw.finished
	if _skip_requested:
		return
	await _parpado(1.0, 0.0, 0.09)
	if _skip_requested:
		return
	await _esperar(0.12)
	if _skip_requested:
		return
	tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(jugador, "position", p0 + Vector3(0, 0.55, 0), 0.6)
	tw.tween_property(head, "rotation:x", 0.0, 0.6)
	await _parpado(0.0, 1.0, 0.3)
	if _skip_requested:
		return
	await tw.finished
	if _skip_requested:
		return
	await _esperar(0.4)

func _buscar_hija_360() -> void:
	if _skip_requested:
		return
	var ry0 = jugador.rotation.y
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(jugador, "rotation:y", ry0 + deg_to_rad(80),  0.55)
	tw.tween_property(head,    "rotation:y", deg_to_rad(22),         0.28)
	tw.tween_property(head,    "rotation:y", deg_to_rad(-18),        0.35)
	tw.tween_property(jugador, "rotation:y", ry0 + deg_to_rad(190), 0.65)
	tw.tween_property(head,    "rotation:y", deg_to_rad(24),         0.28)
	tw.tween_property(jugador, "rotation:y", ry0 + deg_to_rad(310), 0.75)
	tw.tween_property(head,    "rotation:y", deg_to_rad(-14),        0.28)
	tw.tween_property(head,    "rotation:y", 0.0,                    0.28)
	await tw.finished

# _parpado usa siempre variable local — NUNCA toca _tw compartida
func _parpado(desde: float, hasta: float, dur: float) -> void:
	if _skip_requested:
		return
	var tw = create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_method(
		func(v): parpado.material.set_shader_parameter("apertura", v),
		desde, hasta, dur)
	await tw.finished

func _dialogo(texto: String, dur: float) -> void:
	var lineas_dialogo: Array[String] = [texto]
	var auto_avance := _duracion(dur)
	await jugador.reproducir_dialogo(lineas_dialogo, 62.0, auto_avance)

func _play_audio(player: Node) -> void:
	if player == null:
		return
	if player.has_method("play") and player.get("stream") != null:
		player.play()

func _esperar(seg: float) -> void:
	var objetivo := _duracion(seg)
	var transcurrido := 0.0
	while transcurrido < objetivo and not _skip_requested:
		await get_tree().process_frame
		transcurrido += get_process_delta_time()
