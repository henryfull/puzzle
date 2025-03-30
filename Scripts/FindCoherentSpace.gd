# FindCoherentSpace.gd
# Clase de utilidad para encontrar espacios coherentes para grupos de piezas

class_name FindCoherentSpace

# Función para encontrar un espacio coherente para un grupo
static func find_space_for_group(grid, group, avoid_cells = [], columns = 0, rows = 0):
	# Primero, identificar al líder del grupo
	var leader = null
	for p in group:
		if leader == null or (p.original_pos.y < leader.original_pos.y or 
				(p.original_pos.y == leader.original_pos.y and p.original_pos.x < leader.original_pos.x)):
			leader = p
	
	# Si no se especificaron columnas o filas, usar los valores del proyecto
	if columns <= 0:
		columns = GLOBAL.columns
	if rows <= 0:
		rows = GLOBAL.rows
	
	# Recopilar la estructura relativa de las piezas
	var pieces_layout = []
	for p in group:
		var offset = p.original_pos - leader.original_pos
		pieces_layout.append(offset)
	
	# Recorrer todo el tablero buscando un espacio donde quepa el grupo
	for row in range(rows):
		for col in range(columns):
			var base_cell = Vector2(col, row)
			var can_place = true
			var target_cells = []
			
			# Verificar cada posición relativa
			for offset in pieces_layout:
				var check_cell = base_cell + offset
				
				# Verificar límites
				if check_cell.x < 0 or check_cell.x >= columns or check_cell.y < 0 or check_cell.y >= rows:
					can_place = false
					break
				
				# Verificar si la celda está libre y no en la lista de celdas a evitar
				var cell_key_str = "%d_%d" % [int(check_cell.x), int(check_cell.y)]
				if grid.has(cell_key_str) or check_cell in avoid_cells:
					can_place = false
					break
				
				target_cells.append(check_cell)
			
			# Si encontramos un espacio válido, devolver las celdas
			if can_place:
				return target_cells
	
	# Si no encontramos un espacio, devolver un array vacío
	return []
