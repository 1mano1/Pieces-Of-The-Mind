extends Interactable


func _on_interacted(body):
	$AudioStreamPlayer3D.play()
	
	# Le pasamos el "body" a la función iniciar_dialogo
	get_tree().call_group("UI_Dialogo", "iniciar_dialogo", body)
