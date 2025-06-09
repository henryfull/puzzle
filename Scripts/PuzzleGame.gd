# PuzzleGame.gd
# Archivo principal del puzzle - Coordina todos los managers

extends Node2D
class_name PuzzleGame

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")
var VictoryCheckerScene = preload("res://Scripts/gameplay/VictoryChecker.gd")

# Precargar los nuevos managers de puntuación
var PuzzleScoreManagerScene = preload("res://Scripts/PuzzleScoreManager.gd")
var PuzzleRankingManagerScene = preload("res://Scripts/PuzzleRankingManager.gd")

# Precargar la escena de loading puzzle
var LoadingPuzzleScene = preload("res://Scenes/Components/loadingPuzzle/loading_puzzle.tscn")
var loading_puzzle_instance: Node2D

# Referencias a nodos de audio preexistentes en la escena
# NOTA: Ahora se usa AudioManager en lugar de estos nodos directos
# para respetar la configuración de volumen del usuario
@onready var audio_move: AudioStreamPlayer = $AudioMove
@onready var audio_merge: AudioStreamPlayer = $AudioMerge
@onready var audio_flip: AudioStreamPlayer = $AudioFlip

# Referencia al timer de verificación de victoria
@onready var victory_timer: Timer = $VictoryTimer

# Referencia al contenedor de piezas
@export var pieces_container: Node2D
@export var UILayer: CanvasLayer
@export var movesLabel: Label
@export var maxMovesLabel: Label
@export var maxMovesFlipLabel: Label
@export var maxFlipsPanel: Panel
@export var maxFlipsLabel: Label
@export var panelPaused: Panel 

# Referencias a botones en la UI
@export var button_options: Button
@export var flip_button: Button
@export var center_button: Button  # Botón de centrado desde la escena

# Referencias a elementos de puntuación y racha en el UILayer
@export var score_label: Label
@export var streak_label: Label
@export var floating_points_label: Label

# Control para evitar duplicación de puntos flotantes
var last_score_shown: int = 0

# Referencias a mensajes de éxito/error que deberían estar en la escena
@onready var success_message_label: Label = $UILayer/SuccessMessage
@onready var error_message_label: Label = $UILayer/ErrorMessage

# Managers
var input_handler: PuzzleInputHandler
var piece_manager: PuzzlePieceManager
var game_state_manager: PuzzleGameStateManager
var ui_manager: PuzzleUIManager
var score_manager
var ranking_manager

# Variables principales que serán compartidas
var puzzle_texture: Texture2D
var puzzle_width: float
var puzzle_height: float
var cell_size: Vector2
var puzzle_offset: Vector2

# Configuración
@export var image_path: String = "res://Assets/Images/arte1.jpg"
@export var max_scale_percentage: float = 0.9
@export var viewport_scene_path: String = "res://Scenes/TextViewport.tscn"
@export var max_extra_rows: int = 5

var is_mobile: bool = false
var default_rows: int = 0
var default_columns: int = 0

# Estado del puzzle
var puzzle_completed = false
var victory_checker: VictoryChecker

# IDs para progresión
var current_pack_id: String = ""
var current_puzzle_id: String = ""

func _ready():
	print("PuzzleGame: Iniciando juego...")
	
	# Configurar guardado de emergencia al cerrar la aplicación
	get_tree().auto_accept_quit = false
	
	# PASO 1: Instanciar y mostrar el loading puzzle INMEDIATAMENTE
	_show_loading_puzzle()
	
	# PASO 1.5: Ocultar UI temporalmente como medida de seguridad
	_hide_ui_for_loading()
	
	default_rows = GLOBAL.rows
	default_columns = GLOBAL.columns
		
	if OS.has_feature("mobile"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Verificar que los nodos de audio se han cargado correctamente
	_test_audio_nodes()
	
	# Inicializar managers
	_initialize_managers()
	
	# Asegurarnos que el panel de pausa esté oculto al inicio
	if panelPaused:
		panelPaused.visible = false
	
	# Inicializar VictoryChecker
	victory_checker = VictoryCheckerScene.new()
	add_child(victory_checker)
	victory_checker.puzzle_is_complete.connect(_handle_puzzle_really_completed)

	# Verificar si debemos usar el estado guardado o empezar nuevo puzzle
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	var continuing_game = false
	
	# Solo continuar si hay estado guardado Y es el mismo puzzle que queremos jugar
	if puzzle_state_manager and puzzle_state_manager.has_saved_state():
		var saved_pack_id = puzzle_state_manager.get_saved_pack_id()
		var saved_puzzle_id = puzzle_state_manager.get_saved_puzzle_id()
		var current_pack_id_check = GLOBAL.selected_pack.id if GLOBAL.selected_pack else ""
		var current_puzzle_id_check = GLOBAL.selected_puzzle.id if GLOBAL.selected_puzzle else ""
		
		# Solo continuar si es exactamente el mismo puzzle
		if saved_pack_id == current_pack_id_check and saved_puzzle_id == current_puzzle_id_check:
			print("PuzzleGame: Detectado estado guardado para el mismo puzzle, continuando partida...")
			continuing_game = puzzle_state_manager.setup_continue_game()
			if continuing_game:
				print("PuzzleGame: Configuración de continuación aplicada exitosamente")
			else:
				print("PuzzleGame: No se pudo configurar la continuación, empezando nueva partida")
		else:
			print("PuzzleGame: Estado guardado es para otro puzzle (", saved_pack_id, "/", saved_puzzle_id, "), empezando nueva partida")
			# Limpiar el estado guardado del puzzle anterior
			puzzle_state_manager.clear_all_state()
	
	# Configurar el puzzle según los datos seleccionados o guardados
	if GLOBAL.selected_puzzle != null:
		image_path = GLOBAL.selected_puzzle.image
		if GLOBAL.selected_pack != null:
			current_pack_id = GLOBAL.selected_pack.id
		if GLOBAL.selected_puzzle != null:
			current_puzzle_id = GLOBAL.selected_puzzle.id
	
	# Crear o verificar el contenedor de piezas
	_setup_pieces_container()
	
	# Generar textura trasera y crear piezas
	await _setup_puzzle()
	
	# Si estamos continuando una partida, restaurar el estado de las piezas
	if continuing_game and puzzle_state_manager:
		await _restore_puzzle_state(puzzle_state_manager)
	
	# El centrado automático ahora se hace al final de load_and_create_pieces()
	# para asegurar que todas las piezas estén completamente cargadas
	
	# Conectar señales de botones
	_connect_button_signals()
	
	# Configurar modos de juego
	game_state_manager.setup_game_mode()
	
	# Si estamos continuando, restaurar los contadores
	if continuing_game and puzzle_state_manager:
		_restore_game_counters(puzzle_state_manager)
	else:
		# Nueva partida - inicializar el estado
		_initialize_new_puzzle_state()
	
	# Conectar botón de centrado si existe en la escena
	_connect_center_button()
	
	# PASO 2: Esperar un momento adicional para asegurar que todo esté completamente listo
	await get_tree().create_timer(0.15).timeout
	
	# PASO 3: Ocultar y eliminar el loading puzzle
	_hide_loading_puzzle()
	
	# PASO 4: Verificación de seguridad - asegurar que el loading se eliminó
	await get_tree().create_timer(0.2).timeout
	if loading_puzzle_instance != null:
		print("PuzzleGame: ⚠️ Loading puzzle no se eliminó correctamente, forzando eliminación...")
		force_remove_loading_puzzle()
	
	# PASO 5: Restaurar la UI después de eliminar el loading
	_restore_ui_after_loading()
	
	# Mostrar mensaje de bienvenida con opciones de centrado
	_show_centering_welcome_message()
	
	# 🚫 NUEVO: Configurar timer para eliminar diálogos automáticamente
	_setup_dialog_blocker()
	
	# 🚫 NUEVO: Interceptor ultra-agresivo - sobrescribir métodos globales
	_setup_global_dialog_interceptors()

func _connect_button_signals():
	# Conectar botón de opciones (pausa)
	if button_options and not button_options.is_connected("pressed", Callable(self, "_on_button_options_pressed")):
		button_options.connect("pressed", Callable(self, "_on_button_options_pressed"))
	
	# Conectar botón de flip
	if flip_button and not flip_button.is_connected("pressed", Callable(self, "on_flip_button_pressed")):
		flip_button.connect("pressed", Callable(self, "on_flip_button_pressed"))
	
	# Conectar botón de centrado si existe
	if center_button and not center_button.is_connected("pressed", Callable(self, "_on_center_button_pressed")):
		center_button.connect("pressed", Callable(self, "_on_center_button_pressed"))

func _on_button_options_pressed():
	game_state_manager.pause_game()

func _initialize_managers():
	# Crear managers
	input_handler = PuzzleInputHandler.new()
	piece_manager = PuzzlePieceManager.new()
	game_state_manager = PuzzleGameStateManager.new()
	ui_manager = PuzzleUIManager.new()
	score_manager = PuzzleScoreManagerScene.new()
	ranking_manager = PuzzleRankingManagerScene.new()
	
	# Añadir como hijos
	add_child(input_handler)
	add_child(piece_manager)
	add_child(game_state_manager)
	add_child(ui_manager)
	add_child(score_manager)
	add_child(ranking_manager)
	
	# Inicializar con referencias necesarias
	input_handler.initialize(self)
	piece_manager.initialize(self)
	game_state_manager.initialize(self)
	ui_manager.initialize(self)
	score_manager.initialize(self, game_state_manager)
	ranking_manager.initialize()
	
	# Conectar señales del score manager a la UI del UILayer
	_connect_score_ui_signals()

func _connect_score_ui_signals():
	"""Conecta las señales del score manager a los elementos del UILayer"""
	if score_manager:
		score_manager.score_updated.connect(_on_score_updated)
		score_manager.streak_updated.connect(_on_streak_updated)
		score_manager.bonus_applied.connect(_on_bonus_applied)
		print("PuzzleGame: Señales de puntuación conectadas al UILayer")

func _on_score_updated(new_score: int):
	"""Actualiza la puntuación mostrada en el UILayer"""
	if score_label:
		score_label.text = "Puntos: " + str(new_score)
	
	# Mostrar puntos flotantes SIEMPRE que haya un incremento
	if new_score > last_score_shown:
		var points_gained = new_score - last_score_shown
		if points_gained > 0:
			# Mostrar TODOS los incrementos de puntos, no solo los pequeños
			show_floating_points("+" + str(points_gained), "normal")
		
		last_score_shown = new_score

func _on_streak_updated(streak_count: int):
	"""Actualiza la racha mostrada en el UILayer"""
	if streak_label:
		streak_label.text = "Racha: " + str(streak_count)
		
		# Cambiar color según la racha para mejor feedback visual
		if streak_count >= 10:
			streak_label.add_theme_color_override("font_color", Color(1.0, 0.3, 1.0, 1.0))  # Magenta
		elif streak_count >= 5:
			streak_label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0, 1.0))  # Cian
		elif streak_count >= 3:
			streak_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))  # Amarillo
		else:
			streak_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 1.0))  # Verde default

func _on_bonus_applied(bonus_type: String, points: int):
	"""Muestra mensaje descriptivo cuando se aplica un bonus"""
	var bonus_message = ""
	match bonus_type:
		"streak":
			bonus_message = "¡Bonus racha! +" + str(points)
		"group_union":
			bonus_message = "¡Grupos unidos! +" + str(points)
		"no_errors":
			bonus_message = "¡Sin errores! +" + str(points)
		"no_flip":
			bonus_message = "¡Sin flip! +" + str(points)
		_:
			bonus_message = "¡Bonus! +" + str(points)
	
	# Solo mostrar mensaje descriptivo en la parte superior
	# Los puntos flotantes se manejan automáticamente en _on_score_updated()
	show_success_message(bonus_message, 2.0)

# === FUNCIONES PÚBLICAS PARA GESTIÓN DE PUNTUACIÓN EN EL UILAYER ===

func set_score_display(score: int):
	"""Establece la puntuación mostrada en el UILayer directamente"""
	if score_label:
		score_label.text = "Puntos: " + str(score)

func set_streak_display(streak: int):
	"""Establece la racha mostrada en el UILayer directamente"""
	if streak_label:
		streak_label.text = "Racha: " + str(streak)
		
		# Aplicar colores según la racha
		if streak >= 10:
			streak_label.add_theme_color_override("font_color", Color(1.0, 0.3, 1.0, 1.0))  # Magenta
		elif streak >= 5:
			streak_label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0, 1.0))  # Cian
		elif streak >= 3:
			streak_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))  # Amarillo
		else:
			streak_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 1.0))  # Verde default

func update_score_and_streak(score: int, streak: int):
	"""Actualiza tanto la puntuación como la racha de una vez"""
	set_score_display(score)
	set_streak_display(streak)

func get_current_displayed_score() -> int:
	"""Obtiene la puntuación actualmente mostrada en el UILayer"""
	if score_label and score_label.text.begins_with("Puntos: "):
		var score_text = score_label.text.replace("Puntos: ", "")
		return int(score_text)
	return 0

func get_current_displayed_streak() -> int:
	"""Obtiene la racha actualmente mostrada en el UILayer"""
	if streak_label and streak_label.text.begins_with("Racha: "):
		var streak_text = streak_label.text.replace("Racha: ", "")
		return int(streak_text)
	return 0

func hide_score_ui():
	"""Oculta los elementos de puntuación del UILayer"""
	if score_label:
		score_label.visible = false
	if streak_label:
		streak_label.visible = false

func show_score_ui():
	"""Muestra los elementos de puntuación del UILayer"""
	if score_label:
		score_label.visible = true
	if streak_label:
		streak_label.visible = true

func reset_score_display():
	"""Reinicia la visualización de puntuación y racha a valores iniciales"""
	set_score_display(0)
	set_streak_display(0)
	last_score_shown = 0  # Resetear control de puntos flotantes

func show_floating_points(points_text: String, bonus_type: String = ""):
	"""Muestra puntos flotantes animados en el UILayer"""
	if not floating_points_label:
		print("PuzzleGame: Error - floating_points_label no disponible")
		return
	
	print("PuzzleGame: Mostrando puntos flotantes: ", points_text)
	
	# Configurar el texto y color según el tipo de bonus
	floating_points_label.text = points_text
	
	# Aplicar colores según el tipo y cantidad de puntos
	match bonus_type:
		"streak":
			floating_points_label.add_theme_color_override("font_color", Color(1.0, 0.3, 1.0, 1.0))  # Magenta para racha
		"group_union":
			floating_points_label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0, 1.0))  # Cian para grupos unidos
		"no_errors":
			floating_points_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))  # Verde para sin errores
		"no_flip":
			floating_points_label.add_theme_color_override("font_color", Color(0.3, 0.3, 1.0, 1.0))   # Azul para sin flip
		"normal":
			# Determinar color según la cantidad de puntos
			var points_value = int(points_text.replace("+", ""))
			if points_value > 4:
				# Puntos altos (con bonus) - Dorado brillante
				floating_points_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))
			elif points_value > 2:
				# Puntos medios - Amarillo
				floating_points_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))
			else:
				# Puntos básicos - Blanco
				floating_points_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		_:
			floating_points_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))  # Dorado por defecto
	
	# Posicionar en el centro de la pantalla
	var viewport_size = get_viewport_rect().size
	floating_points_label.position.x = (viewport_size.x - floating_points_label.size.x) * 0.5
	floating_points_label.position.y = viewport_size.y * 0.15  # Un poco arriba del centro
	
	# Resetear propiedades iniciales
	floating_points_label.modulate = Color(1, 1, 1, 0)  # Invisible al inicio
	floating_points_label.scale = Vector2(0.5, 0.5)     # Pequeño al inicio
	floating_points_label.visible = true
	
	# Crear animación personalizable
	var tween = create_tween()
	tween.set_parallel(true)  # Permitir múltiples animaciones paralelas
	
	# FASE 1: Aparición con efecto de escala y fade-in (0.3 segundos)
	tween.tween_property(floating_points_label, "modulate", Color(1, 1, 1, 1), 0.3)
	tween.tween_property(floating_points_label, "scale", Vector2(1.2, 1.2), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# FASE 2: Movimiento hacia arriba con efecto de flotación (1.5 segundos)
	var float_target = floating_points_label.position + Vector2(0, -80)
	tween.tween_property(floating_points_label, "position", float_target, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	
	# FASE 3: Reducir escala ligeramente durante el movimiento (0.8 segundos, con delay)
	tween.tween_property(floating_points_label, "scale", Vector2(1.0, 1.0), 0.8).set_delay(0.3).set_ease(Tween.EASE_OUT)
	
	# FASE 4: Desvanecimiento final (0.5 segundos, al final)
	tween.tween_property(floating_points_label, "modulate", Color(1, 1, 1, 0), 0.5).set_delay(1.3)
	
	# FASE 5: Ocultar al final
	tween.tween_callback(func(): floating_points_label.visible = false).set_delay(1.8)
	
	print("PuzzleGame: Animación de puntos flotantes iniciada para: ", points_text)

func _setup_pieces_container():
	if not pieces_container:
		pieces_container = Node2D.new()
		pieces_container.name = "PiecesContainer"
		
		pieces_container.z_index = 5
		# Asegurar que el contenedor esté en la posición (0, 0) para centrado correcto
		pieces_container.position = Vector2.ZERO
		add_child(pieces_container)
		print("Creado contenedor de piezas dinámicamente en posición (0, 0)")
	else:
		print("Usando contenedor de piezas existente:", pieces_container.name)
		pieces_container.z_index = 5
		# Asegurar que el contenedor existente esté en la posición (0, 0)
		pieces_container.position = Vector2.ZERO
		print("PiecesContainer reposicionado a (0, 0) para centrado correcto")

func _setup_puzzle():
	# Primero, generar la textura trasera
	var puzzle_back = await ui_manager.generate_back_texture_from_viewport(viewport_scene_path)
	# Luego crear las piezas
	await piece_manager.load_and_create_pieces(image_path, puzzle_back)

func _unhandled_input(event: InputEvent) -> void:
	input_handler.handle_input(event)

func _notification(what):
	# Interceptar cualquier notificación del sistema durante el puzzle
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		print("PuzzleGame: Detectado cierre de aplicación - Guardando estado de emergencia")
		_emergency_save_state()
		get_tree().quit()
		return

# Funciones de acceso para los managers
func get_puzzle_data():
	return {
		"texture": puzzle_texture,
		"width": puzzle_width,
		"height": puzzle_height,
		"cell_size": cell_size,
		"offset": puzzle_offset
	}

func set_puzzle_data(texture: Texture2D, width: float, height: float, c_size: Vector2, offset: Vector2):
	puzzle_texture = texture
	puzzle_width = width
	puzzle_height = height
	cell_size = c_size
	puzzle_offset = offset

func get_pieces_data():
	return piece_manager.get_pieces_data()

# Función para forzar el recentrado de las piezas (utilidad de diagnóstico)
func force_recenter_puzzle():
	if piece_manager:
		piece_manager.force_recenter_all_pieces()
	else:
		print("PuzzleGame: Error - piece_manager no disponible")

# Función para aplicar corrección inteligente de centrado
func apply_smart_centering():
	if piece_manager:
		print("PuzzleGame: Aplicando corrección inteligente de centrado...")
		piece_manager._apply_smart_centering_correction()
	else:
		print("PuzzleGame: Error - piece_manager no disponible")

# NUEVO: Función para ajustar el margen de bordes dinámicamente (útil para testing)
func adjust_edge_margin(new_margin: float):
	if input_handler:
		input_handler.set_edge_margin(new_margin)
		show_success_message("🔧 Margen de borde: " + str(new_margin) + "px", 2.0)
	else:
		print("PuzzleGame: Error - input_handler no disponible")

# Función para ejecutar diagnóstico completo
func run_positioning_diagnosis():
	if piece_manager:
		print("PuzzleGame: Ejecutando diagnóstico de posicionamiento...")
		return piece_manager._verify_piece_positioning()
	else:
		print("PuzzleGame: Error - piece_manager no disponible")
		return false

# Función para resetear completamente el centrado del puzzle
func force_complete_recenter(silent_mode: bool = false):
	"""
	Función integral que realiza un recentrado completo y seguro del puzzle
	
	Args:
		silent_mode (bool): Si es true, no muestra mensajes al usuario
	"""
	
	if not silent_mode:
		show_success_message("🎯 Ejecutando recentrado completo...", 1.5)
	
	print("PuzzleGame: 🎯 INICIANDO RECENTRADO COMPLETO")
	
	# Paso 1: Diagnóstico inicial
	print("PuzzleGame: Paso 1 - Diagnóstico inicial")
	var initial_diagnosis = run_positioning_diagnosis()
	if initial_diagnosis and not silent_mode:
		show_success_message("✅ Puzzle ya está correctamente centrado", 2.0)
		print("PuzzleGame: ✅ Puzzle ya está centrado correctamente")
		return
	
	# Paso 2: Aplicar corrección inteligente
	print("PuzzleGame: Paso 2 - Aplicando corrección inteligente")
	apply_smart_centering()
	
	# Paso 3: Verificar resultado
	await get_tree().create_timer(0.2).timeout  # Pequeña pausa para que la corrección se aplique
	var final_diagnosis = run_positioning_diagnosis()
	
	if final_diagnosis:
		if not silent_mode:
			show_success_message("✅ Recentrado completado exitosamente", 2.0)
		print("PuzzleGame: ✅ RECENTRADO COMPLETO EXITOSO")
	else:
		# Como último recurso, forzar recentrado
		print("PuzzleGame: Aplicando recentrado forzado como último recurso...")
		force_recenter_puzzle()
		
		if not silent_mode:
			show_success_message("🔧 Recentrado forzado aplicado", 2.0)
		print("PuzzleGame: 🔧 RECENTRADO FORZADO COMPLETADO")

# 🔧 NUEVAS FUNCIONES PARA RESOLUCIÓN DE SUPERPOSICIONES

func resolve_all_puzzle_overlaps():
	"""
	Función pública para resolver todas las superposiciones en el puzzle
	"""
	print("PuzzleGame: 🔧 Ejecutando resolución de superposiciones...")
	
	if piece_manager and piece_manager.has_method("resolve_all_overlaps"):
		show_success_message("🔧 Resolviendo superposiciones...", 1.5)
		await piece_manager.resolve_all_overlaps()
		show_success_message("✅ Superposiciones resueltas", 2.0)
		print("PuzzleGame: ✅ Resolución de superposiciones completada")
	else:
		print("PuzzleGame: ❌ No se pudo acceder a funciones de resolución de superposiciones")
		show_error_message("Error: No se pudo resolver superposiciones", 2.0)

func verify_puzzle_integrity() -> bool:
	"""
	Función para verificar la integridad del puzzle (sin superposiciones)
	Retorna true si todo está correcto, false si hay problemas
	"""
	print("PuzzleGame: 🔍 Verificando integridad del puzzle...")
	
	if piece_manager and piece_manager.has_method("verify_no_overlaps"):
		var is_clean = piece_manager.verify_no_overlaps()
		if is_clean:
			print("PuzzleGame: ✅ Puzzle verificado - Sin superposiciones")
			return true
		else:
			print("PuzzleGame: ⚠️ Se detectaron superposiciones en el puzzle")
			return false
	else:
		print("PuzzleGame: ❌ No se pudo verificar integridad (funciones no disponibles)")
		return false

func force_clean_puzzle_grid():
	"""
	Función para forzar la limpieza del grid del puzzle
	"""
	print("PuzzleGame: 🧹 Forzando limpieza del grid del puzzle...")
	
	if piece_manager and piece_manager.has_method("force_clean_grid"):
		piece_manager.force_clean_grid()
		show_success_message("🧹 Grid del puzzle limpiado", 1.5)
		print("PuzzleGame: ✅ Grid limpiado exitosamente")
	else:
		print("PuzzleGame: ❌ No se pudo limpiar el grid (funciones no disponibles)")
		show_error_message("Error: No se pudo limpiar grid", 2.0)

func run_comprehensive_puzzle_check():
	"""
	Función integral que verifica y corrige todos los problemas del puzzle
	"""
	print("PuzzleGame: 🔧 Ejecutando verificación integral del puzzle...")
	show_success_message("🔧 Verificando integridad del puzzle...", 2.0)
	
	# Paso 1: Verificar superposiciones
	var has_overlaps = not verify_puzzle_integrity()
	if has_overlaps:
		print("PuzzleGame: Detectadas superposiciones, resolviendo...")
		await resolve_all_puzzle_overlaps()
	
	# Paso 2: Verificar centrado
	var centering_ok = run_positioning_diagnosis()
	if not centering_ok:
		print("PuzzleGame: Detectado problema de centrado, corrigiendo...")
		force_complete_recenter(true)
	
	# Paso 3: Verificación final
	var final_overlaps_check = verify_puzzle_integrity()
	var final_centering_check = run_positioning_diagnosis()
	
	if final_overlaps_check and final_centering_check:
		show_success_message("✅ Puzzle verificado - Todo correcto", 3.0)
		print("PuzzleGame: ✅ VERIFICACIÓN INTEGRAL COMPLETADA - Todo está correcto")
	else:
		show_error_message("⚠️ Algunos problemas persisten", 3.0)
		print("PuzzleGame: ⚠️ VERIFICACIÓN INTEGRAL COMPLETADA - Algunos problemas persisten")
		
		if not final_overlaps_check:
			print("PuzzleGame: - Persisten superposiciones")
		if not final_centering_check:
			print("PuzzleGame: - Persisten problemas de centrado")

func _handle_puzzle_really_completed():
	puzzle_completed = true
	print("PuzzleGame: _handle_puzzle_really_completed() - Puzzle marcado como completado internamente tras señal de VictoryChecker.")
	
	# Limpiar el estado guardado del puzzle
	_handle_puzzle_completion_state()
	
	# El VictoryChecker ya maneja la transición a la pantalla de victoria

# Delegación de funciones principales a los managers apropiados
func show_success_message(message: String, duration: float = 1.5):
	# Solo permitir mensajes de éxito normales del juego, NO diálogos de salida
	if not message.contains("salir") and not message.contains("exit") and not message.contains("quit"):
		ui_manager.show_success_message(message, duration)

func show_error_message(message: String, duration: float = 2.0):
	# Solo permitir mensajes de error normales del juego, NO diálogos de salida
	if not message.contains("salir") and not message.contains("exit") and not message.contains("quit"):
		ui_manager.show_error_message(message, duration)

func _on_button_exit_pressed():
	print("PuzzleGame: Botón de salida presionado durante puzzle - IGNORANDO")
	GLOBAL.change_scene_direct("res://Scenes/PuzzleSelection.tscn")
	# No hacer nada, continuar con el juego

func _on_button_repeat_pressed():
	game_state_manager.restart_puzzle()

func on_flip_button_pressed():
	# Notificar al score manager sobre el uso de flip
	if score_manager and score_manager.is_scoring_enabled():
		score_manager.add_flip_use()
	
	ui_manager.on_flip_button_pressed()

func _on_button_toggle_hud_pressed():
	ui_manager.toggle_hud()

func resume_game():
	game_state_manager.resume_game()

# Función llamada cuando se completa el puzzle  
func _on_puzzle_completed():
	print("PuzzleGame: _on_puzzle_completed() llamada - ¡Puzzle completado!")
	
	# Verificar que tenemos los IDs necesarios
	if current_pack_id.is_empty() or current_puzzle_id.is_empty():
		print("ERROR: No se pueden guardar el progreso, faltan los IDs del pack o puzzle")
		return
	
	# Completar puzzle en el score manager
	if score_manager and score_manager.is_scoring_enabled():
		score_manager.complete_puzzle()
		
		# Obtener resumen de la puntuación
		var score_summary = score_manager.get_score_summary()
		
		# Agregar tiempo de finalización
		score_summary["completion_time"] = game_state_manager.elapsed_time
		
		# Guardar la puntuación en el ranking manager
		if ranking_manager:
			ranking_manager.save_puzzle_score(current_pack_id, current_puzzle_id, score_summary)
			ranking_manager.update_global_ranking()
	
	# Marcar el puzzle como completado en el ProgressManager
	print("PuzzleGame: Marcando puzzle como completado - Pack: " + current_pack_id + ", Puzzle: " + current_puzzle_id)
	progress_manager.complete_puzzle(current_pack_id, current_puzzle_id)
	
	# Desbloquear el siguiente puzzle inmediatamente
	var next_puzzle = progress_manager.get_next_unlocked_puzzle(current_pack_id, current_puzzle_id)
	if next_puzzle != null:
		print("PuzzleGame: Siguiente puzzle desbloqueado: " + next_puzzle.name)
	else:
		print("PuzzleGame: No hay siguiente puzzle disponible")
	
	# Forzar el guardado de los datos de progresión
	progress_manager.save_progress_data()
	print("PuzzleGame: Datos de progresión guardados")
	
	# Mostrar pantalla de victoria
	show_victory_screen()

# NUEVO: Función para manejar gestos del borde durante el puzzle
# Esta función devuelve true para indicar que el gesto fue manejado (ignorado)
func handle_back_gesture() -> bool:
	print("PuzzleGame: Gesto del borde detectado durante el puzzle - IGNORANDO completamente")
	# Simplemente devolver true para indicar que el gesto fue "manejado" (ignorado)
	# No mostrar diálogos, no hacer nada, continuar con el juego normalmente
	return true

# Función para mostrar la pantalla de victoria
func show_victory_screen():
	print("Cambiando a la pantalla de victoria")
	
	# Obtener datos del estado del juego para la victoria
	var game_state = game_state_manager.get_current_game_state_for_victory()
	
	# Preparar datos de puntuación si está disponible
	var score_data = {}
	if score_manager and score_manager.is_scoring_enabled():
		score_data = score_manager.get_score_summary()
	
	# Guardar los datos necesarios en GLOBAL para que la escena de victoria pueda acceder a ellos
	GLOBAL.victory_data = {
		"puzzle": GLOBAL.selected_puzzle,
		"pack": GLOBAL.selected_pack,
		"total_moves": game_state.total_moves,
		"elapsed_time": game_state.elapsed_time,
		"flip_count": game_state.flip_count,
		"flip_move_count": game_state.flip_move_count,
		"pack_id": current_pack_id,
		"puzzle_id": current_puzzle_id,
		"is_mobile": is_mobile,
		"relax_mode": game_state.relax_mode,
		"normal_mode": game_state.normal_mode,
		"timer_mode": game_state.timer_mode,
		"challenge_mode": game_state.challenge_mode,
		"score_data": score_data  # Agregar datos de puntuación
	}
	
	# Usar la función safe_change_scene para cambiar a la escena de victoria
	safe_change_scene("res://Scenes/VictoryScreen.tscn")

# Función para cambiar de escena de manera segura
func safe_change_scene(scene_path: String) -> void:
	# Verificar que get_tree() no sea nulo
	if get_tree() != null:
		# Usar call_deferred para cambiar la escena de manera segura
		get_tree().call_deferred("change_scene_to_file", scene_path)
	else:
		push_error("No se pudo cambiar a la escena: " + scene_path)

# ========================================
# FUNCIONES DE AUDIO VIA AUDIOMANAGER
# Todas las funciones de sonido ahora usan AudioManager para respetar
# la configuración de volumen del usuario y los buses de audio
# ========================================

# Función para reproducir sonido de flip
func play_flip_sound():
	print("PuzzleGame: Reproduciendo sonido de flip via AudioManager")
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx("res://Assets/Sounds/SFX/flip.wav")
	else:
		print("PuzzleGame: ERROR - AudioManager no encontrado")

# Función para reproducir sonido de movimiento
func play_move_sound():
	print("PuzzleGame: Reproduciendo sonido de movimiento via AudioManager")
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx("res://Assets/Sounds/SFX/plop.mp3")
	else:
		print("PuzzleGame: ERROR - AudioManager no encontrado")

# Función para reproducir sonido de fusión
func play_merge_sound():
	print("PuzzleGame: Reproduciendo sonido de fusión via AudioManager")
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx("res://Assets/Sounds/SFX/bubble.wav")
	else:
		print("PuzzleGame: ERROR - AudioManager no encontrado")

# Función para verificar que el sistema de audio está funcionando
func _test_audio_nodes():
	print("PuzzleGame: Verificando sistema de audio...")
	
	# Verificar que AudioManager está disponible
	if has_node("/root/AudioManager"):
		print("✅ AudioManager disponible")
		var audio_manager = get_node("/root/AudioManager")
		print("✅ Volumen SFX configurado: ", audio_manager.get_sfx_volume(), "%")
	else:
		print("❌ AudioManager no encontrado")
	
	# Verificar la configuración de volumen del bus SFX
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	var sfx_volume_db = AudioServer.get_bus_volume_db(sfx_bus_index)
	print("🔊 Volumen del bus SFX: ", sfx_volume_db, " dB")
	
	# Verificar archivos de sonido
	print("🎵 Verificando archivos de sonido...")
	var move_sound = load("res://Assets/Sounds/SFX/plop.mp3")
	var merge_sound = load("res://Assets/Sounds/SFX/bubble.wav")
	var flip_sound = load("res://Assets/Sounds/SFX/flip.wav")
	
	print("  - Sonido de movimiento: ", "✅" if move_sound else "❌")
	print("  - Sonido de fusión: ", "✅" if merge_sound else "❌")
	print("  - Sonido de flip: ", "✅" if flip_sound else "❌")
	
	# Test opcional: reproducir sonidos de prueba (comentar en producción)
	if OS.is_debug_build():
		_test_play_sounds()

# Función para probar la reproducción de sonidos
func _test_play_sounds():
	print("PuzzleGame: Iniciando test de sonidos via AudioManager en 2 segundos...")
	await get_tree().create_timer(1.5).timeout
	
	print("🔊 Probando sonido de movimiento...")
	play_move_sound()
	
	await get_tree().create_timer(1.5).timeout
	print("🔊 Probando sonido de fusión...")
	play_merge_sound()
	
	await get_tree().create_timer(1.5).timeout
	print("🔊 Probando sonido de flip...")
	play_flip_sound()
	
	print("PuzzleGame: Test de sonidos completado")

func _connect_center_button():
	# Conectar el botón de centrado si existe en la escena
	if center_button:
		# Conectar la señal del botón
		if not center_button.is_connected("pressed", Callable(self, "_on_center_button_pressed")):
			center_button.connect("pressed", Callable(self, "_on_center_button_pressed"))
		
		# Mostrar u ocultar el botón según el dispositivo
		center_button.visible = is_mobile
		
		print("PuzzleGame: Botón de centrado conectado desde la escena (visible en móviles: ", is_mobile, ")")
	else:
		print("PuzzleGame: No se encontró botón de centrado en la escena")

func _on_center_button_pressed():
	print("PuzzleGame: Botón de centrado presionado")
	force_complete_recenter()

func _show_centering_welcome_message():
	# Mostrar mensaje con información sobre centrado después de un pequeño delay
	await get_tree().create_timer(1.5).timeout
	
	if is_mobile:
		show_success_message("💡 Doble tap o botón 🎯 para centrar puzzle", 3.0)
	else:
		show_success_message("💡 Presiona 'C' para centrar puzzle 🎯", 3.0)

# Función para mostrar el loading puzzle
func _show_loading_puzzle():
	print("PuzzleGame: Mostrando loading puzzle...")
	
	# Debug: Verificar layers existentes
	if UILayer:
		print("PuzzleGame: UILayer detectado con layer: ", UILayer.layer)
	
	# Buscar otros CanvasLayers y sus prioridades
	for child in get_children():
		if child is CanvasLayer:
			print("PuzzleGame: CanvasLayer encontrado: ", child.name, " - Layer: ", child.layer)
	
	# Instanciar el loading puzzle
	loading_puzzle_instance = LoadingPuzzleScene.instantiate()
	
	# Crear un CanvasLayer específico para el loading con prioridad MÁXIMA
	var loading_canvas_layer = CanvasLayer.new()
	loading_canvas_layer.name = "LoadingCanvasLayer"
	loading_canvas_layer.layer = 9999  # Prioridad MÁXIMA para estar por encima de absolutamente todo
	
	# Agregar el CanvasLayer al nodo principal
	add_child(loading_canvas_layer)
	
	# Agregar el loading puzzle al CanvasLayer
	loading_canvas_layer.add_child(loading_puzzle_instance)
	
	# Asegurar z_index alto dentro del CanvasLayer también
	loading_puzzle_instance.z_index = 1000
	
	print("PuzzleGame: Loading puzzle instanciado en CanvasLayer con prioridad 9999")
	print("PuzzleGame: Loading puzzle z_index: ", loading_puzzle_instance.z_index)

# Función para ocultar y eliminar el loading puzzle
func _hide_loading_puzzle():
	print("PuzzleGame: Ocultando loading puzzle...")
	
	if loading_puzzle_instance != null:
		print("PuzzleGame: Loading puzzle instance encontrada, procediendo a eliminar...")
		
		# Obtener el CanvasLayer padre del loading puzzle
		var loading_canvas_layer = loading_puzzle_instance.get_parent()
		
		# Intentar hacer fade out si el método existe
		if loading_puzzle_instance.has_method("fade_out"):
			print("PuzzleGame: Ejecutando fade_out...")
			await loading_puzzle_instance.fade_out()
			print("PuzzleGame: Fade out completado exitosamente")
		else:
			print("PuzzleGame: Método fade_out no encontrado, eliminando directamente")
			# Pequeña pausa para simular transición
			await get_tree().create_timer(1.5).timeout
		
		# Asegurar que la instancia se elimine
		if is_instance_valid(loading_puzzle_instance):
			print("PuzzleGame: Eliminando loading_puzzle_instance...")
			loading_puzzle_instance.queue_free()
			
			# Esperar un frame para asegurar que se procese el queue_free
			await get_tree().process_frame
			
			# Limpiar la referencia
			loading_puzzle_instance = null
			print("PuzzleGame: Loading puzzle eliminado correctamente")
		else:
			print("PuzzleGame: Loading puzzle instance ya no es válida")
			loading_puzzle_instance = null
		
		# Eliminar también el CanvasLayer contenedor
		if loading_canvas_layer != null and is_instance_valid(loading_canvas_layer):
			print("PuzzleGame: Eliminando LoadingCanvasLayer...")
			loading_canvas_layer.queue_free()
			await get_tree().process_frame
			print("PuzzleGame: LoadingCanvasLayer eliminado")
	else:
		print("PuzzleGame: Warning - No hay loading puzzle para eliminar (referencia es null)")

# Función alternativa para forzar la eliminación del loading puzzle
func force_remove_loading_puzzle():
	print("PuzzleGame: Forzando eliminación del loading puzzle...")
	
	if loading_puzzle_instance != null:
		# Obtener el CanvasLayer padre antes de eliminarlo
		var loading_canvas_layer = loading_puzzle_instance.get_parent()
		
		# Hacer invisible inmediatamente
		loading_puzzle_instance.visible = false
		
		# Llamar stop_immediately si existe
		if loading_puzzle_instance.has_method("stop_immediately"):
			loading_puzzle_instance.stop_immediately()
		
		# Eliminar inmediatamente
		loading_puzzle_instance.queue_free()
		loading_puzzle_instance = null
		
		# Eliminar también el CanvasLayer contenedor
		if loading_canvas_layer != null and is_instance_valid(loading_canvas_layer):
			loading_canvas_layer.queue_free()
			print("PuzzleGame: LoadingCanvasLayer también eliminado forzosamente")
		
		print("PuzzleGame: Loading puzzle eliminado forzosamente")
	else:
		print("PuzzleGame: No hay loading puzzle para forzar eliminación")

# Función de debug para verificar el estado del loading puzzle
func debug_loading_puzzle_status():
	print("=== DEBUG LOADING PUZZLE ===")
	print("loading_puzzle_instance: ", loading_puzzle_instance)
	if loading_puzzle_instance != null:
		print("is_instance_valid: ", is_instance_valid(loading_puzzle_instance))
		print("visible: ", loading_puzzle_instance.visible)
		print("name: ", loading_puzzle_instance.name)
		print("parent: ", loading_puzzle_instance.get_parent())
		print("parent name: ", loading_puzzle_instance.get_parent().name if loading_puzzle_instance.get_parent() else "null")
		print("parent layer: ", loading_puzzle_instance.get_parent().layer if loading_puzzle_instance.get_parent() is CanvasLayer else "not CanvasLayer")
	print("============================")

# Función para ocultar temporalmente la UI durante el loading
func _hide_ui_for_loading():
	print("PuzzleGame: Ocultando UI temporalmente para loading...")
	if UILayer:
		UILayer.visible = false
		print("PuzzleGame: UILayer ocultado")

# Función para restaurar la UI después del loading
func _restore_ui_after_loading():
	print("PuzzleGame: Restaurando UI después del loading...")
	if UILayer:
		UILayer.visible = true
		print("PuzzleGame: UILayer restaurado")

# 🚫 FUNCIÓN CRÍTICA: Configurar sistema para bloquear diálogos automáticamente
func _setup_dialog_blocker():
	var dialog_timer = Timer.new()
	dialog_timer.wait_time = 0.016  # Verificar cada frame (~60 FPS = 16ms)
	dialog_timer.timeout.connect(_block_all_dialogs)
	dialog_timer.autostart = true
	add_child(dialog_timer)
	
	# NUEVO: También verificar en _process() para máxima agresividad
	print("PuzzleGame: Sistema de bloqueo de diálogos ULTRA-AGRESIVO activado")

# 🚫 INTERCEPTOR FINAL: Sobrescribir métodos globales para bloquear diálogos
func _setup_global_dialog_interceptors():
	print("PuzzleGame: Configurando interceptores globales de diálogos...")
	
	# Interceptar cualquier nodo que se añada a la escena
	if has_node("/root"):
		var root = get_node("/root")
		if not root.child_entered_tree.is_connected(_on_global_child_added):
			root.child_entered_tree.connect(_on_global_child_added)
			print("PuzzleGame: Interceptor de nodos globales activado")

# 🚫 INTERCEPTOR GLOBAL: Detectar cuando se añade cualquier nodo a la escena
func _on_global_child_added(node):
	# Si es un diálogo, eliminarlo inmediatamente
	if node.is_in_group("exit_dialog") or node.name.contains("Dialog") or node.name.contains("Confirm"):
		print("PuzzleGame: Interceptando creación de diálogo global: ", node.name)
		# Hacerlo invisible inmediatamente
		node.visible = false
		node.modulate.a = 0
		# Eliminarlo en el siguiente frame
		call_deferred("_force_remove_node", node)

# 🚫 FUNCIÓN DE UTILIDAD: Forzar eliminación de nodo
func _force_remove_node(node):
	if is_instance_valid(node):
		print("PuzzleGame: Forzando eliminación de nodo: ", node.name)
		node.queue_free()

# Añadir verificación cada frame para máxima agresividad
func _process(_delta):
	# 🚫 CRÍTICO: Verificar y eliminar diálogos cada frame durante el puzzle
	_block_all_dialogs()

# 🚫 FUNCIÓN CRÍTICA: Eliminar cualquier diálogo que aparezca
func _block_all_dialogs():
	# Lista de nombres comunes de diálogos a eliminar
	var dialog_keywords = ["Dialog", "Confirm", "Exit", "Quit", "Alert", "Warning", "Popup", "Modal"]
	
	# Buscar en toda la escena
	for child in get_children():
		var should_remove = false
		
		# Verificar por nombre
		for keyword in dialog_keywords:
			if child.name.contains(keyword):
				should_remove = true
				break
		
		# Verificar si está en grupos de diálogos
		if child.is_in_group("exit_dialog") or child.is_in_group("dialog") or child.is_in_group("popup"):
			should_remove = true
		
		# Si es un CanvasLayer, verificar sus hijos
		if child is CanvasLayer:
			for grandchild in child.get_children():
				for keyword in dialog_keywords:
					if grandchild.name.contains(keyword):
						print("PuzzleGame: Eliminando diálogo en CanvasLayer: ", grandchild.name)
						# Hacer invisible inmediatamente antes de eliminar
						grandchild.visible = false
						grandchild.modulate.a = 0
						grandchild.queue_free()
		
		# Eliminar diálogos encontrados
		if should_remove:
			print("PuzzleGame: Eliminando diálogo automáticamente: ", child.name)
			# Hacer invisible inmediatamente antes de eliminar
			child.visible = false
			child.modulate.a = 0
			child.queue_free()
	
	# NUEVO: Buscar también en la escena global por si el diálogo se añadió allí
	var current_scene = get_tree().current_scene
	if current_scene and current_scene != self:
		for child in current_scene.get_children():
			if child.is_in_group("exit_dialog") or child.name.contains("Dialog") or child.name.contains("Confirm"):
				print("PuzzleGame: Eliminando diálogo en escena global: ", child.name)
				child.visible = false
				child.modulate.a = 0
				child.queue_free()

# 🚫 NUEVO: Sobrescribir cualquier función que pueda mostrar diálogos
func show_exit_dialog():
	print("PuzzleGame: Intento de mostrar diálogo de salida durante puzzle - BLOQUEADO")
	# No hacer nada, simplemente ignorar

# === MÉTODOS PARA GESTIÓN DEL ESTADO GUARDADO ===

# Inicializar el estado para una nueva partida
func _initialize_new_puzzle_state():
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager:
		puzzle_state_manager.start_new_puzzle_state(current_pack_id, current_puzzle_id, GLOBAL.gamemode, GLOBAL.current_difficult)
		print("PuzzleGame: Nuevo estado de puzzle inicializado")

# Restaurar el estado de las piezas del puzzle
func _restore_puzzle_state(puzzle_state_manager):
	print("PuzzleGame: Restaurando estado de las piezas...")
	
	var saved_pieces_data = puzzle_state_manager.get_saved_pieces_data()
	
	print("PuzzleGame: Datos guardados - Piezas: ", saved_pieces_data.size())
	
	if saved_pieces_data.size() == 0:
		print("PuzzleGame: No hay datos de piezas guardados, usando posiciones iniciales")
		return
	
	# Esperar múltiples frames para asegurar inicialización completa
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Preparar para restauración - no necesitamos desagrupar ya que trabajaremos con el PuzzlePieceManager
	print("PuzzleGame: Preparando restauración de estado...")
	
	# Establecer las posiciones de todas las piezas según los datos guardados
	var pieces = piece_manager.get_pieces()
	print("PuzzleGame: Restaurando posiciones de ", pieces.size(), " piezas...")
	
	# 🔧 PASO 1: Limpiar grid completamente antes de restaurar
	print("PuzzleGame: Limpiando grid antes de restaurar posiciones...")
	piece_manager.grid.clear()
	
	for piece_data in saved_pieces_data:
		# Buscar la pieza correspondiente por order_number
		var target_piece = null
		for piece_obj in pieces:
			if piece_obj.order_number == piece_data.order_number:
				target_piece = piece_obj
				break
		
		if target_piece == null:
			print("PuzzleGame: ⚠️ No se encontró pieza con order_number: ", piece_data.order_number)
			continue
		
		# Restaurar posición global
		if "current_position" in piece_data:
			target_piece.node.global_position = Vector2(
				piece_data.current_position.x,
				piece_data.current_position.y
			)
		
		# Restaurar celda current_cell calculándola desde la posición
		target_piece.current_cell = piece_manager.get_cell_of_piece(target_piece)
		
		# Registrar en el grid después de establecer current_cell
		piece_manager.set_piece_at(target_piece.current_cell, target_piece)
		
		# Restaurar estado volteado si existe
		if "flipped" in piece_data and target_piece.node.has_method("set_flipped"):
			target_piece.node.set_flipped(piece_data.flipped)
		
		# Actualizar estado de posición correcta
		piece_manager.update_piece_position_state(target_piece)
	
	print("PuzzleGame: Posiciones individuales restauradas")
	
	# 🔧 PASO 2: VERIFICAR Y RESOLVER SUPERPOSICIONES CRÍTICAS
	print("PuzzleGame: 🔧 VERIFICANDO SUPERPOSICIONES DESPUÉS DE RESTAURAR...")
	
	# Ejecutar resolución integral de superposiciones
	await piece_manager.resolve_all_overlapping_pieces_comprehensive()
	
	# 🔧 PASO 3: Restaurar grupos después de resolver superposiciones
	print("PuzzleGame: Restaurando estructura de grupos...")
	
	# Agrupar piezas según group_ids guardados
	var groups_to_form = {}
	
	for piece_data in saved_pieces_data:
		if "group_id" in piece_data:
			var group_id = piece_data.group_id
			if not group_id in groups_to_form:
				groups_to_form[group_id] = []
			
			# Buscar la pieza correspondiente
			var target_piece = null
			for piece_obj in pieces:
				if piece_obj.order_number == piece_data.order_number:
					target_piece = piece_obj
					break
			
			if target_piece:
				groups_to_form[group_id].append(target_piece)
	
	# Formar los grupos
	for group_id in groups_to_form.keys():
		var group_pieces = groups_to_form[group_id]
		if group_pieces.size() > 1:
			print("PuzzleGame: Formando grupo con ", group_pieces.size(), " piezas")
			# Asignar todas las piezas al mismo grupo
			for piece_obj in group_pieces:
				piece_obj.group = group_pieces.duplicate()
				
				# Configurar ID de grupo visual
				if piece_obj.node.has_method("set_group_id"):
					piece_obj.node.set_group_id(group_id)
				if piece_obj.node.has_method("update_pieces_group"):
					piece_obj.node.update_pieces_group(group_pieces)
	
	# 🔧 PASO 4: VERIFICACIÓN FINAL CRÍTICA
	print("PuzzleGame: 🔧 VERIFICACIÓN FINAL DESPUÉS DE RESTAURAR GRUPOS...")
	
	# Verificar y resolver cualquier superposición que pueda haber quedado
	if not piece_manager.verify_no_overlaps():
		print("PuzzleGame: ⚠️ DETECTADAS SUPERPOSICIONES DESPUÉS DE RESTAURAR GRUPOS - Resolviendo...")
		await piece_manager.resolve_all_overlapping_pieces_comprehensive()
	
	# Verificar fusiones automáticas
	print("PuzzleGame: Verificando fusiones automáticas...")
	piece_manager.check_all_groups()
	
	# Actualizar efectos visuales
	print("PuzzleGame: Actualizando efectos visuales...")
	for piece_obj in pieces:
		if piece_obj.node.has_method("update_all_visuals"):
			piece_obj.node.update_all_visuals()
	
	# Actualizar bordes de grupo
	piece_manager.update_all_group_borders()
	
	# 🔧 PASO 5: VERIFICACIÓN FINAL Y CENTRADO
	print("PuzzleGame: Ejecutando centrado automático después de restaurar...")
	
	# Esperar un frame antes del centrado
	await get_tree().process_frame
	
	# Aplicar centrado automático para corregir cualquier desplazamiento
	force_complete_recenter(true)
	
	print("PuzzleGame: ✅ Estado del puzzle restaurado exitosamente con verificaciones de superposición")
	
	# Mostrar mensaje de confirmación al usuario
	show_success_message("🔧 Partida cargada y verificada", 2.0)
	
	# 🔧 CRÍTICO: Activar monitoreo automático de superposiciones
	setup_overlap_monitoring()

# Restaurar los contadores del juego
func _restore_game_counters(puzzle_state_manager):
	print("PuzzleGame: Restaurando contadores del juego...")
	
	var saved_counters = puzzle_state_manager.get_saved_counters()
	
	# Restaurar contadores en el game_state_manager
	if game_state_manager:
		if saved_counters.has("elapsed_time"):
			game_state_manager.elapsed_time = saved_counters.elapsed_time
			# Ajustar el tiempo de inicio para que el tiempo transcurrido sea correcto
			game_state_manager.start_time = Time.get_unix_time_from_system() - saved_counters.elapsed_time
		
		if saved_counters.has("total_moves"):
			game_state_manager.total_moves = saved_counters.total_moves
		
		if saved_counters.has("flip_count"):
			game_state_manager.flip_count = saved_counters.flip_count
		
		if saved_counters.has("flip_move_count"):
			game_state_manager.flip_move_count = saved_counters.flip_move_count
		
		if saved_counters.has("time_left"):
			game_state_manager.time_left = saved_counters.time_left
		
		print("PuzzleGame: Contadores restaurados - Tiempo: ", saved_counters.get("elapsed_time", 0), 
			  ", Movimientos: ", saved_counters.get("total_moves", 0))
	
	# Actualizar UI con los valores restaurados
	_update_ui_counters()

# Actualizar la UI con los contadores actuales
func _update_ui_counters():
	if game_state_manager:
		# Actualizar movimientos
		if movesLabel:
			movesLabel.text = str(game_state_manager.total_moves)
		
		# Actualizar tiempo si es visible
		var timer_label = get_node("UILayer/TimerLabel") if has_node("UILayer/TimerLabel") else null
		if timer_label and timer_label.visible:
			var minutes = int(game_state_manager.elapsed_time) / 60
			var seconds = int(game_state_manager.elapsed_time) % 60
			timer_label.text = "%02d:%02d" % [minutes, seconds]

# Función llamada cuando se completa el puzzle para limpiar el estado
func _handle_puzzle_completion_state():
	print("PuzzleGame: Puzzle completado, limpiando estado guardado...")
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager:
		puzzle_state_manager.complete_puzzle()
	
	# Aquí se puede agregar lógica adicional para cuando se completa el puzzle
	print("PuzzleGame: Estado limpiado, pack y puzzle mantenidos para acceso rápido")

# Método para actualizar el estado guardado (llamado periódicamente o en eventos importantes)
func _update_saved_state():
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if not puzzle_state_manager or not puzzle_state_manager.has_saved_state():
		return
	
	# Actualizar contadores
	if game_state_manager:
		puzzle_state_manager.update_counters(
			game_state_manager.elapsed_time,
			game_state_manager.total_moves,
			game_state_manager.flip_count,
			game_state_manager.flip_move_count,
			game_state_manager.time_left
		)
	
	# 🔧 CRUCIAL: Actualizar posiciones usando el PuzzlePieceManager para incluir información de celda
	if piece_manager:
		puzzle_state_manager.update_pieces_positions_from_manager(piece_manager)
	elif pieces_container:
		# Fallback al método anterior si no hay piece_manager disponible
		puzzle_state_manager.update_pieces_positions(pieces_container)

# Guardado de emergencia cuando se cierra la aplicación
func _emergency_save_state():
	print("PuzzleGame: Ejecutando guardado de emergencia...")
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager and puzzle_state_manager.has_saved_state():
		# Actualizar estado inmediatamente
		_update_saved_state()
		# Forzar guardado inmediato
		puzzle_state_manager.save_puzzle_state()
		print("PuzzleGame: Guardado de emergencia completado")

# === FUNCIONES PARA CONTROL DE BORDES DE GRUPO ===

# Función para activar/desactivar bordes de grupo
func toggle_group_borders(enabled: bool):
	if piece_manager:
		piece_manager.set_group_borders_enabled(enabled)
		show_success_message("🔲 Bordes de grupo " + ("activados" if enabled else "desactivados"), 2.0)
	else:
		print("PuzzleGame: Error - piece_manager no disponible")

# Función para cambiar grosor de bordes de grupo
func set_group_border_thickness(thickness: float):
	if piece_manager:
		piece_manager.set_group_border_thickness(thickness)
		show_success_message("🔲 Grosor de bordes: " + str(thickness) + "px", 2.0)
	else:
		print("PuzzleGame: Error - piece_manager no disponible")

# Función para cambiar opacidad de bordes de grupo
func set_group_border_opacity(opacity: float):
	if piece_manager:
		piece_manager.set_group_border_opacity(opacity)
		show_success_message("🔲 Opacidad de bordes: " + str(int(opacity * 100)) + "%", 2.0)
	else:
		print("PuzzleGame: Error - piece_manager no disponible")

# Función para refrescar todos los bordes
func refresh_group_borders():
	if piece_manager:
		piece_manager.refresh_all_group_borders()
		show_success_message("🔲 Bordes de grupo refrescados", 2.0)
	else:
		print("PuzzleGame: Error - piece_manager no disponible")

# Función para mostrar/ocultar temporalmente los bordes
func toggle_group_borders_visibility(visible: bool):
	if piece_manager:
		piece_manager.toggle_group_borders_visibility(visible)
		show_success_message("🔲 Bordes " + ("mostrados" if visible else "ocultados"), 1.5)
	else:
		print("PuzzleGame: Error - piece_manager no disponible")

# Función para convertir bordes existentes a interiores
func convert_borders_to_interior():
	if piece_manager:
		piece_manager.convert_borders_to_interior()
		show_success_message("🔲 Bordes convertidos a interiores", 2.0)
	else:
		print("PuzzleGame: Error - piece_manager no disponible")

# Función de utilidad para centrar el puzzle y actualizar bordes automáticamente
func center_puzzle_and_update_borders(silent: bool = false):
	force_complete_recenter(silent)
	# Los bordes ya se actualizan automáticamente en force_complete_recenter
	if not silent:
		show_success_message("🎯 Puzzle centrado y bordes actualizados", 2.0)

# 🔧 NUEVAS FUNCIONES PARA GESTIÓN AUTOMÁTICA DE SUPERPOSICIONES
func setup_overlap_monitoring():
	"""
	Configura un sistema de monitoreo automático de superposiciones
	"""
	print("PuzzleGame: Configurando monitoreo automático de superposiciones...")
	
	# Crear timer para verificaciones periódicas
	var overlap_timer = Timer.new()
	overlap_timer.name = "OverlapMonitorTimer"
	overlap_timer.wait_time = 2.0  # Verificar cada 2 segundos
	overlap_timer.autostart = true
	overlap_timer.timeout.connect(_on_overlap_check_timeout)
	add_child(overlap_timer)
	
	print("PuzzleGame: Monitoreo automático de superposiciones activado")

func _on_overlap_check_timeout():
	"""
	Ejecuta verificación automática de superposiciones cada cierto tiempo
	"""
	if not piece_manager:
		return
	
	# Verificar si hay superposiciones sin mostrar muchos mensajes
	if not piece_manager.verify_no_overlaps():
		print("PuzzleGame: 🔧 Detectadas superposiciones durante monitoreo automático - Resolviendo...")
		piece_manager.resolve_all_overlaps()
		
		# Mostrar mensaje al usuario solo si es crítico
		show_info_message("🔧 Auto-corrección de posiciones", 1.0)

func force_overlap_resolution():
	"""
	Función pública para forzar la resolución de superposiciones desde cualquier lugar
	"""
	if piece_manager:
		print("PuzzleGame: Forzando resolución completa de superposiciones...")
		piece_manager.resolve_all_overlaps()
		
		# Verificar nuevamente después de la resolución
		if piece_manager.verify_no_overlaps():
			show_success_message("✅ Todas las superposiciones resueltas", 2.0)
		else:
			show_info_message("⚠️ Algunas superposiciones persisten", 2.0)
			# Intentar resolución más agresiva
			piece_manager.recalculate_all_grid_positions()

# Función mejorada para mostrar mensajes informativos (no de éxito)
func show_info_message(message: String, duration: float = 2.0):
	"""
	Muestra un mensaje informativo al usuario
	"""
	if ui_manager and ui_manager.has_method("show_message"):
		ui_manager.show_message(message, duration)
	else:
		print("PuzzleGame: ", message)
