extends Control

signal active_slot_changed(active_index: int, slot_data: Dictionary)

@export var slot_size: Vector2 = Vector2(66.0, 66.0)
@export var slot_gap: int = 8
@export var bar_bottom_margin: int = 24

var _slot_panels: Array[PanelContainer] = []
var _slot_icons: Array[TextureRect] = []
var _slot_amounts: Array[Label] = []
var _slot_name_labels: Array[Label] = []
var _cached_textures: Dictionary = {}

var _active_index: int = 0
var _updating_from_state: bool = false

func _ready() -> void:
	name = "HotbarBosque"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	GameState._ensure_hotbar_initialized()
	_build_ui()
	_connect_state_signals()
	_refresh_slots()
	_apply_active_slot_visual(GameState.hotbar_selected_index, false)

func _exit_tree() -> void:
	_disconnect_state_signals()

func _build_ui() -> void:
	var root_center := CenterContainer.new()
	root_center.name = "BottomCenter"
	root_center.anchor_left = 0.0
	root_center.anchor_top = 1.0
	root_center.anchor_right = 1.0
	root_center.anchor_bottom = 1.0
	root_center.offset_left = 0.0
	root_center.offset_top = float(-bar_bottom_margin - int(slot_size.y) - 8)
	root_center.offset_right = 0.0
	root_center.offset_bottom = 0.0
	root_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_center)

	var bar_bg := PanelContainer.new()
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.17, 0.19, 0.62)
	bg_style.border_color = Color(0.9, 0.9, 0.92, 0.35)
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.corner_radius_top_left = 0
	bg_style.corner_radius_top_right = 0
	bg_style.corner_radius_bottom_left = 0
	bg_style.corner_radius_bottom_right = 0
	bg_style.content_margin_left = 10
	bg_style.content_margin_right = 10
	bg_style.content_margin_top = 8
	bg_style.content_margin_bottom = 8
	bar_bg.add_theme_stylebox_override("panel", bg_style)
	root_center.add_child(bar_bg)

	var hbox := HBoxContainer.new()
	hbox.name = "Slots"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", slot_gap)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(hbox)

	for i in range(GameState.HOTBAR_SIZE):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = slot_size
		panel.pivot_offset = slot_size * 0.5
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.58, 0.58, 0.58, 0.95)
		style.corner_radius_top_left = 0
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.25, 0.26, 0.27, 0.95)
		panel.add_theme_stylebox_override("panel", style)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 6
		icon.offset_top = 6
		icon.offset_right = -6
		icon.offset_bottom = -6
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.visible = false
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)

		var item_name := Label.new()
		item_name.name = "ItemName"
		item_name.anchor_left = 0.0
		item_name.anchor_top = 0.0
		item_name.anchor_right = 1.0
		item_name.anchor_bottom = 1.0
		item_name.offset_left = 0.0
		item_name.offset_top = 0.0
		item_name.offset_right = 0.0
		item_name.offset_bottom = 0.0
		item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_name.add_theme_font_size_override("font_size", 18)
		item_name.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96, 0.95))
		item_name.text = ""
		item_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_name.visible = false
		panel.add_child(item_name)

		var amount := Label.new()
		amount.name = "Amount"
		amount.anchor_left = 1.0
		amount.anchor_top = 1.0
		amount.anchor_right = 1.0
		amount.anchor_bottom = 1.0
		amount.offset_left = -28
		amount.offset_top = -24
		amount.offset_right = -6
		amount.offset_bottom = -4
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amount.add_theme_font_size_override("font_size", 17)
		amount.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98, 0.98))
		amount.text = ""
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(amount)

		hbox.add_child(panel)
		_slot_panels.append(panel)
		_slot_icons.append(icon)
		_slot_amounts.append(amount)
		_slot_name_labels.append(item_name)

func _connect_state_signals() -> void:
	if not GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.connect(_on_inventory_changed)
	if not GameState.hotbar_slot_changed.is_connected(_on_hotbar_slot_changed):
		GameState.hotbar_slot_changed.connect(_on_hotbar_slot_changed)

func _disconnect_state_signals() -> void:
	if GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.disconnect(_on_inventory_changed)
	if GameState.hotbar_slot_changed.is_connected(_on_hotbar_slot_changed):
		GameState.hotbar_slot_changed.disconnect(_on_hotbar_slot_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
				_set_active_slot_from_input(int(key_event.keycode - KEY_1))
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_active_slot_from_input(_active_index - 1)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_active_slot_from_input(_active_index + 1)
			get_viewport().set_input_as_handled()
			return

func _set_active_slot_from_input(raw_index: int) -> void:
	var size: int = GameState.HOTBAR_SIZE
	var wrapped := raw_index % size
	if wrapped < 0:
		wrapped += size

	if wrapped == _active_index:
		return

	_apply_active_slot_visual(wrapped, true)
	if not _updating_from_state:
		GameState.set_hotbar_selected(wrapped)
	emit_signal("active_slot_changed", wrapped, GameState.get_hotbar_slot(wrapped))

func _on_hotbar_slot_changed(active_slot: int, _slot_data: Dictionary) -> void:
	_updating_from_state = true
	_apply_active_slot_visual(active_slot, false)
	_updating_from_state = false

func _on_inventory_changed() -> void:
	_refresh_slots()

func _refresh_slots() -> void:
	var slots: Array[Dictionary] = GameState.get_hotbar_slots()
	for i in range(mini(slots.size(), _slot_panels.size())):
		var data: Dictionary = slots[i]
		var icon := _slot_icons[i]
		var amount := _slot_amounts[i]
		var item_name := _slot_name_labels[i]

		var item_id: String = String(data.get("id", ""))
		var count: int = int(data.get("count", 0))
		var icon_path: String = String(data.get("icon_path", ""))

		if item_id.is_empty() or count <= 0:
			icon.texture = null
			icon.visible = false
			item_name.text = ""
			item_name.visible = false
			amount.text = ""
			continue

		icon.texture = _load_icon(icon_path)
		icon.visible = icon.texture != null
		if icon.visible:
			item_name.text = ""
			item_name.visible = false
		else:
			item_name.text = _short_item_label(item_id)
			item_name.visible = not item_name.text.is_empty()
		amount.text = str(count) if count > 1 else ""

func _short_item_label(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	if item_id.length() <= 2:
		return item_id.to_upper()
	return item_id.substr(0, 2).to_upper()

func _load_icon(icon_path: String) -> Texture2D:
	if icon_path.is_empty():
		return null
	if _cached_textures.has(icon_path):
		return _cached_textures[icon_path] as Texture2D

	var tex := load(icon_path) as Texture2D
	_cached_textures[icon_path] = tex
	return tex

func _apply_active_slot_visual(index: int, with_anim: bool) -> void:
	_active_index = clampi(index, 0, GameState.HOTBAR_SIZE - 1)

	for i in range(_slot_panels.size()):
		var panel := _slot_panels[i]
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue

		if i == _active_index:
			style.bg_color = Color(0.62, 0.62, 0.62, 0.97)
			style.border_color = Color(0.97, 0.97, 0.97, 1.0)
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			if with_anim:
				panel.scale = Vector2(1.0, 1.0)
				var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.05)
				tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.06)
		else:
			style.bg_color = Color(0.58, 0.58, 0.58, 0.95)
			style.border_color = Color(0.25, 0.26, 0.27, 0.95)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			panel.scale = Vector2(1.0, 1.0)
