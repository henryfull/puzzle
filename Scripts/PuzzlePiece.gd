extends Node2D

var puzzle_image: Texture
var fragment_region: Rect2
var original_grid_position: Vector2   # (columna, fila) en la imagen original
var cell_size: Vector2               # Tamaño de cada "celda" (ancho y alto)

var dragging: bool = false
var drag_offset: Vector2
var pieces_group: Array = []

func _ready():
	set_process_input(true)

func set_piece_data(image: Texture, region: Rect2, grid_pos: Vector2, _cell_size: Vector2):
	puzzle_image = image
	fragment_region = region
	original_grid_position = grid_pos
	cell_size = _cell_size
	pieces_group = [self]  # Cada pieza comienza siendo un grupo individual
	update_visual()

func update_visual():
	if has_node("Sprite2D"):
		var sprite = get_node("Sprite2D") as Sprite2D
		var atlas = AtlasTexture.new()
		atlas.atlas = puzzle_image
		atlas.region = fragment_region
		sprite.texture = atlas

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = global_position - event.position
			self.move_to_front()  # Sube esta pieza al frente (z-index mayor)
		else:
			if dragging:
				dragging = false
				# Al soltar, pedimos al padre que coloque la pieza en la celda
				if get_parent().has_method("place_piece"):
					get_parent().place_piece(self)
				# Notificamos que se ha movido
				if get_parent().has_method("on_piece_moved"):
					get_parent().on_piece_moved()

	elif event is InputEventMouseMotion:
		if dragging:
			var new_position = event.position + drag_offset
			# Limitar la posición a los límites del tablero
			if get_parent().has_method("get_grid_boundaries"):
				var bounds = get_parent().get_grid_boundaries()
				new_position.x = clamp(new_position.x, bounds.min_x, bounds.max_x)
				new_position.y = clamp(new_position.y, bounds.min_y, bounds.max_y)
			global_position = new_position


# Método para notificar a las piezas vecinas que se ajusten a la cuadricula
func notify_neighbors_to_snap():
	# Recorremos todos los nodos hermanos (las demás piezas)
	for other in get_parent().get_children():
		if other == self or (other is Node2D and other in pieces_group):
			continue
		if not other.has_method("snap_to_grid"):
			continue
		# Calculamos la celda actual (redondeada) de ambas piezas
		var my_cell = Vector2(round(global_position.x / cell_size.x), round(global_position.y / cell_size.y))
		var other_cell = Vector2(round(other.global_position.x / cell_size.x), round(other.global_position.y / cell_size.y))
		# Si la pieza vecina está adyacente (o incluso en conflicto) con la celda que yo ocupo,
		# la notificamos para que se "snapee" a su celda más cercana.
		if (other_cell - my_cell).length() <= 1:
			other.snap_to_grid()

# Revisa si en celdas adyacentes existen piezas que deben fusionarse
func check_connections():
	# Se recorre entre todos los nodos hermanos
	for other in get_parent().get_children():
		if other == self or (other is Node2D and other in pieces_group):
			continue
		if not other.has_method("set_piece_data"):
			continue
		# Para cada pieza del grupo, obtenemos la celda (índice entero) en la que está
		for piece in pieces_group:
			var my_cell = Vector2(
				round(piece.global_position.x / cell_size.x),
				round(piece.global_position.y / cell_size.y)
			)
			var other_cell = Vector2(
				round(other.global_position.x / cell_size.x),
				round(other.global_position.y / cell_size.y)
			)
			# Calculamos la diferencia en índices
			var diff = other_cell - my_cell
			# Verificamos que sean adyacentes (sin diagonales)
			if (abs(diff.x) == 1 and diff.y == 0) or (abs(diff.y) == 1 and diff.x == 0):
				# Comprobamos que en la posición original también sean vecinos
				var orig_diff = other.original_grid_position - piece.original_grid_position
				if diff == orig_diff:
					merge_with(other)

# Fusiona dos grupos de piezas
func merge_with(other):
	# Agregar al grupo actual todas las piezas del otro grupo que no estén ya
	for piece in other.pieces_group:
		if piece not in pieces_group:
			pieces_group.append(piece)
	# Actualizar la referencia del grupo en cada pieza
	for piece in pieces_group:
		piece.pieces_group = pieces_group
	# Reacomodar las posiciones para que queden en la cuadricula relativa a la pieza de referencia (self)
	for piece in pieces_group:
		var diff = piece.original_grid_position - self.original_grid_position
		piece.global_position = self.global_position + diff * cell_size
