# PuzzleGame.gd
# Archivo principal del puzzle - Coordina todos los managers

extends Node2D
class_name PuzzleGame

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")
var VictoryCheckerScene = preload("res://Scripts/gameplay/VictoryChecker.gd")

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
func force_complete_recenter(silent: bool = false):
	print("PuzzleGame: Forzando recentrado completo del puzzle...")
	
	# 1. Resetear el InputHandler
	if input_handler:
		input_handler.reset_board_to_center()
	
	# 2. Aplicar corrección inteligente
	if piece_manager:
		piece_manager._apply_smart_centering_correction()
	
	# 3. 🔲 NUEVO: Actualizar bordes de grupo después del centrado
	if piece_manager:
		piece_manager.update_all_group_borders()
		print("PuzzleGame: Bordes de grupo actualizados después del centrado")
	
	# 4. Verificar resultado (solo mostrar mensajes si no es silencioso)
	if run_positioning_diagnosis():
		if not silent:
			show_success_message("✅ Puzzle centrado perfectamente", 2.0)
	else:
		if not silent:
			show_error_message("⚠️ El recentrado no fue completamente exitoso", 2.0)

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
	
	# Esperar un frame adicional para estabilidad
	await get_tree().process_frame
	
	# Obtener piezas del PuzzlePieceManager y crear mapa por order_number
	var manager_pieces = piece_manager.get_pieces() if piece_manager else []
	var total_pieces = manager_pieces.size()
	
	print("PuzzleGame: Encontradas ", total_pieces, " piezas en PuzzlePieceManager")
	
	# Restaurar posiciones individuales primero (sin grupos)
	var restored_count = 0
	for piece_data in saved_pieces_data:
		var order = piece_data.get("order_number", -1)
		if order >= 0:
			var found_piece = null
			
			# Buscar la pieza con el order_number correspondiente
			for piece_obj in manager_pieces:
				if piece_obj.node.order_number == order:
					found_piece = piece_obj
					break
			
			if found_piece:
				# Restaurar solo posición y flip state primero
				if piece_data.has("current_position"):
					var current_pos_data = piece_data.current_position
					var target_pos = Vector2.ZERO
					
					# Manejar diferentes formatos de posición (Vector2 directo o diccionario)
					if typeof(current_pos_data) == TYPE_DICTIONARY:
						if current_pos_data.has("x") and current_pos_data.has("y"):
							target_pos = Vector2(current_pos_data.x, current_pos_data.y)
					elif typeof(current_pos_data) == TYPE_STRING:
						# Si es string, intentar parsearlo como Vector2
						var vector_string = current_pos_data.strip_edges()
						if vector_string.begins_with("(") and vector_string.ends_with(")"):
							vector_string = vector_string.substr(1, vector_string.length() - 2)
							var parts = vector_string.split(",")
							if parts.size() == 2:
								target_pos = Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges()))
					elif current_pos_data is Vector2:
						target_pos = current_pos_data
					else:
						print("PuzzleGame: Formato de posición desconocido: ", typeof(current_pos_data))
						continue
					
					# Actualizar posición visual
					found_piece.node.global_position = target_pos
					
					# 🔧 CRUCIAL: Actualizar el grid interno del PuzzlePieceManager
					# Primero remover la pieza de su posición anterior en el grid
					if piece_manager:
						piece_manager.remove_piece_at(found_piece.current_cell)
						
						var new_cell = Vector2.ZERO
						
						# 🎯 PRIORIDAD: Usar celda guardada si está disponible (más confiable)
						if piece_data.has("current_cell"):
							var current_cell_data = piece_data.current_cell
							if typeof(current_cell_data) == TYPE_DICTIONARY and current_cell_data.has("x") and current_cell_data.has("y"):
								new_cell = Vector2(current_cell_data.x, current_cell_data.y)
								print("PuzzleGame: Pieza ", order, " - Usando celda guardada: ", new_cell)
							else:
								# Fallback: calcular desde posición
								new_cell = piece_manager.get_cell_of_piece(found_piece)
								print("PuzzleGame: Pieza ", order, " - Calculando celda desde posición: ", new_cell)
						else:
							# Fallback: calcular desde posición (para saves antiguos)
							new_cell = piece_manager.get_cell_of_piece(found_piece)
							print("PuzzleGame: Pieza ", order, " - Calculando celda (save antiguo): ", new_cell)
						
						# Actualizar el grid con la nueva posición
						piece_manager.set_piece_at(new_cell, found_piece)
						
						print("PuzzleGame: Pieza ", order, " posicionada en ", target_pos, " - Grid actualizado a celda ", new_cell)
					else:
						print("PuzzleGame: Pieza ", order, " posicionada en ", target_pos, " - Sin actualización de grid")
				
				if piece_data.has("is_flipped") and found_piece.node.has_method("set_is_flipped"):
					found_piece.node.set_is_flipped(piece_data.is_flipped)
				
				restored_count += 1
			else:
				print("PuzzleGame: ⚠️ No se pudo restaurar pieza con orden ", order)
	
	# Esperar frame después de colocar las piezas
	await get_tree().process_frame
	
	# Ahora restaurar los grupos usando el PuzzlePieceManager
	print("PuzzleGame: Restaurando grupos usando PuzzlePieceManager...")
	var groups_to_restore = {}
	
	# Organizar piezas por grupo
	for piece_data in saved_pieces_data:
		if piece_data.has("group_id") and piece_data.group_id != -1:
			var group_id = piece_data.group_id
			if not groups_to_restore.has(group_id):
				groups_to_restore[group_id] = []
			groups_to_restore[group_id].append(piece_data.get("order_number", -1))
	
	# Restaurar grupos usando el sistema de PuzzlePieceManager
	if piece_manager:
		for group_id in groups_to_restore.keys():
			var orders_in_group = groups_to_restore[group_id]
			if orders_in_group.size() > 1:
				var piece_objects_in_group = []
				
				# Encontrar los objetos Piece correspondientes (reutilizar manager_pieces)
				for order in orders_in_group:
					for piece_obj in manager_pieces:
						if piece_obj.node.order_number == order:
							piece_objects_in_group.append(piece_obj)
							break
				
				# Crear el grupo usando el sistema correcto
				if piece_objects_in_group.size() > 1:
					# Crear un grupo manualmente asignando el mismo array group a todas las piezas
					for piece_obj in piece_objects_in_group:
						piece_obj.group = piece_objects_in_group.duplicate()
						# Actualizar visuales del nodo
						if piece_obj.node.has_method("set_group_id"):
							piece_obj.node.set_group_id(group_id)
						if piece_obj.node.has_method("update_pieces_group"):
							piece_obj.node.update_pieces_group(piece_objects_in_group)
					
					print("PuzzleGame: Grupo ", group_id, " recreado con ", piece_objects_in_group.size(), " piezas")
	else:
		print("PuzzleGame: ⚠️ No se pudo acceder al PuzzlePieceManager para restaurar grupos")
	
	print("PuzzleGame: Estado de piezas restaurado - ", restored_count, "/", saved_pieces_data.size(), " piezas restauradas correctamente")
	
	# Forzar actualización visual después de la restauración
	await get_tree().process_frame
	print("PuzzleGame: Restauración de estado completada")

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

# NUEVO: Función para manejar gestos del borde durante el puzzle
