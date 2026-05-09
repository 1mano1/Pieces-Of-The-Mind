extends Node3D

# Referencia directa al jugador en esta escena
@onready var jugador: CharacterBody3D = $Jugador

@export var spawn_desde_cocina: Vector3 = Vector3(0.0, 1.2, 0.0)
@export_range(-180.0, 180.0, 1.0) var rotacion_spawn_desde_cocina_y_deg: float = 0.0
@export_file("*.png", "*.webp", "*.jpg") var textura_cordura_path: String = "res://Assets/barra_de_cordura.png"
@export_range(120.0, 120.0, 1.0) var duracion_cordura_segundos: float = 120.0
@export var mostrar_cordura_en_bosque: bool = true
@export_range(48.0, 512.0, 1.0) var tamano_cordura_px: float = 170.0
@export var hotbar_activa_en_bosque: bool = true
@export var enemigo_activo_en_bosque: bool = false
@export_file("*.tscn", "*.glb", "*.gltf") var enemy_model_path: String = ""
@export var enemy_spawn_offset_from_player: Vector3 = Vector3(12.0, 0.0, 12.0)
@export_range(-180.0, 180.0, 1.0) var enemy_spawn_rot_y_deg: float = 0.0
@export var niebla_dinamica_activa: bool = true
@export_range(0.0, 4000.0, 1.0) var niebla_distancia_inicio: float = 40.0
@export_range(1.0, 6000.0, 1.0) var niebla_distancia_maxima: float = 320.0
@export_range(0.0, 1.0, 0.001) var niebla_densidad_cercana: float = 0.004
@export_range(0.0, 1.0, 0.001) var niebla_densidad_profunda: float = 0.03
@export var color_niebla_profunda: Color = Color(0.53, 0.56, 0.55, 1.0)
@export_range(0.05, 1.0, 0.01) var niebla_suavizado: float = 0.18

# Renderizado inteligente estilo chunks (tipo Minecraft):
# solo deja visibles chunks cercanos al jugador para ahorrar recursos.
@export var render_inteligente_activo: bool = true
@export_range(8.0, 128.0, 1.0) var tamano_chunk: float = 24.0
@export_range(1, 8, 1) var radio_chunks_visibles: int = 2
@export_range(0.05, 1.0, 0.01) var intervalo_actualizacion_chunks: float = 0.2
@export_range(10, 5000, 10) var nodos_por_frame_cache: int = 300

var _cache_construida: bool = false
var _acum_actualizacion: float = 0.0
var _chunk_jugador_actual: Vector2i = Vector2i(2147483647, 2147483647)
var _chunks_visuales: Dictionary = {}

var _cordura_actual: float = 100.0
var _hud_cordura_creado: bool = false
var _hud_cordura: Control = null
var _cordura_icono: TextureRect = null
var _cordura_icono_atlas: AtlasTexture = null
var _cordura_inicio_msec: int = 0
var _cordura_strip_region: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)
var _cordura_frame_ancho: float = 0.0
var _cordura_frame_alto: float = 0.0
var _hotbar_bosque: Control = null
var _enemy_controller: CharacterBody3D = null
var _hotbar_retry_time: float = 0.0
var _enemy_retry_time: float = 0.0
var _world_environment: WorldEnvironment = null
var _niebla_origen_xz: Vector2 = Vector2.ZERO
var _niebla_densidad_actual: float = 0.0

const CORDURA_COLS: int = 5
const CORDURA_ROWS: int = 4

func _ready():
	_limpiar_capas_cinematica()
	_detener_audio_respiracion()
	_aplicar_spawn_desde_transicion_si_corresponde()
	if not jugador.is_in_group("player"):
		jugador.add_to_group("player")
	jugador.activar_control()
	_configurar_niebla_dinamica()
	call_deferred("_setup_hotbar_bosque")
	call_deferred("_setup_enemy_spider")
	call_deferred("_spawn_arboles")
	call_deferred("_setup_npc_nina")
	call_deferred("_verificar_regreso_de_mente")

	_cordura_actual = 100.0
	_hud_cordura_creado = false
	_hud_cordura = null
	_cordura_icono = null
	_cordura_icono_atlas = null
	_cordura_inicio_msec = 0
	_cordura_strip_region = Rect2(0.0, 0.0, 0.0, 0.0)
	_cordura_frame_ancho = 0.0

	if render_inteligente_activo:
		call_deferred("_iniciar_render_inteligente")

func _exit_tree() -> void:
	_teardown_hotbar_bosque()

func _is_bosque_scene_active() -> bool:
	var current := get_tree().current_scene
	if current == null:
		return false
	if current == self:
		return true
	return "bosque" in String(current.name).to_lower()

func _setup_hotbar_bosque() -> void:
	if _hotbar_bosque != null and is_instance_valid(_hotbar_bosque):
		_hotbar_bosque.visible = true
		return

	var canvas := jugador.get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas == null:
		push_warning("nivel_bosque: No se pudo crear hotbar (CanvasLayer no encontrado).")
		return

	var hotbar_script := load("res://Scripts/hotbar_bosque.gd") as Script
	if hotbar_script == null:
		push_warning("nivel_bosque: No se pudo cargar Scripts/hotbar_bosque.gd")
		return

	var hotbar := hotbar_script.new() as Control
	if hotbar == null:
		push_warning("nivel_bosque: Error al instanciar hotbar_bosque.gd")
		return

	hotbar.name = "HotbarBosqueUI"
	hotbar.visible = true
	# hotbar.z_index = 90  # Quitamos esto temporalmente por si colisiona con otros CanvasItems en Godot 4
	canvas.add_child(hotbar)
	_hotbar_bosque = hotbar

	if _hotbar_bosque.has_signal("active_slot_changed") and not _hotbar_bosque.active_slot_changed.is_connected(_on_hotbar_active_slot_changed):
		_hotbar_bosque.active_slot_changed.connect(_on_hotbar_active_slot_changed)

	_on_hotbar_active_slot_changed(GameState.hotbar_selected_index, GameState.get_hotbar_slot(GameState.hotbar_selected_index))

func _teardown_hotbar_bosque() -> void:
	if _hotbar_bosque == null:
		return
	if is_instance_valid(_hotbar_bosque):
		if _hotbar_bosque.has_signal("active_slot_changed") and _hotbar_bosque.active_slot_changed.is_connected(_on_hotbar_active_slot_changed):
			_hotbar_bosque.active_slot_changed.disconnect(_on_hotbar_active_slot_changed)
		_hotbar_bosque.queue_free()
	_hotbar_bosque = null

func _on_hotbar_active_slot_changed(active_index: int, slot_data: Dictionary) -> void:
	if is_instance_valid(jugador) and jugador.has_method("on_hotbar_slot_changed"):
		jugador.call("on_hotbar_slot_changed", active_index, slot_data)

func _resolve_enemy_model_path() -> String:
	if not enemy_model_path.is_empty() and ResourceLoader.exists(enemy_model_path):
		return enemy_model_path

	var candidates := [
		"res://Modelos/araña/enemigos/maxdamage_scab-low-poly_gltf/gltf/maxdamage_scab-low-poly.gltf",
		"res://assets/personajes/enemigos/maxdamage_scab-low-poly_gltf/gltf/maxdamage_scab-low-poly.gltf"
	]
	for candidate in candidates:
		if ResourceLoader.exists(candidate):
			return candidate

	return ""

func _setup_enemy_spider() -> void:
	if not enemigo_activo_en_bosque:
		return
	if _enemy_controller != null and is_instance_valid(_enemy_controller):
		return

	var target := _find_existing_enemy_node(self)
	if target != null:
		_enemy_controller = _ensure_enemy_character_body(target)
		if _enemy_controller != null:
			_apply_enemy_script(_enemy_controller)
		return

	var model_path := _resolve_enemy_model_path()
	if model_path.is_empty():
		push_warning("nivel_bosque: No se encontro modelo de enemigo para instanciar.")
		return

	var packed := load(model_path) as PackedScene
	if packed == null:
		push_warning("nivel_bosque: No se pudo cargar PackedScene del enemigo.")
		return

	var body := CharacterBody3D.new()
	body.name = "EnemigoArana"
	add_child(body)
	
	body.global_position = jugador.global_position + enemy_spawn_offset_from_player
	body.global_position.y = jugador.global_position.y
	body.rotation.y = deg_to_rad(enemy_spawn_rot_y_deg)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.2
	collision.shape = shape
	body.add_child(collision)

	var visual := packed.instantiate() as Node3D
	if visual != null:
		visual.name = "Visual"
		body.add_child(visual)
		visual.position = Vector3(0.0, -0.8, 0.0)

	_enemy_controller = body
	_apply_enemy_script(body)

func _find_existing_enemy_node(root: Node) -> Node3D:
	if root == null:
		return null

	for child in root.get_children():
		if child == jugador:
			continue
		if not (child is Node3D):
			continue

		var n3d := child as Node3D
		var lname := String(n3d.name).to_lower()
		if "enemy" in lname or "enemigo" in lname or "scab" in lname or "spider" in lname or "aran" in lname:
			return n3d

		var found := _find_existing_enemy_node(n3d)
		if found != null:
			return found

	return null

func _ensure_enemy_character_body(node: Node3D) -> CharacterBody3D:
	if node is CharacterBody3D:
		var body := node as CharacterBody3D
		if body.get_node_or_null("CollisionShape3D") == null:
			var collision := CollisionShape3D.new()
			var shape := CapsuleShape3D.new()
			shape.radius = 0.45
			shape.height = 1.2
			collision.shape = shape
			body.add_child(collision)
		return body

	var old_parent := node.get_parent()
	if old_parent == null:
		return null

	var wrapper := CharacterBody3D.new()
	wrapper.name = "%s_Controller" % String(node.name)
	old_parent.add_child(wrapper)
	wrapper.global_transform = node.global_transform
	node.reparent(wrapper)
	node.transform = Transform3D.IDENTITY

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.2
	collision.shape = shape
	wrapper.add_child(collision)

	return wrapper

func _apply_enemy_script(body: CharacterBody3D) -> void:
	if body == null:
		return
	var enemy_script := load("res://enemy.gd") as Script
	if enemy_script == null:
		push_warning("nivel_bosque: No se pudo cargar res://enemy.gd")
		return

	if body.get_script() != enemy_script:
		body.set_script(enemy_script)

	var has_player_path: bool = false
	for p in body.get_property_list():
		if String((p as Dictionary).get("name", "")) == "player_path":
			has_player_path = true
			break

	if has_player_path:
		body.set("player_path", body.get_path_to(jugador))

	body.set_physics_process(true)
	if body.has_method("_resolve_player"):
		body.call("_resolve_player")

func _limpiar_capas_cinematica() -> void:
	var color_rect = jugador.get_node_or_null("CanvasLayer/ColorRect") as CanvasItem
	if color_rect != null:
		color_rect.visible = false
	var blur_rect = jugador.get_node_or_null("CanvasLayer/BlurRect") as CanvasItem
	if blur_rect != null:
		blur_rect.visible = false
	var parpado = jugador.get_node_or_null("CanvasLayer/ParpadeoShader") as CanvasItem
	if parpado != null:
		parpado.visible = false
	var dialogo = jugador.get_node_or_null("CanvasLayer/DialogoLabel") as CanvasItem
	if dialogo != null:
		dialogo.visible = false
	var transicion = jugador.get_node_or_null("CanvasLayer/TransicionBosque") as CanvasItem
	if transicion != null:
		transicion.visible = false

func _detener_audio_respiracion() -> void:
	var audio_resp = jugador.get_node_or_null("AudioRespiracion")
	if audio_resp != null and audio_resp.has_method("stop"):
		audio_resp.stop()

func _aplicar_spawn_desde_transicion_si_corresponde() -> void:
	if not GameState.transicion_desde_cocina:
		return

	GameState.transicion_desde_cocina = false
	GameState.intro_terminada = true
	GameState.tarea_hija_completa = true

	var pos_objetivo := spawn_desde_cocina
	var yaw_objetivo := deg_to_rad(rotacion_spawn_desde_cocina_y_deg)
	if GameState.tiene_spawn_bosque:
		pos_objetivo = GameState.spawn_bosque_pos
		yaw_objetivo = GameState.spawn_bosque_rot_y

	jugador.global_position = pos_objetivo
	jugador.rotation.y = yaw_objetivo
	jugador.velocity = Vector3.ZERO

	var head := jugador.get_node_or_null("Head") as Node3D
	if head != null:
		head.rotation = Vector3.ZERO

	GameState.tiene_spawn_bosque = false
	GameState.spawn_bosque_pos = Vector3.ZERO
	GameState.spawn_bosque_rot_y = 0.0

func _iniciar_render_inteligente() -> void:
	await _construir_cache_chunks_async()
	_cache_construida = true
	_forzar_recalculo_chunks()

func _construir_cache_chunks_async() -> void:
	_chunks_visuales.clear()
	var pila: Array[Node] = [self]
	var procesados: int = 0

	while not pila.is_empty():
		var nodo: Node = pila.pop_back()

		if _es_visual_optimizable(nodo):
			var visual := nodo as VisualInstance3D
			var key := _chunk_key(visual.global_position)
			if not _chunks_visuales.has(key):
				_chunks_visuales[key] = []
			(_chunks_visuales[key] as Array).append(visual)

		for hijo in nodo.get_children():
			if hijo == jugador:
				continue
			if hijo is CanvasLayer:
				continue
			pila.append(hijo)

		procesados += 1
		if procesados % nodos_por_frame_cache == 0:
			await get_tree().process_frame

func _es_visual_optimizable(nodo: Node) -> bool:
	if not (nodo is VisualInstance3D):
		return false
	if nodo.is_in_group("always_visible"):
		return false

	var nombre := String(nodo.name)
	if "Terrain3D" in nombre or "Terrain" in nombre:
		return false
	if "Sky" in nombre:
		return false

	return true

func _chunk_key(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / tamano_chunk), floori(pos.z / tamano_chunk))

func _forzar_recalculo_chunks() -> void:
	_chunk_jugador_actual = Vector2i(2147483647, 2147483647)
	_actualizar_visibilidad_chunks()

func _configurar_niebla_dinamica() -> void:
	if not niebla_dinamica_activa:
		return

	_world_environment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _world_environment == null:
		push_warning("nivel_bosque: No se encontro WorldEnvironment para la niebla dinamica.")
		return

	if _world_environment.environment == null:
		_world_environment.environment = Environment.new()

	var env := _world_environment.environment
	env.fog_enabled = true
	env.fog_light_color = color_niebla_profunda

	_niebla_origen_xz = Vector2(jugador.global_position.x, jugador.global_position.z)
	_niebla_densidad_actual = clampf(env.fog_density, 0.0, 1.0)

	_actualizar_niebla_por_profundidad(0.0)

func _actualizar_niebla_por_profundidad(delta: float) -> void:
	if not niebla_dinamica_activa:
		return
	if _world_environment == null or _world_environment.environment == null:
		return
	if not is_instance_valid(jugador):
		return

	var env := _world_environment.environment
	var pos_xz := Vector2(jugador.global_position.x, jugador.global_position.z)
	var distancia_desde_entrada := pos_xz.distance_to(_niebla_origen_xz)
	var distancia_tope := maxf(niebla_distancia_maxima, niebla_distancia_inicio + 1.0)
	var profundidad := clampf(inverse_lerp(niebla_distancia_inicio, distancia_tope, distancia_desde_entrada), 0.0, 1.0)

	var densidad_min := minf(niebla_densidad_cercana, niebla_densidad_profunda)
	var densidad_max := maxf(niebla_densidad_cercana, niebla_densidad_profunda)
	var densidad_objetivo := lerpf(densidad_min, densidad_max, profundidad)

	if delta <= 0.0:
		_niebla_densidad_actual = densidad_objetivo
	else:
		var t_suavizado := clampf(delta * (niebla_suavizado * 60.0), 0.0, 1.0)
		_niebla_densidad_actual = lerpf(_niebla_densidad_actual, densidad_objetivo, t_suavizado)

	env.fog_density = _niebla_densidad_actual
	env.fog_light_color = color_niebla_profunda.darkened(0.16 * profundidad)

func _process(delta: float) -> void:
	_actualizar_cordura()
	_actualizar_niebla_por_profundidad(delta)

	if _hotbar_bosque == null or not is_instance_valid(_hotbar_bosque):
		_hotbar_retry_time += delta
		if _hotbar_retry_time >= 1.0:
			_hotbar_retry_time = 0.0
			_setup_hotbar_bosque()
	else:
		_hotbar_retry_time = 0.0

	if enemigo_activo_en_bosque and (_enemy_controller == null or not is_instance_valid(_enemy_controller)):
		_enemy_retry_time += delta
		if _enemy_retry_time >= 1.0:
			_enemy_retry_time = 0.0
			_setup_enemy_spider()
	else:
		_enemy_retry_time = 0.0

	if not render_inteligente_activo or not _cache_construida:
		return

	_acum_actualizacion += delta
	if _acum_actualizacion < intervalo_actualizacion_chunks:
		return
	_acum_actualizacion = 0.0

	_actualizar_visibilidad_chunks()

func _actualizar_visibilidad_chunks() -> void:
	if not is_instance_valid(jugador):
		return

	var chunk_actual: Vector2i = _chunk_key(jugador.global_position)
	if chunk_actual == _chunk_jugador_actual:
		return
	_chunk_jugador_actual = chunk_actual

	var keys: Array = _chunks_visuales.keys()
	for key in keys:
		if not (key is Vector2i):
			continue
		var chunk: Vector2i = key
		var visible: bool = (
			absi(chunk.x - chunk_actual.x) <= radio_chunks_visibles and
			absi(chunk.y - chunk_actual.y) <= radio_chunks_visibles
		)

		var lista: Array = _chunks_visuales.get(key, [])
		var lista_filtrada: Array = []
		for item in lista:
			if not is_instance_valid(item):
				continue
			if not (item is VisualInstance3D):
				continue
			var visual: VisualInstance3D = item
			lista_filtrada.append(visual)
			visual.visible = visible

		_chunks_visuales[key] = lista_filtrada

func _actualizar_cordura() -> void:
	if not mostrar_cordura_en_bosque:
		return

	# Evita mostrar HUD durante la intro; aparece al llegar al bosque con control.
	if not _hud_cordura_creado:
		if not GameState.intro_terminada:
			return
		_crear_hud_cordura()
		if not _hud_cordura_creado:
			return

	var ahora_msec: int = Time.get_ticks_msec()
	var duracion_msec: int = int(maxf(duracion_cordura_segundos, 1.0) * 1000.0)
	var transcurrido_msec: int = maxi(ahora_msec - _cordura_inicio_msec, 0)
	var progreso: float = clampf(float(transcurrido_msec) / float(duracion_msec), 0.0, 1.0)
	_cordura_actual = (1.0 - progreso) * 100.0

	_refrescar_hud_cordura()

func _crear_hud_cordura() -> void:
	if _hud_cordura_creado:
		return

	var canvas := jugador.get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas == null:
		push_warning("nivel_bosque: No se pudo crear HUD de cordura (CanvasLayer no encontrado).")
		return

	var root := canvas.get_node_or_null("HUDCordura") as Control
	if root != null:
		root.queue_free()
	
	root = Control.new()
	root.name = "HUDCordura"
	canvas.add_child(root)

	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = Vector2(22.0, 18.0)
	root.size = Vector2(tamano_cordura_px, tamano_cordura_px)

	_hud_cordura = root

	var icono = TextureRect.new()
	icono.name = "IconoCordura"
	root.add_child(icono)
	
	icono.set_anchors_preset(Control.PRESET_TOP_LEFT)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icono.position = Vector2.ZERO
	icono.size = Vector2(tamano_cordura_px, tamano_cordura_px)
	_cordura_icono = icono

	var textura := load("res://Assets/barra_de_cordura.png") as Texture2D
	if textura != null and _cordura_icono != null:
		_cordura_strip_region = Rect2(0.0, 0.0, float(textura.get_width()), float(textura.get_height()))
		_cordura_frame_ancho = _cordura_strip_region.size.x / float(CORDURA_COLS)
		_cordura_frame_alto = _cordura_strip_region.size.y / float(CORDURA_ROWS)

		var atlas := AtlasTexture.new()
		atlas.atlas = textura
		atlas.region = Rect2(0, 0, _cordura_frame_ancho, _cordura_frame_alto)
		_cordura_icono_atlas = atlas
		_cordura_icono.texture = _cordura_icono_atlas
	else:
		push_warning("nivel_bosque: No se pudo cargar Assets/barra_de_cordura.png para HUD de cordura.")

	_cordura_inicio_msec = Time.get_ticks_msec()
	_hud_cordura_creado = true
	_refrescar_hud_cordura()

func _refrescar_hud_cordura() -> void:
	if not _hud_cordura_creado:
		return

	var porcentaje := int(round(_cordura_actual))
	porcentaje = clampi(porcentaje, 0, 100)

	if _cordura_icono_atlas != null and _cordura_icono_atlas.atlas != null:
		var total_frames := CORDURA_COLS * CORDURA_ROWS
		var index := int(round((1.0 - (float(porcentaje) / 100.0)) * float(total_frames - 1)))
		index = clampi(index, 0, total_frames - 1)
		
		var col := index % CORDURA_COLS
		var row := index / CORDURA_COLS
		
		_cordura_icono_atlas.region = Rect2(
			_cordura_strip_region.position.x + (_cordura_frame_ancho * float(col)),
			_cordura_strip_region.position.y + (_cordura_frame_alto * float(row)),
			_cordura_frame_ancho,
			_cordura_frame_alto
		)

func _detectar_region_util_textura(textura: Texture2D) -> Rect2:
	if textura == null:
		return Rect2(0.0, 0.0, 0.0, 0.0)

	var img: Image = textura.get_image()
	if img == null or img.is_empty():
		return Rect2(0.0, 0.0, float(textura.get_width()), float(textura.get_height()))

	var w: int = img.get_width()
	var h: int = img.get_height()
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1

	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.03 or c.g > 0.03 or c.b > 0.03:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2(0.0, 0.0, float(w), float(h))

	return Rect2(
		float(min_x),
		float(min_y),
		float(max_x - min_x + 1),
		float(max_y - min_y + 1)
	)

func _spawn_arboles() -> void:
	# Carga inteligente: intentamos cargar tu version si la hiciste, sino cargamos el DAE
	var arbol_mesh_sc = load("res://Assets/Arboles/Arboles/Arboles_Texturizados.tscn") as PackedScene
	var usar_texturizado_automatico = false
	
	if not arbol_mesh_sc:
		arbol_mesh_sc = load("res://Assets/Arboles/Arboles/Arboles.dae") as PackedScene
		usar_texturizado_automatico = true
	
	if not arbol_mesh_sc:
		push_warning("No se pudo cargar la escena de árboles en absoluto.")
		return
		
	var parent_node = Node3D.new()
	parent_node.name = "ArbolesGenerados"
	add_child(parent_node)
	
	# Pre-cargar imagenes/texturas
	var tex_madera = load("res://Assets/Arboles/Arboles/Madera.jpg")
	var tex_hoja = load("res://Assets/Arboles/Arboles/Hoja.png")
	var tex_rama = load("res://Assets/Arboles/Arboles/Rama.png")
	var tex_rama2 = load("res://Assets/Arboles/Arboles/Rama2.png")
	var tex_rama3 = load("res://Assets/Arboles/Arboles/Rama3.png")
	
	# Diccionario para reusar los materiales y no crear miles de copias
	var mat_cache = {}
	
	for i in range(150):
		var inst = arbol_mesh_sc.instantiate() as Node3D
		parent_node.add_child(inst)
		
		if usar_texturizado_automatico:
			_aplicar_texturas_arbol(inst, mat_cache, tex_madera, tex_hoja, tex_rama, tex_rama2, tex_rama3)
		
		var rand_x = randf_range(-100.0, 100.0)
		var rand_z = randf_range(-100.0, 100.0)
		var scale_rnd = randf_range(0.8, 1.5)
		inst.scale = Vector3(scale_rnd, scale_rnd, scale_rnd)
		inst.rotation_degrees.y = randf_range(0.0, 360.0)
		inst.global_position = Vector3(rand_x, 0.0, rand_z)
		
		# Agregamos colisiones de manera correcta a cada sub-arbol dentro del archivo DAE
		_agregar_colisiones_a_mallas(inst)

func _agregar_colisiones_a_mallas(nodo: Node) -> void:
	# Si el nodo es una malla (el modelo visual de un arbol individual)
	if nodo is MeshInstance3D:
		var s_body = StaticBody3D.new()
		var col_shape = CollisionShape3D.new()
		var cyl_shape = CylinderShape3D.new()
		
		# Grosor y alto del tronco
		cyl_shape.radius = 0.5  
		cyl_shape.height = 15.0
		col_shape.shape = cyl_shape
		
		# Movemos la colision a la altura del tronco
		col_shape.position.y = 7.5
		
		s_body.add_child(col_shape)
		nodo.add_child(s_body)
		
	# Buscamos en los sub-nodos recursivamente
	for child in nodo.get_children():
		_agregar_colisiones_a_mallas(child)

func _aplicar_texturas_arbol(nodo: Node, mat_cache: Dictionary, t_mad, t_hoj, t_ram, t_ram2, t_ram3) -> void:
	if nodo is MeshInstance3D and nodo.mesh != null:
		var mesh = nodo.mesh
		for surf_idx in range(mesh.get_surface_count()):
			var old_mat = mesh.surface_get_material(surf_idx)
			if old_mat:
				var m_name = old_mat.resource_name
				if m_name == "": m_name = str(old_mat.resource_path)
				if m_name == "": m_name = str(old_mat)
				
				# Si ya creamos este material antes, lo reciclamos
				if mat_cache.has(m_name):
					nodo.set_surface_override_material(surf_idx, mat_cache[m_name])
				else:
					var new_mat = StandardMaterial3D.new()
					# Determinar texture en base al nombre del material del DAE
					if "Hojas" in m_name:
						new_mat.albedo_texture = t_hoj
						new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
						new_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					elif "Rama.002" in m_name:
						new_mat.albedo_texture = t_ram3
						new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
						new_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					elif "Rama.001" in m_name:
						new_mat.albedo_texture = t_ram2
						new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
						new_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					elif "Rama" in m_name:
						new_mat.albedo_texture = t_ram
						new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
						new_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					else:
						# Asume tronco madera
						new_mat.albedo_texture = t_mad
					
					mat_cache[m_name] = new_mat
					nodo.set_surface_override_material(surf_idx, new_mat)
	
	# Recursividad para hijos
	for child in nodo.get_children():
		_aplicar_texturas_arbol(child, mat_cache, t_mad, t_hoj, t_ram, t_ram2, t_ram3)

# ── NPC Niña ──
var _npc_nina: Node3D = null

func _setup_npc_nina() -> void:
	## CORRECCIÓN: busca también por nombre alternativo "NpcNinaSpawn"
	_npc_nina = get_node_or_null("NpcNina") as Node3D
	if _npc_nina == null:
		_npc_nina = get_node_or_null("NpcNinaSpawn") as Node3D
	if _npc_nina != null and is_instance_valid(_npc_nina):
		# Ya existe en escena: solo corregir su rotación por si acaso
		_npc_nina.rotation = Vector3(0.0, _npc_nina.rotation.y, 0.0)
		return

	# Crear por código
	var nina_scene := load("res://Escenas/npc_nina.tscn") as PackedScene
	if nina_scene == null:
		push_warning("nivel_bosque: No se pudo cargar npc_nina.tscn")
		return

	var nina := nina_scene.instantiate() as Node3D
	nina.name = "NpcNinaSpawn"

	# Asegurar acción de interacción correcta
	if nina is Interactable:
		nina.prompt_input = "Interactuar"

	add_child(nina)

	# ── Calcular posición base (frente al jugador al regresar) ──
	var pos_referencia := spawn_desde_cocina
	var rot_referencia := deg_to_rad(rotacion_spawn_desde_cocina_y_deg)
	# Al regresar de la Mente, GameState tiene la posición guardada del jugador
	if GameState.tiene_spawn_bosque:
		pos_referencia = GameState.spawn_bosque_pos
		rot_referencia = GameState.spawn_bosque_rot_y

	var forward := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, rot_referencia)
	var pos_xz := pos_referencia + (forward * 3.5)

	# ── CORRECCIÓN DE ALTURA: RayCast hacia abajo para encontrar suelo real ──
	# Lanzar desde arriba hacia abajo para no quedar dentro del terreno
	var ray_inicio := Vector3(pos_xz.x, pos_referencia.y + 10.0, pos_xz.z)
	var ray_fin    := Vector3(pos_xz.x, pos_referencia.y - 10.0, pos_xz.z)
	var query := PhysicsRayQueryParameters3D.create(ray_inicio, ray_fin)
	query.exclude = [nina.get_rid()] if nina.get_class() == "StaticBody3D" else []
	var espacio := get_world_3d().direct_space_state
	var result  := espacio.intersect_ray(query)

	var pos_final: Vector3
	if result.size() > 0:
		# Suelo encontrado: posicionar encima con offset mínimo
		pos_final = result["position"]
		pos_final.y += 0.05  # justo encima del suelo
	else:
		# Fallback: usar la Y del jugador (mejor que un offset fijo arbitrario)
		pos_final = Vector3(pos_xz.x, pos_referencia.y, pos_xz.z)

	nina.global_position = pos_final

	# ── CORRECCIÓN DE ROTACIÓN: solo eje Y, sin inclinación ──
	# Calcular el ángulo Y manualmente sin usar look_at (que puede inclinar X/Z)
	var dir_a_jugador := pos_referencia - pos_final
	dir_a_jugador.y = 0.0  # Ignorar diferencia de altura
	if dir_a_jugador.length_squared() > 0.001:
		var angulo_y := atan2(dir_a_jugador.x, dir_a_jugador.z)
		nina.rotation = Vector3(0.0, angulo_y, 0.0)
	else:
		nina.rotation = Vector3.ZERO

	_npc_nina = nina

func _verificar_regreso_de_mente() -> void:
	if not GameState.nina_objetos_entregados:
		return
	if _npc_nina == null:
		return
	# Diálogo de agradecimiento + pastilla
	call_deferred("_dialogo_recompensa_nina")

func _dialogo_recompensa_nina() -> void:
	if jugador == null or _npc_nina == null:
		return
	var dist := jugador.global_position.distance_to(_npc_nina.global_position)
	if dist > 8.0:
		# Esperar a que se acerque
		await get_tree().create_timer(1.0).timeout
		call_deferred("_dialogo_recompensa_nina")
		return
	jugador.desactivar_control()
	await _mostrar_dialogo_bosque("Nina: Lo lograste... gracias.", 3.0)
	await _mostrar_dialogo_bosque("Nina: Toma, esto te ayudará.", 3.0)
	# Dar pastilla
	GameState.agregar_item_hotbar("pildora", 1, "res://Assets/pildora.png")
	await _mostrar_dialogo_bosque("[ Recibiste una Píldora ]", 2.5)
	_ocultar_dialogo_bosque()
	jugador.activar_control()

func _mostrar_dialogo_bosque(texto: String, dur: float) -> void:
	var label := jugador.get_node_or_null("CanvasLayer/DialogoLabel") as Label
	if label != null:
		label.text = texto
		label.visible = true
		label.modulate.a = 1.0
	await get_tree().create_timer(dur).timeout

func _ocultar_dialogo_bosque() -> void:
	var label := jugador.get_node_or_null("CanvasLayer/DialogoLabel") as Label
	if label != null:
		label.visible = false

func _verificar_regreso_fallido() -> void:
	# Si volvió del bosque habiendo aceptado pero sin completar = escapó o murió
	if GameState.nina_hablado_antes and not GameState.nina_acepto_ayudar and not GameState.nina_objetos_entregados:
		# El npc_nina al volver a hablar con ella mostrará el diálogo adecuado automáticamente
		pass
