import re

with open('Scripts/jugador.gd', 'r', encoding='utf-8') as f:
    text = f.read()

pattern = re.compile(r'func _ensure_lupa_ui\(\) -> void:.*?_lupa_ui_layer = ui_root', re.DOTALL)

new_str = '''func _ensure_lupa_ui() -> void:
\tif canvas_layer == null:
\t\treturn

\tvar ui_root := canvas_layer.get_node_or_null("LupaUI") as Control
\tif ui_root == null:
\t\tui_root = Control.new()
\t\tui_root.name = "LupaUI"
\t\tui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
\t\tui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t\tui_root.visible = false
\t\tcanvas_layer.add_child(ui_root)

\t\tvar tex_rect = TextureRect.new()
\t\ttex_rect.texture = load("res://Assets/Lupa/lupa_animacion.png")
\t\ttex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
\t\ttex_rect.custom_minimum_size = Vector2(128, 128)
\t\ttex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
\t\ttex_rect.set_anchors_preset(Control.PRESET_CENTER)
\t\t# Centrado manual ajustado
\t\ttex_rect.position = Vector2((1920 / 2) - 64, (1080 / 2) - 64)
\t\ttex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t\tui_root.add_child(tex_rect)

\t\tvar lbl = Label.new()
\t\tlbl.text = "Presiona TAB para usar"
\t\tlbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
\t\tlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\t\tlbl.add_theme_font_size_override("font_size", 32)
\t\tlbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
\t\tlbl.add_theme_color_override("font_outline_color", Color.BLACK)
\t\tlbl.add_theme_constant_override("outline_size", 4)
\t\tlbl.position = Vector2(0, -60)
\t\tui_root.add_child(lbl)

\t_lupa_ui_layer = ui_root'''

text = pattern.sub(new_str, text)

with open('Scripts/jugador.gd', 'w', encoding='utf-8') as f:
    f.write(text)
