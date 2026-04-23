extends Node3D

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/node_3d.scn")


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/opciones.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
