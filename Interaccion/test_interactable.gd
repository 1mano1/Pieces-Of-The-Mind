extends Interactable

func _ready():
	# ¡Esta es la línea mágica que falta!
	# Conecta la señal del script padre con la función de abajo.
	interacted.connect(_on_interacted)

func _on_interacted(_body):
	# 1. Reproduce el sonido de agarrar
	$AudioStreamPlayer3D.play()
	
	# 2. Lo ocultamos para que parezca que lo agarraste
	visible = false
	
	# 3. En lugar de process_mode, apagamos la colisión. 
	# (Usamos set_deferred para que el motor de físicas no lance un error)
	$CollisionShape3D.set_deferred("disabled", true)
	
	# 5. Esperamos automáticamente a que el audio termine de sonar
	await $AudioStreamPlayer3D.finished
	
	# 6. Ahora sí, lo borramos del juego
	queue_free()
