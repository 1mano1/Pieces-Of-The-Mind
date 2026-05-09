extends Interactable

var lupa_model: Node3D = null

func _ready():
		interacted.connect(_on_interacted)
		prompt_message = "Tomar Lupa"

		if has_node("CollisionShape3D/Sprite3D"):
				$CollisionShape3D/Sprite3D.queue_free()

		var lupa_scene = load("res://Assets/Lupa/ps1_magnifying_glass.blend")
		if lupa_scene:
				lupa_model = lupa_scene.instantiate()
				add_child(lupa_model)
				lupa_model.scale = Vector3(0.5, 0.5, 0.5)

func _process(delta):
		# Girar el modelo de la lupa lentamente sobre su propio eje Y
		if lupa_model != null:
				lupa_model.rotate_y(1.5 * delta)

func _on_interacted(_body):
		var aud = $AudioStreamPlayer3D
		if aud:
				var take_sound = load("res://Audio/tomar_objeto.mp3")
				if take_sound:
						aud.stream = take_sound
				aud.play()

		visible = false

		if has_node("CollisionShape3D"):
				$CollisionShape3D.set_deferred("disabled", true)

		GameState.set_hotbar_slot(0, "lupa", 1, "res://Assets/Lupa/lupa_icon.png")

		_mostrar_imagen_animacion()

		if aud:
				await aud.finished
		else:
				await get_tree().create_timer(1.0).timeout

		queue_free()

func _mostrar_imagen_animacion():
		var canvas = CanvasLayer.new()
		canvas.layer = 100
		canvas.name = "LupaAnimacionCanvas"
		get_tree().root.add_child(canvas)

		var tex_rect = TextureRect.new()
		tex_rect.texture = load("res://Assets/Lupa/lupa_animacion.png")
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.custom_minimum_size = Vector2(128, 128)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_CENTER)
		tex_rect.position = Vector2((1920 / 2) - 64, (1080 / 2) - 64)
		canvas.add_child(tex_rect)

		var lbl = Label.new()
		lbl.text = "Haz conseguido la lupa\nEquipatela en el inventario y presiona TAB para usar"
		lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2, 1)) # Tono verde para relacionarlo con la lupa
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		lbl.position = Vector2(0, -120)
		canvas.add_child(lbl)

		await get_tree().create_timer(4.0).timeout
		if is_instance_valid(canvas):
				canvas.queue_free()
