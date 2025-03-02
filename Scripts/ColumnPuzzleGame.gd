extends Node2D
class_name ColumnPuzzleGame

# === PROPIEDADES EXPORTADAS ===
@export var columns: int = 2
@export var initial_rows: int = 8
@export var cell_size: Vector2 = Vector2(100, 50)
@export var piece_scene_path: String = "res://Scenes/PuzzlePiece.tscn"
@export var background_color: Color = Color(0.2, 0.2, 0.2)
@export var grid_color: Color = Color(0.3, 0.3, 0.3)
@export var group_border_color: Color = Color(0.0, 0.8, 0.2, 0.5)
@export var group_border_width: float = 2.0

# === VARIABLES INTERNAS ===
var board = []  # Array bidimensional que representa el tablero
var pieces = []  # Lista de todas las piezas
var groups = []  # Lista de todos los grupos
var current_rows = 0  # Número actual de filas
var puzzle_offset = Vector2.ZERO  # Posición inicial del tablero
var dragging_group = null  # Grupo que se está arrastrando
var drag_offset = Vector2.ZERO  # Offset para el arrastre
var audio_move: AudioStreamPlayer
var audio_merge: AudioStreamPlayer

# === CLASE PIEZA ===
class Piece:
	var node: Node2D  # Nodo de Godot
	var id: int  # Identificador único
	var current_cell: Vector2  # Posición actual (columna, fila)
	var original_cell: Vector2  # Posición original
	var group = null  # Referencia al grupo al que pertenece
	
	func _init(_node: Node2D, _id: int, _cell: Vector2):
		node = _node
		id = _id
		current_cell = _cell
		original_cell = _cell
		
	func set_group(new_group):
		group = new_group

# === CLASE GRUPO ===
class Group:
	var id: int  # Identificador único
	var pieces = []  # Lista de piezas en el grupo
	var border: Line2D  # Borde visual del grupo
	var bounding_box = Rect2()  # Caja contenedora
	
	func _init(_id: int):
		id = _id
		border = Line2D.new()
		border.width = 2.0
		border.default_color = Color(0.0, 0.8, 0.2, 0.5)
		
	func add_piece(piece: Piece):
		if not piece in pieces:
			pieces.append(piece)
			piece.set_group(self)
			update_bounding_box()
			
	func remove_piece(piece: Piece):
		pieces.erase(piece)
		piece.set_group(null)
		if pieces.size() > 0:
			update_bounding_box()
			
	func update_bounding_box():
		if pieces.size() == 0:
			bounding_box = Rect2()
			return
			
		var min_col = INF
		var min_row = INF
		var max_col = -INF
		var max_row = -INF
		
		for piece in pieces:
			min_col = min(min_col, piece.current_cell.x)
			min_row = min(min_row, piece.current_cell.y)
			max_col = max(max_col, piece.current_cell.x)
			max_row = max(max_row, piece.current_cell.y)
			
		bounding_box = Rect2(min_col, min_row, max_col - min_col + 1, max_row - min_row + 1)
		update_border()
		
	func update_border():
		var points = []
		var rect = bounding_box
		
		# Crear los puntos del borde
		points.append(Vector2(rect.position.x, rect.position.y))
		points.append(Vector2(rect.position.x + rect.size.x, rect.position.y))
		points.append(Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y))
		points.append(Vector2(rect.position.x, rect.position.y + rect.size.y))
		points.append(Vector2(rect.position.x, rect.position.y))
		
		border.points = points
		
	func get_width() -> int:
		return int(bounding_box.size.x)
		
	func get_height() -> int:
		return int(bounding_box.size.y)
		
	func get_top_left() -> Vector2:
		return Vector2(bounding_box.position.x, bounding_box.position.y)

# === FUNCIONES PRINCIPALES ===
func _ready():
	initialize_audio()
	initialize_board()
	create_initial_pieces()
	set_process_unhandled_input(true)

func initialize_audio():
	audio_move = AudioStreamPlayer.new()
	audio_move.stream = load("res://Assets/Sounds/FX/bubble.wav")
	audio_move.bus = "SFX"
	add_child(audio_move)
	
	audio_merge = AudioStreamPlayer.new()
	audio_merge.stream = load("res://Assets/Sounds/FX/plop.mp3")
	audio_merge.bus = "SFX"
	add_child(audio_merge)

func initialize_board():
	# Calcular el offset para centrar el tablero
	var viewport_size = get_viewport_rect().size
	puzzle_offset = Vector2(
		(viewport_size.x - (columns * cell_size.x)) * 0.5,
		100  # Margen superior para dejar espacio a los botones
	)
	
	# Inicializar el tablero con filas iniciales
	board = []
	current_rows = initial_rows
	for _i in range(current_rows):
		var row = []
		for _j in range(columns):
			row.append(null)
		board.append(row)

func create_initial_pieces():
	var piece_scene = load(piece_scene_path)
	if not piece_scene:
		push_error("No se pudo cargar la escena de la pieza")
		return
		
	var piece_id = 0
	
	# Crear piezas iniciales (una por celda)
	for row in range(current_rows):
		for col in range(columns):
			var piece_node = piece_scene.instantiate()
			add_child(piece_node)
			
			# Configurar la pieza con un color aleatorio para distinguirlas
			var color = Color(randf(), randf(), randf())
			piece_node.set_color(color)
			
			# Crear objeto Piece
			var piece = Piece.new(piece_node, piece_id, Vector2(col, row))
			piece_id += 1
			pieces.append(piece)
			
			# Posicionar la pieza en el tablero
			var pos = cell_to_position(col, row)
			piece_node.position = pos
			
			# Registrar en el tablero
			board[row][col] = piece

func _draw():
	# Dibujar el fondo del tablero
	var board_rect = Rect2(
		puzzle_offset,
		Vector2(columns * cell_size.x, current_rows * cell_size.y)
	)
	draw_rect(board_rect, background_color, true)
	
	# Dibujar las líneas de la cuadrícula
	for row in range(current_rows + 1):
		var start = puzzle_offset + Vector2(0, row * cell_size.y)
		var end = start + Vector2(columns * cell_size.x, 0)
		draw_line(start, end, grid_color)
		
	for col in range(columns + 1):
		var start = puzzle_offset + Vector2(col * cell_size.x, 0)
		var end = start + Vector2(0, current_rows * cell_size.y)
		draw_line(start, end, grid_color)
	
	# Los bordes de los grupos se dibujan como nodos Line2D separados

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Iniciar arrastre
			var mouse_pos = event.position
			var piece = find_piece_at_position(mouse_pos)
			
			if piece:
				dragging_group = get_or_create_group_for_piece(piece)
				drag_offset = mouse_pos - cell_to_position(piece.current_cell.x, piece.current_cell.y)
				
				# Elevar las piezas del grupo
				for p in dragging_group.pieces:
					p.node.z_index = 10
		else:
			# Soltar el grupo
			if dragging_group:
				# Calcular la celda destino
				var mouse_pos = event.position
				var target_cell = position_to_cell(mouse_pos - drag_offset)
				
				# Intentar colocar el grupo
				place_group(dragging_group, target_cell.x, target_cell.y)
				
				# Restaurar z_index
				for p in dragging_group.pieces:
					p.node.z_index = 0
					
				dragging_group = null
				audio_move.play()
				
				# Verificar victoria
				check_victory()
	
	elif event is InputEventMouseMotion and dragging_group:
		# Mover el grupo mientras se arrastra
		var delta = event.relative
		for piece in dragging_group.pieces:
			piece.node.position += delta

# === FUNCIONES DE UTILIDAD ===
func cell_to_position(col: int, row: int) -> Vector2:
	return puzzle_offset + Vector2(col * cell_size.x, row * cell_size.y)

func position_to_cell(pos: Vector2) -> Vector2:
	var rel_pos = pos - puzzle_offset
	var col = int(rel_pos.x / cell_size.x)
	var row = int(rel_pos.y / cell_size.y)
	
	# Asegurar que esté dentro de los límites
	col = clamp(col, 0, columns - 1)
	row = clamp(row, 0, current_rows - 1)
	
	return Vector2(col, row)

func find_piece_at_position(pos: Vector2) -> Piece:
	var cell = position_to_cell(pos)
	
	# Verificar si la celda está dentro de los límites
	if cell.y >= 0 and cell.y < current_rows and cell.x >= 0 and cell.x < columns:
		return board[cell.y][cell.x]
	
	return null

func get_or_create_group_for_piece(piece: Piece) -> Group:
	if piece.group:
		return piece.group
		
	# Crear un nuevo grupo para la pieza
	var group = Group.new(groups.size())
	groups.append(group)
	add_child(group.border)
	
	# Añadir la pieza al grupo
	group.add_piece(piece)
	
	return group

func place_group(group: Group, target_col: int, target_row: int):
	var width = group.get_width()
	var height = group.get_height()
	var group_top_left = group.get_top_left()
	
	# Si el grupo se sale de las columnas, intentar en la siguiente fila
	if target_col + width > columns:
		if target_row + 1 < current_rows:
			place_group(group, 0, target_row + 1)
		else:
			add_row()
			place_group(group, 0, target_row + 1)
		return
	
	# Verificar si las celdas destino están libres o si hay que desplazar piezas
	var cells_to_check = []
	for r in range(height):
		for c in range(width):
			var check_row = target_row + r
			var check_col = target_col + c
			
			# Si necesitamos más filas, las añadimos
			while check_row >= current_rows:
				add_row()
			
			cells_to_check.append(Vector2(check_col, check_row))
	
	# Recolectar piezas que necesitan ser desplazadas
	var pieces_to_displace = []
	for cell in cells_to_check:
		var piece_at_cell = board[cell.y][cell.x]
		if piece_at_cell and not piece_at_cell in group.pieces:
			# Si la pieza pertenece a otro grupo, añadir todo el grupo
			if piece_at_cell.group:
				for p in piece_at_cell.group.pieces:
					if not p in pieces_to_displace and not p in group.pieces:
						pieces_to_displace.append(p)
			else:
				pieces_to_displace.append(piece_at_cell)
	
	# Desplazar las piezas afectadas
	for piece in pieces_to_displace:
		# Primero, quitar la pieza de su posición actual
		board[piece.current_cell.y][piece.current_cell.x] = null
		
		# Luego, intentar reubicarla
		var relocated = false
		
		# Intentar en la misma fila primero
		for c in range(columns):
			if c < target_col or c >= target_col + width:
				if board[piece.current_cell.y][c] == null:
					board[piece.current_cell.y][c] = piece
					piece.current_cell = Vector2(c, piece.current_cell.y)
					piece.node.position = cell_to_position(c, piece.current_cell.y)
					relocated = true
					break
		
		# Si no se pudo reubicar en la misma fila, intentar en filas inferiores
		if not relocated:
			var row_to_try = piece.current_cell.y + 1
			while not relocated:
				# Añadir fila si es necesario
				if row_to_try >= current_rows:
					add_row()
				
				for c in range(columns):
					if board[row_to_try][c] == null:
						board[row_to_try][c] = piece
						piece.current_cell = Vector2(c, row_to_try)
						piece.node.position = cell_to_position(c, row_to_try)
						relocated = true
						break
				
				row_to_try += 1
	
	# Ahora, colocar el grupo en su nueva posición
	for piece in group.pieces:
		# Calcular la nueva posición relativa al grupo
		var rel_pos = piece.current_cell - group_top_left
		var new_cell = Vector2(target_col + rel_pos.x, target_row + rel_pos.y)
		
		# Actualizar el tablero y la pieza
		if piece.current_cell.y < current_rows and piece.current_cell.x < columns:
			board[piece.current_cell.y][piece.current_cell.x] = null
		
		board[new_cell.y][new_cell.x] = piece
		piece.current_cell = new_cell
		piece.node.position = cell_to_position(new_cell.x, new_cell.y)
	
	# Actualizar el bounding box del grupo
	group.update_bounding_box()
	
	# Verificar si se pueden fusionar grupos
	check_for_mergeable_groups()

func add_row():
	var new_row = []
	for _i in range(columns):
		new_row.append(null)
	
	board.append(new_row)
	current_rows += 1
	
	# Redibujar el tablero
	queue_redraw()

func check_for_mergeable_groups():
	var merged = true
	
	while merged:
		merged = false
		
		# Verificar cada par de grupos
		for i in range(groups.size()):
			if i >= groups.size():
				break
				
			var group1 = groups[i]
			
			for j in range(i + 1, groups.size()):
				if j >= groups.size():
					break
					
				var group2 = groups[j]
				
				if can_merge_groups(group1, group2):
					merge_groups(group1, group2)
					merged = true
					audio_merge.play()
					break
			
			if merged:
				break

func can_merge_groups(group1: Group, group2: Group) -> bool:
	# Verificar si hay piezas adyacentes entre los grupos
	for piece1 in group1.pieces:
		for piece2 in group2.pieces:
			# Verificar si son adyacentes en su posición original
			var orig_diff = piece2.original_cell - piece1.original_cell
			var are_orig_adjacent = (abs(orig_diff.x) == 1 and orig_diff.y == 0) or (abs(orig_diff.y) == 1 and orig_diff.x == 0)
			
			# Verificar si son adyacentes en su posición actual
			var curr_diff = piece2.current_cell - piece1.current_cell
			var are_curr_adjacent = (abs(curr_diff.x) == 1 and curr_diff.y == 0) or (abs(curr_diff.y) == 1 and curr_diff.x == 0)
			
			# Si son adyacentes tanto en posición original como actual, pueden fusionarse
			if are_orig_adjacent and are_curr_adjacent:
				return true
	
	return false

func merge_groups(group1: Group, group2: Group):
	# Añadir todas las piezas del grupo2 al grupo1
	for piece in group2.pieces.duplicate():
		group1.add_piece(piece)
	
	# Eliminar el grupo2
	remove_child(group2.border)
	groups.erase(group2)
	
	# Actualizar el bounding box del grupo1
	group1.update_bounding_box()

func check_victory():
	# Verificar si todas las piezas están en su posición original
	for piece in pieces:
		if piece.current_cell != piece.original_cell:
			return false
	
	# Si llegamos aquí, todas las piezas están en su posición original
	print("¡Victoria!")
	# Aquí podrías cambiar a una escena de victoria
	get_tree().change_scene_to_file("res://Scenes/VictoryScreen.tscn")
	return true

# === FUNCIONES PARA DEPURACIÓN ===
func print_board():
	print("Estado actual del tablero:")
	for row in range(current_rows):
		var row_str = ""
		for col in range(columns):
			var piece = board[row][col]
			if piece:
				row_str += "[" + str(piece.id) + "]"
			else:
				row_str += "[ ]"
		print(row_str)

# === FUNCIONES PARA LOS BOTONES ===
func _on_volver_pressed():
	# Volver a la pantalla de selección de puzzles
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn")

func _on_reiniciar_pressed():
	# Reiniciar el puzzle
	for group in groups:
		remove_child(group.border)
	
	groups.clear()
	pieces.clear()
	
	# Limpiar el tablero
	for row in range(current_rows):
		for col in range(columns):
			if board[row][col]:
				board[row][col].node.queue_free()
			board[row][col] = null
	
	# Reinicializar
	initialize_board()
	create_initial_pieces()
	queue_redraw() 