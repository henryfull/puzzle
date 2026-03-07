# PuzzleGame.gd
# Archivo principal del puzzle - Coordina todos los managers

extends Node2D
class_name PuzzleGame

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")
var VictoryCheckerScene = preload("res://Scripts/gameplay/VictoryChecker.gd")
var PuzzleDialogBlockerScene = preload("res://Scripts/gameplay/PuzzleDialogBlocker.gd")

# Precargar los nuevos managers de puntuación
var PuzzleScoreManagerScene = preload("res://Scripts/PuzzleScoreManager.gd")
var PuzzleRankingManagerScene = preload("res://Scripts/PuzzleRankingManager.gd")

# Precargar la escena de loading puzzle
var LoadingPuzzleScene = preload("res://Scenes/Components/loadingPuzzle/loading_puzzle.tscn")
var loading_puzzle_instance: Node2D

# Referencias a timer de verificación de victoria
@onready var victory_timer: Timer = $VictoryTimer

# Referencias a elementos de la UI
@export var pieces_container: Node2D
@export var UILayer: CanvasLayer
@export var movesLabel: Label
@export var maxMovesLabel: Label
@export var maxMovesFlipLabel: Label
@export var maxFlipsPanel: Panel
@export var maxFlipsLabel: Label
@export var panelPaused: Panel 
@export var button_options: Button
@export var flip_button: Button
@export var center_button: Button
@export var score_label: Label
@export var streak_label: Label
@export var floating_points_label: Label
@export var flip_image: TextureRect

# Referencias a mensajes de éxito/error que deberían estar en la escena
@onready var success_message_label: Label = $UILayer/SuccessMessage
@onready var error_message_label: Label = $UILayer/ErrorMessage

# Control para evitar duplicación de puntos flotantes
var last_score_shown: int = 0

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

# Configuración de escalas por dispositivo
@export var image_path: String = "res://Assets/Images/arte1.jpg"
@export var max_scale_percentage: float = 0.9
@export var tablet_scale_percentage: float = 0.8
@export var desktop_scale_percentage: float = 0.8
@export var mobile_scale_percentage: float = 1.0
@export var viewport_scene_path: String = "res://Scenes/TextViewport.tscn"
@export var max_extra_rows: int = 5

# Detección de dispositivo
var is_mobile: bool = false
var is_tablet: bool = false
var is_desktop: bool = false
var default_rows: int = 0
var default_columns: int = 0

# Estado del puzzle
var puzzle_completed = false
var victory_checker: VictoryChecker
var current_pack_id: String = ""
var current_puzzle_id: String = ""
var debug_runtime_tools_enabled: bool = false
var dialog_blocker_enabled: bool = false
var dialog_blocker_component: PuzzleDialogBlocker = null
var flip_icon_tween: Tween

# === SONIDOS DISPONIBLES ===
const SOUND_FILES = {
	"flip": "res://Assets/Sounds/SFX/flip.wav",
	"move": "res://Assets/Sounds/SFX/plop.mp3",
	"merge": "res://Assets/Sounds/SFX/bubble.wav"
}
const FLIP_ICON_HALF_TURN_DEGREES := 180.0
const FLIP_ICON_ANIMATION_DURATION := 0.24

# === COLORES PARA RACHAS ===
const STREAK_COLORS = {
	10: Color(1.0, 0.3, 1.0, 1.0),  # Magenta
	5: Color(0.3, 1.0, 1.0, 1.0),   # Cian
	3: Color(1.0, 1.0, 0.3, 1.0),   # Amarillo
	0: Color(0.3, 0.9, 0.3, 1.0)    # Verde default
}

func _ready():
	print("PuzzleGame: Iniciando juego...")
	
	# Configurar guardado de emergencia al cerrar la aplicación
	get_tree().auto_accept_quit = false
	
	# Mostrar loading puzzle inmediatamente
	_show_loading_puzzle()
	_hide_ui_for_loading()
	
	# Configuración inicial
	default_rows = GLOBAL.rows
	default_columns = GLOBAL.columns
		
	if OS.has_feature("mobile"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	
	# Inicialización en secuencia
	_detect_device_type()
	_test_audio_nodes()
	_initialize_managers()
	
	if panelPaused:
		panelPaused.visible = false
	
	# Inicializar VictoryChecker
	victory_checker = VictoryCheckerScene.new()
	add_child(victory_checker)
	victory_checker.puzzle_is_complete.connect(_handle_puzzle_really_completed)

	# Verificar si continuamos una partida existente
	var continuing_game = _check_and_setup_saved_game()
	
	# Configurar puzzle según datos seleccionados o guardados
	_setup_puzzle_configuration()
	
	# Crear contenedor de piezas y configurar puzzle
	_setup_pieces_container()
	await _setup_puzzle()
	
	# Restaurar estado si estamos continuando
	if continuing_game:
		await _restore_puzzle_state(get_node("/root/PuzzleStateManager"))
	
	# Configuración final
	_connect_button_signals()
	game_state_manager.setup_game_mode()
	
	if continuing_game:
		_restore_game_counters(get_node("/root/PuzzleStateManager"))
	else:
		_initialize_new_puzzle_state()
	
	_connect_center_button()
	
	# Finalizar loading
	await get_tree().create_timer(0.15).timeout
	_hide_loading_puzzle()
	
	await get_tree().create_timer(0.2).timeout
	if loading_puzzle_instance != null:
		print("PuzzleGame: ⚠️ Loading puzzle no se eliminó correctamente, forzando eliminación...")
		force_remove_loading_puzzle()
	
	_restore_ui_after_loading()
	_show_centering_welcome_message()

	_ensure_dialog_blocker_component()
	
	# Herramientas de diagnóstico solo en builds de debug
	debug_runtime_tools_enabled = OS.is_debug_build()
	dialog_blocker_enabled = debug_runtime_tools_enabled
	if debug_runtime_tools_enabled:
		_debug_score_system()
		_test_score_system_delayed()
		_setup_dialog_blocker()
		_setup_global_dialog_interceptors()

# === FUNCIONES DE CONFIGURACIÓN INICIAL ===

func _check_and_setup_saved_game() -> bool:
	"""Verifica y configura una partida guardada si existe y corresponde al puzzle actual"""
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if not puzzle_state_manager or not puzzle_state_manager.has_saved_state():
		print("PuzzleGame: No hay estado guardado disponible")
		return false
	
	var saved_pack_id = puzzle_state_manager.get_saved_pack_id()
	var saved_puzzle_id = puzzle_state_manager.get_saved_puzzle_id()
	var saved_game_mode = puzzle_state_manager.puzzle_state.game_mode
	var saved_difficulty = puzzle_state_manager.puzzle_state.difficulty
	
	var current_pack_id = GLOBAL.selected_pack.id if GLOBAL.selected_pack else ""
	var current_puzzle_id = GLOBAL.selected_puzzle.id if GLOBAL.selected_puzzle else ""
	var current_game_mode = GLOBAL.gamemode
	var current_difficulty = GLOBAL.current_difficult
	
	print("PuzzleGame: Verificando compatibilidad de estado guardado...")
	print("  - Guardado: Pack=", saved_pack_id, ", Puzzle=", saved_puzzle_id, ", Modo=", saved_game_mode, ", Dificultad=", saved_difficulty)
	print("  - Actual: Pack=", current_pack_id, ", Puzzle=", current_puzzle_id, ", Modo=", current_game_mode, ", Dificultad=", current_difficulty)
	
	# Verificar que TODOS los parámetros coincidan exactamente
	if (saved_pack_id == current_pack_id and 
		saved_puzzle_id == current_puzzle_id and 
		saved_game_mode == current_game_mode and 
		saved_difficulty == current_difficulty):
		
		print("PuzzleGame: ✅ Estado guardado coincide exactamente con el puzzle actual")
		var continuing_game = puzzle_state_manager.setup_continue_game()
		if continuing_game:
			print("PuzzleGame: Configuración de continuación aplicada exitosamente")
			return true
		else:
			print("PuzzleGame: ❌ No se pudo configurar la continuación, empezando nueva partida")
			puzzle_state_manager.clear_all_state()
	else:
		print("PuzzleGame: ❌ Estado guardado NO coincide con el puzzle actual")
		print("  - Diferencia detectada, limpiando estado guardado")
		puzzle_state_manager.clear_all_state()
	
	return false

func _setup_puzzle_configuration():
	"""Configura la información del puzzle actual"""
	if GLOBAL.selected_puzzle != null:
		image_path = GLOBAL.selected_puzzle.image
		if GLOBAL.selected_pack != null:
			current_pack_id = GLOBAL.selected_pack.id
		if GLOBAL.selected_puzzle != null:
			current_puzzle_id = GLOBAL.selected_puzzle.id

func _detect_device_type():
	"""Detecta el tipo de dispositivo para aplicar la escala correcta"""
	var viewport_size = get_viewport_rect().size
	var screen_diagonal = sqrt(pow(viewport_size.x, 2) + pow(viewport_size.y, 2))
	
	var is_mobile_os = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	if is_mobile_os:
		var min_dimension = min(viewport_size.x, viewport_size.y)
		var max_dimension = max(viewport_size.x, viewport_size.y)
		var is_large_screen = min_dimension > 800 and max_dimension > 1000
		
		if is_large_screen:
			is_tablet = true
			print("PuzzleGame: Dispositivo detectado como TABLET (diagonal: ", screen_diagonal, ", resolución: ", viewport_size, ")")
		else:
			is_mobile = true
			print("PuzzleGame: Dispositivo detectado como MÓVIL (diagonal: ", screen_diagonal, ", resolución: ", viewport_size, ")")
	else:
		is_desktop = true
		print("PuzzleGame: Dispositivo detectado como ORDENADOR (resolución: ", viewport_size, ")")
	
	print("PuzzleGame: Para input táctil - is_mobile usado por InputHandler: ", (is_mobile or is_tablet))

func get_device_scale_factor() -> float:
	"""Devuelve el factor de escala apropiado según el tipo de dispositivo"""
	var device_config = {
		"tablet": {"scale": GLOBAL.settings.puzzle.get("tablet_scale", tablet_scale_percentage), "name": "TABLET"},
		"desktop": {"scale": GLOBAL.settings.puzzle.get("desktop_scale", desktop_scale_percentage), "name": "ORDENADOR"},
		"mobile": {"scale": GLOBAL.settings.puzzle.get("mobile_scale", mobile_scale_percentage), "name": "MÓVIL"}
	}
	
	var device_type = "mobile"
	if is_tablet:
		device_type = "tablet"
	elif is_desktop:
		device_type = "desktop"
	
	var config = device_config.get(device_type, {"scale": max_scale_percentage, "name": "DEFECTO"})
	print("PuzzleGame: Aplicando escala de ", config.name, ": ", config.scale)
	return config.scale

# === FUNCIONES DE MANAGERS ===

func _initialize_managers():
	# Crear managers
	var managers = [
		{instance = PuzzleInputHandler.new(), ref = "input_handler"},
		{instance = PuzzlePieceManager.new(), ref = "piece_manager"},
		{instance = PuzzleGameStateManager.new(), ref = "game_state_manager"},
		{instance = PuzzleUIManager.new(), ref = "ui_manager"},
		{instance = PuzzleScoreManagerScene.new(), ref = "score_manager"},
		{instance = PuzzleRankingManagerScene.new(), ref = "ranking_manager"}
	]
	
	# Añadir como hijos y asignar referencias
	for manager_data in managers:
		add_child(manager_data.instance)
		set(manager_data.ref, manager_data.instance)
	
	# Inicializar con referencias necesarias
	input_handler.initialize(self)
	piece_manager.initialize(self)
	game_state_manager.initialize(self)
	ui_manager.initialize(self)
	score_manager.initialize(self, game_state_manager)
	ranking_manager.initialize()
	
	_connect_score_ui_signals()

func _connect_score_ui_signals():
	"""Conecta las señales del score manager a los elementos del UILayer"""
	if score_manager:
		score_manager.score_updated.connect(_on_score_updated)
		score_manager.streak_updated.connect(_on_streak_updated)
		score_manager.bonus_applied.connect(_on_bonus_applied)
		print("PuzzleGame: Señales de puntuación conectadas al UILayer")

func _connect_button_signals():
	var button_connections = [
		{button = button_options, method = "_on_button_options_pressed"},
		{button = flip_button, method = "on_flip_button_pressed"},
		{button = center_button, method = "_on_center_button_pressed"}
	]
	
	for connection in button_connections:
		if connection.button and not connection.button.is_connected("pressed", Callable(self, connection.method)):
			connection.button.connect("pressed", Callable(self, connection.method))
	
	# Conectar señal de limpieza de estado
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager and not puzzle_state_manager.state_cleared.is_connected(_on_puzzle_state_cleared):
		puzzle_state_manager.state_cleared.connect(_on_puzzle_state_cleared)

func _on_puzzle_state_cleared():
	"""Se llama cuando se limpia el estado del puzzle para resetear contadores"""
	print("PuzzleGame: Estado limpiado, reseteando contadores...")
	
	# Resetear contadores del game_state_manager
	if game_state_manager:
		game_state_manager.total_moves = 0
		game_state_manager.elapsed_time = 0.0
		game_state_manager.flip_count = 0
		game_state_manager.flip_move_count = 0
		game_state_manager.time_left = 0.0
		game_state_manager.is_flip = false
		game_state_manager.is_paused = false
		game_state_manager.accumulated_time = 0.0
		print("PuzzleGame: Contadores del game_state_manager reseteados")
	
	# Resetear contadores del score_manager
	if score_manager:
		score_manager.current_score = 0
		score_manager.streak_count = 0
		score_manager.pieces_placed_correctly = 0
		score_manager.groups_connected = 0
		score_manager.invalid_moves = 0
		score_manager.flip_uses = 0
		score_manager.undo_uses = 0
		score_manager.had_errors = false
		score_manager.used_flip = false
		print("PuzzleGame: Contadores del score_manager reseteados")
	
	# Actualizar UI
	_update_ui_counters()
	sync_flip_button_icon()

# === FUNCIONES DE AUDIO CONSOLIDADAS ===

func play_sound(sound_type: String):
	"""Función unificada para reproducir sonidos via AudioManager"""
	if not SOUND_FILES.has(sound_type):
		print("PuzzleGame: Tipo de sonido desconocido: ", sound_type)
		return
	
	print("PuzzleGame: Reproduciendo sonido de ", sound_type, " via AudioManager")
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(SOUND_FILES[sound_type])
	else:
		print("PuzzleGame: ERROR - AudioManager no encontrado")

func play_flip_sound():
	play_sound("flip")

func play_move_sound():
	play_sound("move")

func play_merge_sound():
	play_sound("merge")

func _test_audio_nodes():
	print("PuzzleGame: Verificando sistema de audio...")
	
	if has_node("/root/AudioManager"):
		print("✅ AudioManager disponible")
		var audio_manager = get_node("/root/AudioManager")
		print("✅ Volumen SFX configurado: ", audio_manager.get_sfx_volume(), "%")
		
		var sfx_bus_index = AudioServer.get_bus_index("SFX")
		var sfx_volume_db = AudioServer.get_bus_volume_db(sfx_bus_index)
		print("🔊 Volumen del bus SFX: ", sfx_volume_db, " dB")
		
		# Verificar archivos de sonido
		print("🎵 Verificando archivos de sonido...")
		for sound_name in SOUND_FILES:
			var sound_resource = load(SOUND_FILES[sound_name])
			print("  - Sonido de ", sound_name, ": ", "✅" if sound_resource else "❌")
		
		if OS.is_debug_build():
			_test_play_sounds()
	else:
		print("❌ AudioManager no encontrado")

func _test_play_sounds():
	print("PuzzleGame: Iniciando test de sonidos via AudioManager...")
	for i in range(len(SOUND_FILES)):
		await get_tree().create_timer(1.5).timeout
		var sound_name = SOUND_FILES.keys()[i]
		print("🔊 Probando sonido de ", sound_name, "...")
		play_sound(sound_name)
	print("PuzzleGame: Test de sonidos completado")

# === FUNCIONES DE PUNTUACIÓN UI ===

func _on_score_updated(new_score: int):
	"""Actualiza la puntuación mostrada en el UILayer"""
	if game_state_manager and game_state_manager.relax_mode:
		return
	
	if score_label:
		score_label.text = "Puntos: " + str(new_score)
	
	if new_score > last_score_shown:
		var points_gained = new_score - last_score_shown
		if points_gained > 0:
			show_floating_points("+" + str(points_gained), "normal")
		last_score_shown = new_score

func _on_streak_updated(streak_count: int):
	"""Actualiza la racha mostrada en el UILayer"""
	if game_state_manager and game_state_manager.relax_mode:
		return
	
	if streak_label:
		streak_label.text = "Racha: " + str(streak_count)
		_apply_streak_color(streak_count)

func _apply_streak_color(streak_count: int):
	"""Aplica el color correspondiente según la racha"""
	var color = STREAK_COLORS[0]  # Default
	for threshold in [10, 5, 3]:
		if streak_count >= threshold:
			color = STREAK_COLORS[threshold]
			break
	
	if streak_label:
		streak_label.add_theme_color_override("font_color", color)

func _on_bonus_applied(bonus_type: String, points: int):
	"""Muestra mensaje descriptivo cuando se aplica un bonus"""
	var bonus_messages = {
		"streak": "¡Bonus racha! +%d",
		"group_union": "¡Grupos unidos! +%d",
		"no_errors": "¡Sin errores! +%d",
		"no_flip": "¡Sin flip! +%d"
	}
	
	var message = bonus_messages.get(bonus_type, "¡Bonus! +%d") % points
	show_floating_points(message, bonus_type)
	
	if bonus_type == "group_union" and GLOBAL.is_haptic_enabled():
		GLOBAL.trigger_haptic_feedback(200)
		print("PuzzleGame: Vibración activada por unión de grupos")

# === FUNCIONES PÚBLICAS PARA GESTIÓN DE PUNTUACIÓN EN EL UILAYER ===

func set_score_display(score: int):
	if score_label:
		score_label.text = "Puntos: " + str(score)

func set_streak_display(streak: int):
	if streak_label:
		streak_label.text = "Racha: " + str(streak)
		_apply_streak_color(streak)

func update_score_and_streak(score: int, streak: int):
	set_score_display(score)
	set_streak_display(streak)

func get_current_displayed_score() -> int:
	if score_label and score_label.text.begins_with("Puntos: "):
		var score_text = score_label.text.replace("Puntos: ", "")
		return int(score_text)
	return 0

func get_current_displayed_streak() -> int:
	if streak_label and streak_label.text.begins_with("Racha: "):
		var streak_text = streak_label.text.replace("Racha: ", "")
		return int(streak_text)
	return 0

func hide_score_ui():
	if score_label:
		score_label.visible = false
	if streak_label:
		streak_label.visible = false

func show_score_ui():
	if score_label:
		score_label.visible = true
	if streak_label:
		streak_label.visible = true

func reset_score_display():
	set_score_display(0)
	set_streak_display(0)
	last_score_shown = 0

func show_floating_points(points_text: String, bonus_type: String = ""):
	"""Muestra puntos flotantes animados en el UILayer"""
	if game_state_manager and game_state_manager.relax_mode:
		return
	
	if not floating_points_label:
		print("PuzzleGame: Error - floating_points_label no disponible")
		return
	
	print("PuzzleGame: Mostrando puntos flotantes: ", points_text)
	
	floating_points_label.text = points_text
	_apply_floating_points_color(bonus_type, points_text)
	
	# Posicionar en el centro de la pantalla
	var viewport_size = get_viewport_rect().size
	floating_points_label.position.x = (viewport_size.x - floating_points_label.size.x) * 0.5
	floating_points_label.position.y = viewport_size.y * 0.15
	
	_animate_floating_points()

func _apply_floating_points_color(bonus_type: String, points_text: String):
	"""Aplica color según el tipo de bonus o cantidad de puntos"""
	var colors = {
		"streak": Color(1.0, 0.3, 1.0, 1.0),      # Magenta
		"group_union": Color(0.3, 1.0, 1.0, 1.0), # Cian
		"no_errors": Color(0.3, 1.0, 0.3, 1.0),   # Verde
		"no_flip": Color(0.3, 0.3, 1.0, 1.0)      # Azul
	}
	
	var color = colors.get(bonus_type)
	if not color:
		# Determinar color según la cantidad de puntos
		var points_value = int(points_text.replace("+", ""))
		if points_value > 4:
			color = Color(1.0, 0.8, 0.2, 1.0)  # Dorado brillante
		elif points_value > 2:
			color = Color(1.0, 1.0, 0.3, 1.0)  # Amarillo
		else:
			color = Color(1.0, 1.0, 1.0, 1.0)  # Blanco
	
	floating_points_label.add_theme_color_override("font_color", color)

func _animate_floating_points():
	"""Anima los puntos flotantes con efectos visuales"""
	# Resetear propiedades iniciales
	floating_points_label.modulate = Color(1, 1, 1, 0)
	floating_points_label.scale = Vector2(0.5, 0.5)
	floating_points_label.visible = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fase 1: Aparición
	tween.tween_property(floating_points_label, "modulate", Color(1, 1, 1, 1), 0.3)
	tween.tween_property(floating_points_label, "scale", Vector2(1.2, 1.2), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Fase 2: Movimiento hacia arriba
	var float_target = floating_points_label.position + Vector2(0, -80)
	tween.tween_property(floating_points_label, "position", float_target, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	
	# Fase 3: Reducir escala
	tween.tween_property(floating_points_label, "scale", Vector2(1.0, 1.0), 0.8).set_delay(0.3).set_ease(Tween.EASE_OUT)
	
	# Fase 4: Desvanecimiento
	tween.tween_property(floating_points_label, "modulate", Color(1, 1, 1, 0), 0.5).set_delay(1.3)
	
	# Fase 5: Ocultar
	tween.tween_callback(func(): floating_points_label.visible = false).set_delay(1.8)

# === FUNCIONES DE CONFIGURACIÓN DE CONTENEDOR ===

func _setup_pieces_container():
	if not pieces_container:
		pieces_container = Node2D.new()
		pieces_container.name = "PiecesContainer"
		pieces_container.z_index = 5
		pieces_container.position = Vector2.ZERO
		add_child(pieces_container)
		print("Creado contenedor de piezas dinámicamente en posición (0, 0)")
	else:
		print("Usando contenedor de piezas existente:", pieces_container.name)
		pieces_container.z_index = 5
		pieces_container.position = Vector2.ZERO
		print("PiecesContainer reposicionado a (0, 0) para centrado correcto")

func _setup_puzzle():
	await piece_manager.load_and_create_pieces(image_path, null)

# === FUNCIONES DE ENTRADA ===

func _unhandled_input(event: InputEvent) -> void:
	if puzzle_completed:
		return
	if game_state_manager and game_state_manager.is_paused:
		return

	# Configuración de escala para desktop
	if event is InputEventKey and event.pressed and not is_mobile and not is_tablet:
		if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_S:
			_show_scale_config_dialog()
			return
	
	if input_handler:
		input_handler.handle_input(event)

func _show_scale_config_dialog():
	"""Muestra un diálogo simple para configurar escalas"""
	var device_data = _get_current_device_data()
	
	var message = "Configuración de Escala del Puzzle\n\n"
	message += "Dispositivo detectado: " + device_data.type + "\n"
	message += "Escala actual: " + str(device_data.scale) + "\n\n"
	message += "Escalas recomendadas:\n"
	message += "• 0.6 - Muy pequeño (máxima visibilidad)\n"
	message += "• 0.7 - Pequeño (recomendado tablets)\n"
	message += "• 0.8 - Medio (equilibrado)\n"
	message += "• 0.9 - Grande (más detalle)\n"
	message += "• 1.0 - Máximo (pantalla completa)\n\n"
	message += "¿Qué escala deseas usar? (0.5-1.0)"
	
	var dialog = AcceptDialog.new()
	dialog.title = "Configurar Escala del Puzzle"
	dialog.dialog_text = message
	
	var line_edit = LineEdit.new()
	line_edit.text = str(device_data.scale)
	line_edit.placeholder_text = "0.8"
	dialog.add_child(line_edit)
	
	add_child(dialog)
	dialog.popup_centered()
	
	await dialog.confirmed
	
	var new_scale = float(line_edit.text)
	if new_scale >= 0.5 and new_scale <= 1.0:
		_set_device_scale(new_scale)
		show_info_message("Escala configurada a: " + str(new_scale), 2.0)
	else:
		show_info_message("Escala inválida. Usa valores entre 0.5 y 1.0", 3.0)
	
	dialog.queue_free()

func _ensure_dialog_blocker_component() -> void:
	if dialog_blocker_component and is_instance_valid(dialog_blocker_component):
		return
	dialog_blocker_component = PuzzleDialogBlockerScene.new()
	add_child(dialog_blocker_component)
	dialog_blocker_component.initialize(self)

func _get_current_device_data() -> Dictionary:
	"""Obtiene datos del dispositivo actual"""
	if is_tablet:
		return {"type": "Tablet", "scale": GLOBAL.settings.puzzle.get("tablet_scale", 0.8), "key": "tablet_scale"}
	elif is_desktop:
		return {"type": "Ordenador", "scale": GLOBAL.settings.puzzle.get("desktop_scale", 0.8), "key": "desktop_scale"}
	elif is_mobile:
		return {"type": "Móvil", "scale": GLOBAL.settings.puzzle.get("mobile_scale", mobile_scale_percentage), "key": "mobile_scale"}
	else:
		return {"type": "Desconocido", "scale": max_scale_percentage, "key": "default_scale"}

func _set_device_scale(new_scale: float):
	"""Establece la escala para el dispositivo actual"""
	var device_data = _get_current_device_data()
	
	# Actualizar la escala correspondiente
	match device_data.key:
		"tablet_scale":
			tablet_scale_percentage = new_scale
		"desktop_scale":
			desktop_scale_percentage = new_scale
		"mobile_scale":
			mobile_scale_percentage = new_scale
	
	GLOBAL.settings.puzzle[device_data.key] = new_scale
	GLOBAL.save_settings()
	print("PuzzleGame: Nueva escala de ", device_data.type.to_lower(), " configurada: ", new_scale)
	
	# Actualizar puzzle si es necesario
	if piece_manager:
		print("PuzzleGame: Actualizando puzzle con nueva escala...")
		_reload_puzzle_with_new_scale()

# Mantener funciones individuales por compatibilidad
func set_tablet_scale(new_scale: float):
	tablet_scale_percentage = new_scale
	GLOBAL.settings.puzzle["tablet_scale"] = new_scale
	GLOBAL.save_settings()
	if is_tablet and piece_manager:
		_reload_puzzle_with_new_scale()

func set_desktop_scale(new_scale: float):
	desktop_scale_percentage = new_scale
	GLOBAL.settings.puzzle["desktop_scale"] = new_scale
	GLOBAL.save_settings()
	if is_desktop and piece_manager:
		_reload_puzzle_with_new_scale()

func set_mobile_scale(new_scale: float):
	mobile_scale_percentage = new_scale
	GLOBAL.settings.puzzle["mobile_scale"] = new_scale
	GLOBAL.save_settings()
	if is_mobile and piece_manager:
		_reload_puzzle_with_new_scale()

func _reload_puzzle_with_new_scale():
	"""Recarga el puzzle aplicando la nueva escala"""
	if not piece_manager:
		print("PuzzleGame: No se puede recargar - piece_manager no disponible")
		return
	
	var current_image = image_path
	var puzzle_back = null
	
	if viewport_scene_path != "":
		var viewport_scene = load(viewport_scene_path)
		if viewport_scene:
			var viewport_instance = viewport_scene.instantiate()
			add_child(viewport_instance)
			await get_tree().process_frame
			var viewport_image = viewport_instance.get_texture().get_image()
			puzzle_back = ImageTexture.new()
			puzzle_back.create_from_image(viewport_image)
			viewport_instance.queue_free()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		print("PuzzleGame: Detectado cierre de aplicación - Guardando estado de emergencia")
		_emergency_save_state()
		get_tree().quit()

# === FUNCIONES DE ACCESO PARA MANAGERS ===

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

# === FUNCIONES DE PIECE MANAGER CONSOLIDADAS ===

func _execute_with_piece_manager(method_name: String, args: Array = [], error_message: String = ""):
	"""Función unificada para ejecutar métodos del piece_manager con verificación"""
	if not piece_manager:
		print("PuzzleGame: Error - piece_manager no disponible")
		if error_message:
			show_error_message(error_message, 2.0)
		return null
	
	if piece_manager.has_method(method_name):
		return piece_manager.callv(method_name, args)
	else:
		print("PuzzleGame: Método '", method_name, "' no disponible en piece_manager")
		return null

# Funciones de centrado
func force_recenter_puzzle():
	_execute_with_piece_manager("force_recenter_all_pieces")

func apply_smart_centering():
	print("PuzzleGame: Aplicando corrección inteligente de centrado...")
	_execute_with_piece_manager("_apply_smart_centering_correction")

func run_positioning_diagnosis():
	print("PuzzleGame: Ejecutando diagnóstico de posicionamiento...")
	return _execute_with_piece_manager("_verify_piece_positioning") or false

# Funciones de superposiciones
func resolve_all_puzzle_overlaps():
	print("PuzzleGame: 🔧 Ejecutando resolución de superposiciones...")
	var result = _execute_with_piece_manager("resolve_all_overlaps", [], "Error: No se pudo resolver superposiciones")
	if result != null:
		print("PuzzleGame: ✅ Resolución de superposiciones completada")

func verify_puzzle_integrity() -> bool:
	print("PuzzleGame: 🔍 Verificando integridad del puzzle...")
	var result = _execute_with_piece_manager("verify_no_overlaps")
	if result != null:
		if result:
			print("PuzzleGame: ✅ Puzzle verificado - Sin superposiciones")
			return true
		else:
			print("PuzzleGame: ⚠️ Se detectaron superposiciones en el puzzle")
			return false
	else:
		print("PuzzleGame: ❌ No se pudo verificar integridad (funciones no disponibles)")
		return false

func force_clean_puzzle_grid():
	print("PuzzleGame: 🧹 Forzando limpieza del grid del puzzle...")
	var result = _execute_with_piece_manager("force_clean_grid", [], "Error: No se pudo limpiar grid")
	if result != null:
		print("PuzzleGame: ✅ Grid limpiado exitosamente")

# Funciones de bordes de grupo
func toggle_group_borders(enabled: bool):
	_execute_with_piece_manager("set_group_borders_enabled", [enabled])

func set_group_border_thickness(thickness: float):
	_execute_with_piece_manager("set_group_border_thickness", [thickness])

func set_group_border_opacity(opacity: float):
	_execute_with_piece_manager("set_group_border_opacity", [opacity])

func refresh_group_borders():
	_execute_with_piece_manager("refresh_all_group_borders")

func toggle_group_borders_visibility(visible: bool):
	_execute_with_piece_manager("toggle_group_borders_visibility", [visible])

func convert_borders_to_interior():
	_execute_with_piece_manager("convert_borders_to_interior")

# === FUNCIONES DE CENTRADO MEJORADAS ===

func force_complete_recenter(silent_mode: bool = false):
	"""Función integral que realiza un recentrado completo y seguro del puzzle"""
	print("PuzzleGame: 🎯 INICIANDO RECENTRADO COMPLETO")
	
	var initial_diagnosis = run_positioning_diagnosis()
	if initial_diagnosis and not silent_mode:
		print("PuzzleGame: ✅ Puzzle ya está centrado correctamente")
		return
	
	print("PuzzleGame: Paso 2 - Aplicando corrección inteligente")
	apply_smart_centering()
	
	await get_tree().create_timer(0.2).timeout
	var final_diagnosis = run_positioning_diagnosis()
	
	if final_diagnosis:
		if not silent_mode:
			print("PuzzleGame: ✅ RECENTRADO COMPLETO EXITOSO")
	else:
		print("PuzzleGame: Aplicando recentrado forzado como último recurso...")
		force_recenter_puzzle()
		if not silent_mode:
			print("PuzzleGame: 🔧 RECENTRADO FORZADO COMPLETADO")

func run_comprehensive_puzzle_check():
	"""Función integral que verifica y corrige todos los problemas del puzzle"""
	print("PuzzleGame: 🔧 Ejecutando verificación integral del puzzle...")
	
	var has_overlaps = not verify_puzzle_integrity()
	if has_overlaps:
		print("PuzzleGame: Detectadas superposiciones, resolviendo...")
		await resolve_all_puzzle_overlaps()
	
	var centering_ok = run_positioning_diagnosis()
	if not centering_ok:
		print("PuzzleGame: Detectado problema de centrado, corrigiendo...")
		force_complete_recenter(true)
	
	var final_overlaps_check = verify_puzzle_integrity()
	var final_centering_check = run_positioning_diagnosis()
	
	if final_overlaps_check and final_centering_check:
		print("PuzzleGame: ✅ VERIFICACIÓN INTEGRAL COMPLETADA - Todo está correcto")
	else:
		show_error_message("⚠️ Algunos problemas persisten", 3.0)
		print("PuzzleGame: ⚠️ VERIFICACIÓN INTEGRAL COMPLETADA - Algunos problemas persisten")
		if not final_overlaps_check:
			print("PuzzleGame: - Persisten superposiciones")
		if not final_centering_check:
			print("PuzzleGame: - Persisten problemas de centrado")

func center_puzzle_and_update_borders(silent: bool = false):
	force_complete_recenter(silent)

# === FUNCIONES DE GESTIÓN DE MENSAJES CONSOLIDADAS ===

func show_message(message: String, duration: float = 2.0, message_type: String = "info"):
	"""Función unificada para mostrar mensajes al usuario"""
	# Filtrar mensajes de salida
	if message.contains("salir") or message.contains("exit") or message.contains("quit"):
		return
	
	match message_type:
		"success":
			if ui_manager:
				ui_manager.show_success_message(message, duration)
		"error":
			if ui_manager:
				ui_manager.show_error_message(message, duration)
		"info":
			if ui_manager and ui_manager.has_method("show_message"):
				ui_manager.show_message(message, duration)
			else:
				print("PuzzleGame: ", message)

func show_success_message(message: String, duration: float = 1.5):
	show_message(message, duration, "success")

func show_error_message(message: String, duration: float = 2.0):
	show_message(message, duration, "error")

func show_info_message(message: String, duration: float = 2.0):
	show_message(message, duration, "info")

# === FUNCIONES DE BOTONES ===

func _on_button_options_pressed():
	game_state_manager.pause_game()

func _on_button_exit_pressed():
	print("PuzzleGame: Botón de salida presionado durante puzzle - IGNORANDO")
	GLOBAL.change_scene_direct("res://Scenes/PuzzleSelection.tscn")

func _on_button_repeat_pressed():
	game_state_manager.restart_puzzle()

func on_flip_button_pressed():
	var was_flip_active := game_state_manager.is_flip

	if score_manager and score_manager.is_scoring_enabled():
		score_manager.add_flip_use()
	ui_manager.on_flip_button_pressed()
	if was_flip_active != game_state_manager.is_flip:
		sync_flip_button_icon(true)
	else:
		sync_flip_button_icon()

func _on_button_toggle_hud_pressed():
	ui_manager.toggle_hud()

func _on_center_button_pressed():
	print("PuzzleGame: Botón de centrado presionado")
	force_complete_recenter()

func resume_game():
	game_state_manager.resume_game()

# === FUNCIONES DE COMPLETAR PUZZLE ===

func _handle_puzzle_really_completed():
	puzzle_completed = true
	print("PuzzleGame: _handle_puzzle_really_completed() - Puzzle marcado como completado internamente tras señal de VictoryChecker.")
	_handle_puzzle_completion_state()

func _on_puzzle_completed():
	print("PuzzleGame: _on_puzzle_completed() llamada - ¡Puzzle completado!")
	
	if current_pack_id.is_empty() or current_puzzle_id.is_empty():
		print("ERROR: No se pueden guardar el progreso, faltan los IDs del pack o puzzle")
		return
	
	# Completar puzzle en el score manager
	if score_manager and score_manager.is_scoring_enabled():
		score_manager.complete_puzzle()
		var score_summary = score_manager.get_score_summary()
		score_summary["completion_time"] = game_state_manager.elapsed_time
		
		if ranking_manager:
			ranking_manager.save_puzzle_score(current_pack_id, current_puzzle_id, score_summary)
			ranking_manager.update_global_ranking()
	
	print("PuzzleGame: Marcando puzzle como completado - Pack: " + current_pack_id + ", Puzzle: " + current_puzzle_id)
	progress_manager.complete_puzzle(current_pack_id, current_puzzle_id)
	
	var next_puzzle = progress_manager.get_next_unlocked_puzzle(current_pack_id, current_puzzle_id)
	if next_puzzle != null:
		print("PuzzleGame: Siguiente puzzle desbloqueado: " + next_puzzle.name)
	else:
		print("PuzzleGame: No hay siguiente puzzle disponible")
	
	progress_manager.save_progress_data()
	print("PuzzleGame: Datos de progresión guardados")
	show_victory_screen()

func handle_back_gesture() -> bool:
	print("PuzzleGame: Gesto del borde detectado durante el puzzle - IGNORANDO completamente")
	return true

func show_victory_screen():
	print("Cambiando a la pantalla de victoria")
	
	var game_state = game_state_manager.get_current_game_state_for_victory()
	var score_data = {}
	if score_manager and score_manager.is_scoring_enabled():
		score_data = score_manager.get_score_summary()
	
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
		"score_data": score_data
	}
	
	safe_change_scene("res://Scenes/VictoryScreen.tscn")

func safe_change_scene(scene_path: String) -> void:
	if get_tree() != null:
		get_tree().call_deferred("change_scene_to_file", scene_path)
	else:
		push_error("No se pudo cambiar a la escena: " + scene_path)

# === FUNCIONES DE CENTRADO Y CONECTAR BOTONES ===

func _connect_center_button():
	if center_button:
		if not center_button.is_connected("pressed", Callable(self, "_on_center_button_pressed")):
			center_button.connect("pressed", Callable(self, "_on_center_button_pressed"))
		
		center_button.visible = is_mobile or is_tablet
		print("PuzzleGame: Botón de centrado conectado desde la escena (visible en móviles/tablets: ", (is_mobile or is_tablet), ")")
	else:
		print("PuzzleGame: No se encontró botón de centrado en la escena")
	
	if is_tablet or is_desktop:
		_create_scale_config_button()

func _create_scale_config_button():
	"""Crea un botón para configurar la escala en tablets y ordenadores"""
	var scale_button = Button.new()
	scale_button.name = "ScaleConfigButton"
	scale_button.text = "⚙️"
	scale_button.custom_minimum_size = Vector2(50, 50)
	scale_button.anchors_preset = Control.PRESET_TOP_RIGHT
	scale_button.position = Vector2(-60, 10)
	
	if UILayer:
		UILayer.add_child(scale_button)
		scale_button.pressed.connect(_show_scale_config_dialog)
		print("PuzzleGame: Botón de configuración de escala creado para ", ("tablet" if is_tablet else "ordenador"))
	else:
		print("PuzzleGame: No se pudo crear botón de configuración - UILayer no encontrado")

func _show_centering_welcome_message():
	await get_tree().create_timer(1.5).timeout

# === FUNCIONES DE LOADING PUZZLE ===

func _show_loading_puzzle():
	print("PuzzleGame: Mostrando loading puzzle...")
	
	if UILayer:
		print("PuzzleGame: UILayer detectado con layer: ", UILayer.layer)
	
	for child in get_children():
		if child is CanvasLayer:
			print("PuzzleGame: CanvasLayer encontrado: ", child.name, " - Layer: ", child.layer)
	
	loading_puzzle_instance = LoadingPuzzleScene.instantiate()
	
	var loading_canvas_layer = CanvasLayer.new()
	loading_canvas_layer.name = "LoadingCanvasLayer"
	loading_canvas_layer.layer = 9999
	
	add_child(loading_canvas_layer)
	loading_canvas_layer.add_child(loading_puzzle_instance)
	loading_puzzle_instance.z_index = 1000
	
	print("PuzzleGame: Loading puzzle instanciado en CanvasLayer con prioridad 9999")

func _hide_loading_puzzle():
	print("PuzzleGame: Ocultando loading puzzle...")
	
	if loading_puzzle_instance != null:
		print("PuzzleGame: Loading puzzle instance encontrada, procediendo a eliminar...")
		
		var loading_canvas_layer = loading_puzzle_instance.get_parent()
		
		if loading_puzzle_instance.has_method("fade_out"):
			print("PuzzleGame: Ejecutando fade_out...")
			await loading_puzzle_instance.fade_out()
			print("PuzzleGame: Fade out completado exitosamente")
		else:
			print("PuzzleGame: Método fade_out no encontrado, eliminando directamente")
			await get_tree().create_timer(1.5).timeout
		
		if is_instance_valid(loading_puzzle_instance):
			print("PuzzleGame: Eliminando loading_puzzle_instance...")
			loading_puzzle_instance.queue_free()
			await get_tree().process_frame
			loading_puzzle_instance = null
			print("PuzzleGame: Loading puzzle eliminado correctamente")
		else:
			print("PuzzleGame: Loading puzzle instance ya no es válida")
			loading_puzzle_instance = null
		
		if loading_canvas_layer != null and is_instance_valid(loading_canvas_layer):
			print("PuzzleGame: Eliminando LoadingCanvasLayer...")
			loading_canvas_layer.queue_free()
			await get_tree().process_frame
			print("PuzzleGame: LoadingCanvasLayer eliminado")
	else:
		print("PuzzleGame: Warning - No hay loading puzzle para eliminar (referencia es null)")

func force_remove_loading_puzzle():
	print("PuzzleGame: Forzando eliminación del loading puzzle...")
	
	if loading_puzzle_instance != null:
		var loading_canvas_layer = loading_puzzle_instance.get_parent()
		
		loading_puzzle_instance.visible = false
		
		if loading_puzzle_instance.has_method("stop_immediately"):
			loading_puzzle_instance.stop_immediately()
		
		loading_puzzle_instance.queue_free()
		loading_puzzle_instance = null
		
		if loading_canvas_layer != null and is_instance_valid(loading_canvas_layer):
			loading_canvas_layer.queue_free()
			print("PuzzleGame: LoadingCanvasLayer también eliminado forzosamente")
		
		print("PuzzleGame: Loading puzzle eliminado forzosamente")
	else:
		print("PuzzleGame: No hay loading puzzle para forzar eliminación")

func _hide_ui_for_loading():
	print("PuzzleGame: Ocultando UI temporalmente para loading...")
	if UILayer:
		UILayer.visible = false
		print("PuzzleGame: UILayer ocultado")

func _restore_ui_after_loading():
	print("PuzzleGame: Restaurando UI después del loading...")
	if UILayer:
		UILayer.visible = true
		print("PuzzleGame: UILayer restaurado")

# === FUNCIONES DE DEBUG Y PRUEBAS ===

func _debug_score_system():
	"""Función de debug para verificar que el sistema de puntuación está funcionando"""
	print("=== 🔍 DEBUG SISTEMA DE PUNTUACIÓN ===")
	
	var components = [
		{name = "Score Manager", obj = score_manager, extra = " - Scoring habilitado: " + str(score_manager.is_scoring_enabled() if score_manager else "N/A")},
		{name = "Score Label", obj = score_label, extra = " - Texto: '" + score_label.text + "'" if score_label else ""},
		{name = "Streak Label", obj = streak_label, extra = " - Texto: '" + streak_label.text + "'" if streak_label else ""},
		{name = "Floating Points Label", obj = floating_points_label, extra = ""},
		{name = "Game State Manager", obj = game_state_manager, extra = " - Modo relax: " + str(game_state_manager.relax_mode) if game_state_manager else ""}
	]
	
	for component in components:
		var status = "✅ DISPONIBLE" if component.obj else "❌ NO DISPONIBLE"
		print(status, " ", component.name, component.extra)
	
	print("========================================")

func _test_score_system_delayed():
	"""Prueba del sistema de puntuación después de unos segundos"""
	await get_tree().create_timer(3.0).timeout
	
	print("🧪 INICIANDO PRUEBA DEL SISTEMA DE PUNTUACIÓN...")
	
	if score_manager and score_manager.is_scoring_enabled():
		score_manager.add_piece_placed_correctly()
		print("🧪 Prueba 1: Pieza colocada correctamente")
		
		await get_tree().create_timer(1.0).timeout
		score_manager.add_groups_connected()
		print("🧪 Prueba 2: Grupos conectados")
	else:
		print("🧪 ERROR: Score manager no disponible o no habilitado")

# === FUNCIONES DE BLOQUEO DE DIÁLOGOS ===

func _setup_dialog_blocker():
	if not dialog_blocker_enabled:
		if dialog_blocker_component:
			dialog_blocker_component.set_enabled(false)
		return
	_ensure_dialog_blocker_component()
	dialog_blocker_component.set_enabled(true)
	print("PuzzleGame: Sistema de bloqueo de diálogos ULTRA-AGRESIVO activado")

func _setup_global_dialog_interceptors():
	if not dialog_blocker_enabled:
		return
	_ensure_dialog_blocker_component()
	dialog_blocker_component.set_enabled(true)
	print("PuzzleGame: Configurando interceptores globales de diálogos...")

func _on_global_child_added(node):
	if dialog_blocker_component:
		dialog_blocker_component.handle_global_child_added(node)

func _force_remove_node(node):
	if dialog_blocker_component:
		dialog_blocker_component.force_remove_node(node)
	elif is_instance_valid(node):
		node.queue_free()

func _process(_delta):
	pass

func _block_all_dialogs():
	if dialog_blocker_component:
		dialog_blocker_component.block_all_dialogs()

func show_exit_dialog():
	print("PuzzleGame: Intento de mostrar diálogo de salida durante puzzle - BLOQUEADO")

# === FUNCIONES DE GESTIÓN DEL ESTADO GUARDADO ===

func _initialize_new_puzzle_state():
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager:
		puzzle_state_manager.start_new_puzzle_state(current_pack_id, current_puzzle_id, GLOBAL.gamemode, GLOBAL.current_difficult)
		print("PuzzleGame: Nuevo estado de puzzle inicializado")
	
	# 🔧 CRÍTICO: Resetear completamente todos los contadores del game_state_manager
	if game_state_manager:
		print("PuzzleGame: Reseteando contadores para nuevo puzzle...")
		game_state_manager.total_moves = 0
		game_state_manager.elapsed_time = 0.0
		game_state_manager.flip_count = 0
		game_state_manager.flip_move_count = 0
		game_state_manager.time_left = 0.0
		game_state_manager.is_flip = false
		game_state_manager.is_paused = false
		game_state_manager.accumulated_time = 0.0
		
		# Resetear también los límites según el modo actual
		game_state_manager.max_moves = GLOBAL.puzzle_limits.max_moves
		game_state_manager.max_flips = GLOBAL.puzzle_limits.max_flips
		game_state_manager.max_flip_moves = GLOBAL.puzzle_limits.max_flip_moves
		game_state_manager.time_left = GLOBAL.puzzle_limits.max_time
		
		print("PuzzleGame: Contadores reseteados - Movimientos: 0, Flips: 0, Tiempo: 0.0")
		
	# 🔧 CRÍTICO: Resetear también los contadores del score_manager
	if score_manager:
		print("PuzzleGame: Reseteando puntuación para nuevo puzzle...")
		score_manager.current_score = 0
		score_manager.streak_count = 0
		score_manager.pieces_placed_correctly = 0
		score_manager.groups_connected = 0
		score_manager.invalid_moves = 0
		score_manager.flip_uses = 0
		score_manager.undo_uses = 0
		score_manager.had_errors = false
		score_manager.used_flip = false
		
		# Emitir señales para actualizar la UI
		score_manager.score_updated.emit(0)
		score_manager.streak_updated.emit(0)
		
		print("PuzzleGame: Puntuación reseteada - Score: 0, Streak: 0")
	
	# Actualizar la UI con los contadores reseteados
	_update_ui_counters()
	sync_flip_button_icon()

func sync_flip_button_icon(animated: bool = false) -> void:
	if flip_image == null:
		return

	var is_flip_active := game_state_manager != null and game_state_manager.is_flip
	if animated:
		_animate_flip_button_icon(is_flip_active)
		return

	_stop_flip_button_icon_animation()
	_apply_flip_button_icon_rest_state(is_flip_active)

func _animate_flip_button_icon(is_flip_active: bool) -> void:
	if flip_image == null:
		return

	_stop_flip_button_icon_animation()
	flip_image.scale = Vector2.ONE

	# Forzamos exactamente media vuelta visual por pulsación.
	flip_image.rotation_degrees = 0.0 if is_flip_active else FLIP_ICON_HALF_TURN_DEGREES

	flip_icon_tween = create_tween()
	flip_icon_tween.tween_property(
		flip_image,
		"rotation_degrees",
		FLIP_ICON_HALF_TURN_DEGREES if is_flip_active else FLIP_ICON_HALF_TURN_DEGREES * 2.0,
		FLIP_ICON_ANIMATION_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flip_icon_tween.parallel().tween_property(
		flip_image,
		"scale",
		Vector2(0.9, 0.9),
		FLIP_ICON_ANIMATION_DURATION * 0.45
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flip_icon_tween.chain().tween_property(
		flip_image,
		"scale",
		Vector2.ONE,
		FLIP_ICON_ANIMATION_DURATION * 0.55
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flip_icon_tween.tween_callback(Callable(self, "_apply_flip_button_icon_rest_state").bind(is_flip_active))

func _apply_flip_button_icon_rest_state(is_flip_active: bool) -> void:
	if flip_image == null:
		return

	flip_image.rotation_degrees = FLIP_ICON_HALF_TURN_DEGREES if is_flip_active else 0.0
	flip_image.scale = Vector2.ONE

func _stop_flip_button_icon_animation() -> void:
	if flip_icon_tween and flip_icon_tween.is_valid():
		flip_icon_tween.kill()
	flip_icon_tween = null

func _restore_puzzle_state(puzzle_state_manager):
	print("PuzzleGame: 🔧 Iniciando restauración UNIFICADA de estado...")
	
	disable_input_events()
	
	var saved_pieces_data = puzzle_state_manager.get_saved_pieces_data()
	print("PuzzleGame: Datos guardados - Piezas: ", saved_pieces_data.size())
	
	if saved_pieces_data.size() == 0:
		print("PuzzleGame: No hay datos de piezas guardados, usando posiciones iniciales")
		enable_input_events()
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var unified_restoration = preload("res://Scripts/Autoload/UnifiedPuzzleRestoration.gd").new()
	unified_restoration.initialize(self, piece_manager)
	
	unified_restoration.restoration_completed.connect(_on_restoration_completed)
	unified_restoration.restoration_failed.connect(_on_restoration_failed)
	
	var restoration_success = unified_restoration.restore_puzzle_state_unified(saved_pieces_data)
	
	enable_input_events()
	
	if restoration_success:
		print("PuzzleGame: ✅ RESTAURACIÓN UNIFICADA COMPLETADA EXITOSAMENTE")
	else:
		print("PuzzleGame: ❌ ERROR EN RESTAURACIÓN UNIFICADA")
	
	unified_restoration.queue_free()

func _on_restoration_completed(success: bool):
	print("PuzzleGame: ✅ Restauración completada exitosamente")

func _on_restoration_failed(error_message: String):
	print("PuzzleGame: ❌ Restauración falló: ", error_message)
	show_error_message("Error al restaurar la partida: " + error_message, 3.0)

func set_auto_centering_enabled(enabled: bool):
	print("PuzzleGame: Centrado automático ", "activado" if enabled else "desactivado")

func force_synchronize_groups():
	"""Función manual para sincronizar grupos cuando hay problemas visuales"""
	print("PuzzleGame: 🔧 SINCRONIZACIÓN MANUAL DE GRUPOS SOLICITADA")
	
	if not piece_manager:
		print("PuzzleGame: ❌ Error - PuzzlePieceManager no disponible")
		return
	
	var group_synchronizer = preload("res://Scripts/Autoload/GroupSynchronizer.gd").new()
	group_synchronizer.initialize(self, piece_manager)
	
	var problems_fixed = group_synchronizer.force_synchronize_all_groups()
	
	if problems_fixed > 0:
		show_success_message("🔧 " + str(problems_fixed) + " problemas de grupos corregidos", 3.0)
		print("PuzzleGame: ✅ ", problems_fixed, " problemas de sincronización corregidos")
	else:
		show_success_message("✅ Todos los grupos están correctos", 2.0)
		print("PuzzleGame: ✅ No se encontraron problemas")
	
	group_synchronizer.queue_free()

func _restore_game_counters(puzzle_state_manager):
	print("PuzzleGame: Restaurando contadores del juego...")
	
	var saved_counters = puzzle_state_manager.get_saved_counters()
	
	if game_state_manager:
		var counter_keys = ["elapsed_time", "total_moves", "flip_count", "flip_move_count", "time_left"]
		
		for key in counter_keys:
			if saved_counters.has(key):
				game_state_manager.set(key, saved_counters[key])
		
		if saved_counters.has("elapsed_time"):
			game_state_manager.start_time = Time.get_unix_time_from_system() - saved_counters.elapsed_time
		
		# Restaurar contadores de flip específicamente
		puzzle_state_manager.restore_flip_counters_to_game_state(game_state_manager)
		
		print("PuzzleGame: Contadores restaurados - Tiempo: ", saved_counters.get("elapsed_time", 0), 
			  ", Movimientos: ", saved_counters.get("total_moves", 0),
			  ", Flips: ", saved_counters.get("flip_count", 0),
			  ", Movimientos en flip: ", saved_counters.get("flip_move_count", 0))
	
	# Restaurar datos de puntuación si existe el score manager
	if score_manager and puzzle_state_manager.has_saved_state():
		var score_restored = puzzle_state_manager.restore_score_data_to_manager(score_manager)
		if score_restored:
			print("PuzzleGame: Datos de puntuación restaurados exitosamente")
		else:
			print("PuzzleGame: No se pudieron restaurar los datos de puntuación")
	
	_update_ui_counters()

func _update_ui_counters():
	if not game_state_manager:
		return
	
	if movesLabel:
		movesLabel.text = str(game_state_manager.total_moves)
	
	# Actualizar UI de flips si están visibles
	if maxFlipsLabel and maxFlipsLabel.visible:
		var remaining_flips = game_state_manager.max_flips - game_state_manager.flip_count
		maxFlipsLabel.text = str(max(0, remaining_flips))
	
	# Actualizar UI de movimientos en flip si están visibles  
	if maxMovesFlipLabel and maxMovesFlipLabel.visible:
		var remaining_flip_moves = game_state_manager.max_flip_moves - game_state_manager.flip_move_count
		maxMovesFlipLabel.text = str(max(0, remaining_flip_moves))
	
	var timer_label = get_node("UILayer/TimerLabel") if has_node("UILayer/TimerLabel") else null
	if timer_label and timer_label.visible:
		var minutes = int(game_state_manager.elapsed_time) / 60
		var seconds = int(game_state_manager.elapsed_time) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
	
	print("PuzzleGame: UI actualizada - Movimientos: ", game_state_manager.total_moves, 
		  ", Flips: ", game_state_manager.flip_count, 
		  ", Movimientos en flip: ", game_state_manager.flip_move_count)

func _handle_puzzle_completion_state():
	print("PuzzleGame: Puzzle completado, limpiando estado guardado...")
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager:
		puzzle_state_manager.complete_puzzle()
	print("PuzzleGame: Estado limpiado, pack y puzzle mantenidos para acceso rápido")

func _update_saved_state():
	# Solo actualizar datos en memoria, no guardar automáticamente al archivo
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if not puzzle_state_manager or not puzzle_state_manager.has_saved_state():
		return
	
	if game_state_manager:
		puzzle_state_manager.update_counters(
			game_state_manager.elapsed_time,
			game_state_manager.total_moves,
			game_state_manager.flip_count,
			game_state_manager.flip_move_count,
			game_state_manager.time_left
		)
	
	if piece_manager:
		puzzle_state_manager.update_pieces_positions_from_manager(piece_manager)
	elif pieces_container:
		puzzle_state_manager.update_pieces_positions(pieces_container)
	
	# Ya no se guarda automáticamente aquí - solo se actualizan los datos en memoria

func _emergency_save_state():
	print("PuzzleGame: Ejecutando guardado de emergencia...")
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager and puzzle_state_manager.has_saved_state():
		_update_saved_state()
		puzzle_state_manager.save_on_player_action("guardado de emergencia")
		print("PuzzleGame: Guardado de emergencia completado")

# Nueva función para guardar por acción específica del jugador
func save_state_on_action(action_name: String):
	print("PuzzleGame: Guardando estado por acción: ", action_name)
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager and puzzle_state_manager.has_saved_state():
		_update_saved_state()  # Actualizar datos primero
		puzzle_state_manager.save_on_player_action(action_name)  # Luego guardar

# === FUNCIONES DE GESTIÓN AUTOMÁTICA DE SUPERPOSICIONES ===

func setup_overlap_monitoring():
	"""Configura un sistema de monitoreo automático de superposiciones"""
	print("PuzzleGame: Configurando monitoreo automático de superposiciones...")
	
	var overlap_timer = Timer.new()
	overlap_timer.name = "OverlapMonitorTimer"
	overlap_timer.wait_time = 2.0
	overlap_timer.autostart = true
	overlap_timer.timeout.connect(_on_overlap_check_timeout)
	add_child(overlap_timer)
	
	print("PuzzleGame: Monitoreo automático de superposiciones activado")

func _on_overlap_check_timeout():
	"""Ejecuta verificación automática de superposiciones cada cierto tiempo"""
	if not piece_manager:
		return
	
	if not piece_manager.verify_no_overlaps():
		print("PuzzleGame: 🔧 Detectadas superposiciones durante monitoreo automático - Resolviendo...")
		piece_manager.resolve_all_overlaps()
		show_info_message("🔧 Auto-corrección de posiciones", 1.0)

func force_overlap_resolution():
	"""Función pública para forzar la resolución de superposiciones desde cualquier lugar"""
	if piece_manager:
		print("PuzzleGame: Forzando resolución completa de superposiciones...")
		piece_manager.resolve_all_overlaps()
		
		if !piece_manager.verify_no_overlaps():
			piece_manager.recalculate_all_grid_positions()

# === FUNCIONES DE GESTIÓN DE EVENTOS DURANTE RESTAURACIÓN ===

# Deshabilitar eventos de entrada temporalmente
func disable_input_events():
	print("PuzzleGame: Deshabilitando eventos de entrada durante restauración...")
	if input_handler:
		input_handler.set_process_unhandled_input(false)
		input_handler.set_process_input(false)
	
	# Deshabilitar eventos en todas las piezas
	if piece_manager:
		var pieces = piece_manager.get_pieces()
		for piece_obj in pieces:
			if piece_obj and piece_obj.node and piece_obj.node.has_node("Area2D"):
				var area2d = piece_obj.node.get_node("Area2D")
				area2d.input_pickable = false

# Habilitar eventos de entrada después de la restauración
func enable_input_events():
	print("PuzzleGame: Habilitando eventos de entrada después de restauración...")
	if input_handler:
		input_handler.set_process_unhandled_input(true)
		input_handler.set_process_input(true)
	
	# Habilitar eventos en todas las piezas
	if piece_manager:
		var pieces = piece_manager.get_pieces()
		for piece_obj in pieces:
			if piece_obj and piece_obj.node and piece_obj.node.has_node("Area2D"):
				var area2d = piece_obj.node.get_node("Area2D")
				area2d.input_pickable = true

func verify_puzzle_state_after_restoration():
	print("PuzzleGame: Verificando estado del puzzle después de restauración...")
	
	if not piece_manager:
		print("PuzzleGame: ❌ piece_manager no disponible")
		return false
	
	var pieces = piece_manager.get_pieces()
	var issues_found = 0
	
	for piece_obj in pieces:
		if not piece_obj or not piece_obj.node:
			issues_found += 1
			print("PuzzleGame: ⚠️ Pieza inválida encontrada")
			continue
		
		if piece_obj.current_cell.x < 0 or piece_obj.current_cell.y < 0:
			issues_found += 1
			print("PuzzleGame: ⚠️ Pieza ", piece_obj.order_number, " tiene current_cell inválido: ", piece_obj.current_cell)
		
		if piece_obj.drag_start_cell != piece_obj.current_cell:
			issues_found += 1
			print("PuzzleGame: ⚠️ Pieza ", piece_obj.order_number, " tiene drag_start_cell desincronizado")
		
		if piece_obj.dragging:
			issues_found += 1
			print("PuzzleGame: ⚠️ Pieza ", piece_obj.order_number, " está en estado de arrastre después de restauración")
			piece_obj.dragging = false
			if piece_obj.node.has_method("set_dragging"):
				piece_obj.node.set_dragging(false)
	
	var grid_issues = piece_manager.verify_no_overlaps()
	if not grid_issues:
		issues_found += 1
		print("PuzzleGame: ⚠️ Detectadas superposiciones en el grid después de restauración")
	
	if issues_found == 0:
		print("PuzzleGame: ✅ Estado del puzzle verificado correctamente")
		return true
	else:
		print("PuzzleGame: ❌ Se encontraron ", issues_found, " problemas en el estado del puzzle")
		return false

# === FUNCIONES DE UTILIDAD ===

func adjust_edge_margin(new_margin: float):
	if input_handler:
		input_handler.set_edge_margin(new_margin)
	else:
		print("PuzzleGame: Error - input_handler no disponible")
