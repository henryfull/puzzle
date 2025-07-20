extends Node2D

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")

var title_subtitle : Label
var scroll_container : ScrollContainer
var margin_container : MarginContainer
var puzzle_grid: Node  # Referencia al componente PuzzleGrid

# Añadir variables para controlar el desplazamiento táctil
var is_scrolling = false
var scroll_start_time = 0

# Variable para controlar si estamos en un dispositivo táctil
var is_touch_device = false

func _ready():
	print("PuzzleSelection: _ready()")
	
	# Detectar si estamos en un dispositivo táctil
	is_touch_device = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("ios") or OS.has_feature("android")
	print("PuzzleSelection: Dispositivo táctil: ", is_touch_device)
	
	# Obtener referencias a los nodos existentes en la escena
	title_subtitle = $CanvasLayer/TitleBanner/Subtitle
	scroll_container = $CanvasLayer/VBoxContainer/ScrollContainer
	margin_container = $CanvasLayer/VBoxContainer/ScrollContainer/MarginContainer
	puzzle_grid = $CanvasLayer/VBoxContainer/ScrollContainer/MarginContainer/PuzzleGrid
	
	# Verificar que todos los nodos se hayan encontrado correctamente
	if title_subtitle and scroll_container and margin_container and puzzle_grid:
		print("PuzzleSelection: Todos los nodos encontrados correctamente")
		
		# Conectar la señal puzzle_selected del PuzzleGrid
		if not puzzle_grid.is_connected("puzzle_selected", Callable(self, "_on_PuzzleSelected")):
			puzzle_grid.connect("puzzle_selected", Callable(self, "_on_PuzzleSelected"))
			print("PuzzleSelection: Señal puzzle_selected conectada desde PuzzleGrid")
	else:
		print("ERROR: No se pudieron encontrar todos los nodos necesarios")
		if not title_subtitle:
			print("ERROR: No se encontró el nodo title_subtitle")
		if not scroll_container:
			print("ERROR: No se encontró el nodo scroll_container")
		if not margin_container:
			print("ERROR: No se encontró el nodo margin_container")
		if not puzzle_grid:
			print("ERROR: No se encontró el nodo puzzle_grid")
	
		
		# Guardar referencias a los hijos actuales
		var children = []
		for child in scroll_container.get_children():
			children.append(child)
	
	# Asegurar que haya un pack seleccionado
	ensure_pack_selected()
	
	# Actualizar los datos del pack seleccionado desde ProgressManager
	update_selected_pack()
	
	# Cargar los puzzles
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
	print("PuzzleSelection: load_puzzles() - Iniciando carga de puzzles")
	
	# Verificar que haya un pack seleccionado
	if GLOBAL.selected_pack == null:
		print("PuzzleSelection: ERROR - No hay pack seleccionado, intentando seleccionar uno")
		ensure_pack_selected()
		
		# Si aún no hay pack seleccionado, mostrar un mensaje de error
		if GLOBAL.selected_pack == null:
			print("PuzzleSelection: ERROR - No se pudo seleccionar un pack")
			return
	
	var pack = GLOBAL.selected_pack
	print("PuzzleSelection: Pack seleccionado - ID: ", pack.get("id", "NO ID"), ", Nombre: ", pack.get("name", "NO NAME"))
	
	# Actualizar el subtítulo mostrando el nombre del pack
	if title_subtitle and pack.has("name"):
		title_subtitle.text = "Pack: " + pack.name
		print("PuzzleSelection: Subtítulo actualizado: ", title_subtitle.text)
	
	# Cargar los puzzles utilizando el componente PuzzleGrid
	if puzzle_grid:
		puzzle_grid.load_puzzles(pack)
		# Desplazar automáticamente al último puzzle disponible por desbloquear
		await get_tree().process_frame
		scroll_to_last_available_puzzle()
	else:
		print("ERROR: No se encontró el componente PuzzleGrid en la escena")

# Función para desplazar automáticamente al último puzzle disponible por desbloquear
func scroll_to_last_available_puzzle():
	print("PuzzleSelection: Buscando último puzzle disponible por desbloquear")
	
	if not puzzle_grid or not GLOBAL.selected_pack:
		print("PuzzleSelection: No hay puzzle_grid o pack seleccionado")
		return
	
	var pack = GLOBAL.selected_pack
	if not pack.has("puzzles") or pack.puzzles.size() == 0:
		print("PuzzleSelection: El pack no tiene puzzles")
		return
	
	var puzzle_to_scroll_to = null
	var last_unlocked_index = -1
	
	# Primero verificar si hay un puzzle guardado en el estado
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager:
		var saved_puzzle_id = puzzle_state_manager.get_saved_puzzle_id()
		if not saved_puzzle_id.is_empty():
			# Buscar el puzzle guardado en el pack actual
			for i in range(pack.puzzles.size()):
				var puzzle_data = pack.puzzles[i]
				if puzzle_data.id == saved_puzzle_id:
					puzzle_to_scroll_to = puzzle_data
					print("PuzzleSelection: Encontrado puzzle guardado: ", puzzle_data.id)
					break
	
	# Si no hay puzzle guardado, buscar el último disponible por desbloquear
	if not puzzle_to_scroll_to:
		# Recorrer los puzzles en orden inverso para encontrar el último disponible
		for i in range(pack.puzzles.size() - 1, -1, -1):
			var puzzle_data = pack.puzzles[i]
			
			# Si encontramos un puzzle desbloqueado pero no completado, ese es el que buscamos
			if puzzle_data.unlocked and not puzzle_data.completed:
				puzzle_to_scroll_to = puzzle_data
				print("PuzzleSelection: Encontrado puzzle por completar: ", puzzle_data.id)
				break
			
			# Guardar referencia al último puzzle desbloqueado
			if puzzle_data.unlocked and last_unlocked_index < i:
				last_unlocked_index = i
				puzzle_to_scroll_to = puzzle_data
	
	# Si encontramos un puzzle, desplazar hasta él
	if puzzle_to_scroll_to:
		print("PuzzleSelection: Desplazando al puzzle encontrado")
		
		# Buscar el índice del puzzle en la cuadrícula
		var puzzle_index = -1
		for i in range(pack.puzzles.size()):
			if pack.puzzles[i].id == puzzle_to_scroll_to.id:
				puzzle_index = i
				break
		
		if puzzle_index >= 0:
			# Calcular la posición aproximada
			var rows = puzzle_index / puzzle_grid.columns
			var scroll_position = rows * (puzzle_grid.get_theme_constant("v_separation") + 200) # 200 es una altura aproximada del elemento de puzzle
			
			# Ajustar el desplazamiento
			scroll_container.scroll_vertical = scroll_position
			print("PuzzleSelection: Desplazado a posición vertical: ", scroll_position)
	else:
		print("PuzzleSelection: No se encontró ningún puzzle disponible por desbloquear")

# Nueva función para asegurar que haya un pack seleccionado
func ensure_pack_selected():
	print("PuzzleSelection: Verificando si hay un pack seleccionado")
	if GLOBAL.selected_pack == null or GLOBAL.selected_pack.is_empty():
		print("PuzzleSelection: No hay pack seleccionado, intentando seleccionar el primero disponible")
		
		# Obtener todos los packs disponibles
		var packs = progress_manager.get_all_packs_with_progress()
		if packs.size() > 0:
			print("PuzzleSelection: Seleccionando el primer pack disponible: ", packs[0].id)
			GLOBAL.selected_pack = packs[0]
		else:
			print("PuzzleSelection: ERROR - No hay packs disponibles para seleccionar")
			
			# Intentar cargar directamente del archivo JSON
			var file = FileAccess.open("res://PacksData/sample_packs.json", FileAccess.READ)
			if file:
				var json_text = file.get_as_text()
				file.close()
				var json_result = JSON.parse_string(json_text)
				if json_result and json_result.has("packs") and json_result.packs.size() > 0:
					print("PuzzleSelection: Seleccionando el primer pack del archivo JSON: ", json_result.packs[0].id)
					GLOBAL.selected_pack = json_result.packs[0]
				else:
					print("PuzzleSelection: ERROR - No se pudo analizar el JSON de packs o está vacío")
			else:
				print("PuzzleSelection: ERROR - No se pudo abrir el archivo JSON de packs")
	else:
		print("PuzzleSelection: Ya hay un pack seleccionado: ", GLOBAL.selected_pack.id)



func _on_PuzzleSelected(puzzle) -> void:
	print("PuzzleSelection: Puzzle seleccionado - ID: ", puzzle.get("id", "NO ID"), ", Nombre: ", puzzle.get("name", "NO NAME"))
	
	# Verificar si estamos seleccionando un puzzle diferente al guardado
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager and puzzle_state_manager.has_saved_state():
		var saved_puzzle_id = puzzle_state_manager.get_saved_puzzle_id()
		var saved_pack_id = puzzle_state_manager.get_saved_pack_id()
		var saved_game_mode = puzzle_state_manager.puzzle_state.game_mode
		var saved_difficulty = puzzle_state_manager.puzzle_state.difficulty
		
		var selected_puzzle_id = puzzle.get("id", "")
		var current_pack_id = GLOBAL.selected_pack.id if GLOBAL.selected_pack else ""
		var current_game_mode = GLOBAL.gamemode
		var current_difficulty = GLOBAL.current_difficult
		
		print("PuzzleSelection: Verificando compatibilidad con estado guardado...")
		print("  - Guardado: Pack=", saved_pack_id, ", Puzzle=", saved_puzzle_id, ", Modo=", saved_game_mode, ", Dificultad=", saved_difficulty)
		print("  - Seleccionado: Pack=", current_pack_id, ", Puzzle=", selected_puzzle_id, ", Modo=", current_game_mode, ", Dificultad=", current_difficulty)
		
		# Verificar si hay alguna diferencia
		if (saved_pack_id != current_pack_id or 
			saved_puzzle_id != selected_puzzle_id or 
			saved_game_mode != current_game_mode or 
			saved_difficulty != current_difficulty):
			
			print("PuzzleSelection: ❌ Puzzle seleccionado es diferente al guardado, limpiando estado")
			puzzle_state_manager.clear_all_state()
		else:
			print("PuzzleSelection: ✅ Puzzle seleccionado coincide con el estado guardado")
	
	# Guardar el puzzle seleccionado en la variable global
	GLOBAL.selected_puzzle = puzzle
	
	# Si ya existe una instancia previa de PreGamePuzzle, la eliminamos
	if has_node("PreGamePuzzle"):
		get_node("PreGamePuzzle").queue_free()
	
	# Crear una nueva instancia de PreGamePuzzle
	var pre_game_scene = load("res://Scenes/PreGamePuzzle.tscn")
	var pre_game_instance = pre_game_scene.instantiate()
	
	# Agregar la instancia a la escena
	add_child(pre_game_instance)
	
	# Hacer visible el panel
	pre_game_instance.get_node("CanvasLayer").visible = true
	
	# Actualizar la información del puzzle en la instancia
	pre_game_instance.updateLayout()
