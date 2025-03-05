extends Node2D

func _ready():
	load_puzzles()
		
func load_puzzles():
	var packs = GLOBAL.selected_pack
	
	# Limpiar cualquier elemento existente en el contenedor
	for child in $CanvasLayer/VBoxContainer.get_children():
		child.queue_free()
	
	# Añadir un título a la pantalla
	var title_label = Label.new()
	title_label.text = "Selecciona un Puzzle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(0, 60)
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	$CanvasLayer/VBoxContainer.add_child(title_label)
	
	# Añadir un subtítulo con el nombre del pack
	if packs.has("name"):
		var subtitle_label = Label.new()
		subtitle_label.text = "Pack: " + packs.name
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		subtitle_label.custom_minimum_size = Vector2(0, 30)
		subtitle_label.add_theme_font_size_override("font_size", 20)
		subtitle_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		$CanvasLayer/VBoxContainer.add_child(subtitle_label)
	
	# Añadir un separador
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 20)
	$CanvasLayer/VBoxContainer.add_child(separator)
	
	# Crear un MarginContainer para dar espacio alrededor del grid
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	$CanvasLayer/VBoxContainer.add_child(margin_container)
	
	# Crear un GridContainer para organizar los puzzles en una cuadrícula
	var grid_container = GridContainer.new()
	grid_container.columns = 2  # Mostrar 2 puzzles por fila
	grid_container.add_theme_constant_override("h_separation", 20)  # Separación horizontal
	grid_container.add_theme_constant_override("v_separation", 20)  # Separación vertical
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_child(grid_container)
	
	# Verificar si hay puzzles para mostrar
	if not packs.has("puzzles") or packs.puzzles.size() == 0:
		var no_puzzles_label = Label.new()
		no_puzzles_label.text = "No hay puzzles disponibles en este pack"
		no_puzzles_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_puzzles_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		no_puzzles_label.custom_minimum_size = Vector2(0, 100)
		no_puzzles_label.add_theme_font_size_override("font_size", 18)
		no_puzzles_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		grid_container.add_child(no_puzzles_label)
		print("No hay puzzles para mostrar")
	else:
		# Cargar los puzzles
		print("Cargando " + str(packs.puzzles.size()) + " puzzles")
		for i in range(packs.puzzles.size()):
			var pack = packs.puzzles[i]
			print("Cargando puzzle " + str(i) + ": " + str(pack))
			
			# Cargar la escena del PuzzleItem
			var puzzle_item_scene = load("res://Scenes/Components/New/PuzzleItem.tscn")
			if puzzle_item_scene:
				var puzzle_item = puzzle_item_scene.instantiate()
				
				# Configurar el tamaño y propiedades del PuzzleItem
				puzzle_item.custom_minimum_size = Vector2(180, 220)
				puzzle_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				puzzle_item.size_flags_vertical = Control.SIZE_EXPAND_FILL
				
				# Configurar el PuzzleItem con los datos del puzzle
				puzzle_item.setup(pack)
				
				# Conectar la señal de selección de puzzle
				puzzle_item.connect("puzzle_selected", Callable(self, "_on_PuzzleSelected"))
				
				# Añadir el PuzzleItem al GridContainer
				grid_container.add_child(puzzle_item)
				print("PuzzleItem añadido correctamente")
			else:
				print("ERROR: No se pudo cargar la escena PuzzleItem")

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
