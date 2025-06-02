# PuzzleGame.gd
# Archivo principal del puzzle - Coordina todos los managers

extends Node2D
class_name PuzzleGame

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")
var VictoryCheckerScene = preload("res://Scripts/gameplay/VictoryChecker.gd")

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

# Referencias a mensajes de éxito/error que deberían estar en la escena
@onready var success_message_label: Label = $UILayer/SuccessMessage
@onready var error_message_label: Label = $UILayer/ErrorMessage

# Managers
var input_handler: PuzzleInputHandler
var piece_manager: PuzzlePieceManager
var game_state_manager: PuzzleGameStateManager
var ui_manager: PuzzleUIManager

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

	# Configurar el puzzle según los datos seleccionados
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
	
	# El centrado automático ahora se hace al final de load_and_create_pieces()
	# para asegurar que todas las piezas estén completamente cargadas
	
	# Conectar señales de botones
	_connect_button_signals()
	
	# Configurar modos de juego
	game_state_manager.setup_game_mode()
	
	# Conectar botón de centrado si existe en la escena
	_connect_center_button()
	
	# Mostrar mensaje de bienvenida con opciones de centrado
	_show_centering_welcome_message()

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
	
	# Añadir como hijos
	add_child(input_handler)
	add_child(piece_manager)
	add_child(game_state_manager)
	add_child(ui_manager)
	
	# Inicializar con referencias necesarias
	input_handler.initialize(self)
	piece_manager.initialize(self)
	game_state_manager.initialize(self)
	ui_manager.initialize(self)

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
	if game_state_manager:
		game_state_manager.handle_notification(what)

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

# Función para ejecutar diagnóstico completo
func run_positioning_diagnosis():
	if piece_manager:
		print("PuzzleGame: Ejecutando diagnóstico de posicionamiento...")
		return piece_manager._verify_piece_positioning()
	else:
		print("PuzzleGame: Error - piece_manager no disponible")
		return false

# Función para resetear completamente el centrado del puzzle
func force_complete_recenter(silent: bool = false):
	print("PuzzleGame: Forzando recentrado completo del puzzle...")
	
	# 1. Resetear el InputHandler
	if input_handler:
		input_handler.reset_board_to_center()
	
	# 2. Aplicar corrección inteligente
	if piece_manager:
		piece_manager._apply_smart_centering_correction()
	
	# 3. Verificar resultado (solo mostrar mensajes si no es silencioso)
	if run_positioning_diagnosis():
		if not silent:
			show_success_message("✅ Puzzle centrado perfectamente", 2.0)
	else:
		if not silent:
			show_error_message("⚠️ El recentrado no fue completamente exitoso", 2.0)

func _handle_puzzle_really_completed():
	puzzle_completed = true
	print("PuzzleGame: _handle_puzzle_really_completed() - Puzzle marcado como completado internamente tras señal de VictoryChecker.")
	# El VictoryChecker ya maneja la transición a la pantalla de victoria

# Delegación de funciones principales a los managers apropiados
func show_success_message(message: String, duration: float = 1.5):
	ui_manager.show_success_message(message, duration)

func show_error_message(message: String, duration: float = 2.0):
	ui_manager.show_error_message(message, duration)

func _on_button_exit_pressed():
	ui_manager.show_exit_dialog()

func _on_button_repeat_pressed():
	game_state_manager.restart_puzzle()

func on_flip_button_pressed():
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

# Función para mostrar la pantalla de victoria
func show_victory_screen():
	print("Cambiando a la pantalla de victoria")
	
	# Obtener datos del estado del juego para la victoria
	var game_state = game_state_manager.get_current_game_state_for_victory()
	
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
		"challenge_mode": game_state.challenge_mode
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
	await get_tree().create_timer(2.0).timeout
	
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
		show_success_message("💡 Triple tap o botón 🎯 para centrar puzzle", 3.0)
	else:
		show_success_message("💡 Presiona 'C' para centrar puzzle 🎯", 3.0)
