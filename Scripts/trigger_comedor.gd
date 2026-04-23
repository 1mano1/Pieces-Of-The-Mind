extends Area3D

@export var escena_demencia_path: NodePath
var _activado := false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Solo activar si: la intro terminó Y la tarea de la hija ya se completó
	if not GameState.intro_terminada:
		return
	if not GameState.tarea_hija_completa:
		return
	if _activado or body.name != "Jugador":
		return
	_activado = true
	var ed = get_node_or_null(escena_demencia_path)
	if ed:
		ed.activar_demencia()
