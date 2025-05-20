extends Node2D

# Referencias a nodos de la interfaz
var pack_selector: OptionButton = null
var puzzle_selector: OptionButton = null
var puzzle_image: TextureRect = null
@export var puzzle_panel: PanelContainer = null
@export var stats_container: PanelContainer = null

# Contenedores para tabla de estadísticas
var stats_scroll_container: ScrollContainer = null
var stats_table_container: VBoxContainer = null
var no_stats_label: Label = null

# Constantes para identificar filas de estadísticas
const STAT_DIFFICULTY = "difficulty"
const STAT_COMPLETIONS = "completions"
const STAT_BEST_TIME = "best_time"
const STAT_BEST_MOVES = "best_moves"
const STAT_BEST_FLIPS = "best_flips"
const STAT_BEST_FLIP_MOVES = "best_flip_moves"
const STAT_HISTORY = "history"

var progress_manager = null

# Datos actuales
var current_pack_id: String = ""
var current_puzzle_id: String = ""
var packs_data = []

func _ready():
	# Obtener referencia al ProgressManager
	progress_manager = get_node("/root/ProgressManager")
	
	# Obtener referencias a los nodos de la interfaz
	pack_selector = %PackDropdown
	puzzle_selector = %PuzzleDropdown
	puzzle_image = %PuzzleImage
	
	# Obtener referencias a los contenedores de estadísticas
	stats_scroll_container = stats_container.get_node("StatsScrollContainer")
	stats_table_container = stats_scroll_container.get_node("StatsTableContainer")
	no_stats_label = stats_container.get_node("NoStatsLabel")
	
	# Cargar todos los packs con su progreso
	packs_data = progress_manager.get_all_packs_with_progress()
	
	# Llenar la lista de packs y seleccionar el primero
	populate_pack_selector()
	
	# Si hay packs disponibles, seleccionar el primero automáticamente
	if pack_selector.item_count > 0:
		pack_selector.select(0)
		_on_pack_selected(0)
	
	# Conectar señales
	if pack_selector:
		pack_selector.item_selected.connect(_on_pack_selected)
	
	if puzzle_selector:
		puzzle_selector.item_selected.connect(_on_puzzle_selected)
	
	# Configurar correctamente el panel y la imagen
	var panel = puzzle_panel
	panel.clip_children = 1 # CLIP_CHILDREN_ONLY
	
	var image = puzzle_image
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

# Llenar el selector de packs (solo los desbloqueados)
func populate_pack_selector():
	if not pack_selector:
		return
	
	pack_selector.clear()
	
	for pack in packs_data:
		# Solo añadir packs desbloqueados
		if pack.has("name") and pack.has("unlocked") and pack.unlocked:
			pack_selector.add_item(pack.name)
			pack_selector.set_item_metadata(pack_selector.get_item_count() - 1, pack.id)

# Llenar el selector de puzzles para un pack (solo los desbloqueados)
func populate_puzzle_selector(pack_id: String):
	if not puzzle_selector:
		return
	
	puzzle_selector.clear()
	current_pack_id = pack_id
	
	# Buscar el pack seleccionado
	var selected_pack = null
	for pack in packs_data:
		if pack.id == pack_id:
			selected_pack = pack
			break
	
	if selected_pack and selected_pack.has("puzzles"):
		for puzzle in selected_pack.puzzles:
			# Solo añadir puzzles desbloqueados
			if puzzle.has("name") and puzzle.has("unlocked") and puzzle.unlocked:
				puzzle_selector.add_item(puzzle.name)
				puzzle_selector.set_item_metadata(puzzle_selector.get_item_count() - 1, puzzle.id)
				
		# Seleccionar automáticamente el primer puzzle
		if puzzle_selector.item_count > 0:
			puzzle_selector.select(0)
			_on_puzzle_selected(0)

# Cargar la imagen del puzzle
func load_puzzle_image(pack_id: String, puzzle_id: String):
	if not puzzle_image:
		return
	
	# Buscar el puzzle en los datos
	var puzzle_data = null
	for pack in packs_data:
		if pack.id == pack_id:
			for puzzle in pack.puzzles:
				if puzzle.id == puzzle_id:
					puzzle_data = puzzle
					break
			break
	
	if puzzle_data and puzzle_data.has("image"):
		var image_path = puzzle_data.image
		var texture = load(image_path)
		var image_texture = load(puzzle_data.image)
		$CanvasLayer/ExpanseImage/PanelContainer/ImageExpanse.texture = image_texture
		if texture:
			puzzle_image.texture = texture
	else:
		# Cargar imagen predeterminada si no hay imagen específica
		var default_texture = load("res://Assets/UI/puzzle_placeholder.png")
		if default_texture:
			puzzle_image.texture = default_texture

# Mostrar tabla de estadísticas para todas las dificultades
func show_stats_table():
	current_puzzle_id = puzzle_selector.get_item_metadata(puzzle_selector.selected)
	
	# Limpiar tabla existente
	for child in stats_table_container.get_children():
		stats_table_container.remove_child(child)
		child.queue_free()
	
	# Obtener estadísticas del puzzle
	var puzzle_stats = progress_manager.get_puzzle_stats(current_pack_id, current_puzzle_id)
	
	if puzzle_stats.size() == 0:
		no_stats_label.visible = true
		stats_scroll_container.visible = false
		return
	
	no_stats_label.visible = false
	stats_scroll_container.visible = true
	
	# Ordenar las dificultades para que se muestren de menor a mayor
	var difficulties = puzzle_stats.keys()
	difficulties.sort_custom(func(a, b): 
		var a_parts = a.split("x")
		var b_parts = b.split("x")
		var a_cols = int(a_parts[0])
		var a_rows = int(a_parts[1])
		var b_cols = int(b_parts[0])
		var b_rows = int(b_parts[1])
		
		# Comparar por número total de celdas
		var a_cells = a_cols * a_rows
		var b_cells = b_cols * b_rows
		
		return a_cells < b_cells
	)
	
	# Crear la tabla de estadísticas con formato de filas y columnas
	create_stats_table(difficulties, puzzle_stats)

# Crear tabla de estadísticas con formato de filas y columnas
func create_stats_table(difficulties: Array, puzzle_stats: Dictionary):
	# Crear fila de encabezados
	var header_row = create_header_row(difficulties)
	stats_table_container.add_child(header_row)
	
	# Fila de veces completado
	var completions_row = create_stat_row(tr("Veces completado"), difficulties, puzzle_stats, 
		func(stats): 
			if stats.has("completions"):
				return str(int(stats["completions"]))
			return "-"
	)
	stats_table_container.add_child(completions_row)
	
	# Fila de mejor tiempo
	var best_time_row = create_stat_row(tr("Mejor tiempo"), difficulties, puzzle_stats, 
		func(stats):
			if stats.has("best_time") and stats["best_time"] > 0:
				var minutes = int(stats["best_time"]) / 60
				var seconds = int(stats["best_time"]) % 60
				return "%02d:%02d" % [minutes, seconds]
			return "-"
	)
	stats_table_container.add_child(best_time_row)
	
	# Fila de fecha mejor tiempo
	var best_time_date_row = create_stat_row(tr("Fecha"), difficulties, puzzle_stats, 
		func(stats):
			if stats.has("best_time_date"):
				return format_date_time(stats["best_time_date"])
			return "-"
	)
	stats_table_container.add_child(best_time_date_row)
	
	# Fila de mejor movimientos
	var best_moves_row = create_stat_row(tr("Mejor movimientos"), difficulties, puzzle_stats, 
		func(stats):
			if stats.has("best_moves") and stats["best_moves"] > 0:
				return str(int(stats["best_moves"]))
			return "-"
	)
	stats_table_container.add_child(best_moves_row)
	

	
	# Fila de mejor flips
	var best_flips_row = create_stat_row(tr("Menor flips"), difficulties, puzzle_stats, 
		func(stats):
			if stats.has("best_flips") and stats["best_flips"] < 99999:
				return str(int(stats["best_flips"]))
			return "-"
	)
	stats_table_container.add_child(best_flips_row)
	

	
	# Fila de mejor movimientos con flip
	var best_flip_moves_row = create_stat_row(tr("Menor mov. flip"), difficulties, puzzle_stats, 
		func(stats):
			if stats.has("best_flip_moves") and stats["best_flip_moves"] < 99999:
				return str(int(stats["best_flip_moves"]))
			return "-"
	)
	stats_table_container.add_child(best_flip_moves_row)
	
	
	# Separador antes de historial
	var separator = HSeparator.new()
	stats_table_container.add_child(separator)
	
	
	# Historial de partidas (3 últimas partidas para cada dificultad)
	# create_history_rows(difficulties, puzzle_stats)

# Crear fila de encabezados
func create_header_row(difficulties: Array) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	
	# Celda vacía para el nombre de estadística
	var empty_cell = create_cell("", true)
	empty_cell.custom_minimum_size.x = 150
	row.add_child(empty_cell)
	
	# Celdas de encabezado para cada dificultad
	for difficulty in difficulties:
		var cell = create_cell(difficulty, true)
		cell.custom_minimum_size.x = 150
		row.add_child(cell)
	
	return row

# Crear fila de estadística
func create_stat_row(stat_name: String, difficulties: Array, puzzle_stats: Dictionary, value_getter: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	
	# Celda para el nombre de la estadística
	var name_cell = create_cell(stat_name, false)
	name_cell.custom_minimum_size.x = 150
	row.add_child(name_cell)
	
	# Celdas para los valores de cada dificultad
	for difficulty in difficulties:
		var stats = puzzle_stats[difficulty]
		var value = value_getter.call(stats)
		
		var cell = create_cell(value, false)
		cell.custom_minimum_size.x = 150
		row.add_child(cell)
	
	return row




# Crear una celda para la tabla
func create_cell(text: String, is_header: bool = false) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if !is_header else HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	
	if is_header:
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
	
	return label

# Formatea una fecha ISO como una cadena legible
func format_date_time(date_str: String) -> String:
	if date_str.find("T") >= 0:
		var parts = date_str.split("T")
		var date_part = parts[0]
		var time_part = parts[1].substr(0, 5)  # Tomar solo HH:MM
		return date_part + " " + time_part
	return date_str

# Manejadores de eventos
func _on_pack_selected(index: int):
	var pack_id = pack_selector.get_item_metadata(index)
	populate_puzzle_selector(pack_id)

func _on_puzzle_selected(index: int):
	var puzzle_id = puzzle_selector.get_item_metadata(index)
	current_puzzle_id = puzzle_id
	
	# Cargar la imagen del puzzle seleccionado
	load_puzzle_image(current_pack_id, puzzle_id)
	
	# Mostrar la tabla de estadísticas para todas las dificultades
	show_stats_table()

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn") 


func _on_button_expanse_pressed() -> void:
	$CanvasLayer/ExpanseImage.visible = true
