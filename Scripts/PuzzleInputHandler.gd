# PuzzleInputHandler.gd
# Manager para gestionar todos los eventos de entrada (mouse, touch, drag & drop, etc.)

extends Node
class_name PuzzleInputHandler

# Referencias al juego principal
var puzzle_game: PuzzleGame
var piece_manager: PuzzlePieceManager

# Variables para gestionar el doble toque
var last_touch_time: float = 0.0
var double_tap_threshold: float = 0.3  # Tiempo en segundos para considerar un doble tap
var last_touch_position: Vector2 = Vector2.ZERO
var double_tap_distance_threshold: float = 50.0  # Distancia máxima para considerar un doble tap

# Variables para gestionar el triple toque (reorganizar piezas)
var touch_count: int = 0
var last_triple_tap_time: float = 0.0
var triple_tap_threshold: float = 0.5  # Tiempo para considerar un triple tap

# Variables para el paneo del tablero
var is_panning := false
var last_pan_position := Vector2.ZERO
var board_offset := Vector2.ZERO  # Desplazamiento actual del tablero
var touch_points := {}  # Para rastrear múltiples puntos de contacto en táctil
var pan_sensitivity: float = 1.0  # Sensibilidad del desplazamiento

func initialize(game: PuzzleGame):
	puzzle_game = game
	piece_manager = game.piece_manager
	
	# IMPORTANTE: Inicializar board_offset en Vector2.ZERO para respetar el centrado
	# El centrado se maneja en PuzzlePieceManager con puzzle_offset
	board_offset = Vector2.ZERO
	
	load_user_preferences()

func _handle_keyboard_input(event: InputEventKey):
	# Alternar límites visuales con tecla 'B' (Borders)
	if event.keycode == KEY_B:
		var current_visibility = true
		if piece_manager.border_areas.size() > 0:
			current_visibility = piece_manager.border_areas[0].visible
		piece_manager.toggle_visual_borders(!current_visibility)
		var status = "mostrados" if !current_visibility else "ocultados"
		puzzle_game.show_success_message("Límites " + status, 1.0)
	
	# DEBUG: Tecla 'C' para forzar recentrado completo
	elif event.keycode == KEY_C and OS.is_debug_build():
		puzzle_game.force_complete_recenter()
	
	# DEBUG: Tecla 'D' para ejecutar diagnóstico
	elif event.keycode == KEY_D and OS.is_debug_build():
		puzzle_game.run_positioning_diagnosis()
	
	# DEBUG: Tecla 'R' para resetear solo InputHandler
	elif event.keycode == KEY_R and OS.is_debug_build():
		reset_board_to_center()
	
	# 🎯 DEBUG: Teclas para ajustar el retraso del centrado automático
	elif event.keycode == KEY_PLUS or event.keycode == KEY_KP_ADD and OS.is_debug_build():
		var new_delay = piece_manager.get_auto_center_delay() + 0.2
		piece_manager.set_auto_center_delay(new_delay)
		puzzle_game.show_success_message("⏰ Retraso aumentado a " + str(new_delay) + "s", 2.0)
	
	elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT and OS.is_debug_build():
		var new_delay = max(0.0, piece_manager.get_auto_center_delay() - 0.2)
		piece_manager.set_auto_center_delay(new_delay)
		puzzle_game.show_success_message("⏰ Retraso reducido a " + str(new_delay) + "s", 2.0)
	
	# DEBUG: Tecla 'T' para mostrar el retraso actual
	elif event.keycode == KEY_T and OS.is_debug_build():
		var current_delay = piece_manager.get_auto_center_delay()
		puzzle_game.show_success_message("⏰ Retraso actual: " + str(current_delay) + "s", 3.0)

func handle_input(event: InputEvent) -> void:
	# Manejo de teclas especiales
	if event is InputEventKey and event.pressed:
		_handle_keyboard_input(event)
	
	# Manejo de eventos táctiles para dispositivos móviles
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	# Manejo de eventos de ratón para PC
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_screen_touch(event: InputEventScreenTouch):
	# Detectar múltiples toques (doble y triple)
	if event.pressed:
		var current_time = Time.get_ticks_msec() / 1000.0
		var time_diff = current_time - last_touch_time
		var position_diff = event.position.distance_to(last_touch_position)
		
		# Reiniciar contador si ha pasado demasiado tiempo
		if time_diff > triple_tap_threshold:
			touch_count = 0
		
		# Incrementar contador de toques si están cerca en tiempo y posición
		if time_diff < triple_tap_threshold and position_diff < double_tap_distance_threshold:
			touch_count += 1
		else:
			touch_count = 1
		
		# Guardar tiempo y posición para el próximo toque
		last_touch_time = current_time
		last_touch_position = event.position
		
		# Procesar según el número de toques
		if touch_count == 2:
			# Es un doble tap, centrar el puzzle
			print("PuzzleInputHandler: Doble tap detectado - Centrando puzzle...")
			puzzle_game.force_complete_recenter()
			puzzle_game.show_success_message("🎯 Puzzle centrado con doble tap", 2.0)
		elif touch_count == 3:
			# Es un triple tap, reorganizar las piezas que están fuera del área del puzzle
			print("PuzzleInputHandler: Triple tap detectado - Reorganizando piezas...")
			piece_manager.reorganize_pieces()
			puzzle_game.show_success_message("🔄 Piezas reorganizadas con triple tap", 2.0)
			# Reiniciar contador después del triple tap
			touch_count = 0
	
	# Guardamos la información del toque en nuestro diccionario
	if event.pressed:
		touch_points[event.index] = event.position
	else:
		touch_points.erase(event.index)
		
	# Para paneo en dispositivos móviles necesitamos DOS dedos
	if puzzle_game.is_mobile:
		if touch_points.size() >= 2 and event.pressed:
			# Iniciar paneo con dos dedos
			is_panning = true
			# Usamos el punto medio entre los dos dedos como punto de referencia
			last_pan_position = get_touch_center()
		elif touch_points.size() < 2:
			# Si hay menos de dos dedos, terminar el paneo
			is_panning = false
	
	# Si es un solo dedo, procesamos como un evento normal de clic de pieza
	if touch_points.size() == 1 and puzzle_game.is_mobile:
		if event.pressed:
			# Debemos pasar la posición específica del evento de toque, no el evento genérico
			process_piece_click_touch(event.position, event.index)
		else:
			process_piece_release()

func _handle_screen_drag(event: InputEventScreenDrag):
	# Actualizar la posición del punto de contacto
	touch_points[event.index] = event.position
	
	# Para paneo en dispositivos móviles necesitamos DOS dedos
	if puzzle_game.is_mobile and touch_points.size() >= 2 and is_panning:
		# En lugar de usar el centro de los dedos, usamos directamente la posición del dedo 
		# que se está moviendo, lo que da un control más directo
		var current_pos = event.position
		
		# El delta es exactamente el movimiento real del dedo
		var delta = event.relative
		
		# Aplicamos directamente el delta del movimiento del dedo, manteniendo
		# la misma dirección que el gesto del usuario, pero ajustando por la sensibilidad
		board_offset += delta * pan_sensitivity
		
		last_pan_position = current_pos
		update_board_position()
	
	# Si estamos arrastrando con un solo dedo y no estamos en modo paneo, mover piezas
	elif puzzle_game.is_mobile and touch_points.size() == 1 and not is_panning:
		# Procesar como arrastre de pieza
		var pieces = piece_manager.get_pieces()
		for piece_obj in pieces:
			if piece_obj.dragging:
				var group_leader = piece_manager.get_group_leader(piece_obj)
				
				# En lugar de usar event.relative, calculamos la nueva posición basada
				# en la posición actual del dedo y el offset guardado al comenzar el arrastre
				var touch_pos = event.position
				
				for p in group_leader.group:
					# Aplicar la nueva posición con el offset original
					p.node.global_position = touch_pos + p.drag_offset
					
					# Asegurar que la pieza tenga el z-index adecuado 
					# mientras se está arrastrando
					if p.node.has_method("set_dragging"):
						p.node.set_dragging(true)
					
					# Si la pieza tiene padre, asegurarse de que esté al frente
					if p.node.get_parent() != null:
						p.node.get_parent().move_child(p.node, p.node.get_parent().get_child_count() - 1)
				
				break

func _handle_mouse_button(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_RIGHT:  # Botón derecho para paneo en PC
		if event.pressed:
			# Iniciar paneo con botón derecho
			is_panning = true
			last_pan_position = event.position
		else:
			# Finalizar paneo
			is_panning = false
	
	# Manejo de doble clic para reorganizar piezas que están fuera del área del puzzle
	# elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
	# 	piece_manager.reorganize_pieces()
	
	# Manejo de click izquierdo para las piezas
	elif event.button_index == MOUSE_BUTTON_LEFT:
		process_piece_click(event)

func _handle_mouse_motion(event: InputEventMouseMotion):
	if is_panning:
		# Actualizar posición del tablero durante el paneo
		var delta = event.relative
		# Aplicar la sensibilidad al desplazamiento
		board_offset += delta * pan_sensitivity
		last_pan_position = event.position
		update_board_position()
	elif event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		# Si estamos arrastrando una pieza
		var pieces = piece_manager.get_pieces()
		for piece_obj in pieces:
			if piece_obj.dragging:
				var group_leader = piece_manager.get_group_leader(piece_obj)
				var delta = event.relative
				for p in group_leader.group:
					p.node.global_position += delta
					
					# Asegurar que la pieza tenga el z-index adecuado 
					# mientras se está arrastrando
					if p.node.has_method("set_dragging"):
						p.node.set_dragging(true)
						
					# Asegurar que la pieza esté al frente moviendo su nodo al final del árbol
					if p.node.get_parent() != null:
						p.node.get_parent().move_child(p.node, p.node.get_parent().get_child_count() - 1)
				break

func update_board_position() -> void:
	# NUEVO: Respetar el centrado inicial del puzzle
	# El board_offset debe ser ADICIONAL al centrado que ya se calculó en PuzzlePieceManager
	
	var pieces_container = puzzle_game.pieces_container
	if pieces_container:
		# Aplicar el board_offset como desplazamiento adicional desde la posición centrada (Vector2.ZERO)
		pieces_container.position = board_offset
	else:
		puzzle_game.position = board_offset
	
	# Limitar el desplazamiento para que el tablero no se aleje demasiado
	var viewport_size = puzzle_game.get_viewport_rect().size
	var puzzle_data = puzzle_game.get_puzzle_data()
	var board_size = Vector2(puzzle_data.width, puzzle_data.height)
	
	# Calcular límites de desplazamiento más conservadores para mantener el puzzle visible
	var margin = 200.0  # Margen mayor para mantener el puzzle más centrado
	var min_x = -board_size.x * 0.3  # Permitir desplazamiento limitado
	var max_x = board_size.x * 0.3
	var min_y = -board_size.y * 0.3
	var max_y = board_size.y * 0.3
	
	# Limitar el desplazamiento con límites más estrictos
	if pieces_container:
		pieces_container.position.x = clamp(pieces_container.position.x, min_x, max_x)
		pieces_container.position.y = clamp(pieces_container.position.y, min_y, max_y)
	else:
		puzzle_game.position.x = clamp(puzzle_game.position.x, min_x, max_x)
		puzzle_game.position.y = clamp(puzzle_game.position.y, min_y, max_y)
	
	# Actualizar el board_offset para reflejar la posición ajustada
	board_offset = pieces_container.position if pieces_container else puzzle_game.position
	
	# Debug información
	if OS.is_debug_build():
		print("PuzzleInputHandler: board_offset=", board_offset, ", container_pos=", pieces_container.position if pieces_container else "N/A")

func process_piece_click_touch(touch_position: Vector2, touch_index: int) -> void:
	# Usar la posición del toque sin ajustar
	var mouse_pos = touch_position
	var clicked_piece = null
	
	# Encontrar la pieza clickeada
	var pieces = piece_manager.get_pieces()
	for piece_obj in pieces:
		# Convertir la posición global del toque a local de cada pieza
		var local_pos = piece_obj.node.to_local(mouse_pos)
		var sprite = piece_obj.sprite
		
		# Verificar si el punto está dentro del sprite
		if sprite.texture != null:
			var tex_rect = Rect2(
				sprite.position - sprite.texture.get_size() * sprite.scale * 0.5,
				sprite.texture.get_size() * sprite.scale
			)
			
			if tex_rect.has_point(local_pos):
				clicked_piece = piece_obj
				break
	
	if clicked_piece:
		# Obtener el líder del grupo
		var group_leader = piece_manager.get_group_leader(clicked_piece)
		
		# Guardar las posiciones originales de cada pieza del grupo antes de comenzar a arrastrar
		for p in group_leader.group:
			# Almacenamos la celda actual como punto de referencia para volver si es necesario
			p.drag_start_cell = p.current_cell
		
		# Mover todo el grupo desde cualquier pieza
		for p in group_leader.group:
			p.dragging = true
			# Guardar el offset (diferencia entre posición de la pieza y posición del toque)
			p.drag_offset = p.node.global_position - mouse_pos
			
			# Usar el nuevo método set_dragging para cambiar el z-index
			if p.node.has_method("set_dragging"):
				p.node.set_dragging(true)
			else:
				p.node.z_index = 9999
				
			# Asegurar que la pieza esté al frente moviendo su nodo al final del árbol
			if p.node.get_parent() != null:
				p.node.get_parent().move_child(p.node, p.node.get_parent().get_child_count() - 1)

func process_piece_click(event: InputEvent) -> void:
	if event.pressed:
		# Usar la posición global del mouse sin ajustar por el desplazamiento
		var mouse_pos = event.position
		var clicked_piece = null
		
		# Para diagnóstico
		if OS.is_debug_build():
			print("Clic en posición: ", mouse_pos)
		
		# Encontrar la pieza clickeada
		var pieces = piece_manager.get_pieces()
		for piece_obj in pieces:
			# Verificar si la pieza es válida
			if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node):
				continue
			
			# Verificar si el punto está dentro de la pieza usando to_local
			if is_mouse_over_piece(piece_obj, mouse_pos):
				clicked_piece = piece_obj
				if OS.is_debug_build():
					print("Pieza encontrada en: ", piece_obj.node.global_position)
				break
		
		if clicked_piece:
			# Obtener el líder del grupo
			var group_leader = piece_manager.get_group_leader(clicked_piece)
			
			# Guardar las posiciones originales de cada pieza del grupo antes de comenzar a arrastrar
			for p in group_leader.group:
				# Almacenamos la celda actual como punto de referencia para volver si es necesario
				p.drag_start_cell = p.current_cell
			
			# Mover todo el grupo desde cualquier pieza
			for p in group_leader.group:
				p.dragging = true
				p.drag_offset = p.node.global_position - mouse_pos
				
				# Usar el nuevo método set_dragging para cambiar el z-index
				if p.node.has_method("set_dragging"):
					p.node.set_dragging(true)
				else:
					p.node.z_index = 9999
					
				# Asegurar que la pieza esté al frente moviendo su nodo al final del árbol
				if p.node.get_parent() != null:
					p.node.get_parent().move_child(p.node, p.node.get_parent().get_child_count() - 1)

	else:
		# Al soltar, procesar el final del arrastre de la pieza
		process_piece_release()

func process_piece_release() -> void:
	# Al soltar, colocar todo el grupo
	var dragging_piece = null
	var pieces = piece_manager.get_pieces()
	for piece_obj in pieces:
		if piece_obj.dragging:
			dragging_piece = piece_obj
			break
	
	if dragging_piece:
		var group_leader = piece_manager.get_group_leader(dragging_piece)
		for p in group_leader.group:
			p.dragging = false
			
			# Usar el nuevo método set_dragging para restaurar el z-index
			if p.node.has_method("set_dragging"):
				p.node.set_dragging(false)
			else:
				p.node.z_index = 0
		
		# Guardar la posición actual antes de colocar el grupo
		var old_position = group_leader.current_cell
		
		# Colocar el grupo - aquí ocurre la magia
		piece_manager.place_group(group_leader)
		
		# Incrementar contador de movimientos solo si la posición cambió
		if old_position != group_leader.current_cell:
			print("PuzzleInputHandler: Pieza movida de ", old_position, " a ", group_leader.current_cell)
			puzzle_game.game_state_manager.increment_move_count()
		else:
			print("PuzzleInputHandler: Pieza no se movió, permanece en ", old_position)

func is_mouse_over_piece(piece_obj, mouse_pos: Vector2) -> bool:
	# Verificaciones de seguridad
	if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node) or not is_instance_valid(piece_obj.sprite):
		return false
		
	var sprite = piece_obj.sprite
	if sprite.texture == null:
		return false

	# Convertir mouse_pos a espacio local de la pieza
	var local_pos = piece_obj.node.to_local(mouse_pos)
	
	# Para diagnóstico
	if OS.is_debug_build() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		print("Mouse pos: ", mouse_pos)
		print("Local pos en pieza: ", local_pos)
		print("Sprite pos: ", sprite.position)
		print("Sprite scale: ", sprite.scale)
		print("Texture size: ", sprite.texture.get_size())
	
	# Crear un rectángulo que represente el área del sprite
	var tex_rect = Rect2(
		sprite.position - sprite.texture.get_size() * sprite.scale * 0.5,
		sprite.texture.get_size() * sprite.scale
	)
	
	# Verificar si el punto local está dentro del rectángulo
	return tex_rect.has_point(local_pos)

# Función para obtener el centro entre todos los puntos de contacto
func get_touch_center() -> Vector2:
	var center = Vector2.ZERO
	if touch_points.size() > 0:
		for point in touch_points.values():
			center += point
		center /= touch_points.size()
	return center

# Función para cambiar la sensibilidad del desplazamiento
func set_pan_sensitivity(value: float) -> void:
	pan_sensitivity = clamp(value, 0.1, 2.0)
	
	# Guardar en GLOBAL (método preferido)
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		if not "puzzle" in global.settings:
			global.settings.puzzle = {}
		
		global.settings.puzzle.pan_sensitivity = pan_sensitivity
		
		if global.has_method("save_settings"):
			global.save_settings()

# Función para cargar las preferencias del usuario
func load_user_preferences() -> void:
	# Cargar preferencias desde GLOBAL
	if has_node("/root/GLOBAL"):
		var global = GLOBAL
		if "puzzle" in global.settings:
			# Cargar sensibilidad de desplazamiento
			if "pan_sensitivity" in global.settings.puzzle:
				pan_sensitivity = global.settings.puzzle.pan_sensitivity
				print("PuzzleInputHandler: Sensibilidad cargada desde GLOBAL: ", pan_sensitivity)

# Nueva función para reiniciar el board_offset al centrado inicial
func reset_board_to_center():
	print("PuzzleInputHandler: Reseteando tablero al centro")
	board_offset = Vector2.ZERO
	update_board_position() 