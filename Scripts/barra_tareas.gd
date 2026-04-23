extends CanvasLayer

@onready var panel_img   = $PanelImg
@onready var tarea_label = $TareaLabel
@onready var check_label = $CheckLabel

var _tw: Tween
const PANEL_W   = 300.0
const X_VISIBLE = -PANEL_W - 20.0   # anclado a borde derecho
const X_OCULTO  = 20.0              # fuera de pantalla (positivo = más a la derecha)

func _ready():
	add_to_group("barra_tareas")
	visible = false
	_set_x(X_OCULTO)

func _set_x(x: float) -> void:
	panel_img.offset_right   = x
	panel_img.offset_left    = x - PANEL_W
	tarea_label.offset_right = x
	tarea_label.offset_left  = x - PANEL_W
	check_label.offset_right = x
	check_label.offset_left  = x - PANEL_W

func deslizar_entrar() -> void:
	visible = true
	check_label.visible    = false
	check_label.modulate.a = 0.0
	_set_x(X_OCULTO)
	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_method(_set_x, X_OCULTO, X_VISIBLE, 0.75)
	await _tw.finished

func completar_tarea() -> void:
	check_label.visible    = true
	check_label.modulate.a = 0.0
	_tw = create_tween()
	_tw.tween_property(check_label, "modulate:a", 1.0, 0.4)
	await _tw.finished
	await get_tree().create_timer(1.5).timeout
	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_method(_set_x, X_VISIBLE, X_OCULTO, 0.6)
	await _tw.finished
	visible = false
