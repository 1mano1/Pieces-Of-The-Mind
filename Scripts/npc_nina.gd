## npc_nina.gd
## NPC del alma de Nina en el bosque.
## CORRECCIONES:
##   - Rotación: look_at solo en eje Y (sin inclinación X/Z).
##   - Posicionamiento: RayCast hacia abajo para encontrar el suelo real al regresar de la mente.
extends Interactable

var _jugador: Node = null
var _en_dialogo: bool = false
var _esperando_yn: bool = false
var _presiono_y: bool = false
var _presiono_n: bool = false

@export var ruta_escena_mente: String = "res://Escenas/mente_nina.tscn"

func _ready() -> void:
	prompt_message = "Hablar con el Alma"
	prompt_input = "Interactuar"
	interacted.connect(_on_interacted)

	# Asegurar que el modelo sea visible y la cápsula no
	var visual = get_node_or_null("VisualNina")
	if visual:
		visual.visible = true
	var mesh = get_node_or_null("CollisionShape3D/MeshInstance3D")
	if mesh:
		mesh.visible = false

	# Corregir la rotación al inicializarse (puede llegar con transform incorrecto)
	_corregir_rotacion_vertical()

func _corregir_rotacion_vertical() -> void:
	## Preserva solo la rotación en Y, elimina cualquier inclinación en X o Z.
	rotation = Vector3(0.0, rotation.y, 0.0)

func mirar_hacia_jugador(pos_jugador: Vector3) -> void:
	## Hace que Nina mire al jugador SOLO rotando en Y, sin inclinarse.
	var dir := pos_jugador - global_position
	dir.y = 0.0  # Ignorar diferencia de altura
	if dir.length_squared() < 0.001:
		return
	var angulo_y := atan2(dir.x, dir.z)
	rotation = Vector3(0.0, angulo_y, 0.0)

func _on_interacted(body) -> void:
	if _en_dialogo:
		return
	_jugador = body
	_iniciar_dialogo()

func _unhandled_input(event: InputEvent) -> void:
	if not _esperando_yn:
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.physical_keycode == KEY_Y or ke.keycode == KEY_Y:
		_presiono_y = true
		get_viewport().set_input_as_handled()
	elif ke.physical_keycode == KEY_N or ke.keycode == KEY_N:
		_presiono_n = true
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	# Forzar visibilidad del modelo y ocultación de cápsula
	var mesh = get_node_or_null("CollisionShape3D/MeshInstance3D")
	if mesh and mesh.visible:
		mesh.visible = false
	var visual = get_node_or_null("VisualNina")
	if visual and not visual.visible:
		visual.visible = true

	# Mantener rotación vertical en todo momento (evita que física/look_at la incline)
	if rotation.x != 0.0 or rotation.z != 0.0:
		rotation = Vector3(0.0, rotation.y, 0.0)

	if not _esperando_yn:
		return
	if _presiono_y:
		_presiono_y = false
		_esperando_yn = false
		_on_acepto()
	elif _presiono_n:
		_presiono_n = false
		_esperando_yn = false
		_on_rechazo()

func _iniciar_dialogo() -> void:
	if _jugador == null or _en_dialogo:
		return
	_en_dialogo = true
	_jugador.desactivar_control()

	if GameState.nina_objetos_entregados:
		_cerrar_dialogo()
		return

	if GameState.nina_acepto_ayudar:
		await _linea("Alma: Recuerda... tienes tiempo limitado.", 2.5)
		_mostrar_texto("")
		_en_dialogo = false
		_entrar_a_mente()
		return

	if GameState.nina_hablado_antes:
		if not GameState.nina_acepto_ayudar:
			await _linea("Alma: Que paso... te dio miedo?", 2.5)
			await _linea("Alma: Aun puedes ayudarme. Lo intentaras de nuevo?", 2.5)
		else:
			await _linea("Alma: Entonces... me ayudaras?", 2.5)
		_pedir_yn()
		return

	await _linea("Jugador: Quien eres? Estas perdida?", 2.8)
	await _linea("Alma: ...", 2.0)
	await _linea("Alma: Tu eres el perdido aqui.", 2.5)
	await _linea("Alma: Pero yo puedo ayudarte... si me ayudas a mi.", 3.0)
	await _linea("Jugador: De que manera?", 2.0)
	await _linea("Alma: Necesito recuperar unos objetos importantes.", 2.8)
	await _linea("Alma: Me ayudas?", 2.0)
	GameState.nina_hablado_antes = true
	_pedir_yn()

func _pedir_yn() -> void:
	_mostrar_texto("[Y] Si     [N] No")
	_presiono_y = false
	_presiono_n = false
	_esperando_yn = true

func _on_acepto() -> void:
	GameState.nina_acepto_ayudar = true
	_en_dialogo = true
	_jugador.desactivar_control()
	await _linea("Alma: Gracias... entra en mi mente. Tienes 15 segundos.", 3.0)
	_mostrar_texto("")
	_en_dialogo = false
	_entrar_a_mente()

func _on_rechazo() -> void:
	_en_dialogo = true
	_jugador.desactivar_control()
	await _linea("Alma: ...", 1.5)
	_cerrar_dialogo()

func _entrar_a_mente() -> void:
	if _jugador == null:
		return
	var canvas := _jugador.get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas != null:
		var fade := canvas.get_node_or_null("FadeMente") as ColorRect
		if fade == null:
			fade = ColorRect.new()
			fade.name = "FadeMente"
			fade.set_anchors_preset(Control.PRESET_FULL_RECT)
			fade.color = Color(0, 0, 0, 0)
			fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fade.z_index = 500
			canvas.add_child(fade)
		GameState.tiene_spawn_bosque = true
		GameState.spawn_bosque_pos = _jugador.global_position
		GameState.spawn_bosque_rot_y = _jugador.rotation.y
		var tw := create_tween()
		tw.tween_property(fade, "color", Color(0, 0, 0, 1), 1.2)
		await tw.finished
	await get_tree().create_timer(0.3).timeout
	GameState.reset_mente_objetos()
	get_tree().change_scene_to_file(ruta_escena_mente)

func _cerrar_dialogo() -> void:
	_mostrar_texto("")
	_en_dialogo = false
	_esperando_yn = false
	if _jugador != null:
		_jugador.activar_control()

func _linea(texto: String, dur: float = 2.8) -> void:
	_mostrar_texto(texto)
	await get_tree().create_timer(dur).timeout

func _mostrar_texto(texto: String) -> void:
	if _jugador == null:
		return
	var label := _jugador.get_node_or_null("CanvasLayer/DialogoLabel") as Label
	if label == null:
		return
	if texto.is_empty():
		label.visible = false
	else:
		label.text    = texto
		label.visible = true
		label.modulate = Color.WHITE
		label.add_theme_font_size_override("font_size", 32)
		label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		label.anchor_top = 0.0
		label.offset_top = 10.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
