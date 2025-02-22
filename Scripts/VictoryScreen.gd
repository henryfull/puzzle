extends Node2D

func _ready():
	# Aquí se puede actualizar la UI para mostrar la puntuación final y logros desbloqueados
	print("¡Victoria! Puzzle completado. Mostrando resumen y logros.")
	
	# Ejemplo: actualizar una etiqueta llamada 'FinalScore' si existe
	if has_node("FinalScore"):
		get_node("FinalScore").text = "¡Felicidades! Puzzle completado."

func _on_RepeatButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")

func _on_NextPuzzleButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn")

func _on_MainMenuButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn") 
