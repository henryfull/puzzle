# PuzzleUIManager.gd
# Manager para gestionar la interfaz de usuario, mensajes y elementos visuales

extends Node
class_name PuzzleUIManager

# Referencias al juego principal
var puzzle_game: Node2D

# Variables para el estado del HUD
var hud_visible: bool = true

# Variables para la UI de puntuación dinámicas eliminadas
# Los elementos de puntuación ahora están directamente en el UILayer

func initialize(game: Node2D):
	puzzle_game = game
	# Ya no necesitamos crear dinámicamente la UI de puntuación
	# Los elementos están directamente en el UILayer de la escena

# Función para mostrar mensaje de éxito
func show_success_message(message: String, duration: float = 1.5):
	var label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))  # Verde claro
	
	# Ajustar tamaño de fuente para dispositivos móviles
	if puzzle_game.is_mobile:
		label.add_theme_font_size_override("font_size", 28)
	else:
		label.add_theme_font_size_override("font_size", 18)
	
	# Posicionar en la parte superior de la pantalla
	var viewport_size = puzzle_game.get_viewport_rect().size
	
	# Centrar horizontalmente y ajustar el ancho para que quepa el texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size.x = viewport_size.x * 0.8
	label.position.x = viewport_size.x * 0.1
	label.position.y = 60
	
	# Añadir a la escena
	puzzle_game.add_child(label)
	
	# Crear un temporizador para eliminar el mensaje después del tiempo especificado
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.connect("timeout", Callable(label, "queue_free"))
	puzzle_game.add_child(timer)
	timer.start()

# Función para mostrar mensaje de error
func show_error_message(message: String, duration: float = 2.0):
	var label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Rojo claro
	
	# Ajustar tamaño de fuente para dispositivos móviles
	if puzzle_game.is_mobile:
		label.add_theme_font_size_override("font_size", 28)
	else:
		label.add_theme_font_size_override("font_size", 18)
	
	# Posicionar en la parte superior de la pantalla
	var viewport_size = puzzle_game.get_viewport_rect().size
	
	# Centrar horizontalmente y ajustar el ancho para que quepa el texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size.x = viewport_size.x * 0.8
	label.position.x = viewport_size.x * 0.1
	label.position.y = 60
	
	# Añadir a la escena
	puzzle_game.add_child(label)
	
	# Crear un temporizador para eliminar el mensaje después del tiempo especificado
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.connect("timeout", Callable(label, "queue_free"))
	puzzle_game.add_child(timer)
	timer.start()

# Función para mostrar diálogo de salida (abre menú de pausa)
func show_exit_dialog():
	GLOBAL.change_scene_direct("res://Scenes/PuzzleSelection.tscn")

# Función para manejar el botón de flip
func on_flip_button_pressed():
	print("PuzzleUIManager: 🔄 Botón de flip presionado")
	puzzle_game.game_state_manager.debug_flip_state()
	
	# Obtener información sobre límites de flips
	var max_flips = puzzle_game.game_state_manager.max_flips
	var current_flips = puzzle_game.game_state_manager.flip_count
	var is_currently_flipped = puzzle_game.game_state_manager.is_flip
	
	# Verificar si estamos en modo flip actualmente
	if is_currently_flipped:
		print("PuzzleUIManager: 🔄 Modo flip activo - Revirtiendo a normal sin contar flip")
		_revert_flip_to_normal()
		puzzle_game.play_flip_sound()
		puzzle_game.game_state_manager.is_flip = false
		return
	elif !is_currently_flipped and current_flips >= max_flips and (puzzle_game.game_state_manager.timer_mode or puzzle_game.game_state_manager.challenge_mode):
		# Solo bloquear en modos limitados cuando se alcance el límite
		print("PuzzleUIManager: ❌ Flip bloqueado en modo limitado - límite alcanzado")
		show_error_message("No puedes realizar más flips (" + str(current_flips) + "/" + str(max_flips) + ")", 2.0)
		return
	
	puzzle_game.game_state_manager.is_flip = true
	_cancel_flip_timers()
	puzzle_game.play_flip_sound()
	# Variable para rastrear si encontramos una pieza seleccionada
	var target_piece = null
	
	# Primero intentamos encontrar una pieza que esté siendo arrastrada
	var pieces = puzzle_game.piece_manager.get_pieces()
	for piece_obj in pieces:
		if piece_obj.dragging:
			target_piece = piece_obj
			break
	
	# PASO 1: Verificar si podemos incrementar el contador de flips
	# Solo aplicar límites en modo desafío o contrarreloj
	var can_increment_flip = true
	var is_limited_mode = puzzle_game.game_state_manager.timer_mode or puzzle_game.game_state_manager.challenge_mode
	
	if is_limited_mode and max_flips > 0 and current_flips >= max_flips:
		can_increment_flip = false
		print("PuzzleUIManager: ⚠️ Límite de flips alcanzado en modo limitado, pero permitiendo flip visual sin incrementar contador")
	elif not is_limited_mode:
		print("PuzzleUIManager: ✅ Modo sin límites - Flip permitido sin restricciones")
	
	# Solo incrementar contador si no hemos alcanzado el límite (o si estamos en modo sin límites)
	if can_increment_flip and !is_currently_flipped:
		print("PuzzleUIManager: ✅ Incrementando contador de flips: ", current_flips, " -> ", current_flips + 1)
		puzzle_game.game_state_manager._increment_flip_count()
	
	# PASO 2: Crear la animación de flip
	var tween = puzzle_game.create_tween()
	var pieces_to_flip = []
	
	# Determinar qué piezas voltear
	if target_piece == null:
		# Si no hay pieza seleccionada, voltear todas las piezas
		pieces_to_flip = pieces
	else:
		# Si hay una pieza seleccionada, voltear solo su grupo
		pieces_to_flip = target_piece.group
	
	# Realizar la animación de flip
	for piece_obj in pieces_to_flip:
		if piece_obj.node.has_method("flip_piece"):
			# Animar la escala para dar efecto de volteo
			tween.parallel().tween_property(piece_obj.node, "scale", Vector2(0, 1), puzzle_game.piece_manager.flip_speed)
			
			# A la mitad de la animación, cambiar la textura
			tween.tween_callback(func():
				piece_obj.node.flip_piece()
				# Actualizar los colores después del flip
				if piece_obj.node.has_method("update_all_visuals"):
					piece_obj.node.update_all_visuals()
			).set_delay(puzzle_game.piece_manager.flip_speed)
			
			# Restaurar la escala
			tween.parallel().tween_property(piece_obj.node, "scale", Vector2(1, 1), puzzle_game.piece_manager.flip_speed).set_delay(puzzle_game.piece_manager.flip_speed)
	
	# PASO 3: Activar modo flip DESPUÉS de que termine la animación
	# Usar un delay fijo de 0.5 segundos para asegurar que la animación termine
	tween.tween_callback(func():
		print("PuzzleUIManager: ⏰ Activando modo flip para contar movimientos")
		
		# Debug del estado después de activar flip
		puzzle_game.game_state_manager.debug_flip_state()
		
		# Crear timer para el modo flip
		var flip_timer = Timer.new()
		flip_timer.name = "FlipModeTimer"
		flip_timer.wait_time = 15.0  # Mantener el modo flip por 15 segundos (más tiempo)
		flip_timer.one_shot = true
		flip_timer.connect("timeout", Callable(self, "_on_flip_timer_timeout").bind(flip_timer))
		puzzle_game.add_child(flip_timer)
		flip_timer.start()
		
		print("PuzzleUIManager: Modo flip activo por 15 segundos para contar movimientos")
		
		# Mostrar mensaje visual indicando que el modo flip está activo

	).set_delay(0.5)  # Delay fijo de medio segundo para asegurar que termine la animación

# Función para revertir flip a normal sin contar un flip adicional
func _revert_flip_to_normal():
	print("PuzzleUIManager: 🔄 Revirtiendo flip a normal sin contar flip adicional")
	
	# Variable para rastrear si encontramos una pieza seleccionada
	var target_piece = null
	
	# Primero intentamos encontrar una pieza que esté siendo arrastrada
	var pieces = puzzle_game.piece_manager.get_pieces()
	for piece_obj in pieces:
		if piece_obj.dragging:
			target_piece = piece_obj
			break
	
	# Crear la animación de flip (de vuelta a normal)
	var tween = puzzle_game.create_tween()
	var pieces_to_flip = []
	
	# Determinar qué piezas voltear
	if target_piece == null:
		# Si no hay pieza seleccionada, voltear todas las piezas
		pieces_to_flip = pieces
	else:
		# Si hay una pieza seleccionada, voltear solo su grupo
		pieces_to_flip = target_piece.group
	
	# Realizar la animación de flip (volver a normal)
	for piece_obj in pieces_to_flip:
		if piece_obj.node.has_method("flip_piece"):
			# Animar la escala para dar efecto de volteo
			tween.parallel().tween_property(piece_obj.node, "scale", Vector2(0, 1), puzzle_game.piece_manager.flip_speed)
			
			# A la mitad de la animación, cambiar la textura
			tween.tween_callback(func():
				piece_obj.node.flip_piece()
				# Actualizar los colores después del flip
				if piece_obj.node.has_method("update_all_visuals"):
					piece_obj.node.update_all_visuals()
			).set_delay(puzzle_game.piece_manager.flip_speed)
			
			# Restaurar la escala
			tween.parallel().tween_property(piece_obj.node, "scale", Vector2(1, 1), puzzle_game.piece_manager.flip_speed).set_delay(puzzle_game.piece_manager.flip_speed)
	
	# Desactivar modo flip DESPUÉS de que termine la animación
	tween.tween_callback(func():
		print("PuzzleUIManager: ⏰ Desactivando modo flip después de revertir")
		puzzle_game.game_state_manager.debug_flip_state()
		
		# Cancelar cualquier timer de flip activo
		_cancel_flip_timers()
		
		# Mostrar mensaje visual
		# show_success_message("Vuelto a normal - Modo Flip Desactivado", 2.0)
	).set_delay(0.5)  # Delay fijo de medio segundo para asegurar que termine la animación

# Función llamada cuando expira el timer de flip
func _on_flip_timer_timeout(flip_timer: Timer = null):
	print("PuzzleUIManager: Desactivando modo flip por timeout")
	puzzle_game.game_state_manager.is_flip = false
	puzzle_game.game_state_manager.debug_flip_state()
	if flip_timer and is_instance_valid(flip_timer):
		flip_timer.queue_free()
	# show_success_message("Modo Flip Desactivado", 1.5)

# Función auxiliar para cancelar todos los timers de flip activos
func _cancel_flip_timers():
	print("PuzzleUIManager: Cancelando timers de flip activos")
	for child in puzzle_game.get_children():
		if child is Timer and child.name == "FlipModeTimer":
			child.stop()
			child.queue_free()
			print("PuzzleUIManager: Timer de flip cancelado")

# Función para desactivar manualmente el modo flip
func deactivate_flip_mode():
	print("PuzzleUIManager: Desactivando modo flip manualmente")
	puzzle_game.game_state_manager.is_flip = false
	puzzle_game.game_state_manager.debug_flip_state()
	# show_success_message("Modo Flip Desactivado", 1.5)
	
	# Usar la función auxiliar para cancelar timers
	_cancel_flip_timers()

# Función para alternar HUD
func toggle_hud():
	hud_visible = !hud_visible
	
	# Obtener referencias a los botones de HUD
	var hide_button = puzzle_game.get_node_or_null("BackgroundLayer/ButtonHideHUD")
	var show_button = puzzle_game.get_node_or_null("BackgroundLayer/ButtonShowHUD")
	var ui_layer = puzzle_game.get_node_or_null("UILayer")
	
	if hud_visible:
		# Mostrar HUD
		if ui_layer:
			ui_layer.visible = true
		if hide_button:
			hide_button.visible = true
		if show_button:
			show_button.visible = false
		# show_success_message("HUD Mostrado", 1.0)
	else:
		# Ocultar HUD
		if ui_layer:
			ui_layer.visible = false
		if hide_button:
			hide_button.visible = false
		if show_button:
			show_button.visible = true
		# show_success_message("HUD Oculto", 1.0)

# === FUNCIONES DE INTERFAZ DE PUNTUACIÓN ===
# NOTA: Las funciones de UI de puntuación han sido movidas a PuzzleGame.gd
# ya que los elementos ahora están integrados directamente en el UILayer de la escena

# Estas funciones ahora son manejadas directamente por PuzzleGame:
# - _on_score_updated() 
# - _on_streak_updated()
# - _on_bonus_applied()
# - hide_score_ui() / show_score_ui()
# 
# Los elementos ScoreLabel y StreakLabel están en la escena y se actualizan
# automáticamente a través de las señales conectadas en PuzzleGame._connect_score_ui_signals() 
