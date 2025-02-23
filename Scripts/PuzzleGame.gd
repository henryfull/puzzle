extends Node2D

@export var image_path: String = "res://Assets/Images/paisaje1.jpg"
@export var columns: int = 2
@export var rows: int = 4

var total_moves: int = 0
var puzzle_completed: bool = false

var cell_size: Vector2
var grid = {}  # clave "col_fila" -> pieza

# Offset donde se "colocará" el puzzle para centrarlo en la ventana
var puzzle_offset: Vector2 = Vector2.ZERO

func _ready():
	load_puzzle()

func load_puzzle():
	var puzzle_image = load(image_path) as Texture
	if not puzzle_image:
		printerr("Error al cargar la imagen: ", image_path)
		return

	# -----------------------------------------------------
	# 1) Calcular escala para que la imagen no exceda la ventana
	# -----------------------------------------------------
	var viewport_size = get_viewport().get_visible_rect().size
	var original_w = float(puzzle_image.get_width())
	var original_h = float(puzzle_image.get_height())

	# Factor de escala para que la imagen quepa en la ventana
	var scale_factor = min(viewport_size.x / original_w, viewport_size.y / original_h)
	# Si la imagen ya es más pequeña que la ventana, scale_factor >= 1 (no se agranda).
	# Si es más grande, se reduce.

	var scaled_w = original_w * scale_factor
	var scaled_h = original_h * scale_factor

	# -----------------------------------------------------
	# 2) Dividir la imagen en columns x rows
	# -----------------------------------------------------
	var piece_width = scaled_w / columns
	var piece_height = scaled_h / rows
	cell_size = Vector2(piece_width, piece_height)

	# -----------------------------------------------------
	# 3) Calcular el offset para centrar el puzzle escalado
	# -----------------------------------------------------
	# El tamaño total del puzzle tras escalar es (scaled_w, scaled_h).
	# Lo centramos en la ventana:
	puzzle_offset = (viewport_size - Vector2(scaled_w, scaled_h)) * 0.5

	var piece_scene = load("res://Scenes/PuzzlePiece.tscn") as PackedScene
	if not piece_scene:
		printerr("Error al cargar PuzzlePiece.tscn")
		return

	grid.clear()

	# Generar lista de todas las celdas (col, row) y desordenarlas
	var grid_positions = []
	for row_i in range(rows):
		for col_i in range(columns):
			grid_positions.append(Vector2(col_i, row_i))
	grid_positions.shuffle()

	var index = 0

	# -----------------------------------------------------
	# 4) Instanciar cada pieza
	# -----------------------------------------------------
	for row_i in range(rows):
		for col_i in range(columns):
			var piece_instance = piece_scene.instantiate()

			# Region en la imagen original (SIN ESCALAR), para que se vea bien
			# en el Sprite2D:
			var original_piece_w = original_w / columns
			var original_piece_h = original_h / rows
			var region = Rect2(
				col_i * original_piece_w,
				row_i * original_piece_h,
				original_piece_w,
				original_piece_h
			)

			piece_instance.set_piece_data(
				puzzle_image,
				region,
				Vector2(col_i, row_i),  # posición original en la cuadrícula
				cell_size
			)

			# Tomar una celda aleatoria de las disponibles
			var random_cell = grid_positions[index]
			index += 1

			# Posición inicial = offset de centrado + (celda * tamaño)
			piece_instance.position = puzzle_offset + random_cell * cell_size

			set_piece_at(random_cell, piece_instance)
			add_child(piece_instance)

func cell_key(cell: Vector2) -> String:
	return str(int(cell.x)) + "_" + str(int(cell.y))

func get_piece_at(cell: Vector2):
	return grid.get(cell_key(cell), null)

func set_piece_at(cell: Vector2, piece):
	grid[cell_key(cell)] = piece

func remove_piece_at(cell: Vector2):
	grid.erase(cell_key(cell))

func get_grid_boundaries() -> Dictionary:
	# Límite izquierdo/derecho en píxeles
	var min_x = puzzle_offset.x
	var max_x = puzzle_offset.x + (columns * cell_size.x) - cell_size.x
	if max_x < min_x:
		max_x = min_x  # por si columns=1

	# Límite superior/inferior en píxeles
	# NOTA: Si el puzzle se expande en filas, max_y irá cambiando,
	#       pero aquí lo calculamos con rows actual. Si se "empujan"
	#       piezas, podrían salir de la vista.
	var max_row = rows - 1
	for key in grid.keys():
		var parts = key.split("_")
		var r = int(parts[1])
		if r > max_row:
			max_row = r

	var min_y = puzzle_offset.y
	var max_y = puzzle_offset.y + (max_row * cell_size.y)

	return {
		"min_x": min_x, "max_x": max_x,
		"min_y": min_y, "max_y": max_y
	}

func place_piece(piece):
	var target_cell = Vector2(
		round((piece.global_position.x - puzzle_offset.x) / cell_size.x),
		round((piece.global_position.y - puzzle_offset.y) / cell_size.y)
	)

	target_cell.x = clamp(target_cell.x, 0, columns - 1)
	if target_cell.y >= rows:
		rows = int(target_cell.y) + 1

	var adjacent_pieces = find_adjacent_pieces(piece, target_cell)
	if adjacent_pieces.size() > 0:
		for adj_piece in adjacent_pieces:
			if are_mergeable(piece, adj_piece):
				merge_pieces(piece, adj_piece)
				return

	for p in piece.pieces_group:
		var diff = p.original_grid_position - piece.original_grid_position
		var p_target = target_cell + diff

		var occupant = get_piece_at(p_target)
		if occupant != null and occupant not in piece.pieces_group:
			push_piece(p_target)

		remove_piece_at(get_cell_of_piece(p))
		# Asignar nueva posición en píxeles, sumando el offset de centrado
		p.global_position = puzzle_offset + p_target * cell_size
		set_piece_at(p_target, p)

func find_adjacent_pieces(piece, cell: Vector2) -> Array:
	var adjacent = []
	var directions = [
		Vector2(0, -1),  # arriba
		Vector2(0, 1),   # abajo
		Vector2(-1, 0),  # izquierda
		Vector2(1, 0),   # derecha
	]

	for dir in directions:
		var check_cell = cell + dir
		var other = get_piece_at(check_cell)
		if other != null and other != piece and not (other in piece.pieces_group):
			adjacent.append(other)
	return adjacent

func are_mergeable(piece1, piece2) -> bool:
	var diff = piece2.original_grid_position - piece1.original_grid_position
	# Adyacentes sin diagonales => x=±1, y=0 o x=0, y=±1
	if (abs(diff.x) == 1 and diff.y == 0) or (abs(diff.y) == 1 and diff.x == 0):
		return true
	return false

func merge_pieces(piece1, piece2):
	var new_group = []
	new_group.append_array(piece1.pieces_group)
	for p in piece2.pieces_group:
		if p not in new_group:
			new_group.append(p)

	for p in new_group:
		p.pieces_group = new_group

	var base_cell = get_cell_of_piece(piece1)
	for p in new_group:
		var diff = p.original_grid_position - piece1.original_grid_position
		remove_piece_at(get_cell_of_piece(p))
		p.global_position = puzzle_offset + (base_cell + diff) * cell_size
		set_piece_at(base_cell + diff, p)

func get_cell_of_piece(piece) -> Vector2:
	var px = piece.global_position.x - puzzle_offset.x
	var py = piece.global_position.y - puzzle_offset.y
	return Vector2(round(px / cell_size.x), round(py / cell_size.y))

func push_piece(cell: Vector2):
	var occupant = get_piece_at(cell)
	if occupant == null:
		return
	var new_cell = cell + Vector2(0, 1)
	if new_cell.y >= rows:
		rows = int(new_cell.y) + 1

	if get_piece_at(new_cell) != null:
		push_piece(new_cell)

	remove_piece_at(cell)
	occupant.global_position = puzzle_offset + new_cell * cell_size
	set_piece_at(new_cell, occupant)

func on_piece_moved():
	total_moves += 1
	print("Movimiento realizado. Total movimientos: ", total_moves)
	check_victory()

func check_victory():
	var total_expected = rows * columns
	for child in get_children():
		if child is Node2D and child.has_method("pieces_group"):
			if child.pieces_group.size() == total_expected:
				on_puzzle_completed()
				break

func on_puzzle_completed():
	puzzle_completed = true
	print("Puzzle completado en ", total_moves, " movimientos.")
	# Aquí podrías cambiar de escena o mostrar un popup
