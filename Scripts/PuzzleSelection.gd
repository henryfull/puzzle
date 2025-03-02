extends Node2D

func _ready():
	load_puzzles()
	add_column_puzzle_button()
		
func load_puzzles():
	var packs = GLOBAL.selected_pack
	for pack in packs.puzzles:
		var button = Button.new() # Crear un nuevo botón
		button.text = pack["name"] # Asignar el nombre del pack al botón
		button.pressed.connect(Callable(self, "_on_PuzzleSelected").bind(pack))
		$CanvasLayer/VBoxContainer.add_child(button) # Añadir el botón al VBoxContainer

func add_column_puzzle_button():
	# Añadir un separador
	var separator = HSeparator.new()
	$CanvasLayer/VBoxContainer.add_child(separator)
	
	# Añadir un título
	var label = Label.new()
	label.text = "Puzzles Especiales"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$CanvasLayer/VBoxContainer.add_child(label)
	
	# Añadir el botón para el puzzle de columnas
	var button = Button.new()
	button.text = "Puzzle de Columnas"
	button.pressed.connect(Callable(self, "_on_ColumnPuzzleSelected"))
	$CanvasLayer/VBoxContainer.add_child(button)

func _on_PuzzleSelected(puzzle):
	# Función llamada al seleccionar un puzzle
	GLOBAL.selected_puzzle = puzzle
	print("Puzzle seleccionado: ", puzzle)
	get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn") 

func _on_ColumnPuzzleSelected():
	# Función llamada al seleccionar el puzzle de columnas
	print("Puzzle de columnas seleccionado")
	get_tree().change_scene_to_file("res://Scenes/ColumnPuzzle/ColumnPuzzleGame.tscn")

func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/PackSelection.tscn")
