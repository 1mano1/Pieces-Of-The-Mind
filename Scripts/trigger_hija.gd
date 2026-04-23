extends Area3D

@export var barra_tareas_path: NodePath

const DIALOGO_HIJA = "Aqui deberia estar... Donde se habra metido?"

var _activado := false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not GameState.intro_terminada:
		return
	if _activado or body.name != "Jugador":
		return
	_activado = true
	await _secuencia(body)

func _secuencia(jugador: Node) -> void:
	var lineas_dialogo: Array[String] = [DIALOGO_HIJA]
	await jugador.reproducir_dialogo(lineas_dialogo, 60.0, 3.5)

	# Buscar barra_tareas por NodePath primero, luego por grupo
	var bt: Node = null
	if barra_tareas_path and not barra_tareas_path.is_empty():
		bt = get_node_or_null(barra_tareas_path)
	if bt == null:
		bt = get_tree().get_first_node_in_group("barra_tareas")
	if bt != null:
		await bt.completar_tarea()

	GameState.tarea_hija_completa = true
