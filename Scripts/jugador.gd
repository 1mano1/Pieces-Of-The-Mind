extends CharacterBody3D

signal cinematic_skip_requested
signal health_changed(current_health: float, max_health: float)
signal player_died
signal hotbar_slot_selected(active_index: int, slot_data: Dictionary)
signal flashlight_toggled(is_on: bool)

const SPEED = 5.0
const MOUSE_SENSITIVITY = 0.002
const DEFAULT_DIALOGUE_CHARS_PER_SECOND = 45.0

@export_range(20.0, 300.0, 1.0) var max_health: float = 100.0
@export_range(0.5, 12.0, 0.1) var regen_delay_seconds: float = 4.0
@export_range(1.0, 120.0, 0.5) var regen_per_second: float = 24.0
@export_range(0.2, 1.0, 0.01) var max_damage_overlay_alpha: float = 0.8
@export_range(0.5, 12.0, 0.1) var flashlight_energy: float = 4.5
@export_range(3.0, 35.0, 0.5) var flashlight_range: float = 18.0
@export_range(8.0, 60.0, 1.0) var flashlight_half_angle_deg: float = 24.0
@export_range(8.0, 60.0, 1.0) var flashlight_effect_half_angle_deg: float = 26.0

@onready var head: Node3D = $Head
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var dialogo_label: Label = get_node_or_null("CanvasLayer/DialogoLabel")
@onready var canvas_layer: CanvasLayer = get_node_or_null("CanvasLayer") as CanvasLayer

var puede_moverse: bool = false
var is_in_dialogue: bool = false
var is_in_cinematic: bool = false
var is_dead: bool = false

var current_health: float = 100.0
var _last_damage_msec: int = 0
var _overlay_target_alpha: float = 0.0
var _damage_overlay: ColorRect = null
var _game_over_label: Label = null
var _selected_hotbar_index: int = 0
var _selected_hotbar_slot: Dictionary = {}
var _flashlight: SpotLight3D = null
var _flashlight_on: bool = false
var footsteps_player: AudioStreamPlayer = null
var footsteps_player_bosque: AudioStreamPlayer = null
var damage_audio_player: AudioStreamPlayer = null
var game_over_audio_player: AudioStreamPlayer = null

var _dialogue_typing: bool = false
var _dialogue_force_complete_line: bool = false
var _dialogue_advance_requested: bool = false
var _dialogue_last_line_typing_time: float = 0.0
var _cinematic_skip_enabled_at_msec: int = 0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	puede_moverse = false
	current_health = max_health
	_last_damage_msec = Time.get_ticks_msec()
	GameState._ensure_hotbar_initialized()
	_selected_hotbar_index = GameState.hotbar_selected_index
	_selected_hotbar_slot = GameState.get_hotbar_slot(_selected_hotbar_index)
	if dialogo_label != null:
		dialogo_label.visible = false
		dialogo_label.visible_characters = -1
	_ensure_damage_ui()
	_ensure_crosshair_plus_ui()
	_ensure_flashlight()
	_setup_footsteps_audio()
	emit_signal("health_changed", current_health, max_health)

func activar_control() -> void:
	if is_dead:
		return
	puede_moverse = true
	velocity = Vector3.ZERO

func desactivar_control() -> void:
	puede_moverse = false
	velocity = Vector3.ZERO

func iniciar_cinematica() -> void:
	is_in_cinematic = true
	# Evita detectar como "salto" una pulsacion de espacio residual del frame previo.
	_cinematic_skip_enabled_at_msec = Time.get_ticks_msec() + 250
	desactivar_control()

func terminar_cinematica() -> void:
	is_in_cinematic = false
	if is_in_dialogue:
		cerrar_dialogo()
	activar_control()

func saltar_cinematica_actual() -> void:
	if animation_player != null and animation_player.is_playing():
		animation_player.stop()
	emit_signal("cinematic_skip_requested")
	terminar_cinematica()

func _process(delta: float) -> void:
	_update_health_regen(delta)
	_update_damage_overlay(delta)

func _ensure_damage_ui() -> void:
	if canvas_layer == null:
		return

	var overlay := canvas_layer.get_node_or_null("DamageOverlay") as ColorRect
	if overlay == null:
		overlay = ColorRect.new()
		overlay.name = "DamageOverlay"
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.color = Color(0.9, 0.05, 0.05, 0.0)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas_layer.add_child(overlay)
	_damage_overlay = overlay

	var label := canvas_layer.get_node_or_null("GameOverLabel") as Label
	if label == null:
		label = Label.new()
		label.name = "GameOverLabel"
		label.text = "Has muerto"
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.offset_left = -160.0
		label.offset_top = -30.0
		label.offset_right = 160.0
		label.offset_bottom = 30.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 46)
		label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 0.0))
		label.visible = false
		canvas_layer.add_child(label)
	_game_over_label = label

func _ensure_crosshair_plus_ui() -> void:
	if canvas_layer == null:
		return

	var legacy_crosshair := canvas_layer.get_node_or_null("TextureRect") as CanvasItem
	if legacy_crosshair != null:
		legacy_crosshair.visible = false

	var root := canvas_layer.get_node_or_null("CrosshairPlus") as Control
	if root == null:
		root = Control.new()
		root.name = "CrosshairPlus"
		root.anchor_left = 0.5
		root.anchor_top = 0.5
		root.anchor_right = 0.5
		root.anchor_bottom = 0.5
		root.offset_left = -20.0
		root.offset_top = -20.0
		root.offset_right = 20.0
		root.offset_bottom = 20.0
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.z_index = 120
		canvas_layer.add_child(root)

	var shadow := root.get_node_or_null("PlusShadow") as Label
	if shadow == null:
		shadow = Label.new()
		shadow.name = "PlusShadow"
		shadow.anchor_left = 0.0
		shadow.anchor_top = 0.0
		shadow.anchor_right = 1.0
		shadow.anchor_bottom = 1.0
		shadow.offset_left = 1.0
		shadow.offset_top = 1.0
		shadow.offset_right = 1.0
		shadow.offset_bottom = 1.0
		shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		shadow.add_theme_font_size_override("font_size", 28)
		shadow.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.72))
		shadow.text = "+"
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shadow)
	else:
		shadow.text = "+"

	var plus := root.get_node_or_null("PlusMain") as Label
	if plus == null:
		plus = Label.new()
		plus.name = "PlusMain"
		plus.anchor_left = 0.0
		plus.anchor_top = 0.0
		plus.anchor_right = 1.0
		plus.anchor_bottom = 1.0
		plus.offset_left = 0.0
		plus.offset_top = 0.0
		plus.offset_right = 0.0
		plus.offset_bottom = 0.0
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.add_theme_font_size_override("font_size", 28)
		plus.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
		plus.text = "+"
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(plus)
	else:
		plus.text = "+"

func _ensure_flashlight() -> void:
	if head == null:
		return

	var spot := head.get_node_or_null("LinternaSpot") as SpotLight3D
	if spot == null:
		spot = SpotLight3D.new()
		spot.name = "LinternaSpot"
		head.add_child(spot)

	spot.position = Vector3(0.12, 0.01, 0.0)
	spot.rotation = Vector3(deg_to_rad(-2.0), 0.0, 0.0)
	spot.light_color = Color(1.0, 0.95, 0.84)
	spot.light_energy = flashlight_energy
	spot.spot_range = flashlight_range
	spot.spot_angle = flashlight_half_angle_deg
	spot.shadow_enabled = true
	spot.visible = _flashlight_on

	_flashlight = spot

func _setup_footsteps_audio() -> void:
	# Pasos Intro
	footsteps_player = AudioStreamPlayer.new()
	var stream = load("res://sonidos/Sonido de pasos en superficie plana.mp3")
	if stream:
		if stream is AudioStreamMP3:
			stream.loop = true
		footsteps_player.stream = stream
		# Ajusta el volumen y aceleramos el audio un 30%
		footsteps_player.volume_db = -5.0
		footsteps_player.pitch_scale = 1.3 # Acelera el audio (1.0 es normal, 1.3 es más rápido)
		add_child(footsteps_player)

	# Pasos Bosque
	footsteps_player_bosque = AudioStreamPlayer.new()
	var stream_bosque = load("res://sonidos/Sonido de Pasos en el Bosque.mp3")
	if stream_bosque:
		if stream_bosque is AudioStreamMP3:
			stream_bosque.loop = true
		footsteps_player_bosque.stream = stream_bosque
		footsteps_player_bosque.volume_db = -3.0 # Ligeramente más alto si el audio de bosque suele ser suave
		footsteps_player_bosque.pitch_scale = 1.3 # Acelerado 30% también
		add_child(footsteps_player_bosque)

	# Sonido de daño
	damage_audio_player = AudioStreamPlayer.new()
	var stream_damage = load("res://sonidos/daño a jugador.mp3")
	if stream_damage:
		# No hacemos loop porque es solo un impacto
		damage_audio_player.stream = stream_damage
		damage_audio_player.volume_db = 0.0
		add_child(damage_audio_player)

	# Reproductor Game Over
	game_over_audio_player = AudioStreamPlayer.new()
	game_over_audio_player.volume_db = 0.0
	add_child(game_over_audio_player)

func has_flashlight() -> bool:
	return GameState.has_hotbar_item("linterna")

func toggle_flashlight() -> bool:
	if is_dead:
		return false
	if not has_flashlight():
		return false

	_ensure_flashlight()
	if _flashlight == null:
		return false

	_flashlight_on = not _flashlight_on
	_flashlight.visible = _flashlight_on
	emit_signal("flashlight_toggled", _flashlight_on)
	return true

func is_flashlight_on() -> bool:
	if _flashlight == null:
		return false
	return _flashlight_on and _flashlight.visible

func is_enemy_in_flashlight(enemy_world_pos: Vector3) -> bool:
	if not is_flashlight_on():
		return false
	if _flashlight == null or not is_instance_valid(_flashlight):
		return false

	var to_enemy: Vector3 = enemy_world_pos - _flashlight.global_position
	var dist: float = to_enemy.length()
	if dist > flashlight_range:
		return false
	if dist <= 0.001:
		return true

	var forward: Vector3 = -_flashlight.global_transform.basis.z.normalized()
	var dot: float = forward.dot(to_enemy / dist)
	var min_dot: float = cos(deg_to_rad(flashlight_effect_half_angle_deg))
	return dot >= min_dot

func take_damage(amount: float = 30.0) -> void:
	if is_dead:
		return
	if amount <= 0.0:
		return

	current_health = maxf(current_health - amount, 0.0)
	_last_damage_msec = Time.get_ticks_msec()
	_update_overlay_target_alpha()
	emit_signal("health_changed", current_health, max_health)
	
	# Reproducir sonido de daño si estamos en el bosque
	var curr_scene = get_tree().current_scene
	if curr_scene != null and "bosque" in str(curr_scene.name).to_lower():
		if damage_audio_player != null and not damage_audio_player.playing:
			damage_audio_player.play()

	if current_health <= 0.0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	desactivar_control()
	is_in_cinematic = false

	if is_in_dialogue:
		cerrar_dialogo()

	_flashlight_on = false
	if _flashlight != null and is_instance_valid(_flashlight):
		_flashlight.visible = false

	_overlay_target_alpha = max_damage_overlay_alpha
	if _game_over_label != null:
		_game_over_label.visible = true
		var col := _game_over_label.get_theme_color("font_color", "Label")
		_game_over_label.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 1.0))

	# Detener sonidos de pasos al morir
	if footsteps_player != null and footsteps_player.playing:
		footsteps_player.stop()
	if footsteps_player_bosque != null and footsteps_player_bosque.playing:
		footsteps_player_bosque.stop()

	# Reproducir uno de los 3 audios de Game Over de manera aleatoria
	if game_over_audio_player != null:
		var audios = [
			"res://sonidos/game over 1.mp3",
			"res://sonidos/game over 2.mp3",
			"res://sonidos/game over 3.mp3"
		]
		var rng = RandomNumberGenerator.new()
		rng.randomize() # Asegura la aleatoriedad
		var seleccion = audios[rng.randi() % audios.size()]
		var stream_go = load(seleccion)
		if stream_go:
			game_over_audio_player.stream = stream_go
			game_over_audio_player.play()

	emit_signal("player_died")

func _update_health_regen(delta: float) -> void:
	if is_dead:
		return
	if current_health >= max_health:
		return

	var elapsed_msec: int = Time.get_ticks_msec() - _last_damage_msec
	if elapsed_msec < int(regen_delay_seconds * 1000.0):
		return

	var prev: float = current_health
	current_health = minf(max_health, current_health + regen_per_second * delta)
	if current_health != prev:
		_update_overlay_target_alpha()
		emit_signal("health_changed", current_health, max_health)

func _update_overlay_target_alpha() -> void:
	var ratio: float = clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	var missing_ratio: float = 1.0 - ratio
	_overlay_target_alpha = missing_ratio * max_damage_overlay_alpha

func _update_damage_overlay(delta: float) -> void:
	if _damage_overlay == null:
		return
	var c: Color = _damage_overlay.color
	c.a = move_toward(c.a, _overlay_target_alpha, delta * 1.8)
	_damage_overlay.color = c

func is_player_dead() -> bool:
	return is_dead

func on_hotbar_slot_changed(active_index: int, slot_data: Dictionary) -> void:
	_selected_hotbar_index = active_index
	_selected_hotbar_slot = slot_data.duplicate(true)
	emit_signal("hotbar_slot_selected", _selected_hotbar_index, _selected_hotbar_slot)

func get_selected_hotbar_slot() -> Dictionary:
	return _selected_hotbar_slot.duplicate(true)

func get_current_health() -> float:
	return current_health

func use_selected_hotbar_item() -> bool:
	if is_dead:
		return false

	var slot: Dictionary = GameState.get_hotbar_slot(_selected_hotbar_index)
	var item_id: String = String(slot.get("id", ""))
	var count: int = int(slot.get("count", 0))

	if item_id.is_empty() or count <= 0:
		return false

	if item_id == "linterna":
		return toggle_flashlight()

	if item_id == "pildora":
		if current_health >= max_health:
			return false
		current_health = minf(max_health, current_health + 35.0)
		_last_damage_msec = Time.get_ticks_msec()
		_update_overlay_target_alpha()
		emit_signal("health_changed", current_health, max_health)
		GameState.consume_selected_hotbar_item(1)
		return true

	return false

func reproducir_dialogo(lineas: Array[String], chars_por_segundo: float = DEFAULT_DIALOGUE_CHARS_PER_SECOND, auto_avance_segundos: float = -1.0) -> void:
	if dialogo_label == null or lineas.is_empty():
		return

	is_in_dialogue = true
	dialogo_label.visible = true
	dialogo_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	dialogo_label.z_index = 4096
	dialogo_label.add_theme_font_size_override("font_size", 45)
	dialogo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	dialogo_label.add_theme_constant_override("outline_size", 8)

	for linea in lineas:
		if not is_in_dialogue:
			break
		await _escribir_dialogo_linea(linea, chars_por_segundo)
		if not is_in_dialogue:
			break
		await _esperar_avance_dialogo(auto_avance_segundos)

	cerrar_dialogo()

func cerrar_dialogo() -> void:
	is_in_dialogue = false
	_dialogue_typing = false
	_dialogue_force_complete_line = false
	_dialogue_advance_requested = false
	_dialogue_last_line_typing_time = 0.0
	if dialogo_label != null:
		dialogo_label.visible_characters = -1
		dialogo_label.visible = false

func _escribir_dialogo_linea(texto: String, chars_por_segundo: float) -> void:
	if dialogo_label == null:
		return

	dialogo_label.text = texto
	dialogo_label.visible_characters = 0
	_dialogue_typing = true
	_dialogue_force_complete_line = false

	var total_chars := texto.length()
	var acumulado := 0.0
	var cps: float = maxf(chars_por_segundo, 1.0)
	var tiempo_escritura := 0.0

	while is_in_dialogue and dialogo_label.visible_characters < total_chars and not _dialogue_force_complete_line:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		tiempo_escritura += delta
		acumulado += delta * cps
		var avance := int(acumulado)
		if avance > 0:
			acumulado -= avance
			dialogo_label.visible_characters = min(dialogo_label.visible_characters + avance, total_chars)

	dialogo_label.visible_characters = -1
	_dialogue_typing = false
	_dialogue_force_complete_line = false
	_dialogue_last_line_typing_time = tiempo_escritura

func _esperar_avance_dialogo(auto_avance_segundos: float) -> void:
	_dialogue_advance_requested = false

	if auto_avance_segundos < 0.0:
		while is_in_dialogue and not _dialogue_advance_requested:
			await get_tree().process_frame
	else:
		# El auto-avance representa la duracion total minima de la linea,
		# no un tiempo adicional despues de terminar de escribir.
		var espera_objetivo := maxf(auto_avance_segundos - _dialogue_last_line_typing_time, 0.0)
		var transcurrido := 0.0
		while is_in_dialogue and not _dialogue_advance_requested and transcurrido < espera_objetivo:
			await get_tree().process_frame
			transcurrido += get_process_delta_time()

	_dialogue_advance_requested = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_linterna") and not event.is_echo():
		if toggle_flashlight():
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("Interactuar") and not event.is_echo():
		if use_selected_hotbar_item():
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_accept") and not event.is_echo():
		if is_in_dialogue:
			if _dialogue_typing:
				_dialogue_force_complete_line = true
			else:
				_dialogue_advance_requested = true
			get_viewport().set_input_as_handled()
			return
		if is_in_cinematic:
			if Time.get_ticks_msec() < _cinematic_skip_enabled_at_msec:
				get_viewport().set_input_as_handled()
				return
			saltar_cinematica_actual()
			get_viewport().set_input_as_handled()
			return

	if not puede_moverse:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not puede_moverse:
		return
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		# Iniciar sonido si el jugador camina y está tocando el suelo
		if is_on_floor():
			var curr_scene = get_tree().current_scene
			var is_intro_scene = (curr_scene != null and "node_3d" in str(curr_scene.scene_file_path).to_lower())
			var is_bosque_scene = (curr_scene != null and "bosque" in str(curr_scene.name).to_lower())
			
			if is_intro_scene and not GameState.tarea_hija_completa:
				if footsteps_player != null and not footsteps_player.playing:
					if footsteps_player_bosque != null and footsteps_player_bosque.playing:
						footsteps_player_bosque.stop()
					footsteps_player.play()
			elif is_bosque_scene:
				if footsteps_player_bosque != null and not footsteps_player_bosque.playing:
					if footsteps_player != null and footsteps_player.playing:
						footsteps_player.stop()
					footsteps_player_bosque.play()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	# Detener los sonidos si dejamos de presionar teclas o estamos en el aire
	if not direction or not is_on_floor():
		if footsteps_player != null and footsteps_player.playing:
			footsteps_player.stop()
		if footsteps_player_bosque != null and footsteps_player_bosque.playing:
			footsteps_player_bosque.stop()

	move_and_slide()
