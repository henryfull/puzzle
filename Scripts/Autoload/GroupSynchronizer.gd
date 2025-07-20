# GroupSynchronizer.gd
# Sistema especializado para detectar y corregir desincronizaciones en grupos de piezas
# Soluciona el problema donde piezas del mismo grupo aparecen en lugares lejanos

extends Node
class_name GroupSynchronizer

var puzzle_game: Node
var piece_manager: Node

func initialize(game: Node, manager: Node):
	"""Inicializa el sincronizador de grupos"""
	puzzle_game = game
	piece_manager = manager
	print("GroupSynchronizer: Sistema inicializado")

func detect_and_fix_group_desynchronization() -> int:
	"""
	Detecta y corrige desincronizaciones en grupos
	Retorna el número de problemas encontrados y corregidos
	"""
	print("GroupSynchronizer: 🔍 Detectando desincronizaciones en grupos...")
	
	var problems_found = 0
	var groups_processed = {}
	
	# Obtener todas las piezas
	var pieces = piece_manager.get_pieces()
	
	# Procesar cada grupo único
	for piece_obj in pieces:
		if piece_obj.group.size() <= 1:
			continue  # Saltar piezas individuales
		
		# Usar el primer elemento del grupo como identificador único
		var group_leader = piece_manager.get_group_leader(piece_obj)
		var group_id = group_leader.node.get_instance_id()
		
		if group_id in groups_processed:
			continue  # Ya procesamos este grupo
		
		groups_processed[group_id] = true
		
		# Verificar si el grupo tiene desincronización
		var desync_issues = _analyze_group_synchronization(group_leader.group)
		
		if desync_issues > 0:
			print("GroupSynchronizer: ⚠️ Grupo con ", group_leader.group.size(), " piezas tiene ", desync_issues, " problemas")
			_fix_group_synchronization(group_leader.group)
			problems_found += desync_issues
	
	print("GroupSynchronizer: ✅ Análisis completado - ", problems_found, " problemas corregidos")
	return problems_found

func _analyze_group_synchronization(group: Array) -> int:
	"""Analiza un grupo específico buscando problemas de sincronización"""
	var issues = 0
	
	if group.size() <= 1:
		return 0
	
	# Problema 1: Verificar si las piezas están muy alejadas visualmente
	var visual_positions = []
	var logical_positions = []
	
	for piece in group:
		visual_positions.append(piece.node.position)
		logical_positions.append(piece.current_cell)
	
	# Calcular distancias visuales entre piezas del grupo
	var max_visual_distance = 0.0
	for i in range(visual_positions.size()):
		for j in range(i + 1, visual_positions.size()):
			var distance = visual_positions[i].distance_to(visual_positions[j])
			max_visual_distance = max(max_visual_distance, distance)
	
	# Calcular distancias lógicas entre piezas del grupo
	var max_logical_distance = 0.0
	for i in range(logical_positions.size()):
		for j in range(i + 1, logical_positions.size()):
			var distance = logical_positions[i].distance_to(logical_positions[j])
			max_logical_distance = max(max_logical_distance, distance)
	
	# Si las distancias son muy diferentes, hay desincronización
	var puzzle_data = puzzle_game.get_puzzle_data()
	var cell_size = puzzle_data["cell_size"].x  # Asumiendo celdas cuadradas
	
	var expected_visual_distance = max_logical_distance * cell_size
	var distance_discrepancy = abs(max_visual_distance - expected_visual_distance)
	
	# Problema: Las piezas están muy alejadas visualmente para la distancia lógica que deberían tener
	if distance_discrepancy > cell_size * 2:  # Tolerancia de 2 celdas
		print("GroupSynchronizer: 📏 Discrepancia de distancia - Visual: ", max_visual_distance, " vs Esperada: ", expected_visual_distance)
		issues += 1
	
	# Problema 2: Verificar si current_cell y posición visual no coinciden
	for piece in group:
		var expected_visual_pos = puzzle_data["offset"] + piece.current_cell * puzzle_data["cell_size"]
		var actual_visual_pos = piece.node.position
		var position_error = expected_visual_pos.distance_to(actual_visual_pos)
		
		if position_error > cell_size * 0.5:  # Tolerancia de media celda
			print("GroupSynchronizer: 📍 Pieza ", piece.order_number, " desincronizada - Error: ", position_error)
			issues += 1
	
	return issues

func _fix_group_synchronization(group: Array):
	"""Corrige la sincronización de un grupo"""
	print("GroupSynchronizer: 🔧 Corrigiendo sincronización de grupo con ", group.size(), " piezas")
	
	if group.size() <= 1:
		return
	
	var puzzle_data = puzzle_game.get_puzzle_data()
	var leader = piece_manager.get_group_leader(group[0])
	
	# ESTRATEGIA: Usar current_cell como fuente de verdad y corregir posiciones visuales
	
	# Paso 1: Verificar que todas las piezas del grupo tienen current_cell válidos
	for piece in group:
		if piece.current_cell == Vector2(-1, -1):
			print("GroupSynchronizer: ⚠️ Pieza ", piece.order_number, " sin current_cell válido, calculando...")
			piece.current_cell = piece_manager.get_cell_of_piece(piece)
	
	# Paso 2: Verificar que el grupo tiene celdas contiguas (como debería ser)
	var group_is_contiguous = _verify_group_contiguity(group)
	
	if not group_is_contiguous:
		print("GroupSynchronizer: ⚠️ Grupo no es contiguo, reagrupando...")
		_regroup_scattered_pieces(group)
	
	# Paso 3: Sincronizar posiciones visuales con current_cell
	_sync_visual_positions_to_cells(group)
	
	# Paso 4: Actualizar información visual del grupo
	_update_group_visuals(group)

func _verify_group_contiguity(group: Array) -> bool:
	"""Verifica si las piezas de un grupo son contiguas en el grid"""
	if group.size() <= 1:
		return true
	
	var cells = []
	for piece in group:
		cells.append(piece.current_cell)
	
	# Verificar que cada celda tiene al menos una vecina en el grupo
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	
	for cell in cells:
		var has_neighbor = false
		for dir in directions:
			var neighbor_cell = cell + dir
			if neighbor_cell in cells:
				has_neighbor = true
				break
		
		if not has_neighbor and cells.size() > 1:
			print("GroupSynchronizer: 📍 Celda aislada detectada: ", cell)
			return false
	
	return true

func _regroup_scattered_pieces(group: Array):
	"""Reagrupa piezas dispersas para que estén contiguas"""
	print("GroupSynchronizer: 🔀 Reagrupando piezas dispersas...")
	
	if group.size() <= 1:
		return
	
	var leader = group[0]
	var leader_cell = leader.current_cell
	
	# Encontrar posiciones contiguas alrededor del líder
	var directions = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var available_positions = []
	
	# Buscar celdas libres alrededor del líder
	for radius in range(1, group.size()):
		for dir in directions:
			var test_cell = leader_cell + dir * radius
			
			# Verificar que está dentro de los límites
			if test_cell.x >= 0 and test_cell.x < piece_manager.current_columns and test_cell.y >= 0 and test_cell.y < piece_manager.current_rows:
				var occupant = piece_manager.get_piece_at(test_cell)
				if occupant == null or occupant in group:
					available_positions.append(test_cell)
	
	# Reubicar piezas del grupo (excepto el líder) en posiciones contiguas
	var position_index = 0
	for i in range(1, group.size()):  # Empezar desde 1 para saltar el líder
		if position_index < available_positions.size():
			var piece = group[i]
			var new_cell = available_positions[position_index]
			
			# Limpiar posición anterior
			piece_manager.remove_piece_at(piece.current_cell)
			
			# Actualizar current_cell
			piece.current_cell = new_cell
			
			# Registrar en nueva posición
			piece_manager.set_piece_at(new_cell, piece)
			
			print("GroupSynchronizer: Pieza ", piece.order_number, " reubicada a ", new_cell)
			position_index += 1

func _sync_visual_positions_to_cells(group: Array):
	"""Sincroniza las posiciones visuales con las celdas lógicas"""
	print("GroupSynchronizer: 🎯 Sincronizando posiciones visuales...")
	
	var puzzle_data = puzzle_game.get_puzzle_data()
	
	for piece in group:
		var expected_position = puzzle_data["offset"] + piece.current_cell * puzzle_data["cell_size"]
		var current_position = piece.node.position
		var position_error = expected_position.distance_to(current_position)
		
		if position_error > 5.0:  # Solo corregir si el error es significativo
			print("GroupSynchronizer: 📍 Corrigiendo posición de pieza ", piece.order_number, " - Error: ", position_error)
			piece.node.position = expected_position
			
			# También asegurar que el sprite interno esté centrado
			if piece.node.has_node("Sprite2D"):
				piece.node.get_node("Sprite2D").position = Vector2.ZERO

func _update_group_visuals(group: Array):
	"""Actualiza los efectos visuales del grupo después de la sincronización"""
	print("GroupSynchronizer: 🎨 Actualizando visuales de grupo...")
	
	var group_id = group[0].node.get_instance_id()
	
	for piece in group:
		# Actualizar ID de grupo
		if piece.node.has_method("set_group_id"):
			piece.node.set_group_id(group_id)
		
		# Actualizar pieces_group
		if piece.node.has_method("update_pieces_group"):
			piece.node.update_pieces_group(group)
		
		# Actualizar efectos visuales
		if piece.node.has_method("update_all_visuals"):
			piece.node.update_all_visuals()
	
	# Actualizar bordes de grupo
	if piece_manager.has_method("update_all_group_borders"):
		piece_manager.update_all_group_borders()

func force_synchronize_all_groups():
	"""Función pública para forzar sincronización de todos los grupos"""
	print("GroupSynchronizer: 🚀 FORZANDO SINCRONIZACIÓN DE TODOS LOS GRUPOS")
	
	var problems_fixed = detect_and_fix_group_desynchronization()
	
	if problems_fixed > 0:
		print("GroupSynchronizer: ✅ ", problems_fixed, " problemas de sincronización corregidos")
	else:
		print("GroupSynchronizer: ✅ Todos los grupos están correctamente sincronizados")
	
	return problems_fixed 