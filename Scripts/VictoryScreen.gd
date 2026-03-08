extends Control

@export var labelNamePuzzle: Label
@export var labelInfo: Label
@export var statsLabel: Label
@export var puzzleImage2D: Sprite2D
@export var textView: RichTextLabel
@export var labelTitle : Label
@export var expanseImagePanel : Panel
@export var time_label: Label
@export var moves_label: Label
@export var score_label: Label
@export var new_time_label: Label
@export var new_moves_label: Label
@export var new_score_label: Label

# Variables para almacenar los datos del puzzle
var puzzle_data = null
var pack_data = null
var total_moves = 0
var elapsed_time = 0.0  # Nueva variable para el tiempo transcurrido
var difficulty = {"columns": 0, "rows": 0}  # Nueva variable para la dificultad
var current_pack_id = ""
var current_puzzle_id = ""
var progress_manager = null
var flip_count = 0      # Número de flips realizados
var flip_move_count = 0  # Movimientos durante flips

# Variables para datos de puntuación
var score_data = {}     # Datos de puntuación del sistema de scoring

# Referencias a nodos de la interfaz
var image_view = null
var text_view = null
var toggle_button = null
var showing_image = true

# Variable para detectar si estamos en un dispositivo móvil
var is_mobile = false

func _ready():
	# Reproducir sonido de victoria
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx("res://Assets/Sounds/SFX/win.wav")
	
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Obtener referencia al ProgressManager
	progress_manager = get_node("/root/ProgressManager")
	setup_ui()
	
	# Obtener los datos de victoria desde GLOBAL
	if GLOBAL.has_method("get") and GLOBAL.get("victory_data") != null:
		var victory_data = GLOBAL.victory_data
		
		# Cargar los datos del puzzle
		if victory_data.has("puzzle"):
			puzzle_data = victory_data.puzzle
		
		# Cargar los datos del pack
		if victory_data.has("pack"):
			pack_data = victory_data.pack
		
		# Cargar el número de movimientos
		if victory_data.has("total_moves"):
			total_moves = victory_data.total_moves
		
		# Cargar el tiempo transcurrido
		if victory_data.has("elapsed_time"):
			elapsed_time = victory_data.elapsed_time
			
		# Cargar información de dificultad
		if victory_data.has("difficulty"):
			difficulty = victory_data.difficulty
		
		# Cargar los IDs para la navegación
		if victory_data.has("pack_id"):
			current_pack_id = victory_data.pack_id

		# Cargar datos de flips
		if victory_data.has("flip_count"):
			flip_count = victory_data.flip_count

		if victory_data.has("flip_move_count"):
			flip_move_count = victory_data.flip_move_count

		if victory_data.has("puzzle_id"):
			current_puzzle_id = victory_data.puzzle_id
		
		# Cargar datos de puntuación
		if victory_data.has("score_data"):
			score_data = victory_data.score_data
			print("VictoryScreen: Datos de puntuación cargados: ", score_data)
		
		# Limpiar los datos de victoria para evitar problemas si se vuelve a esta escena

	
	# Si tenemos datos del puzzle, mostrarlos
	if puzzle_data != null:
		update_ui_with_puzzle_data()
	else:
		# Si no hay datos, intentar usar GLOBAL.selected_puzzle como respaldo
		if GLOBAL.selected_puzzle != null:
			puzzle_data = GLOBAL.selected_puzzle
			update_ui_with_puzzle_data()
	
	# Mostrar logros desbloqueados si hay alguno
	show_unlocked_achievements()
	
	# Verificar si la dificultad progresiva está habilitada y aumentarla si es el caso
	if GLOBAL.progresive_difficulty == true:
		if GLOBAL.rows < 22:
			GLOBAL.rows += 1
		elif GLOBAL.columns < 10:
			GLOBAL.columns += 1
		# Guardar la configuración actualizada
		GLOBAL.save_settings()
	
	# Configurar todos los paneles de resultados
	setup_result_panels()
	
	# Adaptar la UI para dispositivos móviles
	# adapt_ui_for_device()
	if GLOBAL.has_method("get") and GLOBAL.get("victory_data") != null:
		# Guardar las estadísticas en el ProgressManager
		save_stats_to_progress_manager(GLOBAL.victory_data)
		

# Función para configurar la interfaz básica
func setup_ui():
	# Configurar el Sprite2D si existe
	var sprite = puzzleImage2D
	if sprite and sprite.texture:
		# Obtener el tamaño del contenedor
		var container_size = get_viewport_rect().size
		
		# Calcular el espacio disponible para la imagen (considerando otros elementos)
		var available_height = container_size.y * 0.60  # Usar solo el 65% de la altura para la imagen
		var max_width = min(container_size.x * 0.7, 720)  # Limitar el ancho máximo
		
		# Calcular la escala para que la imagen se ajuste al espacio disponible
		var texture_size = sprite.texture.get_size()
		var scale_factor_width = max_width / texture_size.x
		var scale_factor_height = available_height / texture_size.y
		
		# Usar el factor más pequeño para asegurar que la imagen quepa completamente
		var scale_factor = min(scale_factor_width, scale_factor_height)
		
		# Aplicar la escala manteniendo la proporción
		sprite.scale = Vector2(scale_factor, scale_factor)
		
		# Centrar la imagen en el contenedor

		
		# Guardar referencia
		image_view = sprite
	
	# Configurar la vista de texto
	text_view = textView
	if text_view:
		text_view.visible = false
		text_view.bbcode_enabled = true
		text_view.scroll_active = true
		text_view.add_theme_font_size_override("normal_font_size", 18)  # Aumentar tamaño de fuente
		text_view.add_theme_color_override("default_color", Color(0, 0, 0))
		text_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Configurar márgenes para el texto
		text_view.add_theme_constant_override("margin_left", 40)
		text_view.add_theme_constant_override("margin_right", 40)
		text_view.add_theme_constant_override("margin_top", 40)
		text_view.add_theme_constant_override("margin_bottom", 40)
		
		# Configurar el espaciado entre líneas
		text_view.add_theme_constant_override("line_separation", 10)
	
	# Configurar el botón de alternancia
	toggle_button = $CanvasLayer/VBoxContainer/BlockButtonChange/Button
	if toggle_button:
		toggle_button.custom_minimum_size = Vector2(150, 40)
		toggle_button.add_theme_stylebox_override("normal", _create_button_style(Color(0.1, 0.3, 0.5, 1.0)))
		toggle_button.add_theme_stylebox_override("hover", _create_button_style(Color(0.2, 0.4, 0.6, 1.0)))
		toggle_button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.05, 0.2, 0.4, 1.0)))
		toggle_button.add_theme_color_override("font_color", Color(1, 1, 1))
		if not toggle_button.is_connected("pressed", Callable(self, "_on_toggle_view_pressed")):
			toggle_button.connect("pressed", Callable(self, "_on_toggle_view_pressed"))
	
	# Configurar los botones existentes
	var hbox_buttons = $CanvasLayer/VBoxContainer/HBoxContainer
	if hbox_buttons:
		# Centrar el contenedor de botones
		hbox_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Asegurarse de que los botones tengan el estilo correcto
		for button in hbox_buttons.get_children():
			if button is Button:
				button.custom_minimum_size = Vector2(150, 50)
				button.add_theme_stylebox_override("normal", _create_button_style(Color(0.1, 0.3, 0.5, 1.0)))
				button.add_theme_stylebox_override("hover", _create_button_style(Color(0.2, 0.4, 0.6, 1.0)))
				button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.05, 0.2, 0.4, 1.0)))
				button.add_theme_color_override("font_color", Color(1, 1, 1))

	_refresh_toggle_button_text()

func update_ui_texts():
	if labelTitle:
		labelTitle.text = TranslationServer.translate("common_completed").to_upper()

	update_ui_with_puzzle_data()
	_refresh_toggle_button_text()

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		update_ui_texts()

func _refresh_toggle_button_text():
	if toggle_button:
		toggle_button.text = TranslationServer.translate("common_image") if !showing_image else TranslationServer.translate("common_text")

# Función para actualizar la interfaz con los datos del puzzle
func update_ui_with_puzzle_data():
	# Actualizar la información de movimientos y tiempo
	var info_label = labelInfo
	if info_label:
		info_label.text = TranslationServer.translate("victory_completed_in_prefix") + " " + str(total_moves) + TranslationServer.translate("victory_moves_suffix") + "\n" + TranslationServer.translate("victory_time_prefix") + " " + _format_time_value(elapsed_time)
	
	# Actualizar la información de estadísticas
	var stats_label = statsLabel
	if stats_label and progress_manager:
		# Obtener las estadísticas del puzzle actual
		var puzzle_stats = progress_manager.get_puzzle_stats(current_pack_id, current_puzzle_id)
		var difficulty_key = _get_difficulty_key()
		
		if puzzle_stats.has(difficulty_key):
			var stats = puzzle_stats[difficulty_key]
			
			var stats_text = "%s: %s\n" % [TranslationServer.translate("stats_best_time"), _format_time_value(stats.best_time)]
			stats_text += "%s: %s\n" % [TranslationServer.translate("stats_best_moves"), str(stats.best_moves)]
			stats_text += "%s: %s" % [TranslationServer.translate("stats_completions"), str(stats.completions)]
			
			stats_label.text = stats_text
		else:
			stats_label.text = TranslationServer.translate("stats_no_previous")
	
	# Actualizar todos los paneles de resultados
	setup_result_panels()
	
	# Actualizar la imagen
	if puzzle_data and puzzle_data.has("image"):
		var image_texture = load(puzzle_data.image)
		$CanvasLayer/ExpanseImage/PanelContainer/ImageExpanse.texture = image_texture

		if image_view is Sprite2D:
			image_view.texture = image_texture
			
			# Recalcular la escala para la nueva textura
			var container_size = get_viewport_rect().size
			
			# Calcular el espacio disponible para la imagen (considerando otros elementos)
			var available_height = container_size.y * 0.65  # Usar solo el 65% de la altura para la imagen
			var max_width = min(container_size.x * 0.8, 720)  # Limitar el ancho máximo
			
			# Calcular la escala para que la imagen se ajuste al espacio disponible
			var texture_size = image_texture.get_size()
			var scale_factor_width = max_width / texture_size.x
			var scale_factor_height = available_height / texture_size.y
			
			# Usar el factor más pequeño para asegurar que la imagen quepa completamente
			var scale_factor = min(scale_factor_width, scale_factor_height)
			
			# Aplicar la escala manteniendo la proporción
			image_view.scale = Vector2(scale_factor, scale_factor)
			
		elif image_view is Control:
			var texture_rect = image_view.get_node_or_null("TextureRect")
			if texture_rect:
				texture_rect.texture = image_texture
	
	# Actualizar el nombre del puzzle
	if puzzle_data and puzzle_data.has("name"):
		var name_label = labelNamePuzzle
		if name_label:
			name_label.text = TranslationServer.translate(puzzle_data.name).to_upper()
			name_label.visible = true
	
	# Actualizar el texto descriptivo
	if puzzle_data and puzzle_data.has("description") and text_view:
		# Formatear el texto para resaltar el nombre científico si existe
		var description = puzzle_data.description
		var localized_description = TranslationServer.translate(description)
		var formatted_text = localized_description
		
		# Buscar posibles nombres científicos (en cursiva o entre comillas)
		var regex = RegEx.new()
		regex.compile("([A-Z][a-z]+ [a-z]+)")
		var result = regex.search(localized_description)
		
		if result:
			var scientific_name = result.get_string()
			formatted_text = localized_description.replace(scientific_name, "[color=red]" + scientific_name + "[/color]")
		
		# Añadir formato adicional para mejorar la legibilidad
		formatted_text = "[center][font_size=20]" + formatted_text + "[/font_size][/center]"
		
		text_view.text = formatted_text
	
	# Verificar si hay un siguiente puzzle disponible
	var next_button = $CanvasLayer/VBoxContainer/HBoxContainer/Siguiente
	if next_button and progress_manager:
		var next_puzzle = progress_manager.get_next_unlocked_puzzle(current_pack_id, current_puzzle_id)
		next_button.disabled = (next_puzzle == null)

# Función para alternar entre la vista de imagen y texto
func _on_toggle_view_pressed():
	showing_image = !showing_image
	
	# Alternar la visibilidad
	if image_view:
		image_view.visible = showing_image
	if text_view:
		text_view.visible = !showing_image
	
	# Actualizar el texto del botón
	_refresh_toggle_button_text()

# Función para crear un estilo de botón
func _create_button_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	
	# Añadir padding para mejor experiencia táctil
	if is_mobile:
		style.content_margin_left = 15
		style.content_margin_right = 15
		style.content_margin_top = 10
		style.content_margin_bottom = 10
	
	return style

# Funciones existentes para los botones
func _on_RepeatButton_pressed():
	GLOBAL.change_scene_with_loading("res://Scenes/PuzzleGame.tscn")

func _on_NextPuzzleButton_pressed():
	# Obtener el siguiente puzzle del pack actual
	var next_puzzle = progress_manager.get_next_unlocked_puzzle(current_pack_id, current_puzzle_id)
	
	if next_puzzle != null:
		# Si hay un siguiente puzzle, lo cargamos directamente
		GLOBAL.selected_puzzle = next_puzzle
		# Reiniciar la escena actual con el nuevo puzzle
		GLOBAL.change_scene_with_loading("res://Scenes/PuzzleGame.tscn")
	else:
		# Si no hay siguiente puzzle, volvemos a la selección
		GLOBAL.change_scene_with_loading("res://Scenes/PuzzleSelection.tscn")

func _on_MainMenuButton_pressed():
	GLOBAL.change_scene_with_loading("res://Scenes/PuzzleSelection.tscn")

# Función para mostrar logros desbloqueados en esta partida
func show_unlocked_achievements():
	# Verificar si tenemos acceso al AchievementsManager
	if not has_node("/root/AchievementsManager"):
		return
	
	var achievements_manager = get_node("/root/AchievementsManager")
	var unlocked_achievements = achievements_manager.get_achievements_unlocked_this_session()
	
	# Si no hay logros desbloqueados, no hacer nada
	if unlocked_achievements.size() == 0:
		return
	
	# Encontrar la sección de estadísticas para añadir información de logros
	var stats_label = statsLabel
	if stats_label:
		var achievement_text = TranslationServer.translate("common_achievements") + "\n"
		
		for achievement_id in unlocked_achievements:
			var achievement_data = achievements_manager.get_achievement(achievement_id)
			if achievement_data.size() > 0:
				achievement_text += "- " + TranslationServer.translate(achievement_data.name) + "\n"
		
		stats_label.text = achievement_text
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stats_label.add_theme_font_size_override("font_size", 18)
		stats_label.add_theme_color_override("font_color", Color(0.1, 0.3, 0.8))
	
	# También añadir información a la vista de texto
	if text_view and text_view.bbcode_enabled:
		var current_text = text_view.text
		var achievement_bbcode = "\n\n[center][color=#003399][font_size=22]" + TranslationServer.translate("common_achievements").to_upper() + "[/font_size][/color][/center]\n\n"
		
		for achievement_id in unlocked_achievements:
			var achievement_data = achievements_manager.get_achievement(achievement_id)
			if achievement_data.size() > 0:
				achievement_bbcode += "[center][color=#0055AA][font_size=20]" + TranslationServer.translate(achievement_data.name) + "[/font_size][/color]\n"
				achievement_bbcode += "[font_size=18]" + TranslationServer.translate(achievement_data.desc) + "[/font_size][/center]\n\n"
		
		text_view.text = current_text + achievement_bbcode
	
	# Limpiar la lista de logros desbloqueados después de mostrarlos
	achievements_manager.clear_achievements_unlocked_this_session()
	
	# Hacer visible la sección de logros
	if stats_label:
		stats_label.visible = true 

# Función para configurar los valores mostrados en la pantalla de victoria
func setup_result_panels():
	var difficulty_stats := _get_current_difficulty_stats()
	var final_score = score_data.get("final_score", 0) if score_data and score_data.size() > 0 else 0

	time_label.text = _format_time_value(elapsed_time)
	moves_label.text = str(total_moves)
	score_label.text = str(final_score)
	_set_new_record_state(new_time_label, _is_better_result(difficulty_stats, "best_time", elapsed_time, true, 99999.0))
	_set_new_record_state(new_moves_label, _is_better_result(difficulty_stats, "best_moves", total_moves, true, 99999))
	_set_new_record_state(new_score_label, _is_better_result(difficulty_stats, "best_score", final_score, false, 0))

func _get_current_difficulty_stats() -> Dictionary:
	if not progress_manager:
		return {}

	var puzzle_stats: Dictionary = progress_manager.get_puzzle_stats(current_pack_id, current_puzzle_id)
	var difficulty_key := _get_difficulty_key()

	if puzzle_stats.has(difficulty_key):
		return puzzle_stats[difficulty_key]

	return {}

func _get_difficulty_key() -> String:
	return str(difficulty.columns) + "x" + str(difficulty.rows)

func _format_time_value(time_in_seconds: float) -> String:
	var minutes = int(time_in_seconds) / 60
	var seconds = int(time_in_seconds) % 60
	return "%02d:%02d" % [minutes, seconds]

func _is_better_result(difficulty_stats: Dictionary, stat_key: String, current_value, compare_less: bool, default_value) -> bool:
	if difficulty_stats.is_empty():
		return true

	var best_value = difficulty_stats.get(stat_key, default_value)
	if compare_less:
		return current_value < best_value

	return current_value > best_value

func _set_new_record_state(target_label: Label, is_new_record: bool) -> void:
	if target_label:
		target_label.visible = is_new_record

# Nueva función para guardar todas las estadísticas en el ProgressManager
func save_stats_to_progress_manager(victory_data):
	if not progress_manager:
		return
		
	# Preparar la estructura de estadísticas
	var stats = {
		"time": elapsed_time,
		"moves": total_moves,
		"columns": difficulty.columns,
		"rows": difficulty.rows,
		"flips": victory_data.get("flip_count", 0),  # Nuevo - número de flips
		"flip_moves": victory_data.get("flip_move_count", 0),  # Nuevo - movimientos durante flips
		"gamemode": victory_data.get("gamemode", 0),  # Nuevo - modalidad de juego
		"score": score_data.get("final_score", 0),  # Nuevo - puntuación obtenida
		"date": Time.get_datetime_string_from_system()
	}
	var difficulty_key = _get_difficulty_key()
	# Crear la clave de dificultad basada en las dimensiones del puzzle
	# Guardar las estadísticas con los 4 parámetros en el orden correcto
	progress_manager.save_puzzle_stats(stats, current_pack_id, current_puzzle_id, difficulty_key)
	GLOBAL.victory_data = null


func showExpaneseImage():
	# Primero se muestra el fondo negro del expanseImage
	expanseImagePanel.visible = true
	


func _on_texture_button_exit_pressed() -> void:
	pass # Replace with function body.
