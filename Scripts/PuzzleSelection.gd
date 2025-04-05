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
	else:
		print("ERROR: No se encontró el componente PuzzleGrid en la escena")


	# No es necesario recargar la escena en la selección de puzzles,
	# ya que los puzzles se cargarán con la nueva dificultad cuando se seleccionen

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
