extends Node2D

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")

var title_label : Label
var scroll_container : ScrollContainer
var margin_container : MarginContainer
var grid_container: GridContainer

# Añadir variables para controlar el desplazamiento táctil
var is_scrolling = false
var scroll_start_time = 0

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
	
	# Intentar reemplazar el ScrollContainer estándar con nuestro TouchScrollContainer
	if scroll_container:
		var parent = scroll_container.get_parent()
		var index = scroll_container.get_index()
		
		# Guardar referencias a los hijos actuales
		var children = []
		for child in scroll_container.get_children():
			children.append(child)
		
		# Intentar cargar la escena del TouchScrollContainer
		var touch_scroll_scene = load("res://Scenes/Components/TouchScrollContainer.tscn")
		if touch_scroll_scene:
			# Crear una nueva instancia del TouchScrollContainer
			var new_scroll = touch_scroll_scene.instantiate()
			
			# Copiar propiedades del ScrollContainer original
			new_scroll.size_flags_horizontal = scroll_container.size_flags_horizontal
			new_scroll.size_flags_vertical = scroll_container.size_flags_vertical
			new_scroll.custom_minimum_size = scroll_container.custom_minimum_size
			new_scroll.horizontal_scroll_mode = scroll_container.horizontal_scroll_mode
			new_scroll.vertical_scroll_mode = scroll_container.vertical_scroll_mode
			
			# Conectar señales de desplazamiento
			new_scroll.connect("touch_scroll_started", Callable(self, "_on_scroll_started"))
			new_scroll.connect("touch_scroll_ended", Callable(self, "_on_scroll_ended"))
			
			# Eliminar el ScrollContainer original
			parent.remove_child(scroll_container)
			scroll_container.queue_free()
			
			# Añadir el nuevo TouchScrollContainer
			parent.add_child(new_scroll)
			parent.move_child(new_scroll, index)
			
			# Mover los hijos al nuevo ScrollContainer
			for child in children:
				if child.get_parent():
					child.get_parent().remove_child(child)
				new_scroll.add_child(child)
			
			# Actualizar la referencia
			scroll_container = new_scroll
			print("PuzzleSelection: ScrollContainer reemplazado por TouchScrollContainer")
		else:
			print("PuzzleSelection: No se pudo cargar TouchScrollContainer, intentando adjuntar script")
			
			# Intentar adjuntar el script TouchScrollHandler
			var touch_handler_script = load("res://Scripts/TouchScrollHandler.gd")
			if touch_handler_script:
				scroll_container.set_script(touch_handler_script)
				
				# Conectar señales de desplazamiento
				if scroll_container.has_signal("touch_scroll_started"):
					scroll_container.connect("touch_scroll_started", Callable(self, "_on_scroll_started"))
				if scroll_container.has_signal("touch_scroll_ended"):
					scroll_container.connect("touch_scroll_ended", Callable(self, "_on_scroll_ended"))
				
				print("PuzzleSelection: Script TouchScrollHandler adjuntado al ScrollContainer")
	
	# Configurar el GridContainer para mejorar el desplazamiento táctil
	if grid_container:
		grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Conectar la señal de visibilidad
	connect("visibility_changed", Callable(self, "_on_visibility_changed"))
	
	# Actualizar los datos del pack seleccionado desde ProgressManager
	update_selected_pack()
	
	# Cargar los puzzles
	load_puzzles()

# Función que se ejecuta cuando la escena se vuelve visible
func _on_visibility_changed():
	print("PuzzleSelection: _on_visibility_changed() - Visibilidad cambiada")
	if is_visible_in_tree():
		print("PuzzleSelection: La escena se ha vuelto visible, actualizando datos")
		# Actualizar los datos del pack seleccionado
		update_selected_pack()
		# Recargar los puzzles con los datos actualizados
		load_puzzles()
		
# Nueva función para actualizar los datos del pack seleccionado
func update_selected_pack():
	if GLOBAL.selected_pack != null and GLOBAL.selected_pack.has("id"):
		print("PuzzleSelection: Actualizando datos del pack seleccionado: " + GLOBAL.selected_pack.id)
		# Obtener los datos actualizados del pack desde ProgressManager
		var updated_pack = progress_manager.get_pack_with_progress(GLOBAL.selected_pack.id)
		if not updated_pack.is_empty():
			print("PuzzleSelection: Datos del pack actualizados correctamente")
			GLOBAL.selected_pack = updated_pack
		else:
			print("ERROR: No se pudieron obtener los datos actualizados del pack")
	else:
		print("ERROR: No hay pack seleccionado o no tiene ID")
		
func load_puzzles():
	var pack = GLOBAL.selected_pack
	
	# Limpiar cualquier elemento existente en el grid_container, no en el VBoxContainer
	for child in grid_container.get_children():
		child.queue_free()
	
	# Añadir un título a la pantalla
	if title_label:
		title_label.text = "Pack: " + pack.name
		title_label.custom_minimum_size = Vector2(0, 80)
		title_label.add_theme_font_size_override("font_size", 36)
	
	# Configurar el ScrollContainer
	if scroll_container:
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(0, 0)  # Eliminar altura mínima fija
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	# Configurar el MarginContainer
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 25)
		margin_container.add_theme_constant_override("margin_right", 25)
		margin_container.add_theme_constant_override("margin_top", 25)
		margin_container.add_theme_constant_override("margin_bottom", 25)
		margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Configurar el GridContainer
	if grid_container:
		grid_container.columns = 2
		grid_container.add_theme_constant_override("h_separation", 30)
		grid_container.add_theme_constant_override("v_separation", 30)
		grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Verificar si hay puzzles para mostrar
	if not pack.has("puzzles") or pack.puzzles.size() == 0:
		var no_puzzles_label = Label.new()
		no_puzzles_label.text = "No hay puzzles disponibles en este pack"
		no_puzzles_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_puzzles_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		no_puzzles_label.custom_minimum_size = Vector2(0, 120)
		no_puzzles_label.add_theme_font_size_override("font_size", 22)
		no_puzzles_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		grid_container.add_child(no_puzzles_label)
		print("No hay puzzles para mostrar")
	else:
		# Cargar los puzzles
		print("Cargando " + str(pack.puzzles.size()) + " puzzles")
		for i in range(pack.puzzles.size()):
			var puzzle = pack.puzzles[i]
			print("Cargando puzzle " + str(i) + ": " + str(puzzle))
			
			# Verificar si el puzzle está desbloqueado
			var is_unlocked = puzzle.has("unlocked") and puzzle.unlocked
			var is_completed = puzzle.has("completed") and puzzle.completed
			
			print("Puzzle " + puzzle.id + " - Desbloqueado: " + str(is_unlocked) + ", Completado: " + str(is_completed))
			
			# Cargar la escena del PuzzleItem
			var puzzle_item_scene = load("res://Scenes/Components/New/PuzzleItem.tscn")
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
				
				# Configurar el filtro de ratón para permitir la interacción
				puzzle_item.mouse_filter = Control.MOUSE_FILTER_STOP
				
				# Conectar la señal de selección de puzzle solo si está desbloqueado
				if is_unlocked:
					puzzle_item.connect("puzzle_selected", Callable(self, "_on_PuzzleSelected"))
				
				# Añadir el PuzzleItem al GridContainer
				grid_container.add_child(puzzle_item)
				print("PuzzleItem añadido correctamente")
			else:
				print("ERROR: No se pudo cargar la escena PuzzleItem")

func _on_PuzzleSelected(puzzle):
	# Evitar selección durante el desplazamiento
	if is_scrolling:
		print("PuzzleSelection: Ignorando selección durante desplazamiento")
		return
		
	# Verificar si ha pasado suficiente tiempo desde el inicio del desplazamiento
	var current_time = Time.get_ticks_msec()
	if current_time - scroll_start_time < 300:  # 300ms de umbral
		print("PuzzleSelection: Ignorando selección inmediatamente después del desplazamiento")
		return
	
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

# Nueva función para manejar el cambio de dificultad
func _on_difficulty_changed(columns, rows):
	print("PuzzleSelection: Dificultad cambiada a " + str(columns) + "x" + str(rows))
	
	# Actualizar las variables globales
	GLOBAL.columns = columns
	GLOBAL.rows = rows
	
	# No es necesario recargar la escena en la selección de puzzles,
	# ya que los puzzles se cargarán con la nueva dificultad cuando se seleccionen

func _on_scroll_started():
	is_scrolling = true
	scroll_start_time = Time.get_ticks_msec()
	print("PuzzleSelection: Inicio de desplazamiento")

func _on_scroll_ended():
	# Mantener el estado de desplazamiento por un breve período para evitar clics accidentales
	await get_tree().create_timer(0.1).timeout
	is_scrolling = false
	print("PuzzleSelection: Fin de desplazamiento")
