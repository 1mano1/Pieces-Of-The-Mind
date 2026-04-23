extends Node3D


func _on_volumen_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Volumen.tscn")


func _on_resolution_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Resolucion.tscn")



func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/MainMenu.tscn")
