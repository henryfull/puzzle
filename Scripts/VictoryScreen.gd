extends Node2D

func _ready():
	# Aquí se puede actualizar la UI para mostrar la puntuación final y logros desbloqueados
	print("¡Victoria! Puzzle completado. Mostrando resumen y logros.")
	var tex
	# Si hay un puzzle seleccionado, se carga su imagen
	if GLOBAL.selected_puzzle != null:
		tex = load(GLOBAL.selected_puzzle.image)
		$CanvasLayer/VBoxContainer/LabelPuzzle.text = GLOBAL.selected_puzzle.name
	if has_node("CanvasLayer/VBoxContainer/Sprite2D"):
		var sprite: Sprite2D = get_node("CanvasLayer/VBoxContainer/Sprite2D")
		$CanvasLayer/VBoxContainer/Sprite2D.texture = tex
	# Actualizar la etiqueta FinalScore si existe


	
	# Ejemplo: actualizar una etiqueta llamada 'FinalScore' si existe
	if has_node("FinalScore"):
		get_node("FinalScore").text = "¡Felicidades! Puzzle completado."

func _on_RepeatButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")

func _on_NextPuzzleButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn")

func _on_MainMenuButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn") 
