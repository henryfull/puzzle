# PuzzleGame.gd
# Script completo en una sola escena de tipo Node2D

extends Node2D
class_name PuzzleGame

#
# === PROPIEDADES EXPORTADAS (modificables en el Inspector) ===
#
@export var image_path: String = "res://Assets/Images/arte1.jpg"
@export var columns: int = 2
@export var rows: int = 6
@export var max_scale_percentage: float = 0.8

#
# === VARIABLES INTERNAS ===
#
var puzzle_texture: Texture2D
var puzzle_width: float
var puzzle_height: float
var cell_size: Vector2
var puzzle_offset: Vector2

# Diccionario para saber qué pieza está en cada celda
# Clave: "col_fila" (String), Valor: referencia a la pieza
var grid := {}

# Array para almacenar todas las piezas creadas (por si se quiere iterar)
var pieces := []

# Para contar movimientos o verificar victoria
var total_moves: int = 0

#
# === SUBCLASE: Piece ===
# Representa cada pieza del puzzle como un Node2D con Sprite2D integrado.
#
class Piece:
	var node: Node2D
	var sprite: Sprite2D
	var original_pos: Vector2
	var current_cell: Vector2
	var dragging := false
	var drag_offset := Vector2.ZERO
	var group := []  # Lista de piezas en el mismo grupo

	func _init(_node: Node2D, _sprite: Sprite2D, _orig: Vector2):
		node = _node
		sprite = _sprite
		original_pos = _orig
		current_cell = _orig
		group = [self]  # Inicialmente, cada pieza está en su propio grupo

#
# === FUNCIÓN _ready(): se llama al iniciar la escena ===
#
func _ready():
	load_and_create_pieces()

#
# === CARGA DE IMAGEN Y CREACIÓN DE PIEZAS ===
#
func load_and_create_pieces():
	# 1) Cargar la textura
	puzzle_texture = load(image_path) if load(image_path) else null
	if puzzle_texture == null:
		push_warning("No se pudo cargar la imagen en: %s" % image_path)
		return

	# 2) Calcular escalado
	var viewport_size = get_viewport_rect().size
	var original_w = float(puzzle_texture.get_width())
	var original_h = float(puzzle_texture.get_height())

	# Factor para no exceder el max_scale_percentage
	var scale_factor_w = (viewport_size.x * max_scale_percentage) / original_w
	var scale_factor_h = (viewport_size.y * max_scale_percentage) / original_h
	var final_scale_factor = min(scale_factor_w, scale_factor_h, 1.0)

	puzzle_width = original_w * final_scale_factor
	puzzle_height = original_h * final_scale_factor

	# 3) Definir el tamaño de cada celda
	cell_size = Vector2(puzzle_width / columns, puzzle_height / rows)

	# 4) Calcular offset para centrar el puzzle
	puzzle_offset = (viewport_size - Vector2(puzzle_width, puzzle_height)) * 0.5

	# 5) Generar la lista de celdas y "desordenarlas" (solo columnas por fila)
	grid.clear()
	pieces.clear()
	var cell_list: Array[Vector2] = []
	for r in range(rows):
		for c in range(columns):
			cell_list.append(Vector2(c, r))

	# Desordenar completamente el cell_list
	cell_list.shuffle()

	# 6) Crear cada pieza (rows x columns)
	var index = 0
	for row_i in range(rows):
		for col_i in range(columns):
			# Crear un nodo2D para la pieza
			var piece_node = Node2D.new()
			add_child(piece_node)

			# Añadir un Sprite2D como hijo
			var sprite = Sprite2D.new()
			piece_node.add_child(sprite)

			# Definir la región original (SIN escalado) para la parte de la textura
			var piece_orig_w = original_w / columns
			var piece_orig_h = original_h / rows
			var region_rect = Rect2(
				col_i * piece_orig_w,
				row_i * piece_orig_h,
				piece_orig_w,
				piece_orig_h
			)

			# Crear un AtlasTexture para mostrar solo esa porción
			var atlas_tex = AtlasTexture.new()
			atlas_tex.atlas = puzzle_texture
			atlas_tex.region = region_rect
			sprite.texture = atlas_tex

			# Calcular y aplicar la escala para que la pieza se ajuste a la celda
			var scale_x = cell_size.x / piece_orig_w
			var scale_y = cell_size.y / piece_orig_h
			sprite.scale = Vector2(scale_x, scale_y)
			
			# Centrar el sprite en su nodo padre
			sprite.position = cell_size * 0.5

			# Crear la clase "Piece"
			var piece_obj = Piece.new(piece_node, sprite, Vector2(col_i, row_i))
			pieces.append(piece_obj)

			# Posición inicial: la celda "desordenada"
			var random_cell = cell_list[index]
			index += 1

			# Ubicar la pieza en pantalla
			var piece_pos = puzzle_offset + random_cell * cell_size
			piece_node.position = piece_pos

			# Registrar en grid
			set_piece_at(random_cell, piece_obj)

	# Activar la captura de eventos de mouse a nivel global
	# (Podrías usar _input() o unhandled_input(), en este ejemplo iremos con _unhandled_input)
	set_process_unhandled_input(true)

#
# === GESTIÓN DE EVENTOS DE RATÓN / TECLADO ===
#
func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_pos = event.position
			var clicked_piece = null
			
			# Encontrar la pieza clickeada
			for piece_obj in pieces:
				if is_mouse_over_piece(piece_obj, mouse_pos):
					clicked_piece = piece_obj
					break
			
			if clicked_piece:
				# Obtener el líder del grupo
				var group_leader = get_group_leader(clicked_piece)
				
				# Mover todo el grupo desde cualquier pieza
				for p in group_leader.group:
					p.dragging = true
					p.drag_offset = p.node.global_position - mouse_pos
					p.node.z_index = 9999
		else:
			# Al soltar, colocar todo el grupo
			var dragging_piece = null
			for piece_obj in pieces:
				if piece_obj.dragging:
					dragging_piece = piece_obj
					break
			
			if dragging_piece:
				var group_leader = get_group_leader(dragging_piece)
				for p in group_leader.group:
					p.dragging = false
					p.node.z_index = 0
				place_group(group_leader)
				total_moves += 1
				check_victory()

	elif event is InputEventMouseMotion:
		# Mover todo el grupo junto
		for piece_obj in pieces:
			if piece_obj.dragging:
				var group_leader = get_group_leader(piece_obj)
				var delta = event.relative
				for p in group_leader.group:
					p.node.global_position += delta
				break

#
# === DETECCIÓN DE CLIC SOBRE LA PIEZA ===
#
func is_mouse_over_piece(piece_obj: Piece, mouse_pos: Vector2) -> bool:
	# Revisamos si el mouse está sobre el sprite
	var sprite = piece_obj.sprite
	if sprite.texture == null:
		return false

	# Convertir mouse_pos a espacio local de la pieza
	var local_pos = piece_obj.node.to_local(mouse_pos)
	var tex_rect = Rect2(sprite.position - sprite.texture.get_size() * sprite.scale * 0.5,
						 sprite.texture.get_size() * sprite.scale)
	return tex_rect.has_point(local_pos)

#
# === COLOCAR LA PIEZA (SNAP A CELDA) ===
#
func place_piece(piece_obj: Piece):
	# 1) Calcular la celda según la posición actual
	var mouse_px = piece_obj.node.global_position - puzzle_offset
	var cell_x = int(round(mouse_px.x / cell_size.x))
	var cell_y = int(round(mouse_px.y / cell_size.y))

	# Clampeamos para que no se salga de la grid
	cell_x = clamp(cell_x, 0, columns - 1)
	cell_y = clamp(cell_y, 0, rows - 1)
	var new_cell = Vector2(cell_x, cell_y)

	# 2) Ver si hay otra pieza en esa celda
	var occupant = get_piece_at(new_cell)
	if occupant != null and occupant != piece_obj:
		# Verificar si pueden fusionarse
		if are_pieces_mergeable(piece_obj, occupant):
			merge_pieces(piece_obj, occupant)
			return
		else:
			swap_pieces(piece_obj, occupant)
			return

	# 3) Si no hay ocupante, simplemente colocar la pieza
	remove_piece_at(piece_obj.current_cell)
	set_piece_at(new_cell, piece_obj)
	piece_obj.node.position = puzzle_offset + new_cell * cell_size

	# 4) Fusionar con piezas adyacentes, si es posible
	var adjacent = find_adjacent_pieces(piece_obj, new_cell)
	for adj in adjacent:
		if are_pieces_mergeable(piece_obj, adj):
			merge_pieces(piece_obj, adj)

func find_adjacent_pieces(piece: Piece, cell: Vector2) -> Array:
	var adjacent = []
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	
	for dir in directions:
		var check_cell = cell + dir
		if check_cell.x < 0 or check_cell.x >= columns or check_cell.y < 0 or check_cell.y >= rows:
			continue
		var other = get_piece_at(check_cell)
		if other != null and other != piece and not (other in piece.group):
			adjacent.append(other)
	
	return adjacent

func are_pieces_mergeable(piece1: Piece, piece2: Piece) -> bool:
	# Verificar si las piezas son adyacentes en su posición original
	var diff = piece2.original_pos - piece1.original_pos
	var are_adjacent = (abs(diff.x) == 1 and diff.y == 0) or (abs(diff.y) == 1 and diff.x == 0)
	
	# También verificar que sus posiciones actuales coincidan aproximadamente con la diferencia original
	if are_adjacent:
		var current_diff = get_cell_of_piece(piece2) - get_cell_of_piece(piece1)
		return abs(current_diff.x - diff.x) < 0.1 and abs(current_diff.y - diff.y) < 0.1
	return false

#
# === INTERCAMBIAR DOS PIEZAS ===
#
func swap_pieces(a: Piece, b: Piece):
	var cell_a = a.current_cell
	var cell_b = b.current_cell

	remove_piece_at(cell_a)
	remove_piece_at(cell_b)

	set_piece_at(cell_b, a)
	set_piece_at(cell_a, b)

	# Reposicionar
	a.node.position = puzzle_offset + cell_b * cell_size
	b.node.position = puzzle_offset + cell_a * cell_size

#
# === GRID: GET/SET/REMOVE PIEZA EN CELDA ===
#
func cell_key(cell: Vector2) -> String:
	return "%d_%d" % [int(cell.x), int(cell.y)]

func set_piece_at(cell: Vector2, piece_obj: Piece):
	grid[cell_key(cell)] = piece_obj
	piece_obj.current_cell = cell

func get_piece_at(cell: Vector2) -> Piece:
	return grid.get(cell_key(cell), null)

func remove_piece_at(cell: Vector2):
	grid.erase(cell_key(cell))

#
# === OBTENER LA CELDA DE UNA PIEZA POR SU POSICIÓN ===
#
func get_cell_of_piece(piece_obj: Piece) -> Vector2:
	var px = piece_obj.node.global_position.x - puzzle_offset.x
	var py = piece_obj.node.global_position.y - puzzle_offset.y
	var cx = int(round(px / cell_size.x))
	var cy = int(round(py / cell_size.y))
	return Vector2(cx, cy)

#
# === (OPCIONAL) LÓGICA DE FUSIÓN O VICTORIA ===
#
# Si quisieras fusionar piezas o verificar la victoria,
# podrías añadir funciones aquí que revisen celdas adyacentes
# y unan las piezas en un solo "grupo".
#

func merge_pieces(piece1: Piece, piece2: Piece):
	# Combinar los grupos
	var new_group = []
	new_group.append_array(piece1.group)
	for p in piece2.group:
		if not (p in new_group):
			new_group.append(p)
	
	# Actualizar el grupo en todas las piezas
	for p in new_group:
		p.group = new_group
		# Asegurar que la posición es correcta
		var offset = p.original_pos - piece1.original_pos
		var target_cell = piece1.current_cell + offset
		p.node.position = puzzle_offset + target_cell * cell_size
		set_piece_at(target_cell, p)

func place_group(piece: Piece):
	# Calcular la celda destino para la pieza principal (líder)
	var leader = piece
	var target_cell = get_cell_of_piece(leader)
	target_cell.x = clamp(target_cell.x, 0, columns - 1)
	target_cell.y = clamp(target_cell.y, 0, rows - 1)
	
	# Liberar las celdas ocupadas por las piezas del grupo
	for p in piece.group:
		remove_piece_at(p.current_cell)
	
	# Colocar cada pieza del grupo en su posición relativa
	for p in piece.group:
		var offset = p.original_pos - leader.original_pos
		var p_target = target_cell + offset
		var occupant = get_piece_at(p_target)
		if occupant != null and not (occupant in piece.group):
			# Realizar el intercambio: colocar p en p_target y mover el occupant a la celda antigua de p
			var old_cell = p.current_cell
			remove_piece_at(occupant.current_cell)
			remove_piece_at(old_cell)
			set_piece_at(p_target, p)
			set_piece_at(old_cell, occupant)
			p.node.position = puzzle_offset + p_target * cell_size
			occupant.node.position = puzzle_offset + old_cell * cell_size
		else:
			set_piece_at(p_target, p)
			p.node.position = puzzle_offset + p_target * cell_size
	
	# Intentar fusionar el grupo con piezas adyacentes fuera del grupo
	var merged = true
	while merged:
		merged = false
		for p in piece.group.duplicate():
			var adjacent = find_adjacent_pieces(p, p.current_cell)
			for adj in adjacent:
				if are_pieces_mergeable(p, adj):
					merge_pieces(p, adj)
					merged = true
					break
			if merged:
				break

func check_victory():
	for piece_obj in pieces:
		if piece_obj.current_cell != piece_obj.original_pos:
			return
	get_tree().change_scene_to_file("res://Scenes/VictoryScreen.tscn")

# Agregar una nueva función para obtener el líder del grupo
func get_group_leader(piece: Piece) -> Piece:
	if piece.group.size() > 0:
		# Devolver la pieza con la posición original más baja (arriba-izquierda)
		var leader = piece.group[0]
		for p in piece.group:
			if p.original_pos.y < leader.original_pos.y or \
			   (p.original_pos.y == leader.original_pos.y and p.original_pos.x < leader.original_pos.x):
				leader = p
		return leader
	return piece
