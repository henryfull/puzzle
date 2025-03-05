extends Node2D

var title_label : Label
var scroll_container : ScrollContainer
var margin_container : MarginContainer
var grid_container: GridContainer

func _ready():
	print("PuzzleSelection: _ready()")
	
	# Obtener referencias a los nodos existentes en la escena
	title_label = $CanvasLayer/VBoxContainer/TitlePuzzleSelection
	scroll_container = $CanvasLayer/VBoxContainer/ScrollContainer
	margin_container = $CanvasLayer/VBoxContainer/ScrollContainer/MarginContainer
	grid_container = $CanvasLayer/VBoxContainer/ScrollContainer/MarginContainer/GridContainer
	
	# Verificar que todos los nodos se hayan encontrado correctamente
	if title_label and scroll_container and margin_container and grid_container:
		print("PuzzleSelection: Todos los nodos encontrados correctamente")
	else:
		print("ERROR: No se pudieron encontrar todos los nodos necesarios")
		if not title_label:
			print("ERROR: No se encontró el nodo title_label")
		if not scroll_container:
			print("ERROR: No se encontró el nodo scroll_container")
		if not margin_container:
			print("ERROR: No se encontró el nodo margin_container")
		if not grid_container:
			print("ERROR: No se encontró el nodo grid_container")
	
	load_puzzles()
		
func load_puzzles():
	var packs = GLOBAL.selected_pack
	
	# Limpiar cualquier elemento existente en el grid_container, no en el VBoxContainer
	for child in grid_container.get_children():
		child.queue_free()
	
	# Añadir un título a la pantalla
	if title_label:
		title_label.text = "Pack: " + packs.name
		title_label.custom_minimum_size = Vector2(0, 60)
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	
	# Configurar el ScrollContainer
	if scroll_container:
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(0, 400)  # Altura mínima para el scroll
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # Desactivar scroll horizontal
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO  # Activar scroll vertical automático
	
	# Configurar el MarginContainer
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 20)
		margin_container.add_theme_constant_override("margin_right", 20)
		margin_container.add_theme_constant_override("margin_top", 20)
		margin_container.add_theme_constant_override("margin_bottom", 20)
		margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Configurar el GridContainer
	if grid_container:
		grid_container.columns = 2  # Mostrar 2 puzzles por fila
		grid_container.add_theme_constant_override("h_separation", 20)  # Separación horizontal
		grid_container.add_theme_constant_override("v_separation", 20)  # Separación vertical
		grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
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
				puzzle_item.custom_minimum_size = Vector2(180, 300)
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
	print("PuzzleSelection: _on_PuzzleSelected() - SEÑAL RECIBIDA")
	print("PuzzleSelection: Datos del puzzle recibidos: ", puzzle)
	
	if puzzle == null:
		print("ERROR: Los datos del puzzle son NULL")
		return
	
	if typeof(puzzle) != TYPE_DICTIONARY:
		print("ERROR: Los datos del puzzle no son un diccionario, son de tipo: ", typeof(puzzle))
		return
	
	print("PuzzleSelection: Nombre del puzzle: ", puzzle.get("name", "NO NAME"))
	print("PuzzleSelection: Guardando puzzle en GLOBAL.selected_puzzle")
	
	GLOBAL.selected_puzzle = puzzle
	print("PuzzleSelection: Cambiando a escena PuzzleGame.tscn")
	
	# Verificar que la escena existe antes de cambiar
	if ResourceLoader.exists("res://Scenes/PuzzleGame.tscn"):
		print("PuzzleSelection: La escena PuzzleGame.tscn existe, cambiando...")
		get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")
	else:
		print("ERROR: La escena PuzzleGame.tscn no existe")
		# Intentar con otra ruta
		if ResourceLoader.exists("res://Scenes/PuzzleGame.tscn"):
			print("PuzzleSelection: Intentando con ruta alternativa...")
			get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")
		else:
			print("ERROR: No se pudo encontrar la escena del juego")

func _on_ColumnPuzzleSelected():
	# Función llamada al seleccionar el puzzle de columnas
	print("Puzzle de columnas seleccionado")
	get_tree().change_scene_to_file("res://Scenes/ColumnPuzzle/ColumnPuzzleGame.tscn")

func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/PackSelection.tscn")
