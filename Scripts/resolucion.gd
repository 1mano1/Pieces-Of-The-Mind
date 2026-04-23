extends Control

@onready var resolution_options = $CanvasLayer/Control/CenterContainer/VBoxContainer/ResolutionOptions

var resolutions = {
	"1920 x 1080": Vector2i(1920, 1080),
	"1600 x 900": Vector2i(1600, 900),
	"1366 x 768": Vector2i(1366, 768),
	"1280 x 720": Vector2i(1280, 720),
	"1024 x 768": Vector2i(1024, 768),
	"800 x 600": Vector2i(800, 600)
}

var selected_resolution = Vector2i(1280, 720)

func _ready():
	for resolution in resolutions.keys():
		resolution_options.add_item(resolution)

func _on_apply_button_pressed():
	var selected_text = resolution_options.get_item_text(
		resolution_options.selected
	)

	selected_resolution = resolutions[selected_text]

	DisplayServer.window_set_size(selected_resolution)

	# Centrar ventana en pantalla
	var screen_size = DisplayServer.screen_get_size()
	var window_position = (screen_size - selected_resolution) / 2
	DisplayServer.window_set_position(window_position)

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Escenas/Opciones.tscn")
