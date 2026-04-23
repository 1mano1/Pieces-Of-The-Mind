extends CanvasLayer

var battery_bar: ProgressBar
var battery_label: Label
var flashlight_icon: Label
var controls_label: Label
var sanity_bar: ProgressBar
var hotbar_slots: Array[MarginContainer] = []
var damage_overlay: ColorRect
var game_over_panel: PanelContainer

func _ready() -> void:
	_create_damage_ui()
	_create_hotbar()
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	var hbox_title = HBoxContainer.new()
	vbox.add_child(hbox_title)
	
	flashlight_icon = Label.new()
	flashlight_icon.text = "[LINTERNA]"
	flashlight_icon.add_theme_font_size_override("font_size", 14)
	flashlight_icon.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	hbox_title.add_child(flashlight_icon)
	
	battery_bar = ProgressBar.new()
	battery_bar.min_value = 0.0
	battery_bar.max_value = 100.0
	battery_bar.value = 100.0
	battery_bar.custom_minimum_size = Vector2(200, 20)
	battery_bar.show_percentage = false
	
	var bar_style_bg = StyleBoxFlat.new()
	bar_style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bar_style_bg.corner_radius_top_left = 4
	bar_style_bg.corner_radius_top_right = 4
	bar_style_bg.corner_radius_bottom_left = 4
	bar_style_bg.corner_radius_bottom_right = 4
	battery_bar.add_theme_stylebox_override("background", bar_style_bg)
	
	var bar_style_fill = StyleBoxFlat.new()
	bar_style_fill.bg_color = Color(0.2, 0.8, 0.2, 0.9)
	bar_style_fill.corner_radius_top_left = 4
	bar_style_fill.corner_radius_top_right = 4
	bar_style_fill.corner_radius_bottom_left = 4
	bar_style_fill.corner_radius_bottom_right = 4
	battery_bar.add_theme_stylebox_override("fill", bar_style_fill)
	vbox.add_child(battery_bar)
	
	battery_label = Label.new()
	battery_label.text = "[||||||||||] 100%"
	battery_label.add_theme_font_size_override("font_size", 13)
	battery_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	vbox.add_child(battery_label)
	
	var margin_controls = MarginContainer.new()
	margin_controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin_controls.add_theme_constant_override("margin_right", 20)
	margin_controls.add_theme_constant_override("margin_top", 20)
	add_child(margin_controls)
	
	controls_label = Label.new()
	controls_label.text = "[W][A][S][D] Mover\n[ESPACIO] Saltar\n[CLICK-DER] Linterna\n[P] Pausa"
	controls_label.add_theme_font_size_override("font_size", 12)
	controls_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7, 0.5))
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	margin_controls.add_child(controls_label)
	
	var margin_sanity = MarginContainer.new()
	margin_sanity.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	margin_sanity.add_theme_constant_override("margin_left", 20)
	add_child(margin_sanity)
	
	sanity_bar = ProgressBar.new()
	sanity_bar.min_value = 0.0
	sanity_bar.max_value = 100.0
	sanity_bar.value = 100.0
	sanity_bar.custom_minimum_size = Vector2(25, 300)
	sanity_bar.show_percentage = false
	sanity_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	
	var sanity_bg = StyleBoxFlat.new()
	sanity_bg.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	sanity_bg.border_width_left = 2
	sanity_bg.border_width_right = 2
	sanity_bg.border_width_top = 2
	sanity_bg.border_width_bottom = 2
	sanity_bg.border_color = Color(0.4, 0.5, 0.6, 0.2)
	sanity_bg.corner_radius_top_left = 10
	sanity_bg.corner_radius_top_right = 10
	sanity_bg.corner_radius_bottom_left = 10
	sanity_bg.corner_radius_bottom_right = 10
	sanity_bar.add_theme_stylebox_override("background", sanity_bg)
	
	var sanity_fill = StyleBoxFlat.new()
	sanity_fill.bg_color = Color(0.2, 0.9, 0.3, 0.6)
	sanity_fill.corner_radius_top_left = 10
	sanity_fill.corner_radius_top_right = 10
	sanity_fill.corner_radius_bottom_left = 10
	sanity_fill.corner_radius_bottom_right = 10
	sanity_bar.add_theme_stylebox_override("fill", sanity_fill)
	margin_sanity.add_child(sanity_bar)
	
	var crosshair = Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(crosshair)

func update_battery(percent: float) -> void:
	battery_bar.value = percent
	var bars_total := 10
	var bars_filled := int(percent / 10.0)
	var bar_text := "[" + "|".repeat(bars_filled) + " ".repeat(bars_total - bars_filled) + "] %d%%" % int(percent)
	battery_label.text = bar_text
	var fill_style := battery_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		if percent > 50.0:
			fill_style.bg_color = Color(0.2, 0.8, 0.2, 0.9)
			battery_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		elif percent > 20.0:
			fill_style.bg_color = Color(0.9, 0.7, 0.1, 0.9)
			battery_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
		else:
			fill_style.bg_color = Color(0.9, 0.2, 0.1, 0.9)
			battery_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))

func update_sanity(percent: float) -> void:
	if sanity_bar:
		sanity_bar.value = percent
		var fill_style := sanity_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if percent > 50.0:
				fill_style.bg_color = Color(0.2, 0.9, 0.3, 0.6)
			elif percent > 20.0:
				fill_style.bg_color = Color(0.9, 0.8, 0.2, 0.6)
			else:
				fill_style.bg_color = Color(0.9, 0.1, 0.1, 0.7)

func _create_hotbar() -> void:
	var full_rect = MarginContainer.new()
	full_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	full_rect.add_theme_constant_override("margin_bottom", 20)
	full_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(full_rect)
	
	var align_bottom = VBoxContainer.new()
	align_bottom.alignment = BoxContainer.ALIGNMENT_END
	align_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect.add_child(align_bottom)
	
	var align_center = HBoxContainer.new()
	align_center.alignment = BoxContainer.ALIGNMENT_CENTER
	align_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	align_bottom.add_child(align_center)
	
	var hotbar_bg = PanelContainer.new()
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.7, 0.7, 0.7, 0.8)
	bg_style.content_margin_left = 3
	bg_style.content_margin_right = 3
	bg_style.content_margin_top = 3
	bg_style.content_margin_bottom = 3
	hotbar_bg.add_theme_stylebox_override("panel", bg_style)
	align_center.add_child(hotbar_bg)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	hotbar_bg.add_child(hbox)
	
	for i in range(9):
		var slot = _create_hotbar_slot()
		hbox.add_child(slot)
		hotbar_slots.append(slot)
	
	update_hotbar_selection(0)

func _create_hotbar_slot() -> MarginContainer:
	var slot = MarginContainer.new()
	slot.custom_minimum_size = Vector2(40, 40)
	
	var dark_bg = ColorRect.new()
	dark_bg.color = Color(0.2, 0.2, 0.2)
	slot.add_child(dark_bg)
	
	var m1 = MarginContainer.new()
	m1.add_theme_constant_override("margin_left", 2)
	m1.add_theme_constant_override("margin_top", 2)
	slot.add_child(m1)
	
	var light_bg = ColorRect.new()
	light_bg.color = Color(1.0, 1.0, 1.0)
	m1.add_child(light_bg)
	
	var m2 = MarginContainer.new()
	m2.add_theme_constant_override("margin_right", 2)
	m2.add_theme_constant_override("margin_bottom", 2)
	m1.add_child(m2)
	
	var center_bg = ColorRect.new()
	center_bg.color = Color(0.55, 0.55, 0.55)
	m2.add_child(center_bg)
	
	var highlight = Panel.new()
	highlight.name = "Highlight"
	var hl_style = StyleBoxFlat.new()
	hl_style.bg_color = Color(0, 0, 0, 0)
	hl_style.border_width_left = 3
	hl_style.border_width_right = 3
	hl_style.border_width_top = 3
	hl_style.border_width_bottom = 3
	hl_style.border_color = Color(1.0, 1.0, 1.0, 0.9)
	highlight.add_theme_stylebox_override("panel", hl_style)
	highlight.visible = false
	slot.add_child(highlight)
	
	return slot

func update_hotbar_selection(index: int) -> void:
	for i in range(hotbar_slots.size()):
		var slot = hotbar_slots[i]
		var highlight = slot.get_node("Highlight")
		if highlight:
			highlight.visible = (i == index)

func _create_damage_ui() -> void:
	damage_overlay = ColorRect.new()
	damage_overlay.color = Color(1.0, 0.0, 0.0, 0.0)
	damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_overlay)
	
	game_over_panel = PanelContainer.new()
	game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	game_over_panel.visible = false
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	game_over_panel.add_theme_stylebox_override("panel", panel_style)
	
	var go_vbox = VBoxContainer.new()
	go_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	go_vbox.add_theme_constant_override("separation", 15)
	game_over_panel.add_child(go_vbox)
	
	var title = Label.new()
	title.text = "JUEGO TERMINADO"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Presiona ENTER para reintentar"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_vbox.add_child(subtitle)
	
	add_child(game_over_panel)

func update_damage_overlay(hits: int) -> void:
	if not damage_overlay: return
	
	match hits:
		1:
			damage_overlay.color.a = 0.2
		2:
			damage_overlay.color.a = 0.5
		_:
			damage_overlay.color.a = 0.0

func show_game_over() -> void:
	if game_over_panel:
		game_over_panel.visible = true
	if damage_overlay:
		damage_overlay.color.a = 0.8