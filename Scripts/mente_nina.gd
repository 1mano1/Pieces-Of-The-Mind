## mente_nina.gd  — v3
## CORRECCIONES PRINCIPALES:
##   - Camera3D.make_current() garantizado desde _ready() y como fallback en _process().
##   - Jugador se reposiciona dentro del quirófano usando el Sketchfab_Scene como referencia,
##     con RayCast hacia abajo para encontrar el piso real.
##   - Prioridad manual: si el nodo Jugador ya está en escena no se recrea.
##   - Objetos: vincula nodos existentes o los crea por código.
##   - Tecla [X]: usa _input() para máxima fiabilidad.
extends Node3D

const TIEMPO_LIMITE: float = 15.0
const ESCENA_BOSQUE: String = "res://Escenas/nivel_bosque.tscn"

# Offset Y sobre el origen del Sketchfab_Scene para el spawn del jugador.
# Si el piso del modelo está a Y=0 local, este valor es la altura del jugador sobre él.
const SPAWN_Y_SOBRE_PISO: float = 1.1

# Posiciones locales de los objetos (relativas al global_position del Sketchfab_Scene)
const POS_PELUCHE_LOCAL  := Vector3(-2.5, 0.5,  1.2)
const POS_TIJERAS_LOCAL  := Vector3( 2.1, 0.5, -0.8)
const POS_ZAPATO_LOCAL   := Vector3( 0.3, 0.5,  2.8)

var _jugador: CharacterBody3D
var _quirofano: Node3D
var _camara_activada: bool = false

var _tiempo_restante: float = TIEMPO_LIMITE
var _timer_activo: bool = false
var _terminado: bool = false

# UI
var _canvas: CanvasLayer
var _reloj_label: Label
var _checklist_root: Control
var _check_peluche: Label
var _check_tijeras: Label
var _check_zapato: Label
var _jumpscare_rect: ColorRect
var _prompt_label: Label

# Objetos 3D coleccionables
var _obj_peluche: Node3D
var _obj_tijeras: Node3D
var _obj_zapato: Node3D

# ──────────────────────────────────────────────
#  READY
# ──────────────────────────────────────────────
func _ready() -> void:
	await get_tree().process_frame

	# 1. Referencia al quirófano (ya en escena)
	_quirofano = get_node_or_null("Sketchfab_Scene") as Node3D

	# 2. Jugador (prioridad: nodo en escena)
	_jugador = get_node_or_null("Jugador") as CharacterBody3D
	if _jugador == null:
		_jugador = _buscar_jugador_en_arbol()

	# 3. Garantizar WorldEnvironment
	_garantizar_ambiente()

	# 4. Vincular/crear objetos del checklist
	_vincular_objetos_checklist()

	# 5. UI
	_construir_ui()

	# 6. Activar control y cámara
	if _jugador != null:
		_ajustar_spawn_jugador()
		_jugador.activar_control()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_hacer_camara_current()
	else:
		var cam_fb := Camera3D.new()
		if _quirofano != null:
			cam_fb.global_position = _quirofano.global_position + Vector3(0, 2, 3)
			cam_fb.look_at(_quirofano.global_position)
		else:
			cam_fb.position = Vector3(0, 2, 5)
		add_child(cam_fb)
		cam_fb.make_current()

	_timer_activo = true

func _hacer_camara_current() -> void:
	if _jugador == null:
		return
	# Rutas comunes en un CharacterBody3D FPS
	var rutas := ["Head/Camera3D", "Camera3D", "Head/Camara", "Camara"]
	for ruta in rutas:
		var cam := _jugador.get_node_or_null(ruta) as Camera3D
		if cam != null:
			cam.make_current()
			_camara_activada = true
			return
	# Búsqueda recursiva
	var cam_gen := _jugador.find_child("Camera3D", true, false) as Camera3D
	if cam_gen != null:
		cam_gen.make_current()
		_camara_activada = true

func _ajustar_spawn_jugador() -> void:
	if _jugador == null:
		return

	var room_pos := Vector3.ZERO
	if _quirofano != null:
		room_pos = _quirofano.global_position

	# Si el jugador está demasiado lejos del cuarto, moverlo dentro
	var dist := _jugador.global_position.distance_to(room_pos)
	if dist > 12.0 or dist < 0.01:
		# Posición inicial: sobre el origen del cuarto
		var pos_spawn := room_pos + Vector3(0.0, SPAWN_Y_SOBRE_PISO, 0.0)

		# RayCast para encontrar el piso real del modelo
		var ray_desde := pos_spawn + Vector3(0, 5, 0)
		var ray_hasta  := pos_spawn + Vector3(0, -5, 0)
		var query := PhysicsRayQueryParameters3D.create(ray_desde, ray_hasta)
		var espacio := get_world_3d().direct_space_state
		var hit := espacio.intersect_ray(query)
		if hit.size() > 0:
			pos_spawn = hit["position"]
			pos_spawn.y += 0.15

		_jugador.global_position = pos_spawn
		_jugador.velocity = Vector3.ZERO

	# Limpiar inclinación del Head
	var head := _jugador.get_node_or_null("Head") as Node3D
	if head:
		head.rotation = Vector3.ZERO

func _garantizar_ambiente() -> void:
	var wenv := get_tree().root.find_child("WorldEnvironment", true, false)
	if wenv != null:
		return
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment_mente"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.ambient_light_energy = 1.2
	world_env.environment = env
	add_child(world_env)

func _vincular_objetos_checklist() -> void:
	var origin := _quirofano.global_position if _quirofano != null else Vector3.ZERO
	_obj_peluche = _encontrar_o_crear("peluche", "res://Modelos/peluche.glb",
		origin + POS_PELUCHE_LOCAL)
	_obj_tijeras = _encontrar_o_crear("tijeras", "res://Modelos/tijeras.glb",
		origin + POS_TIJERAS_LOCAL)
	_obj_zapato  = _encontrar_o_crear("zapato",  "res://Modelos/zapato.glb",
		origin + POS_ZAPATO_LOCAL)

func _encontrar_o_crear(id: String, glb_path: String, pos_mundo: Vector3) -> Node3D:
	for nombre in ["Obj_" + id.capitalize(), "Obj_" + id, id.capitalize(), id]:
		var nodo := get_node_or_null(nombre) as Node3D
		if nodo != null:
			nodo.set_meta("item_id", id)
			_agregar_prompt_si_falta(nodo)
			return nodo
	return _crear_objeto(id, glb_path, pos_mundo)

func _agregar_prompt_si_falta(nodo: Node3D) -> void:
	if nodo.get_node_or_null("Prompt") != null:
		return
	var lbl := Label3D.new()
	lbl.text = "[E] Recoger"
	lbl.font_size = 42
	lbl.modulate = Color(1, 1, 0.6, 1)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 0.7, 0)
	lbl.visible = false
	lbl.name = "Prompt"
	nodo.add_child(lbl)

func _crear_objeto(id: String, glb_path: String, pos_mundo: Vector3) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Obj_" + id
	add_child(raiz)
	raiz.global_position = pos_mundo
	raiz.set_meta("item_id", id)
	var res := load(glb_path) as PackedScene
	if res != null:
		var v := res.instantiate() as Node3D
		v.scale = Vector3(0.4, 0.4, 0.4)
		raiz.add_child(v)
	_agregar_prompt_si_falta(raiz)
	return raiz

func _buscar_jugador_en_arbol() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody3D
	var found := get_tree().root.find_child("Jugador", true, false)
	if found is CharacterBody3D:
		return found as CharacterBody3D
	return null

# ──────────────────────────────────────────────
#  INPUT
# ──────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if _terminado:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.physical_keycode == KEY_X or ke.keycode == KEY_X:
				get_viewport().set_input_as_handled()
				_escapar()

# ──────────────────────────────────────────────
#  PROCESS
# ──────────────────────────────────────────────
func _process(delta: float) -> void:
	# Fallback: reintenta activar cámara hasta que funcione
	if not _camara_activada and _jugador != null:
		_hacer_camara_current()

	if _terminado or _jugador == null:
		return

	if _timer_activo:
		_tiempo_restante -= delta
		_actualizar_reloj()
		if _tiempo_restante <= 5.0:
			var pulso := sin(Time.get_ticks_msec() * 0.006) * 0.5 + 0.5
			_reloj_label.add_theme_color_override("font_color",
				Color(1.0, pulso * 0.3, pulso * 0.3, 1.0))
		if _tiempo_restante <= 0.0:
			_tiempo_restante = 0.0
			_timer_activo = false
			_activar_jumpscare()
			return

	_revisar_objetos()

	if GameState.mente_objetos_completos() and not _terminado:
		_timer_activo = false
		_terminado = true
		_completar_mision()

func _actualizar_reloj() -> void:
	var seg := maxf(_tiempo_restante, 0.0)
	_reloj_label.text = "⏱ %.1f" % seg
	if seg <= 5.0:
		var escala := 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.08
		_reloj_label.scale = Vector2(escala, escala)
	else:
		_reloj_label.scale = Vector2.ONE

func _revisar_objetos() -> void:
	var prompt_texto := ""
	var objetos := [
		{"nodo": _obj_peluche, "id": "peluche", "check": _check_peluche,
		 "recogido": GameState.mente_peluche_recogido},
		{"nodo": _obj_tijeras, "id": "tijeras", "check": _check_tijeras,
		 "recogido": GameState.mente_tijeras_recogidas},
		{"nodo": _obj_zapato,  "id": "zapato",  "check": _check_zapato,
		 "recogido": GameState.mente_zapato_recogido},
	]
	for datos in objetos:
		var nodo: Node3D = datos["nodo"] as Node3D
		var id: String   = datos["id"] as String
		var check: Label = datos["check"] as Label
		var recogido: bool = datos["recogido"] as bool
		if nodo == null or not is_instance_valid(nodo):
			continue
		if recogido:
			nodo.visible = false
			check.text = "☑ " + id.capitalize()
			check.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
			continue
		var dist := _jugador.global_position.distance_to(nodo.global_position)
		var en_rango := dist <= 2.2
		var prompt_nodo := nodo.get_node_or_null("Prompt") as Label3D
		if prompt_nodo:
			prompt_nodo.visible = en_rango
		if en_rango:
			prompt_texto = "[E] Recoger " + id.capitalize()
			if Input.is_action_just_pressed("Interactuar"):
				_recoger_objeto(id)
	_prompt_label.text = prompt_texto

func _recoger_objeto(id: String) -> void:
	match id:
		"peluche":
			GameState.mente_peluche_recogido = true
			GameState.agregar_item_hotbar("peluche", 1, "")
		"tijeras":
			GameState.mente_tijeras_recogidas = true
			GameState.agregar_item_hotbar("tijeras", 1, "")
		"zapato":
			GameState.mente_zapato_recogido = true
			GameState.agregar_item_hotbar("zapato", 1, "")

# ──────────────────────────────────────────────
#  FINALES
# ──────────────────────────────────────────────
func _completar_mision() -> void:
	if _jugador != null:
		_jugador.desactivar_control()
	var fade := _crear_fade()
	var tw := create_tween()
	tw.tween_property(fade, "color", Color(0, 0, 0, 1), 1.0)
	await tw.finished
	GameState.nina_objetos_entregados = true
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file(ESCENA_BOSQUE)

func _activar_jumpscare() -> void:
	_terminado = true
	if _jugador != null:
		_jugador.desactivar_control()
	var tw := create_tween()
	tw.tween_property(_jumpscare_rect, "color", Color(0.8, 0.0, 0.0, 0.95), 0.08)
	tw.tween_property(_jumpscare_rect, "color", Color(0.8, 0.0, 0.0, 0.0),  0.15)
	tw.tween_property(_jumpscare_rect, "color", Color(0.8, 0.0, 0.0, 0.95), 0.07)
	await tw.finished
	await get_tree().create_timer(0.5).timeout
	tw = create_tween()
	tw.tween_property(_jumpscare_rect, "color", Color(0, 0, 0, 1), 0.5)
	await tw.finished
	GameState.nina_acepto_ayudar = false
	GameState.reset_mente_objetos()
	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_file(ESCENA_BOSQUE)

func _escapar() -> void:
	if _terminado:
		return
	_terminado = true
	_timer_activo = false
	if _jugador != null:
		_jugador.desactivar_control()
	var fade := _crear_fade()
	var tw := create_tween()
	tw.tween_property(fade, "color", Color(0, 0, 0, 1), 0.9)
	await tw.finished
	GameState.nina_acepto_ayudar = false
	GameState.reset_mente_objetos()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file(ESCENA_BOSQUE)

# ──────────────────────────────────────────────
#  UI
# ──────────────────────────────────────────────
func _construir_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)

	var reloj_bg := PanelContainer.new()
	reloj_bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	reloj_bg.position = Vector2(20, 20)
	reloj_bg.size = Vector2(160, 70)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.0, 0.0, 0.75)
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	style.border_color = Color(0.8, 0.1, 0.1, 0.9)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2;  style.border_width_bottom = 2
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 8;   style.content_margin_bottom = 8
	reloj_bg.add_theme_stylebox_override("panel", style)
	_canvas.add_child(reloj_bg)

	_reloj_label = Label.new()
	_reloj_label.text = "⏱ 15.0"
	_reloj_label.add_theme_font_size_override("font_size", 32)
	_reloj_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	_reloj_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_reloj_label.add_theme_constant_override("outline_size", 4)
	_reloj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reloj_bg.add_child(_reloj_label)

	_checklist_root = VBoxContainer.new()
	_checklist_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_checklist_root.position = Vector2(20, 100)
	_checklist_root.add_theme_constant_override("separation", 6)
	_canvas.add_child(_checklist_root)
	_check_peluche = _crear_check_label("☐ Peluche")
	_check_tijeras = _crear_check_label("☐ Tijeras")
	_check_zapato  = _crear_check_label("☐ Zapato")

	var escape_lbl := Label.new()
	escape_lbl.text = "[X] Escapar"
	escape_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	escape_lbl.position = Vector2(20, -60)
	escape_lbl.add_theme_font_size_override("font_size", 26)
	escape_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.85))
	escape_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	escape_lbl.add_theme_constant_override("outline_size", 3)
	_canvas.add_child(escape_lbl)

	_prompt_label = Label.new()
	_prompt_label.text = ""
	_prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt_label.position = Vector2(0, -90)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 36)
	_prompt_label.add_theme_color_override("font_color", Color(1, 1, 0.7, 1))
	_prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt_label.add_theme_constant_override("outline_size", 5)
	_canvas.add_child(_prompt_label)

	_jumpscare_rect = ColorRect.new()
	_jumpscare_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_jumpscare_rect.color = Color(0.6, 0.0, 0.0, 0.0)
	_jumpscare_rect.z_index = 999
	_jumpscare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_jumpscare_rect)

func _crear_check_label(texto: String) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.95))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	_checklist_root.add_child(lbl)
	return lbl

func _crear_fade() -> ColorRect:
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.z_index = 1000
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(fade)
	return fade
