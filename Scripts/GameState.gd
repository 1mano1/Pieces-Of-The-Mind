## GameState.gd
## Autoload singleton — agrégalo en Proyecto > Ajustes del Proyecto > Autoload
## Nombre: GameState   Ruta: res://Scripts/GameState.gd

extends Node

signal inventory_changed
signal hotbar_slot_changed(active_slot: int, slot_data: Dictionary)

const HOTBAR_SIZE: int = 9

# true = la cinemática intro ya terminó y el jugador tiene control
var intro_terminada: bool = false

# true = el jugador ya visitó el cuarto de la hija y la tarea está completa
var tarea_hija_completa: bool = false

# Permite recargar nivel sin volver a ejecutar la intro (una sola vez).
var saltar_intro_una_vez: bool = false

# Señala que se entró al bosque desde la transición post cocina.
var transicion_desde_cocina: bool = false

# Spawn opcional de llegada al bosque.
var tiene_spawn_bosque: bool = false
var spawn_bosque_pos: Vector3 = Vector3.ZERO
var spawn_bosque_rot_y: float = 0.0

# Inventario base para hotbar (9 slots) persistente entre estados.
var hotbar_slots: Array[Dictionary] = []
var hotbar_selected_index: int = 0

func _ready() -> void:
	_ensure_hotbar_initialized()

func _empty_slot() -> Dictionary:
	return {
		"id": "",
		"count": 0,
		"icon_path": ""
	}

func _ensure_hotbar_initialized() -> void:
	if hotbar_slots.size() == HOTBAR_SIZE:
		_ensure_hotbar_has_flashlight()
		return

	hotbar_slots.clear()
	for i in range(HOTBAR_SIZE):
		hotbar_slots.append(_empty_slot())

	# Contenido inicial de ejemplo para pruebas.
	hotbar_slots[0] = {
		"id": "linterna",
		"count": 1,
		"icon_path": ""
	}
	hotbar_slots[1] = {
		"id": "pildora",
		"count": 3,
		"icon_path": "res://Assets/pildora.png"
	}
	hotbar_selected_index = 0
	emit_signal("inventory_changed")
	emit_signal("hotbar_slot_changed", hotbar_selected_index, get_hotbar_slot(hotbar_selected_index))

func _ensure_hotbar_has_flashlight() -> void:
	var has_linterna: bool = false
	for slot_any in hotbar_slots:
		var slot: Dictionary = slot_any as Dictionary
		if String(slot.get("id", "")) == "linterna" and int(slot.get("count", 0)) > 0:
			has_linterna = true
			break

	if has_linterna:
		return

	var target_index: int = -1
	for i in range(hotbar_slots.size()):
		var slot: Dictionary = hotbar_slots[i]
		if String(slot.get("id", "")).is_empty() or int(slot.get("count", 0)) <= 0:
			target_index = i
			break

	if target_index == -1:
		target_index = 0

	hotbar_slots[target_index] = {
		"id": "linterna",
		"count": 1,
		"icon_path": ""
	}
	emit_signal("inventory_changed")
	if target_index == hotbar_selected_index:
		emit_signal("hotbar_slot_changed", hotbar_selected_index, get_hotbar_slot(hotbar_selected_index))

func get_hotbar_slots() -> Array[Dictionary]:
	_ensure_hotbar_initialized()
	var copia: Array[Dictionary] = []
	for slot in hotbar_slots:
		copia.append((slot as Dictionary).duplicate(true))
	return copia

func get_hotbar_slot(index: int) -> Dictionary:
	_ensure_hotbar_initialized()
	if index < 0 or index >= HOTBAR_SIZE:
		return _empty_slot()
	return (hotbar_slots[index] as Dictionary).duplicate(true)

func set_hotbar_selected(index: int) -> void:
	_ensure_hotbar_initialized()
	var next_index: int = clampi(index, 0, HOTBAR_SIZE - 1)
	if next_index == hotbar_selected_index:
		return
	hotbar_selected_index = next_index
	emit_signal("hotbar_slot_changed", hotbar_selected_index, get_hotbar_slot(hotbar_selected_index))

func set_hotbar_slot(index: int, item_id: String, count: int, icon_path: String = "") -> void:
	_ensure_hotbar_initialized()
	if index < 0 or index >= HOTBAR_SIZE:
		return

	var slot: Dictionary = {
		"id": item_id,
		"count": maxi(count, 0),
		"icon_path": icon_path
	}
	if slot["count"] == 0 or String(slot["id"]).is_empty():
		slot = _empty_slot()

	hotbar_slots[index] = slot
	emit_signal("inventory_changed")
	if index == hotbar_selected_index:
		emit_signal("hotbar_slot_changed", hotbar_selected_index, get_hotbar_slot(hotbar_selected_index))

func clear_hotbar_slot(index: int) -> void:
	set_hotbar_slot(index, "", 0, "")

func set_hotbar_count(index: int, count: int) -> void:
	_ensure_hotbar_initialized()
	if index < 0 or index >= HOTBAR_SIZE:
		return
	var slot: Dictionary = hotbar_slots[index]
	if not slot.has("id") or String(slot["id"]).is_empty():
		return
	set_hotbar_slot(index, String(slot["id"]), count, String(slot.get("icon_path", "")))

func consume_selected_hotbar_item(amount: int = 1) -> void:
	_ensure_hotbar_initialized()
	var slot: Dictionary = hotbar_slots[hotbar_selected_index]
	if not slot.has("id") or String(slot["id"]).is_empty():
		return
	var current_count: int = int(slot.get("count", 0))
	set_hotbar_count(hotbar_selected_index, current_count - maxi(amount, 1))

func has_hotbar_item(item_id: String) -> bool:
	_ensure_hotbar_initialized()
	for slot_any in hotbar_slots:
		var slot: Dictionary = slot_any as Dictionary
		if String(slot.get("id", "")) == item_id and int(slot.get("count", 0)) > 0:
			return true
	return false

func find_hotbar_item_slot(item_id: String) -> int:
	_ensure_hotbar_initialized()
	for i in range(hotbar_slots.size()):
		var slot: Dictionary = hotbar_slots[i]
		if String(slot.get("id", "")) == item_id and int(slot.get("count", 0)) > 0:
			return i
	return -1
