# UnifiedPuzzleRestoration.gd
# Sistema unificado de restauración de puzzles que elimina conflictos entre procesos
# Reemplaza todos los sistemas fragmentados de corrección que causaban desmontaje visual

extends Node
class_name UnifiedPuzzleRestoration

# Señales para comunicación
signal restoration_completed(success: bool)
signal restoration_failed(error_message: String)

# Estados del sistema
enum RestorationState {
	IDLE,
	PREPARING,
	RESTORING_POSITIONS,
	RESTORING_GROUPS,
	FINALIZING,
	COMPLETED,
	FAILED
}

var current_state: RestorationState = RestorationState.IDLE
var puzzle_game: Node
var piece_manager: Node
var is_restoration_active: bool = false

# Banderas de control para desactivar sistemas automáticos
var auto_centering_disabled: bool = false
var overlap_resolution_disabled: bool = false  
var group_checking_disabled: bool = false
var border_updates_disabled: bool = false

func initialize(game: Node, manager: Node):
	"""Inicializa el sistema de restauración unificado"""
	puzzle_game = game
	piece_manager = manager
	print("UnifiedPuzzleRestoration: Sistema inicializado")

func restore_puzzle_state_unified(saved_pieces_data: Array) -> bool:
	"""
	Función principal que restaura el estado del puzzle de manera unificada
	Retorna true si la restauración fue exitosa
	"""
	if is_restoration_active:
		print("UnifiedPuzzleRestoration: ⚠️ Restauración ya en curso, ignorando solicitud")
		return false
	
	print("UnifiedPuzzleRestoration: 🔧 INICIANDO RESTAURACIÓN UNIFICADA")
	is_restoration_active = true
	current_state = RestorationState.PREPARING
	
	# === FASE 1: PREPARACIÓN ===
	print("UnifiedPuzzleRestoration: Fase 1 - Preparación del sistema")
	_disable_all_automatic_systems()
	_prepare_clean_state()
	
	# === FASE 2: RESTAURACIÓN DE POSICIONES ===
	print("UnifiedPuzzleRestoration: Fase 2 - Restauración de posiciones")
	current_state = RestorationState.RESTORING_POSITIONS
	var positions_restored = _restore_piece_positions_unified(saved_pieces_data)
	
	if not positions_restored:
		print("UnifiedPuzzleRestoration: ❌ Error en restauración de posiciones")
		_finalize_restoration(false, "Error al restaurar posiciones")
		return false
	
	# === FASE 3: RESTAURACIÓN DE GRUPOS ===
	print("UnifiedPuzzleRestoration: Fase 3 - Restauración de grupos")
	current_state = RestorationState.RESTORING_GROUPS
	var groups_restored = _restore_piece_groups_unified(saved_pieces_data)
	
	if not groups_restored:
		print("UnifiedPuzzleRestoration: ❌ Error en restauración de grupos")
		_finalize_restoration(false, "Error al restaurar grupos")
		return false
	
	# === FASE 4: FINALIZACIÓN ===
	print("UnifiedPuzzleRestoration: Fase 4 - Finalización")
	current_state = RestorationState.FINALIZING
	_finalize_unified_restoration()
	
	# === COMPLETADO ===
	current_state = RestorationState.COMPLETED
	_finalize_restoration(true, "Restauración completada exitosamente")
	return true

func _disable_all_automatic_systems():
	"""Desactiva todos los sistemas automáticos que pueden interferir"""
	print("UnifiedPuzzleRestoration: Desactivando sistemas automáticos...")
	
	auto_centering_disabled = true
	overlap_resolution_disabled = true
	group_checking_disabled = true
	border_updates_disabled = true
	
	# Notificar al piece_manager que no ejecute procesos automáticos
	if piece_manager.has_method("set_auto_processes_enabled"):
		piece_manager.set_auto_processes_enabled(false)
	
	# Desactivar centrado automático en el juego
	if puzzle_game.has_method("set_auto_centering_enabled"):
		puzzle_game.set_auto_centering_enabled(false)

func _enable_all_automatic_systems():
	"""Reactiva todos los sistemas automáticos"""
	print("UnifiedPuzzleRestoration: Reactivando sistemas automáticos...")
	
	auto_centering_disabled = false
	overlap_resolution_disabled = false
	group_checking_disabled = false
	border_updates_disabled = false
	
	# Notificar al piece_manager que puede ejecutar procesos automáticos
	if piece_manager.has_method("set_auto_processes_enabled"):
		piece_manager.set_auto_processes_enabled(true)
	
	# Reactivar centrado automático en el juego
	if puzzle_game.has_method("set_auto_centering_enabled"):
		puzzle_game.set_auto_centering_enabled(true)

func _prepare_clean_state():
	"""Prepara el estado del puzzle para la restauración"""
	print("UnifiedPuzzleRestoration: Preparando estado limpio...")
	
	# Limpiar grid completamente
	if piece_manager.has_method("clear_grid"):
		piece_manager.clear_grid()
	
	# Limpiar estados de arrastre
	var pieces = piece_manager.get_pieces()
	for piece_obj in pieces:
		if piece_obj and piece_obj.node:
			piece_obj.dragging = false
			piece_obj.drag_offset = Vector2.ZERO
			# Resetear grupo temporalmente a pieza individual
			piece_obj.group = [piece_obj]
	
	# Limpiar bordes de grupo existentes
	if piece_manager.has_method("clear_all_group_borders"):
		piece_manager.clear_all_group_borders()

func _restore_piece_positions_unified(saved_pieces_data: Array) -> bool:
	"""Restaura las posiciones de las piezas de manera unificada"""
	print("UnifiedPuzzleRestoration: Restaurando posiciones de ", saved_pieces_data.size(), " piezas...")
	
	var pieces = piece_manager.get_pieces()
	var successfully_restored = 0
	var puzzle_data = puzzle_game.get_puzzle_data()
	
	for piece_data in saved_pieces_data:
		# Buscar la pieza correspondiente
		var target_piece = null
		for piece_obj in pieces:
			if piece_obj.order_number == piece_data.order_number:
				target_piece = piece_obj
				break
		
		if target_piece == null:
			print("UnifiedPuzzleRestoration: ⚠️ No se encontró pieza ", piece_data.order_number)
			continue
		
		# Restaurar current_cell PRIMERO
		if "current_cell" in piece_data and piece_data.current_cell != null:
			var saved_cell = Vector2(piece_data.current_cell.x, piece_data.current_cell.y)
			target_piece.current_cell = saved_cell
			
			# Calcular y aplicar posición visual basada en current_cell
			var visual_position = puzzle_data["offset"] + saved_cell * puzzle_data["cell_size"]
			target_piece.node.position = visual_position
			
			# Registrar en grid DESPUÉS de establecer both current_cell y posición visual
			piece_manager.set_piece_at(saved_cell, target_piece)
			
			# Sincronizar drag_start_cell con current_cell
			target_piece.drag_start_cell = saved_cell
			
			print("UnifiedPuzzleRestoration: Pieza ", piece_data.order_number, " restaurada a ", saved_cell)
		else:
			print("UnifiedPuzzleRestoration: ⚠️ Sin datos de celda para pieza ", piece_data.order_number)
			continue
		
		# Restaurar estado volteado
		if "flipped" in piece_data and target_piece.node.has_method("set_flipped"):
			target_piece.node.set_flipped(piece_data.flipped)
		
		successfully_restored += 1
	
	print("UnifiedPuzzleRestoration: ", successfully_restored, "/", saved_pieces_data.size(), " posiciones restauradas")
	return successfully_restored > 0

func _restore_piece_groups_unified(saved_pieces_data: Array) -> bool:
	"""Restaura los grupos de piezas de manera unificada"""
	print("UnifiedPuzzleRestoration: Restaurando grupos...")
	
	# Crear mapa de grupos por group_id
	var groups_to_form = {}
	var pieces = piece_manager.get_pieces()
	
	# Recopilar piezas por group_id
	for piece_data in saved_pieces_data:
		if not "group_id" in piece_data:
			continue
		
		var group_id = piece_data.group_id
		if group_id == -1 or group_id == null:
			continue  # Pieza individual
		
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
	
	# Formar los grupos de manera segura
	var groups_formed = 0
	for group_id in groups_to_form.keys():
		var group_pieces = groups_to_form[group_id]
		if group_pieces.size() > 1:
			# Verificar que todas las piezas son válidas
			var valid_pieces = []
			for piece_obj in group_pieces:
				if piece_obj and piece_obj.node and is_instance_valid(piece_obj.node):
					valid_pieces.append(piece_obj)
			
			if valid_pieces.size() > 1:
				# Formar el grupo de manera unificada
				_form_group_unified(valid_pieces, group_id)
				groups_formed += 1
			else:
				print("UnifiedPuzzleRestoration: ⚠️ Grupo ", group_id, " descartado por piezas inválidas")
	
	print("UnifiedPuzzleRestoration: ", groups_formed, " grupos formados")
	return true

func _form_group_unified(group_pieces: Array, group_id):
	"""Forma un grupo de manera unificada sin activar procesos automáticos"""
	print("UnifiedPuzzleRestoration: Formando grupo ", group_id, " con ", group_pieces.size(), " piezas")
	
	# Asignar grupo a todas las piezas
	for piece_obj in group_pieces:
		piece_obj.group = group_pieces.duplicate()
		
		# Configurar ID de grupo visual
		if piece_obj.node.has_method("set_group_id"):
			piece_obj.node.set_group_id(group_id)
		
		# Actualizar pieces_group en el nodo
		if piece_obj.node.has_method("update_pieces_group"):
			piece_obj.node.update_pieces_group(group_pieces)
	
	# Actualizar piezas de borde del grupo SIN activar sistemas automáticos
	_update_group_edges_unified(group_pieces)

func _update_group_edges_unified(group_pieces: Array):
	"""Actualiza las piezas de borde de un grupo sin activar sistemas automáticos"""
	if group_pieces.size() <= 1:
		for piece in group_pieces:
			if piece.node.has_method("set_edge_piece"):
				piece.node.set_edge_piece(true)
		return
	
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	
	# Resetear todos como no-borde
	for piece in group_pieces:
		if piece.node.has_method("set_edge_piece"):
			piece.node.set_edge_piece(false)
	
	# Identificar piezas de borde
	for piece in group_pieces:
		var cell = piece.current_cell
		var is_edge = false
		
		for dir in directions:
			var neighbor_cell = cell + dir
			var has_neighbor = false
			
			for other_piece in group_pieces:
				if other_piece.current_cell == neighbor_cell:
					has_neighbor = true
					break
			
			if not has_neighbor:
				is_edge = true
				break
		
		if piece.node.has_method("set_edge_piece"):
			piece.node.set_edge_piece(is_edge)

func _finalize_unified_restoration():
	"""Finaliza la restauración de manera unificada"""
	print("UnifiedPuzzleRestoration: Finalizando restauración...")
	
	# Actualizar estados de posición correcta para todas las piezas
	var pieces = piece_manager.get_pieces()
	for piece_obj in pieces:
		if piece_manager.has_method("update_piece_position_state"):
			piece_manager.update_piece_position_state(piece_obj)
	
	# Actualizar efectos visuales
	for piece_obj in pieces:
		if piece_obj.node.has_method("update_all_visuals"):
			piece_obj.node.update_all_visuals()
	
	# 🔧 CRÍTICO: Ejecutar sincronización de grupos ANTES de crear bordes
	print("UnifiedPuzzleRestoration: Ejecutando sincronización de grupos...")
	_synchronize_all_groups()
	
	# Crear bordes de grupo UNA SOLA VEZ al final
	if piece_manager.has_method("update_all_group_borders"):
		piece_manager.update_all_group_borders()

func _finalize_restoration(success: bool, message: String):
	"""Finaliza el proceso de restauración"""
	print("UnifiedPuzzleRestoration: ", message)
	
	# Reactivar sistemas automáticos
	_enable_all_automatic_systems()
	
	# Resetear estado
	is_restoration_active = false
	current_state = RestorationState.COMPLETED if success else RestorationState.FAILED
	
	# Emitir señal apropiada
	if success:
		restoration_completed.emit(true)
	else:
		restoration_failed.emit(message)

func is_restoration_in_progress() -> bool:
	"""Verifica si hay una restauración en curso"""
	return is_restoration_active

func get_current_state() -> RestorationState:
	"""Obtiene el estado actual de la restauración"""
	return current_state

func _synchronize_all_groups():
	"""Ejecuta sincronización de grupos usando GroupSynchronizer"""
	print("UnifiedPuzzleRestoration: Inicializando sincronización de grupos...")
	
	# Crear e inicializar el sincronizador de grupos
	var group_synchronizer = preload("res://Scripts/Autoload/GroupSynchronizer.gd").new()
	group_synchronizer.initialize(puzzle_game, piece_manager)
	
	# Ejecutar sincronización
	var problems_fixed = group_synchronizer.force_synchronize_all_groups()
	
	if problems_fixed > 0:
		print("UnifiedPuzzleRestoration: ✅ ", problems_fixed, " problemas de sincronización de grupos corregidos")
	else:
		print("UnifiedPuzzleRestoration: ✅ Todos los grupos están correctamente sincronizados")
	
	# Limpiar el sincronizador
	group_synchronizer.queue_free() 