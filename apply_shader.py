# -*- coding: utf-8 -*-
import re

with open('Scripts/jugador.gd', 'r', encoding='utf-8') as f:
    text = f.read()

# Modify vars to add the color_rect reference
var_pattern = r'var is_lupa_mode:\s*bool = false\n\s*var _lupa_ui_layer:\s*Control = null'

new_var_str = '''var is_lupa_mode: bool = false
\tvar _lupa_ui_layer: Control = null
\tvar _lupa_post_process: ColorRect = null'''

text = re.sub(var_pattern, new_var_str, text, count=1)

# Modify activation and deactivation
act_pattern = re.compile(r'func _activar_ambiente_lupa\(\):.*?func is_flashlight_on\(\) -> bool:', re.DOTALL)
new_act_str = '''func _activar_ambiente_lupa():
\tif canvas_layer == null:
\t\treturn
\t
\tif _lupa_post_process == null:
\t\t_lupa_post_process = ColorRect.new()
\t\t_lupa_post_process.set_anchors_preset(Control.PRESET_FULL_RECT)
\t\t_lupa_post_process.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t\t
\t\tvar mat = ShaderMaterial.new()
\t\tmat.shader = load("res://Shaders/vision_lupa.gdshader")
\t\t_lupa_post_process.material = mat
\t\t
\t\tcanvas_layer.add_child(_lupa_post_process)
\t\tcanvas_layer.move_child(_lupa_post_process, 0)
\t
\t_lupa_post_process.visible = true
\t
\tvar cam = get_viewport().get_camera_3d()
\tif cam:
\t\tcam.cull_mask = cam.cull_mask | 2 # Add Layer 2 for hidden objects

func _desactivar_ambiente_lupa():
\tif _lupa_post_process != null:
\t\t_lupa_post_process.visible = false
\t
\tvar cam = get_viewport().get_camera_3d()
\tif cam:
\t\tcam.cull_mask = cam.cull_mask & ~2 # Remove Layer 2

func is_flashlight_on() -> bool:'''
text = act_pattern.sub(new_act_str, text)

# Update UI Label position
ui_pattern = re.compile(r'lbl\.position = Vector2\(0, -60\)')
text = ui_pattern.sub('lbl.position = Vector2(0, -120)', text) # move up

with open('Scripts/jugador.gd', 'w', encoding='utf-8') as f:
    f.write(text)
