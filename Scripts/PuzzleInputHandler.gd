# PuzzleInputHandler.gd
# Manager para gestionar todos los eventos de entrada (mouse, touch, drag & drop, etc.)

extends Node
class_name PuzzleInputHandler

# Referencias al juego principal
var puzzle_game: PuzzleGame
var piece_manager: PuzzlePieceManager

# ✨ SISTEMA DE DOBLE TAP DIRECTO Y SIMPLE
var last_tap_time: float = 0.0
var last_tap_pos: Vector2 = Vector2.ZERO

# Variables para el paneo del tablero
var is_panning := false
var last_pan_position := Vector2.ZERO
var board_offset := Vector2.ZERO  # Desplazamiento actual del tablero
var touch_points := {}  # Para rastrear múltiples puntos de contacto en táctil
var pan_sensitivity: float = 1.0  # Sensibilidad del desplazamiento

# NUEVO: Configuración para prevenir conflictos con gestos del sistema
var edge_margin: float = 40.0  # Margen en píxeles desde los bordes para ignorar toques

# Evita recalcular/resolver superposiciones de forma agresiva en cada input
const OVERLAP_RESOLUTION_COOLDOWN_MS: int = 250
var _last_overlap_resolution_ms: int = 0
const GROUP_SYNC_COOLDOWN_MS: int = 800
const GROUP_SYNCHRONIZER_SCRIPT = preload("res://Scripts/Autoload/GroupSynchronizer.gd")
var _last_group_sync_check_ms: int = 0
var _group_synchronizer: Node = null

func initialize(game: PuzzleGame):
	puzzle_game = game
	piece_manager = game.piece_manager
	
	# IMPORTANTE: Inicializar board_offset en Vector2.ZERO para respetar el centrado
	# El centrado se maneja en PuzzlePieceManager con puzzle_offset
	board_offset = Vector2.ZERO
	
	load_user_preferences()

	# Reutilizar una sola instancia para evitar crear nodos por cada movimiento
	if _group_synchronizer and is_instance_valid(_group_synchronizer):
		_group_synchronizer.free()
	_group_synchronizer = GROUP_SYNCHRONIZER_SCRIPT.new()
	_group_synchronizer.initialize(puzzle_game, piece_manager)

func _exit_tree() -> void:
	if _group_synchronizer and is_instance_valid(_group_synchronizer):
		_group_synchronizer.free()
	_group_synchronizer = null



func _handle_keyboard_input(event: InputEventKey):
	# Alternar límites visuales con tecla 'B' (Borders)
	if event.keycode == KEY_B:
		var current_visibility = true
		if piece_manager.border_areas.size() > 0:
			current_visibility = piece_manager.border_areas[0].visible
		piece_manager.toggle_visual_borders(!current_visibility)
		var status = "mostrados" if !current_visibility else "ocultados"

	
	# DEBUG: Tecla 'C' para forzar recentrado directo
	elif event.keycode == KEY_C and OS.is_debug_build():
		print("PuzzleInputHandler: Tecla C presionada - Centrando directamente")
		center_puzzle()
	
	# DEBUG: Tecla 'D' para ejecutar diagnóstico
	elif event.keycode == KEY_D and OS.is_debug_build():
		puzzle_game.run_positioning_diagnosis()
	
	# DEBUG: Tecla 'R' para resetear solo InputHandler
	elif event.keycode == KEY_R and OS.is_debug_build():
		reset_board_to_center()
	
	# 🎯 DEBUG: Teclas para ajustar el retraso del centrado automático
	elif (event.keycode == KEY_PLUS or event.keycode == KEY_KP_ADD) and OS.is_debug_build():
		var new_delay = piece_manager.get_auto_center_delay() + 0.2
		piece_manager.set_auto_center_delay(new_delay)
	
	elif (event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT) and OS.is_debug_build():
		var new_delay = max(0.0, piece_manager.get_auto_center_delay() - 0.2)
		piece_manager.set_auto_center_delay(new_delay)
	
	# DEBUG: Tecla 'T' para mostrar el retraso actual
	elif event.keycode == KEY_T and OS.is_debug_build():
		var current_delay = piece_manager.get_auto_center_delay()
	
	# 🔧 DEBUG: Teclas para ajustar el margen de bordes
	elif event.keycode == KEY_BRACKETLEFT and OS.is_debug_build():
		var new_margin = max(20.0, edge_margin - 10.0)
		set_edge_margin(new_margin)
	
	elif event.keycode == KEY_BRACKETRIGHT and OS.is_debug_build():
		var new_margin = min(100.0, edge_margin + 10.0)
		set_edge_margin(new_margin)
	
	# DEBUG: Tecla 'M' para mostrar el margen actual
	# elif event.keycode == KEY_M and OS.is_debug_build():
	# 	puzzle_game.show_success_message("🔧 Margen actual: " + str(edge_margin) + "px", 3.0)

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

func _resolve_overlaps_if_needed(context: String) -> void:
	if not piece_manager:
		return

	# Primera barrera: si no hay superposiciones, no hacemos nada.
	if piece_manager.verify_no_overlaps():
		return

	# Segunda barrera: evitar corregir de forma repetitiva durante ráfagas de eventos.
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_overlap_resolution_ms < OVERLAP_RESOLUTION_COOLDOWN_MS:
		return

	_last_overlap_resolution_ms = now_ms
	print("PuzzleInputHandler: ⚠️ Superposiciones detectadas (", context, "). Se omite la autocorrección agresiva para no romper grupos.")

# Función mejorada para verificar si un toque está en una zona segura
func is_touch_in_safe_zone(position: Vector2) -> bool:
	var screen_size = get_viewport().get_visible_rect().size
	return (position.x >= edge_margin and position.x <= screen_size.x - edge_margin and
			position.y >= edge_margin and position.y <= screen_size.y - edge_margin)

func _handle_screen_touch(event: InputEventScreenTouch):
	# 🚫 PREVENIR CONFLICTOS CON GESTOS DEL SISTEMA OPERATIVO
	# No procesar toques muy cerca de los bordes de la pantalla
	if not is_touch_in_safe_zone(event.position):
		print("Input táctil ignorado por estar demasiado cerca del borde de pantalla")
		return
	
	# ✨ NUEVO: Sistema de doble tap ultra-simple y directo
	if event.pressed:
		var current_time = Time.get_ticks_msec()
		var time_diff = current_time - last_tap_time
		var pos_diff = event.position.distance_to(last_tap_pos)
		
		print("PuzzleInputHandler: Tap detectado - Tiempo desde último: ", time_diff, "ms, Distancia: ", pos_diff, "px")
		
		# Si es un doble tap (menos de 500ms y menos de 100px de distancia)
		if time_diff < 500 and pos_diff < 100 and last_tap_time > 0:
			print("PuzzleInputHandler: ¡DOBLE TAP DETECTADO! Centrando directamente...")
			
			# Centrar DIRECTAMENTE sin pasar por funciones complejas
			_center_puzzle_directly()
			puzzle_game.show_success_message("🎯 Puzzle centrado", 2.0)
			
			# Resetear para evitar triple taps
			last_tap_time = 0
			last_tap_pos = Vector2.ZERO
		else:
			# Primer tap o tap fuera de rango
			last_tap_time = current_time
			last_tap_pos = event.position
	
	# Guardamos la información del toque en nuestro diccionario
	if event.pressed:
		touch_points[event.index] = event.position
	else:
		touch_points.erase(event.index)
		
	# Para paneo en dispositivos móviles Y tablets necesitamos DOS dedos
	if (puzzle_game.is_mobile or puzzle_game.is_tablet):
		if touch_points.size() >= 2 and event.pressed:
			# Iniciar paneo con dos dedos
			is_panning = true
			# Usamos el punto medio entre los dos dedos como punto de referencia
			last_pan_position = get_touch_center()
		elif touch_points.size() < 2:
			# Si hay menos de dos dedos, terminar el paneo
			is_panning = false
	
	# Si es un solo dedo, procesamos como un evento normal de clic de pieza
	if touch_points.size() == 1 and (puzzle_game.is_mobile or puzzle_game.is_tablet):
		if event.pressed:
			# Debemos pasar la posición específica del evento de toque, no el evento genérico
			process_piece_click_touch(event.position, event.index)
		else:
			process_piece_release()

func _handle_screen_drag(event: InputEventScreenDrag):
	# 🚫 PREVENIR CONFLICTOS CON GESTOS DEL SISTEMA OPERATIVO
	# También aplicar la verificación de bordes para los drags
	var screen_size = get_viewport().get_visible_rect().size
	
	# Si el drag se acerca demasiado a los bordes, limitarlo
	var safe_position = event.position
	safe_position.x = clamp(safe_position.x, edge_margin, screen_size.x - edge_margin)
	safe_position.y = clamp(safe_position.y, edge_margin, screen_size.y - edge_margin)
	
	# Actualizar la posición del punto de contacto con la posición segura
	touch_points[event.index] = safe_position
	
	# Para paneo en dispositivos móviles necesitamos DOS dedos
	if (puzzle_game.is_mobile or puzzle_game.is_tablet) and touch_points.size() >= 2 and is_panning:
		# En lugar de usar el centro de los dedos, usamos directamente la posición del dedo 
		# que se está moviendo, lo que da un control más directo
		var current_pos = safe_position
		
		# El delta es exactamente el movimiento real del dedo, pero ajustado para evitar bordes
		var delta = event.relative
		
		# Si el movimiento nos llevaría demasiado cerca del borde, reducir el delta
		var future_pos = event.position + delta
		if not is_touch_in_safe_zone(future_pos):
			# Reducir el delta para mantener la posición dentro de los límites seguros
			delta *= 0.5
		
		# Aplicamos directamente el delta del movimiento del dedo, manteniendo
		# la misma dirección que el gesto del usuario, pero ajustando por la sensibilidad
		board_offset += delta * pan_sensitivity
		
		last_pan_position = current_pos
		update_board_position()
	
	# Si estamos arrastrando con un solo dedo y no estamos en modo paneo, mover piezas
	elif (puzzle_game.is_mobile or puzzle_game.is_tablet) and touch_points.size() == 1 and not is_panning:
		# Procesar como arrastre de pieza
		var pieces = piece_manager.get_pieces()
		for piece_obj in pieces:
			if piece_obj.dragging:
				var group_leader = piece_manager.get_group_leader(piece_obj)
				
				# En lugar de usar event.relative, calculamos la nueva posición basada
				# en la posición actual del dedo y el offset guardado al comenzar el arrastre
				var touch_pos = safe_position  # Usar la posición segura
				
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
	
	# ✨ NUEVO: Doble clic en PC para centrar puzzle directamente
	elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		print("PuzzleInputHandler: ¡Doble clic detectado! Centrando directamente...")
		_center_puzzle_directly()
		puzzle_game.show_success_message("🎯 Puzzle centrado", 2.0)
	
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
	var board_size = Vector2(puzzle_data["width"], puzzle_data["height"])
	
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

func process_piece_click(event: InputEvent) -> void:
	if event.pressed:
		# Usar la posición global del mouse sin ajustar por el desplazamiento
		var mouse_pos = event.position
		var clicked_piece = null
		
		# Para diagnóstico
		if OS.is_debug_build():
			print("Clic en posición: ", mouse_pos)
		
		# 🔧 MEJORADO: Encontrar la pieza más apropiada considerando z-index y superposiciones
		clicked_piece = _find_best_piece_at_position(mouse_pos)
		
		if clicked_piece:
			# 🔧 CRÍTICO: Resolver cualquier superposición ANTES de iniciar el arrastre
			print("PuzzleInputHandler: Verificando superposiciones antes de arrastrar...")
			_resolve_overlaps_if_needed("before_drag_start")
			
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

# 🔧 NUEVA FUNCIÓN MEJORADA PARA ENCONTRAR LA MEJOR PIEZA
func _find_best_piece_at_position(mouse_pos: Vector2):
	"""
	Encuentra la mejor pieza en una posición considerando:
	1. Prioridad por z-index (piezas al frente primero)
	2. Verificación precisa de área
	3. Exclusión de piezas ya en proceso de arrastre
	"""
	var candidate_pieces = []
	var pieces = piece_manager.get_pieces()
	
	# 🔧 CRÍTICO: Verificar y resolver superposiciones ANTES de la detección
	if not piece_manager.verify_no_overlaps():
		print("PuzzleInputHandler: Resolviendo superposiciones automáticamente antes de detectar clic...")
		_resolve_overlaps_if_needed("before_piece_pick")
		# Actualizar la lista de piezas después de resolver superposiciones
		pieces = piece_manager.get_pieces()
	
	# PASO 1: Encontrar todas las piezas candidatas bajo el cursor
	for piece_obj in pieces:
		# Verificar si la pieza es válida
		if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node):
			continue
		
		# Saltar piezas que ya están siendo arrastradas
		if piece_obj.dragging:
			continue
		
		# Verificar si el punto está dentro de la pieza usando verificación mejorada
		if _is_mouse_over_piece_improved(piece_obj, mouse_pos):
			candidate_pieces.append({
				"piece": piece_obj,
				"z_index": piece_obj.node.z_index,
				"distance_to_center": _calculate_distance_to_piece_center(piece_obj, mouse_pos),
				"is_dragging": piece_obj.dragging,
				"is_at_correct_position": piece_obj.is_at_correct_position
			})
			
			if OS.is_debug_build():
				print("Candidata encontrada: pieza ", piece_obj.order_number, " z-index: ", piece_obj.node.z_index, " distancia: ", _calculate_distance_to_piece_center(piece_obj, mouse_pos))
	
	if candidate_pieces.is_empty():
		if OS.is_debug_build():
			print("No se encontraron piezas bajo el cursor en ", mouse_pos)
		return null
	
	# PASO 2: Ordenar candidatos por prioridad inteligente
	candidate_pieces.sort_custom(func(a, b):
		# 🔧 PRIORIDAD 1: Nunca seleccionar piezas que están siendo arrastradas
		if a.is_dragging != b.is_dragging:
			return not a.is_dragging  # La que NO está siendo arrastrada tiene prioridad
		
		# 🔧 PRIORIDAD 2: z-index más alto (piezas visualmente al frente)
		if a.z_index != b.z_index:
			return a.z_index > b.z_index
		
		# 🔧 PRIORIDAD 3: Piezas fuera de posición tienen prioridad (están siendo movidas)
		if a.is_at_correct_position != b.is_at_correct_position:
			return not a.is_at_correct_position  # La que NO está en posición correcta tiene prioridad
		
		# 🔧 PRIORIDAD 4: Distancia al centro de la pieza (más cerca del centro)
		return a.distance_to_center < b.distance_to_center
	)
	
	var best_piece = candidate_pieces[0].piece
	
	if OS.is_debug_build():
		print("Mejor pieza seleccionada: ", best_piece.order_number, 
			  " z-index: ", best_piece.node.z_index,
			  " distancia: ", candidate_pieces[0].distance_to_center,
			  " posición correcta: ", candidate_pieces[0].is_at_correct_position)
	
	# 🔧 NUEVA VERIFICACIÓN: Si hay múltiples candidatos con z-index similar, verificar superposiciones
	var similar_z_candidates = candidate_pieces.filter(func(c): return abs(c.z_index - candidate_pieces[0].z_index) <= 10)
	if similar_z_candidates.size() > 1:
		print("PuzzleInputHandler: Múltiples candidatos con z-index similar - Verificando superposiciones...")
		_verify_and_fix_visual_conflicts(similar_z_candidates)
	
	return best_piece

# 🔧 NUEVA FUNCIÓN PARA VERIFICAR Y RESOLVER CONFLICTOS VISUALES
func _verify_and_fix_visual_conflicts(candidates: Array):
	"""
	Verifica posibles conflictos visuales de selección.
	No reposiciona piezas para no introducir efectos secundarios durante el input.
	"""
	if candidates.size() <= 1:
		return
	
	if OS.is_debug_build():
		print("PuzzleInputHandler: Detectados ", candidates.size(), " candidatos con z-index similar; se prioriza por orden de selección sin mover piezas.")

# 🔧 FUNCIÓN MEJORADA DE VERIFICACIÓN DE MOUSE SOBRE PIEZA
func _is_mouse_over_piece_improved(piece_obj, mouse_pos: Vector2) -> bool:
	"""
	Verificación mejorada que considera z-index y áreas de colisión más precisas
	"""
	# Verificaciones de seguridad básicas
	if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node) or not is_instance_valid(piece_obj.sprite):
		return false
		
	var sprite = piece_obj.sprite
	if sprite.texture == null:
		return false

	# Convertir mouse_pos a espacio local de la pieza
	var local_pos = piece_obj.node.to_local(mouse_pos)
	
	# 🔧 MEJORADO: Usar el área de colisión de Area2D si está disponible y es más precisa
	if piece_obj.node.has_node("Area2D"):
		var area2d = piece_obj.node.get_node("Area2D")
		if area2d.has_node("CollisionShape2D"):
			var collision_shape = area2d.get_node("CollisionShape2D")
			if collision_shape.shape is RectangleShape2D:
				var rect_shape = collision_shape.shape as RectangleShape2D
				# Crear rectángulo de colisión centrado
				var collision_rect = Rect2(
					collision_shape.position - rect_shape.size * 0.5,
					rect_shape.size
				)
				# Aplicar la escala del collision shape
				collision_rect.position *= collision_shape.scale
				collision_rect.size *= collision_shape.scale
				
				# 🔧 NUEVA VERIFICACIÓN: Reducir ligeramente el área para evitar superposiciones
				var margin = 5.0  # Margen en píxeles
				collision_rect = collision_rect.grow(-margin)
				
				if collision_rect.has_point(local_pos):
					return true
	
	# Fallback: usar el rectángulo del sprite como antes, pero con margen
	var tex_rect = Rect2(
		sprite.position - sprite.texture.get_size() * sprite.scale * 0.5,
		sprite.texture.get_size() * sprite.scale
	)
	
	# Aplicar margen también al fallback
	var margin = 5.0
	tex_rect = tex_rect.grow(-margin)
	
	return tex_rect.has_point(local_pos)

# 🔧 NUEVA FUNCIÓN PARA CALCULAR DISTANCIA AL CENTRO DE LA PIEZA
func _calculate_distance_to_piece_center(piece_obj, mouse_pos: Vector2) -> float:
	"""
	Calcula la distancia del cursor al centro de la pieza para desempatar
	"""
	var piece_center = piece_obj.node.global_position
	return mouse_pos.distance_to(piece_center)

func process_piece_click_touch(touch_position: Vector2, touch_index: int) -> void:
	# Usar la posición del toque sin ajustar
	var mouse_pos = touch_position
	
	# 🔧 CRÍTICO: Resolver superposiciones antes de cualquier detección
	print("PuzzleInputHandler: Verificando superposiciones antes de detectar toque...")
	_resolve_overlaps_if_needed("before_touch_pick")
	
	# 🔧 MEJORADO: Usar la misma lógica mejorada para detección táctil
	var clicked_piece = _find_best_piece_at_position(mouse_pos)
	
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
		
		# 🔧 CRÍTICO: Verificar y resolver superposiciones después de colocar
		print("PuzzleInputHandler: Verificando superposiciones después de soltar pieza...")
		_resolve_overlaps_if_needed("after_piece_release")
		
		# 🔧 NUEVO: Verificación automática de sincronización de grupos después de mover
		_verify_group_synchronization_after_move(group_leader)
		
		# Incrementar contador de movimientos solo si la posición cambió
		if old_position != group_leader.current_cell:
			print("PuzzleInputHandler: Pieza movida de ", old_position, " a ", group_leader.current_cell)
			puzzle_game.game_state_manager.increment_move_count()
			
			# ✨ NUEVO: Notificar al score manager sobre el movimiento exitoso
			if puzzle_game.score_manager and puzzle_game.score_manager.is_scoring_enabled():
				if group_leader.group.size() == 1:
					# Pieza individual colocada correctamente
					puzzle_game.score_manager.add_piece_placed_correctly()
				else:
					# Grupo movido exitosamente
					puzzle_game.score_manager.add_group_moved_successfully(group_leader.group.size())
				
				print("PuzzleInputHandler: ✨ Puntuación actualizada por movimiento exitoso")
		else:
			print("PuzzleInputHandler: Pieza no se movió, permanece en ", old_position)

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

# Función para cambiar el margen de bordes dinámicamente
func set_edge_margin(value: float) -> void:
	edge_margin = clamp(value, 20.0, 100.0)
	print("PuzzleInputHandler: Margen de borde actualizado a: ", edge_margin)

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
			
			# Cargar margen de bordes si existe
			if "edge_margin" in global.settings.puzzle:
				edge_margin = global.settings.puzzle.edge_margin
				print("PuzzleInputHandler: Margen de borde cargado desde GLOBAL: ", edge_margin)

# Nueva función para reiniciar el board_offset al centrado inicial
func reset_board_to_center():
	print("PuzzleInputHandler: Reseteando tablero al centro")
	board_offset = Vector2.ZERO
	update_board_position()
	
	# 🔲 NUEVO: Actualizar bordes de grupo después de resetear al centro
	if piece_manager:
		piece_manager.update_all_group_borders()
		print("PuzzleInputHandler: Bordes de grupo actualizados después de resetear al centro") 

# ✨ NUEVA FUNCIÓN: Centrar puzzle de manera directa y completa
func _center_puzzle_directly():
	print("PuzzleInputHandler: *** INICIANDO CENTRADO DIRECTO COMPLETO ***")
	
	if not piece_manager or piece_manager.pieces.size() == 0:
		print("PuzzleInputHandler: No hay piezas para centrar")
		return
	
	# PASO 1: Calcular el centro de la pantalla
	var viewport_size = puzzle_game.get_viewport_rect().size
	var screen_center = viewport_size * 0.5
	print("PuzzleInputHandler: Centro de pantalla: ", screen_center)
	
	# PASO 2: Calcular el centro actual del puzzle
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var pieces = piece_manager.get_pieces()
	
	for piece_obj in pieces:
		if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node):
			continue
		var pos = piece_obj.node.global_position
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	
	var puzzle_size = max_pos - min_pos
	var current_center = min_pos + puzzle_size * 0.5
	print("PuzzleInputHandler: Centro actual del puzzle: ", current_center)
	print("PuzzleInputHandler: Tamaño del puzzle: ", puzzle_size)
	
	# PASO 3: Calcular el offset necesario para centrar
	var offset_needed = screen_center - current_center
	print("PuzzleInputHandler: Offset necesario: ", offset_needed)
	
	# PASO 4: CRÍTICO - Ocultar bordes antes de mover piezas
	print("PuzzleInputHandler: Ocultando bordes de grupo temporalmente...")
	piece_manager.hide_all_group_borders()
	
	# PASO 5: Aplicar el offset a TODAS las piezas Y actualizar datos internos
	var pieces_moved = 0
	var puzzle_data = puzzle_game.get_puzzle_data()
	
	for piece_obj in pieces:
		if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node):
			continue
		
		# Mover la pieza visualmente
		piece_obj.node.global_position += offset_needed
		
		# CRÍTICO: También actualizar posición del sprite interno si existe
		if piece_obj.node.has_node("Sprite2D"):
			var sprite = piece_obj.node.get_node("Sprite2D") 
			# El sprite debe permanecer en (0,0) relativo al nodo padre
			sprite.position = Vector2.ZERO
		
		pieces_moved += 1
	
	print("PuzzleInputHandler: Piezas movidas visualmente: ", pieces_moved)
	
	# PASO 6: CRÍTICO - Actualizar el puzzle_offset en puzzle_data para mantener consistencia
	var new_offset = puzzle_data["offset"] + offset_needed
	puzzle_game.set_puzzle_data(
		puzzle_data["texture"],
		puzzle_data["width"], 
		puzzle_data["height"],
		puzzle_data["cell_size"],
		new_offset
	)
	print("PuzzleInputHandler: Puzzle offset actualizado a: ", new_offset)
	
	# PASO 7: CRÍTICO - Resetear board_offset y sincronizar contenedor
	board_offset = Vector2.ZERO
	if puzzle_game.pieces_container:
		puzzle_game.pieces_container.position = Vector2.ZERO
		print("PuzzleInputHandler: Contenedor de piezas reseteado")
	
	# CRÍTICO: También resetear la posición del PuzzleGame si tiene offset
	puzzle_game.position = Vector2.ZERO
	print("PuzzleInputHandler: Posición de PuzzleGame reseteada")
	
	# PASO 8: Esperar un frame para que las posiciones se estabilicen
	await puzzle_game.get_tree().process_frame
	
	# PASO 9: Verificar y actualizar información de grupos
	print("PuzzleInputHandler: Verificando grupos después del centrado...")
	piece_manager.check_all_groups()
	
	# PASO 10: Recrear y mostrar bordes de grupo en nuevas posiciones
	print("PuzzleInputHandler: Recreando bordes de grupo en nuevas posiciones...")
	piece_manager.clear_all_group_borders()
	await puzzle_game.get_tree().process_frame
	piece_manager.update_all_group_borders()
	
	# PASO 11: Verificación final de consistencia
	print("PuzzleInputHandler: Verificación final...")
	for piece_obj in pieces:
		if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node):
			continue
		
		# Asegurar que el estado visual esté correcto
		if piece_obj.node.has_method("update_all_visuals"):
			piece_obj.node.update_all_visuals()
	
	# Debug final: Verificar que todo esté centrado
	await puzzle_game.get_tree().process_frame
	var final_min_pos = Vector2(INF, INF)
	var final_max_pos = Vector2(-INF, -INF)
	for piece_obj in pieces:
		if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node):
			continue
		var pos = piece_obj.node.global_position
		final_min_pos.x = min(final_min_pos.x, pos.x)
		final_min_pos.y = min(final_min_pos.y, pos.y)
		final_max_pos.x = max(final_max_pos.x, pos.x)
		final_max_pos.y = max(final_max_pos.y, pos.y)
	
	var final_center = (final_min_pos + final_max_pos) * 0.5
	print("PuzzleInputHandler: Centro final del puzzle: ", final_center)
	print("PuzzleInputHandler: Centro de pantalla: ", screen_center)
	print("PuzzleInputHandler: Discrepancia final: ", final_center - screen_center)
	
	print("PuzzleInputHandler: *** CENTRADO COMPLETO FINALIZADO ***")

# ✨ FUNCIÓN PÚBLICA: Para centrar el puzzle desde cualquier lugar
func center_puzzle():
	"""
	Función pública para centrar el puzzle desde cualquier lugar del código
	"""
	print("PuzzleInputHandler: Centrando puzzle via función pública...")
	_center_puzzle_directly()
	if puzzle_game.ui_manager:
		puzzle_game.show_success_message("🎯 Puzzle centrado", 2.0)

# 🔧 NUEVA FUNCIÓN: Verificación automática de sincronización después de mover
func _verify_group_synchronization_after_move(moved_group_leader):
	"""Verifica automáticamente la sincronización de grupos después de mover una pieza"""
	
	# Solo verificar si el grupo tiene más de 1 pieza
	if moved_group_leader.group.size() <= 1:
		return

	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_group_sync_check_ms < GROUP_SYNC_COOLDOWN_MS:
		return
	_last_group_sync_check_ms = now_ms
	
	if OS.is_debug_build():
		print("PuzzleInputHandler: Verificando sincronización de grupo movido...")
	
	if not _group_synchronizer:
		_group_synchronizer = GROUP_SYNCHRONIZER_SCRIPT.new()
		_group_synchronizer.initialize(puzzle_game, piece_manager)
	
	# Analizar solo el grupo que se movió
	var group = moved_group_leader.group
	var sync_issues = _group_synchronizer._analyze_group_synchronization(group)
	
	if sync_issues > 0:
		print("PuzzleInputHandler: ⚠️ Detectados ", sync_issues, " problemas de sincronización, corrigiendo...")
		_group_synchronizer._fix_group_synchronization(group)
		print("PuzzleInputHandler: ✅ Problemas de sincronización corregidos automáticamente")
	elif OS.is_debug_build():
		print("PuzzleInputHandler: ✅ Grupo está correctamente sincronizado")
