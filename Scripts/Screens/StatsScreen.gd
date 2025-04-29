extends Node2D

# Referencias a nodos de la interfaz
var pack_selector: OptionButton = null
var puzzle_selector: OptionButton = null
var difficulty_selector: OptionButton = null
var puzzle_image: TextureRect = null

# Labels de estadísticas
var completions_label: Label = null
var best_time_label: Label = null
var best_time_date_label: Label = null
var best_moves_label: Label = null
var best_moves_date_label: Label = null
var no_records_label: Label = null
var no_stats_label: Label = null
var general_stats_label: Label = null

var progress_manager = null

# Datos actuales
var current_pack_id: String = ""
var current_puzzle_id: String = ""
var current_difficulty: String = ""
var packs_data = []

func _ready():
	# Obtener referencia al ProgressManager
	progress_manager = get_node("/root/ProgressManager")
	
	# Obtener referencias a los nodos de la interfaz
	pack_selector = $CanvasLayer/MainContainer/ContentContainer/Selectors/PackSelector/PackDropdown
	puzzle_selector = $CanvasLayer/MainContainer/ContentContainer/Selectors/PuzzleSelector/PuzzleDropdown
	difficulty_selector = $CanvasLayer/MainContainer/ContentContainer/Selectors/DifficultySelector/DifficultyDropdown
	puzzle_image = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/PuzzleImagePanel/MarginContainer/PuzzleImage
	
	# Obtener referencias a los labels de estadísticas
	var stats_container = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/StatsPanel/StatsContainer
	general_stats_label = stats_container.get_node("GeneralStatsLabel")
	completions_label = stats_container.get_node("CompletionsLabel")
	best_time_label = stats_container.get_node("BestTimeLabel")
	best_time_date_label = stats_container.get_node("BestTimeDateLabel")
	best_moves_label = stats_container.get_node("BestMovesLabel")
	best_moves_date_label = stats_container.get_node("BestMovesDateLabel")
	no_records_label = stats_container.get_node("NoRecordsLabel")
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
	
	if difficulty_selector:
		difficulty_selector.item_selected.connect(_on_difficulty_selected)
	
	# Configurar correctamente el panel y la imagen
	var panel = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/PuzzleImagePanel
	panel.clip_children = 1 # CLIP_CHILDREN_ONLY
	
	var image = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/PuzzleImagePanel/MarginContainer/PuzzleImage
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

# Llenar el selector de dificultades para un puzzle
func populate_difficulty_selector(puzzle_id: String):
	if not difficulty_selector:
		return
	
	difficulty_selector.clear()
	current_puzzle_id = puzzle_id
	
	# Cargar la imagen del puzzle seleccionado
	load_puzzle_image(current_pack_id, puzzle_id)
	
	# Obtener estadísticas del puzzle
	var puzzle_stats = progress_manager.get_puzzle_stats(current_pack_id, puzzle_id)
	
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
	
	for difficulty in difficulties:
		difficulty_selector.add_item(difficulty)
		difficulty_selector.set_item_metadata(difficulty_selector.get_item_count() - 1, difficulty)
	
	# Seleccionar automáticamente la primera dificultad
	if difficulty_selector.item_count > 0:
		difficulty_selector.select(0)
		_on_difficulty_selected(0)

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
		if texture:
			puzzle_image.texture = texture
	else:
		# Cargar imagen predeterminada si no hay imagen específica
		var default_texture = load("res://Assets/UI/puzzle_placeholder.png")
		if default_texture:
			puzzle_image.texture = default_texture

# Mostrar estadísticas para una dificultad específica
func show_stats_for_difficulty(difficulty: String):
	current_difficulty = difficulty
	
	# Resetear todos los labels
	reset_stats_display()
	
	# Obtener estadísticas
	var puzzle_stats = progress_manager.get_puzzle_stats(current_pack_id, current_puzzle_id)
	if not puzzle_stats.has(difficulty):
		no_stats_label.visible = true
		general_stats_label.visible = false
		return
	
	var stats = puzzle_stats[difficulty]
	
	# Mostrar estadísticas generales
	general_stats_label.visible = true
	
	# Verificar si hay datos de récords
	var has_records = (stats.has("best_time") and stats["best_time"] > 0) or (stats.has("best_moves") and stats["best_moves"] > 0) or (stats.has("best_flips") and stats["best_flips"] < 99999) or (stats.has("best_flip_moves") and stats["best_flip_moves"] < 99999)
	
	if not has_records:
		no_records_label.visible = true
		return
	
	# Actualizar completado
	completions_label.text = tr("Veces completado: ") + str(int(stats["completions"]))
	completions_label.visible = true
	
	# Actualizar mejor tiempo
	if stats.has("best_time") and stats["best_time"] > 0:
		var best_time_minutes = int(stats["best_time"]) / 60
		var best_time_seconds = int(stats["best_time"]) % 60
		best_time_label.text = tr("Mejor tiempo: ") + "%02d:%02d" % [best_time_minutes, best_time_seconds]
		best_time_label.visible = true
		
		# Fecha del mejor tiempo
		if stats.has("best_time_date"):
			var date_str = format_date_time(stats["best_time_date"])
			best_time_date_label.text = tr("Conseguido el: ") + date_str
			best_time_date_label.visible = true
	
	# Actualizar mejor movimientos
	if stats.has("best_moves") and stats["best_moves"] > 0:
		best_moves_label.text = tr("Mejor movimientos: ") + str(int(stats["best_moves"]))
		best_moves_label.visible = true
		
		# Fecha de los mejores movimientos
		if stats.has("best_moves_date"):
			var date_str = format_date_time(stats["best_moves_date"])
			best_moves_date_label.text = tr("Conseguido el: ") + date_str
			best_moves_date_label.visible = true
	
	# Nuevas estadísticas: Flips
	if stats.has("best_flips") and stats["best_flips"] < 99999:
		var flips_label = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/StatsPanel/StatsContainer/FlipsLabel
		if flips_label:
			flips_label.text = tr("Menor número de flips: ") + str(int(stats["best_flips"]))
			flips_label.visible = true
		
		# Fecha de los mejores flips
		if stats.has("best_flips_date"):
			var flips_date_label = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/StatsPanel/StatsContainer/FlipsDateLabel
			if flips_date_label:
				var date_str = format_date_time(stats["best_flips_date"])
				flips_date_label.text = tr("Conseguido el: ") + date_str
				flips_date_label.visible = true
	
	# Nuevas estadísticas: Movimientos durante flips
	if stats.has("best_flip_moves") and stats["best_flip_moves"] < 99999:
		var flip_moves_label = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/StatsPanel/StatsContainer/FlipMovesLabel
		if flip_moves_label:
			flip_moves_label.text = tr("Menor movimientos con flip: ") + str(int(stats["best_flip_moves"]))
			flip_moves_label.visible = true
		
		# Fecha de los mejores movimientos en flip
		if stats.has("best_flip_moves_date"):
			var flip_moves_date_label = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/StatsPanel/StatsContainer/FlipMovesDateLabel
			if flip_moves_date_label:
				var date_str = format_date_time(stats["best_flip_moves_date"])
				flip_moves_date_label.text = tr("Conseguido el: ") + date_str
				flip_moves_date_label.visible = true
	
	# Mostrar historial si hay entradas
	if stats.has("history") and stats["history"].size() > 0:
		var history_label = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/StatsPanel/StatsContainer/HistoryLabel
		if history_label:
			var history_text = tr("Historial de partidas:") + "\n"
			
			for i in range(min(5, stats["history"].size())):
				var entry = stats["history"][i]
				var entry_time = "%02d:%02d" % [int(entry["time"]) / 60, int(entry["time"]) % 60]
				
				# Añadir información del modo de juego
				var gamemode_name = "Normal"
				if entry.has("gamemode"):
					match entry["gamemode"]:
						1: gamemode_name = "Relax"
						3: gamemode_name = "Contrarreloj"
						4: gamemode_name = "Desafío"
				
				history_text += "\n" + format_date_time(entry["date"]) + " - " + tr("Modo: ") + gamemode_name
				history_text += "\n  " + tr("Tiempo: ") + entry_time + ", " + tr("Movimientos: ") + str(entry["moves"])
				
				# Añadir información sobre flips si está disponible
				var flips_info = ""
				if entry.has("flips"):
					flips_info = tr("Flips: ") + str(entry["flips"])
				
				if entry.has("flip_moves"):
					if flips_info != "":
						flips_info += ", "
					flips_info += tr("Mov. flip: ") + str(entry["flip_moves"])
				
				if flips_info != "":
					history_text += "\n  " + flips_info
				
				history_text += "\n"
			
			history_label.text = history_text
			history_label.visible = true

# Restablecer la visualización de estadísticas
func reset_stats_display():
	general_stats_label.visible = false
	completions_label.visible = false
	best_time_label.visible = false
	best_time_date_label.visible = false
	best_moves_label.visible = false
	best_moves_date_label.visible = false
	no_records_label.visible = false
	no_stats_label.visible = false
	
	# Ocultar también los nuevos labels
	var flips_label = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/StatsPanel/StatsContainer/FlipsLabel
	var flips_date_label = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/StatsPanel/StatsContainer/FlipsDateLabel
	var flip_moves_label = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/StatsPanel/StatsContainer/FlipMovesLabel
	var flip_moves_date_label = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/StatsPanel/StatsContainer/FlipMovesDateLabel
	var history_label = $CanvasLayer/MainContainer/ContentContainer/ContentHBox/StatsPanel/StatsContainer/HistoryLabel
	
	if flips_label:
		flips_label.visible = false
	if flips_date_label:
		flips_date_label.visible = false
	if flip_moves_label:
		flip_moves_label.visible = false
	if flip_moves_date_label:
		flip_moves_date_label.visible = false
	if history_label:
		history_label.visible = false

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
	
	# No necesitamos limpiar el selector de dificultades aquí ya que
	# se llenará automáticamente al seleccionar el primer puzzle

func _on_puzzle_selected(index: int):
	var puzzle_id = puzzle_selector.get_item_metadata(index)
	populate_difficulty_selector(puzzle_id)
	
	# No necesitamos limpiar el contenedor de estadísticas aquí ya que
	# se llenará automáticamente al seleccionar la primera dificultad

func _on_difficulty_selected(index: int):
	var difficulty = difficulty_selector.get_item_metadata(index)
	show_stats_for_difficulty(difficulty)

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn") 
