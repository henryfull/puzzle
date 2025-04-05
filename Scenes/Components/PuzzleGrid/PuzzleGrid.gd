extends GridContainer

# Señal que se emitirá cuando se seleccione un puzzle
signal puzzle_selected(puzzle_data)

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")

func _ready():
	print("PuzzleGrid: _ready()")
	
	# Configuración del GridContainer
	columns = 2
	mouse_filter = Control.MOUSE_FILTER_PASS

# Cargar los puzzles para un pack específico
func load_puzzles(pack):
	print("PuzzleGrid: load_puzzles() - Iniciando carga de puzzles")
	
	# Verificar que haya un pack válido
	if pack == null or not pack.has("id"):
		print("PuzzleGrid: ERROR - Pack inválido o sin ID")
		_show_error_message("Error: Pack inválido o sin ID")
		return
		
	print("PuzzleGrid: Pack seleccionado - ID: ", pack.get("id", "NO ID"), ", Nombre: ", pack.get("name", "NO NAME"))
	
	# Limpiar cualquier elemento existente
	for child in get_children():
		child.queue_free()
	
	# Verificar si hay puzzles para mostrar
	if not pack.has("puzzles") or pack.puzzles.size() == 0:
		print("PuzzleGrid: ERROR - No hay puzzles en el pack seleccionado")
		_show_error_message("No hay puzzles disponibles en este pack")
		return
	
	# Cargar los puzzles
	print("PuzzleGrid: Cargando " + str(pack.puzzles.size()) + " puzzles")
	
	for i in range(pack.puzzles.size()):
		var puzzle = pack.puzzles[i]
		print("PuzzleGrid: Cargando puzzle " + str(i) + ": " + str(puzzle.get("id", "NO ID")))
		
		# Verificar si el puzzle está desbloqueado
		var is_unlocked = puzzle.has("unlocked") and puzzle.unlocked
		var is_completed = puzzle.has("completed") and puzzle.completed
		
		print("PuzzleGrid: Puzzle " + puzzle.get("id", "NO ID") + " - Desbloqueado: " + str(is_unlocked) + ", Completado: " + str(is_completed))
		
		# Cargar la escena del PuzzleItem
		var puzzle_item_scene = load("res://Scenes/Components/PuzzleItem/PuzzleItem.tscn")
		if puzzle_item_scene:
			var puzzle_item = puzzle_item_scene.instantiate()
			
			# Configurar el tamaño y propiedades del PuzzleItem
			puzzle_item.custom_minimum_size = Vector2(220, 350)
			puzzle_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			puzzle_item.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			# Configurar el PuzzleItem con los datos del puzzle
			puzzle_item.setup(puzzle)
			
			# Si el puzzle no está desbloqueado, desactivar el PuzzleItem
			if not is_unlocked:
				puzzle_item.set_locked(true)
			
			# Si el puzzle está completado, marcarlo como tal
			if is_completed:
				puzzle_item.set_completed(true)
			

			
			# Desconectar cualquier señal previa para evitar conexiones duplicadas
			if puzzle_item.is_connected("puzzle_selected", Callable(self, "_on_PuzzleSelected")):
				puzzle_item.disconnect("puzzle_selected", Callable(self, "_on_PuzzleSelected"))
			
			# Conectar la señal de selección de puzzle
			puzzle_item.connect("puzzle_selected", Callable(self, "_on_PuzzleSelected"))
			print("PuzzleGrid: PuzzleItem: Señal puzzle_selected conectada")
			
			# Añadir el PuzzleItem al GridContainer
			add_child(puzzle_item)
			print("PuzzleGrid: PuzzleItem añadido correctamente")
		else:
			print("PuzzleGrid: ERROR - No se pudo cargar la escena PuzzleItem")
	
	print("PuzzleGrid: Carga de puzzles completada")

# Función para mostrar mensajes de error
func _show_error_message(message: String):
	var error_label = Label.new()
	error_label.text = message
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.custom_minimum_size = Vector2(0, 120)
	error_label.add_theme_font_size_override("font_size", 22)
	error_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	add_child(error_label)
	print("PuzzleGrid: Mensaje de error mostrado: " + message)

# Manejador de la señal puzzle_selected desde un PuzzleItem
func _on_PuzzleSelected(puzzle):
	print("PuzzleGrid: _on_PuzzleSelected() - SEÑAL RECIBIDA")
	print("PuzzleGrid: Datos del puzzle recibidos: ", puzzle)
	
	# Primero, emitir la señal al componente padre (PuzzleSelection)
	puzzle_selected.emit(puzzle)
	
	# Obtener el componente padre para verificar si se permite la selección
	var parent = get_parent()
	while parent and not parent.has_method("_on_PuzzleSelected"):
		parent = parent.get_parent()
	
	# Si encontramos un padre con el método _on_PuzzleSelected, consultamos si se permite la selección
	var selection_allowed = true
	if parent and parent.has_method("_on_PuzzleSelected"):
		selection_allowed = parent._on_PuzzleSelected(puzzle)
	
	# Si no se permite la selección (durante scroll), salir
	if not selection_allowed:
		print("PuzzleGrid: Selección no permitida por el componente padre (scroll activo)")
		return
	
	# Si se permite la selección, continuar con la lógica de selección de puzzle
	print("PuzzleGrid: Selección permitida, procesando puzzle")
	
	# Verificar los datos del puzzle
	if puzzle == null:
		print("PuzzleGrid: ERROR - Los datos del puzzle son NULL")
		return
	
	if typeof(puzzle) != TYPE_DICTIONARY:
		print("PuzzleGrid: ERROR - Los datos del puzzle no son un diccionario, son de tipo: ", typeof(puzzle))
		return
	
	print("PuzzleGrid: Nombre del puzzle: ", puzzle.get("name", "NO NAME"))
	print("PuzzleGrid: Guardando puzzle en GLOBAL.selected_puzzle")
	
	# Guardar el puzzle seleccionado en la variable global
	GLOBAL.selected_puzzle = puzzle
	print("PuzzleGrid: Cambiando a escena PuzzleGame.tscn")
	
	# Verificar que la escena existe antes de cambiar
	if ResourceLoader.exists("res://Scenes/PuzzleGame.tscn"):
		print("PuzzleGrid: La escena PuzzleGame.tscn existe, cambiando...")
		get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")
	else:
		print("PuzzleGrid: ERROR - La escena PuzzleGame.tscn no existe")
		# Intentar con otra ruta
		if ResourceLoader.exists("res://Scenes/PuzzleGame.tscn"):
			print("PuzzleGrid: Intentando con ruta alternativa...")
			get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")
		else:
			print("PuzzleGrid: ERROR - No se pudo encontrar la escena del juego")
