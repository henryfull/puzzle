# PuzzleGameStateManager.gd
# Manager para gestionar el estado del juego: tiempo, pausa, modos, victoria y derrota

extends Node
class_name PuzzleGameStateManager

# Referencias al juego principal
var puzzle_game: PuzzleGame

# === VARIABLES PARA MODOS DE JUEGO ===
var relax_mode: bool = false
var normal_mode: bool = false
var timer_mode: bool = false
var challenge_mode: bool = false

# Límites y contadores para modos especiales
var flip_count: int = 0
var flip_move_count: int = 0
var max_flips: int = 0
var max_flip_moves: int = 0
var max_moves: int = 0
var time_left: float = 0.0
var defeat_reason: String = ""
var timer_countdown: Timer = null

# Variables para el sistema de pausa
var is_paused: bool = false  # Estado actual de pausa
var is_flip: bool = false # Estado actual del flip
var pause_start_time: float = 0.0  # Momento en que se pausó el juego
var accumulated_time: float = 0.0  # Tiempo acumulado en pausa
var is_options_menu_open: bool = false  # Estado del menú de opciones

# Variables para registro de estadísticas
var start_time: float = 0.0  # Tiempo de inicio en segundos
var elapsed_time: float = 0.0  # Tiempo transcurrido en segundos
var is_timer_active: bool = false  # Para controlar si el temporizador está activo
var total_moves: int = 0

func initialize(game: PuzzleGame):
	puzzle_game = game
	
	# Conectar la señal "options_closed" del OptionsManager para reanudar el juego
	if has_node("/root/OptionsManager"):
		var options_manager = get_node("/root/OptionsManager")
		if !options_manager.is_connected("options_closed", Callable(self, "_on_options_closed")):
			options_manager.connect("options_closed", Callable(self, "_on_options_closed"))
	
	# Timer de guardado eliminado - ahora se guarda solo por acciones del jugador
	# El guardado ocurre cuando el jugador mueve piezas o hace flip
	print("PuzzleGameStateManager: Sistema configurado para guardado por acciones únicamente")

func setup_game_mode():
	# Iniciar el temporizador para medir el tiempo de juego
	start_game_timer()

	# Debug: Mostrar información del modo de juego
	print("PuzzleGameStateManager: Configurando modo de juego - GLOBAL.gamemode: ", GLOBAL.gamemode)
	print("PuzzleGameStateManager: Límites disponibles:")
	print("  - max_moves: ", GLOBAL.puzzle_limits.max_moves)
	print("  - max_flips: ", GLOBAL.puzzle_limits.max_flips)
	print("  - max_flip_moves: ", GLOBAL.puzzle_limits.max_flip_moves)
	print("  - max_time: ", GLOBAL.puzzle_limits.max_time)

	# --- Lógica de modos de juego ---
	match GLOBAL.gamemode:
		0:
			relax_mode = true
			# Ocultar contadores y reloj
			if puzzle_game.has_node("UILayer/TimerLabel"):
				puzzle_game.get_node("UILayer/TimerLabel").visible = false
				puzzle_game.movesLabel.visible = false
				puzzle_game.maxMovesLabel.visible = false
				puzzle_game.maxMovesFlipLabel.visible = false
				puzzle_game.maxFlipsPanel.visible = false
			# Ocultar elementos de puntuación en modo relax
			if puzzle_game.score_label:
				puzzle_game.score_label.visible = false
			if puzzle_game.streak_label:
				puzzle_game.streak_label.visible = false
		1:
			relax_mode = true
			# Ocultar contadores y reloj
			if puzzle_game.has_node("UILayer/TimerLabel"):
				puzzle_game.get_node("UILayer/TimerLabel").visible = false
				puzzle_game.movesLabel.visible = false
				puzzle_game.maxMovesLabel.visible = false
				puzzle_game.maxMovesFlipLabel.visible = false
				puzzle_game.maxFlipsPanel.visible = false
			# Ocultar elementos de puntuación en modo relax
			if puzzle_game.score_label:
				puzzle_game.score_label.visible = false
			if puzzle_game.streak_label:
				puzzle_game.streak_label.visible = false

		2:
			normal_mode = true
			# Mostrar contadores normales
			if puzzle_game.has_node("UILayer/TimerLabel"):
				puzzle_game.get_node("UILayer/TimerLabel").visible = true
				puzzle_game.movesLabel.visible = true
				puzzle_game.maxMovesLabel.visible = false
				puzzle_game.maxMovesFlipLabel.visible = false
				puzzle_game.maxFlipsPanel.visible = false
			# Mostrar elementos de puntuación en modo normal
			if puzzle_game.score_label:
				puzzle_game.score_label.visible = true
			if puzzle_game.streak_label:
				puzzle_game.streak_label.visible = true

		3:
			timer_mode = true
			# Definir tiempo límite
			time_left = GLOBAL.puzzle_limits.max_time
			max_flip_moves = GLOBAL.puzzle_limits.max_flip_moves
			max_flips = GLOBAL.puzzle_limits.max_flips
			flip_move_count = 0
			
			# Mostrar reloj en cuenta atrás
			if puzzle_game.has_node("UILayer/TimerLabel"):
				puzzle_game.get_node("UILayer/TimerLabel").visible = true
				puzzle_game.movesLabel.visible = true
				puzzle_game.maxMovesLabel.visible = false
				puzzle_game.maxMovesFlipLabel.visible = true
				puzzle_game.maxMovesFlipLabel.text = str(max_flip_moves)
				puzzle_game.maxFlipsPanel.visible = true
				puzzle_game.maxFlipsLabel.text = str(max_flips)
			# Mostrar elementos de puntuación en modo contrarreloj
			if puzzle_game.score_label:
				puzzle_game.score_label.visible = true
			if puzzle_game.streak_label:
				puzzle_game.streak_label.visible = true
			# Crear un timer para cuenta atrás
			timer_countdown = Timer.new()
			timer_countdown.wait_time = 1.0
			timer_countdown.one_shot = false
			timer_countdown.connect("timeout", Callable(self, "_on_timer_countdown"))
			puzzle_game.add_child(timer_countdown)
			timer_countdown.start()
		4:
			challenge_mode = true
			max_moves = GLOBAL.puzzle_limits.max_moves
			max_flips = GLOBAL.puzzle_limits.max_flips
			max_flip_moves = GLOBAL.puzzle_limits.max_flip_moves
			
			# Inicializar contadores
			total_moves = 0
			flip_count = 0
			flip_move_count = 0
			
			print("PuzzleGameStateManager: Modo desafío configurado - Max movimientos: ", max_moves, ", Max flips: ", max_flips, ", Max movimientos en flip: ", max_flip_moves)
			
			# Configurar UI inicial con valores correctos
			puzzle_game.maxMovesLabel.text = str(max_moves)
			puzzle_game.maxMovesFlipLabel.text = str(max_flip_moves)
			puzzle_game.maxFlipsLabel.text = str(max_flips)
			
			# Mostrar contadores
			if puzzle_game.has_node("UILayer/TimerLabel"):
				puzzle_game.get_node("UILayer/TimerLabel").visible = true
				puzzle_game.movesLabel.visible = false
				puzzle_game.maxMovesLabel.visible = true
				puzzle_game.maxMovesFlipLabel.visible = true
				puzzle_game.maxFlipsPanel.visible = true
			# Mostrar elementos de puntuación en modo desafío
			if puzzle_game.score_label:
				puzzle_game.score_label.visible = true
			if puzzle_game.streak_label:
				puzzle_game.streak_label.visible = true
	
	# Debug inicial del estado
	debug_flip_state()

# Función para iniciar el temporizador de juego
func start_game_timer():
	start_time = Time.get_unix_time_from_system()
	is_timer_active = true
	accumulated_time = 0.0
	
	# Crear y añadir un timer para actualizar el tiempo transcurrido
	var timer = Timer.new()
	timer.name = "GameTimer"
	timer.wait_time = 1.0  # Actualizar cada segundo
	timer.one_shot = false
	timer.autostart = true
	timer.connect("timeout", Callable(self, "update_elapsed_time"))
	puzzle_game.add_child(timer)
	
	print("PuzzleGameStateManager: Temporizador de juego iniciado")

# Función para actualizar el tiempo transcurrido
func update_elapsed_time():
	if is_timer_active and !is_paused:
		# Calcular el tiempo actual correctamente
		elapsed_time = Time.get_unix_time_from_system() - start_time - accumulated_time
		
		# Actualizar UI si existe
		update_timer_ui()

# Función para detener el temporizador de juego
func stop_game_timer():
	is_timer_active = false
	
	# La última actualización del tiempo transcurrido debe ser correcta
	if is_paused:
		# Si está pausado, usar el tiempo guardado en pause_start_time
		elapsed_time = pause_start_time - start_time - accumulated_time
	else:
		elapsed_time = Time.get_unix_time_from_system() - start_time - accumulated_time
	
	# Detener el timer si existe
	if puzzle_game.has_node("GameTimer"):
		var timer = puzzle_game.get_node("GameTimer")
		timer.stop()
	
	puzzle_game.panelPaused.visible = true
	print("PuzzleGameStateManager: Temporizador de juego detenido. Tiempo total: ", elapsed_time, " segundos")

# Función para actualizar la UI del temporizador (si existe)
func update_timer_ui():
	# Si existe un nodo de UI para mostrar el tiempo, actualizarlo
	var timer_label = puzzle_game.get_node("UILayer/TimerLabel") if puzzle_game.has_node("UILayer/TimerLabel") else null
	
	if timer_label:
		var minutes = int(elapsed_time) / 60
		var seconds = int(elapsed_time) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func handle_notification(what):
	# Control de pausa cuando la ventana pierde el foco
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if !is_paused and is_timer_active and !puzzle_game.puzzle_completed:
			pause_game()
			print("PuzzleGameStateManager: Juego pausado por pérdida de foco")
	
	# Reanudar el juego cuando la ventana vuelve a tener foco
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if is_paused and !is_options_menu_open and !puzzle_game.puzzle_completed:
			resume_game()
			print("PuzzleGameStateManager: Juego reanudado por recuperación de foco")

# Función para pausar el juego
func pause_game():
	if is_paused or puzzle_game.puzzle_completed:
		return
		
	is_paused = true
	pause_start_time = Time.get_unix_time_from_system()
	puzzle_game.panelPaused.visible = true
	
	# Guardar el tiempo transcurrido en el momento de la pausa
	elapsed_time = pause_start_time - start_time - accumulated_time
	
	# Pausar el temporizador manteniendo el estado actual
	if puzzle_game.has_node("GameTimer"):
		var timer = puzzle_game.get_node("GameTimer")
		timer.paused = true
	
	# Guardar estado al pausar (acción del jugador)
	_save_state_on_player_action("pausar juego")
	
	print("PuzzleGameStateManager: Juego pausado en tiempo:", elapsed_time)

# Función para reanudar el juego
func resume_game():
	if !is_paused or puzzle_game.puzzle_completed:
		return
		
	# Calcular el tiempo que estuvo en pausa
	var current_time = Time.get_unix_time_from_system()
	var pause_duration = current_time - pause_start_time
	
	# Acumular tiempo de pausa
	accumulated_time += pause_duration
	
	is_paused = false
	
	# Reanudar el temporizador
	if puzzle_game.has_node("GameTimer"):
		var timer = puzzle_game.get_node("GameTimer")
		timer.paused = false
	
	# Guardar estado al reanudar (acción del jugador)
	_save_state_on_player_action("reanudar juego")
	
	# Mostrar mensaje de reanudación
	puzzle_game.panelPaused.visible = false
	
	print("PuzzleGameStateManager: Juego reanudado después de ", pause_duration, " segundos en pausa. Tiempo acumulado en pausa:", accumulated_time)

# Función para manejar el cierre del menú de opciones
func _on_options_closed():
	is_options_menu_open = false
	if is_paused and !puzzle_game.puzzle_completed:
		resume_game()

# --- Timer de cuenta atrás para modo contrarreloj ---
func _on_timer_countdown():
	if timer_mode:
		time_left -= 1.0
		# Actualizar el label del reloj
		if puzzle_game.has_node("UILayer/TimerLabel"):
			var timer_label = puzzle_game.get_node("UILayer/TimerLabel")
			var minutes = int(time_left) / 60
			var seconds = int(time_left) % 60
			timer_label.text = "%02d:%02d" % [minutes, seconds]
		if time_left <= 0:
			timer_countdown.stop()
			defeat_reason = "Tiempo agotado"
			_show_defeat_message(defeat_reason)

# --- Lógica de movimientos y flips ---
func increment_move_count():
	total_moves += 1
	print("PuzzleGameStateManager: Incrementando movimientos. Total: ", total_moves, " - Modo flip activo: ", is_flip)
	
	# Notificar al score manager sobre movimiento inválido si es aplicable
	# Esto se maneja desde el piece manager cuando detecta movimientos inválidos
	
	# Actualizar UI de movimientos normales
	if puzzle_game.movesLabel:
		puzzle_game.movesLabel.text = str(total_moves)
		
	# En modo desafío, mostrar movimientos restantes
	if challenge_mode and max_moves > 0:
		var remaining_moves = max_moves - total_moves
		if puzzle_game.maxMovesLabel.visible:
			puzzle_game.maxMovesLabel.text = str(remaining_moves)
		print("PuzzleGameStateManager: Movimientos restantes en desafío: ", remaining_moves)
		
		# Verificar derrota por movimientos
		if total_moves >= max_moves:
			defeat_reason = "Límite de movimientos alcanzado"
			_show_defeat_message(defeat_reason)
			return
	
	# Si estamos en modo flip, incrementar contador de movimientos en flip
	if is_flip:
		print("PuzzleGameStateManager: ✅ Movimiento realizado en modo flip - Incrementando flip_move_count")
		_increment_flip_move_count()
	else:
		print("PuzzleGameStateManager: ⚪ Movimiento realizado en modo normal")
	
	# NUEVO: Guardar estado por acción del jugador (mover pieza)
	_save_state_on_player_action("movimiento de pieza")
	
	# Debug del estado actual después del movimiento
	debug_flip_state()

func _increment_flip_count():
	flip_count += 1
	print("PuzzleGameStateManager: 🔄 Incrementando flips. Total: ", flip_count, " - Activando modo flip")
	
	# Actualizar UI de flips en modos que lo requieren
	if (timer_mode or challenge_mode) and max_flips > 0:
		var remaining_flips = max_flips - flip_count
		if puzzle_game.maxFlipsLabel:
			puzzle_game.maxFlipsLabel.text = str(remaining_flips)
		print("PuzzleGameStateManager: Flips restantes: ", remaining_flips)
		
		# Nota: Ya no se termina el juego al alcanzar el límite de flips
		# El jugador simplemente no puede incrementar más el contador
	
	# NUEVO: Guardar estado por acción del jugador (flip)
	_save_state_on_player_action("flip de piezas")

func _increment_flip_move_count():
	flip_move_count += 1
	print("PuzzleGameStateManager: 🔄 Incrementando movimientos en flip. Total: ", flip_move_count, " (is_flip=", is_flip, ")")
	
	# Actualizar UI de movimientos en flip
	if (timer_mode or challenge_mode) and max_flip_moves > 0:
		var remaining_flip_moves = max_flip_moves - flip_move_count
		if puzzle_game.maxMovesFlipLabel:
			puzzle_game.maxMovesFlipLabel.text = str(remaining_flip_moves)
		print("PuzzleGameStateManager: Movimientos en flip restantes: ", remaining_flip_moves)
		
		# Verificar derrota por límite de movimientos en flip
		if flip_move_count >= max_flip_moves:
			defeat_reason = "Límite de movimientos en flip alcanzado"
			_show_defeat_message(defeat_reason)

# Función para verificar y debuggear el estado del flip
func debug_flip_state():
	print("PuzzleGameStateManager: [DEBUG] Estado actual:")
	print("  - is_flip: ", is_flip)
	print("  - flip_count: ", flip_count)
	print("  - flip_move_count: ", flip_move_count)
	print("  - total_moves: ", total_moves)
	print("  - timer_mode: ", timer_mode)
	print("  - challenge_mode: ", challenge_mode)

# --- Mensaje temporal de derrota ---
func _show_defeat_message(reason: String):
	# Preparar los datos de derrota para enviar a la pantalla de derrota
	var defeat_data = {
		"total_moves": total_moves,
		"elapsed_time": elapsed_time,
		"flip_count": flip_count,
		"flip_move_count": flip_move_count,
		"reason": reason,
		"scene_path": "res://Scenes/PuzzleGame.tscn"
	}
	GLOBAL.defeat_data = defeat_data

	# Cambiar a la pantalla de derrota
	GLOBAL.change_scene_with_loading("res://Scenes/DefeatScreen/DefeatScreen.tscn")

	# Pausar el juego y detener timers (por si acaso)
	is_paused = true
	if timer_countdown:
		timer_countdown.stop()
	stop_game_timer()

# Funciones para VictoryChecker
func get_current_game_state_for_victory() -> Dictionary:
	return {
		"total_moves": total_moves,
		"elapsed_time": elapsed_time,
		"current_pack_id": puzzle_game.current_pack_id,
		"current_puzzle_id": puzzle_game.current_puzzle_id,
		"flip_count": flip_count,
		"flip_move_count": flip_move_count,
		"relax_mode": relax_mode,
		"normal_mode": normal_mode,
		"timer_mode": timer_mode,
		"challenge_mode": challenge_mode
	}

# Función para reiniciar el puzzle
func restart_puzzle():
	print("PuzzleGameStateManager: Reiniciando puzzle con dificultad original " + str(puzzle_game.default_columns) + "x" + str(puzzle_game.default_rows))
	
	# 🔧 CRÍTICO: Limpiar completamente el estado guardado para forzar posiciones aleatorias nuevas
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager:
		print("PuzzleGameStateManager: Limpiando estado guardado para generar posiciones aleatorias nuevas")
		puzzle_state_manager.clear_all_state()
	
	# Resetear contadores del juego a cero
	total_moves = 0
	elapsed_time = 0.0
	flip_count = 0
	flip_move_count = 0
	is_flip = false
	
	# Resetear timers si existen
	if timer_countdown:
		timer_countdown.stop()
	stop_game_timer()
		
	# Esperar un momento antes de reiniciar el puzzle
	await puzzle_game.get_tree().create_timer(0.5).timeout
	
	# Limpiar las piezas actuales
	var pieces = puzzle_game.piece_manager.get_pieces()
	for piece_obj in pieces:
		if piece_obj.node != null:
			piece_obj.node.queue_free()
	
	# Limpiar las listas en el piece manager
	puzzle_game.piece_manager.grid.clear()
	puzzle_game.piece_manager.pieces.clear()
	
	# 🔧 IMPORTANTE: Resetear también variables de expansión para empezar desde cero
	puzzle_game.piece_manager.extra_rows_added = 0
	puzzle_game.piece_manager.rows_added_top = 0
	puzzle_game.piece_manager.current_rows = puzzle_game.default_rows
	puzzle_game.piece_manager.current_columns = puzzle_game.default_columns
	

	# Si falla la generación de la textura trasera, recargamos la escena
	print("PuzzleGameStateManager: Error al generar textura trasera, recargando escena...")
	puzzle_game.get_tree().reload_current_scene()

# Función para manejar gestos de 'volver atrás'
func handle_back_gesture() -> bool:
	print("PuzzleGameStateManager: Manejando gesto de volver atrás en puzzle activo")
	
	# Si el puzzle está completado, permitir que el gesto funcione normalmente
	if puzzle_game.puzzle_completed:
		return false  # Usar comportamiento por defecto (salir del puzzle)
	
	# Si el puzzle está activo (no completado), mostrar diálogo de confirmación
	# solo si hay un timer activo, de lo contrario simplemente ignorar el gesto
	if is_timer_active:
		puzzle_game.ui_manager.show_exit_dialog()
	
	# Siempre devolver true para evitar que se salga automáticamente del puzzle
	# cuando el jugador está jugando activamente
	return true  # Bloquear el comportamiento por defecto

# Función para mostrar el menú de opciones
func show_options_menu():
	if !is_paused:
		pause_game()

# Función para actualizar el estado guardado del puzzle
func _update_puzzle_state():
	if puzzle_game and puzzle_game.has_method("_update_saved_state"):
		puzzle_game._update_saved_state() 

# Nueva función para guardar estado por acción del jugador
func _save_state_on_player_action(action_type: String):
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager:
		# Actualizar contadores en el estado antes de guardar
		puzzle_state_manager.update_counters(elapsed_time, total_moves, flip_count, flip_move_count, time_left)
		
		# Sincronizar contadores de flip entre sistemas
		if puzzle_game.score_manager:
			puzzle_state_manager.sync_flip_counters_from_game_state(self, puzzle_game.score_manager)
		
		# Actualizar datos de puntuación si existe el score manager
		if puzzle_game.score_manager:
			puzzle_state_manager.update_score_data(puzzle_game.score_manager)
		
		# Actualizar posiciones de piezas desde el piece manager
		if puzzle_game.piece_manager:
			puzzle_state_manager.update_pieces_positions_from_manager(puzzle_game.piece_manager)
		
		# Guardar por acción específica
		puzzle_state_manager.save_on_player_action(action_type) 
