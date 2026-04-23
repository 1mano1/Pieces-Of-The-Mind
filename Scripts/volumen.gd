extends Control

@onready var volume_slider = $Panel/VolumeSlider

func _ready():
	# volumen inicial
	volume_slider.value = 50

func _on_volume_slider_value_changed(value):
	# convertir 0-100 a decibeles
	var db = linear_to_db(value / 100.0)

	# Bus 0 = Master
	AudioServer.set_bus_volume_db(0, db)

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Escenas/Opciones.tscn")
