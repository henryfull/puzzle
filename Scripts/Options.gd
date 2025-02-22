extends Node2D

func _ready():
	# Inicialización de la pantalla de opciones
	# Aquí puedes configurar sliders para música y efectos, y otros ajustes
	pass

# Ejemplo de función para volver al menú principal
func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
