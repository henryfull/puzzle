extends Node2D

func _ready():
	load_puzzles()
		
func load_puzzles():
	var packs = GLOBAL.selected_pack
	for pack in packs.puzzles:
		var button = Button.new() # Crear un nuevo botón
		button.text = pack["name"] # Asignar el nombre del pack al botón
		button.pressed.connect(Callable(self, "_on_PuzzleSelected").bind(pack))
		$VBoxContainer.add_child(button) # Añadir el botón al VBoxContainer


func _on_PuzzleSelected(puzzle):
	# Función llamada al seleccionar un puzzle
	GLOBAL.selected_puzzle = puzzle
	print("Puzzle seleccionado: ", puzzle)
	get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn") 

func _on_BackButton_pressed():
	get_tree().quit_on_go_back
