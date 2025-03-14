# PuzzleGame.gd
# Script completo en una sola escena de tipo Node2D

extends Node2D
class_name PuzzleGame

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")

#
# === PROPIEDADES EXPORTADAS (modificables en el Inspector) ===
#
@export var image_path: String = "res://Assets/Images/arte1.jpg"

@export var max_scale_percentage: float = 0.9  # Aumentado para aprovechar más espacio
@export var viewport_scene_path: String = "res://Scenes/TextViewport.tscn"
@export var max_extra_rows: int = 5  # Máximo número de filas adicionales que se pueden añadir

#
# === VARIABLES INTERNAS ===
#
var puzzle_texture: Texture2D
var puzzle_width: float
var puzzle_height: float
var cell_size: Vector2
var puzzle_offset: Vector2
var original_rows: int  # Para guardar el número original de filas
var extra_rows_added: int = 0  # Contador de filas adicionales añadidas
var is_mobile: bool = false  # Para detectar si estamos en un dispositivo móvil

# Diccionario para saber qué pieza está en cada celda
# Clave: "col_fila" (String), Valor: referencia a la pieza
var grid := {}

# Array para almacenar todas las piezas creadas (por si se quiere iterar)
var pieces := []

# Para contar movimientos o verificar victoria
var total_moves: int = 0

var audio_move: AudioStreamPlayer
var audio_merge: AudioStreamPlayer

# === VARIABLES PARA GESTIÓN DE PROGRESIÓN ===
var current_pack_id: String = ""
var current_puzzle_id: String = ""

# Variables para la pantalla de victoria
var victory_image_view: Control
var victory_text_view: Control
var victory_toggle_button: Button

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
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Configurar el puzzle según los datos seleccionados
	if GLOBAL.selected_puzzle != null:
		image_path = GLOBAL.selected_puzzle.image
		
		# Guardar los IDs para la progresión
		if GLOBAL.selected_pack != null:
			current_pack_id = GLOBAL.selected_pack.id
		
		if GLOBAL.selected_puzzle != null:
			current_puzzle_id = GLOBAL.selected_puzzle.id
	
	make_sounds_game()
	
	# Guardar el número original de filas
	original_rows = GLOBAL.rows

	# Primero, obtenemos la textura trasera usando la escena del Viewport y esperando un frame
	var puzzle_back = await generate_back_texture_from_viewport(viewport_scene_path)
	# Luego cargamos y creamos las piezas con la parte frontal normal
	load_and_create_pieces(puzzle_back)
	
	# Crear un temporizador para verificar periódicamente la victoria
	var victory_timer = Timer.new()
	victory_timer.wait_time = 1.0  # Verificar cada segundo (más frecuente)
	victory_timer.autostart = true
	victory_timer.one_shot = false
	victory_timer.connect("timeout", Callable(self, "check_victory_periodic"))
	add_child(victory_timer)
	
	# Crear un botón para verificar victoria manualmente
	create_verify_button()

func make_sounds_game():
	audio_move = AudioStreamPlayer.new()
	audio_move.stream = load("res://Assets/Audio/move.wav")
	audio_move.volume_db = -10
	add_child(audio_move)
	
	audio_merge = AudioStreamPlayer.new()
	audio_merge.stream = load("res://Assets/Audio/merge.wav")
	audio_merge.volume_db = -5
	add_child(audio_merge)

func generate_back_texture_from_viewport(viewport_scene_path: String) -> Texture2D:
	# 1) Cargar la escena del viewport
	var vp_scene = load(viewport_scene_path)
	if not vp_scene:
		push_warning("No se pudo cargar la escena de Viewport: %s" % viewport_scene_path)
		return null

	# 2) Instanciarla y añadirla temporalmente; el nodo raíz debe ser de tipo Viewport
	var vp_instance = vp_scene.instantiate() as SubViewport
	add_child(vp_instance)

	# Asignar la descripción al Label del TextViewport usando GLOBAL.selected_puzzle
	if GLOBAL.selected_puzzle != null:
		var puzzle_data = GLOBAL.selected_puzzle
		var label = vp_instance.get_node("Label")
		if label:
			# Ajustar el tamaño de la fuente según el dispositivo
			if is_mobile:
				label.add_theme_font_size_override("font_size", 24)
			
			label.text = puzzle_data.description
			# Centrar el texto
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	await get_tree().process_frame # Esperar un frame para que el viewport se inicialice

	# 3) Esperar un frame para que Godot dibuje el texto en el Viewport
	await get_tree().process_frame

	# 4) Asegurarnos de que el viewport tenga una textura válida
	var viewport_texture = vp_instance.get_texture()
	if not viewport_texture:
		push_warning("No se pudo obtener la textura del viewport")
		vp_instance.queue_free()
		return null
		
	var vp_image: Image = viewport_texture.get_image()
	var back_texture = ImageTexture.create_from_image(vp_image)

	# 5) Quitar el viewport de la escena (ya no lo necesitamos)
	vp_instance.queue_free()

	return back_texture

#
# === CARGA DE IMAGEN Y CREACIÓN DE PIEZAS ===
#
func load_and_create_pieces(puzzle_back: Texture2D):
	# 1) Cargar la textura
	puzzle_texture = load(image_path) if load(image_path) else null
	if puzzle_texture == null:
		push_warning("No se pudo cargar la imagen en: %s" % image_path)
		return

	# 2) Calcular escalado
	var viewport_size = get_viewport_rect().size
	var original_w = float(puzzle_texture.get_width())
	var original_h = float(puzzle_texture.get_height())

	# Ajustar el factor de escala según el dispositivo
	var device_scale_factor = 1.0
	if is_mobile:
		# En dispositivos móviles, usar un porcentaje mayor del espacio disponible
		device_scale_factor = 0.95
	else:
		device_scale_factor = max_scale_percentage
	
	# Factor para no exceder el porcentaje máximo de la pantalla
	var scale_factor_w = (viewport_size.x * device_scale_factor) / original_w
	var scale_factor_h = (viewport_size.y * device_scale_factor) / original_h
	var final_scale_factor = min(scale_factor_w, scale_factor_h, 1.0)

	puzzle_width = original_w * final_scale_factor
	puzzle_height = original_h * final_scale_factor

	# 3) Definir el tamaño de cada celda
	cell_size = Vector2(puzzle_width / GLOBAL.columns, puzzle_height / GLOBAL.rows)

	# 4) Calcular offset para centrar el puzzle
	puzzle_offset = (viewport_size - Vector2(puzzle_width, puzzle_height)) * 0.5

	# 5) Generar la lista de celdas y "desordenarlas" (solo columnas por fila)
	grid.clear()
	pieces.clear()
	var cell_list: Array[Vector2] = []
	for r in range(GLOBAL.rows):
		for c in range(GLOBAL.columns):
			cell_list.append(Vector2(c, r))

	# Desordenar completamente el cell_list
	cell_list.shuffle()

	# 6) Crear cada pieza (rows x columns)
	var piece_scene = load("res://Scenes/PuzzlePiece.tscn")
	if piece_scene == null:
		push_warning("No se pudo cargar PuzzlePiece.tscn")
		return
	
	var index = 0
	for row_i in range(GLOBAL.rows):
		for col_i in range(GLOBAL.columns):
			# Instanciar PuzzlePiece.tscn
			var piece_node = piece_scene.instantiate()
			add_child(piece_node)
			
			# Definir la región original (SIN escalado) para la parte de la textura
			var piece_orig_w = original_w / GLOBAL.columns
			var piece_orig_h = original_h / GLOBAL.rows
			var region_rect = Rect2(
				col_i * piece_orig_w,
				row_i * piece_orig_h,
				piece_orig_w,
				piece_orig_h
			)
			
			# Configurar la pieza con la textura frontal y la trasera (puzzle_back)
			piece_node.set_piece_data(puzzle_texture, puzzle_back, region_rect)
			
			# Calcular y aplicar la escala para que la pieza se ajuste a la celda
			var scale_x = cell_size.x / piece_orig_w
			var scale_y = cell_size.y / piece_orig_h
			piece_node.get_node("Sprite2D").scale = Vector2(scale_x, scale_y)
			
			# Centrar el sprite en su nodo padre
			piece_node.get_node("Sprite2D").position = cell_size * 0.5
			
			# Crear la instancia de la clase "Piece" para el manejo de grid
			var piece_obj = Piece.new(piece_node, piece_node.get_node("Sprite2D"), Vector2(col_i, row_i))
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
	check_all_groups()

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
					if p.node.get_parent() != null:
						p.node.get_parent().move_child(p.node, p.node.get_parent().get_child_count() - 1)
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
				AudioManager.play_sfx("res://Assets/Audio/move.wav")
				
				# Verificar y corregir el estado del grid después de cada movimiento
				verify_and_fix_grid()
				
				# Verificar victoria después de cada movimiento
				check_victory()
				
				# También verificar por posición visual
				call_deferred("check_victory_by_position")

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
	cell_x = clamp(cell_x, 0, GLOBAL.columns - 1)
	cell_y = clamp(cell_y, 0, GLOBAL.rows - 1)
	var new_cell = Vector2(cell_x, cell_y)

	# 2) Ver si hay otra pieza en esa celda
	var occupant = get_piece_at(new_cell)
	if occupant != null and occupant != piece_obj:
		# Verificar si pueden fusionarse
		if are_pieces_mergeable(piece_obj, occupant):
			merge_pieces(piece_obj, occupant)
			return
		else:
			# Verificar si la pieza está en un grupo con otras piezas
			if piece_obj.group.size() > 1:
				# Si está en un grupo, mantener el comportamiento actual
				# (no intercambiar, solo mover el grupo completo)
				show_error_message("No se puede intercambiar: la pieza está en un grupo")
				return
			
			# Si el ocupante está en un grupo con otras piezas, no intercambiar
			if occupant.group.size() > 1:
				# Generar un error para depuración
				push_warning("No se puede intercambiar con una pieza que está en un grupo")
				show_error_message("No se puede intercambiar: la pieza destino está en un grupo")
				return
			
			# Si ninguna está en un grupo, intercambiar las piezas
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
		if check_cell.x < 0 or check_cell.x >= GLOBAL.columns or check_cell.y < 0 or check_cell.y >= GLOBAL.rows:
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
	
	# Mostrar mensaje de éxito
	show_success_message("¡Piezas intercambiadas!")
	
	# Generar un error para depuración
	push_warning("Intercambiando pieza en " + str(cell_a) + " con pieza en " + str(cell_b))

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
		
		# Asegurarse de que la celda está dentro de los límites
		target_cell.x = clamp(target_cell.x, 0, GLOBAL.columns - 1)
		if target_cell.y >= GLOBAL.rows:
			if not add_extra_row():
				target_cell.y = GLOBAL.rows - 1
		
		# Actualizar la posición de la pieza
		remove_piece_at(p.current_cell)
		set_piece_at(target_cell, p)
		p.node.position = puzzle_offset + target_cell * cell_size
	
	# Reproducir sonido de fusión
	AudioManager.play_sfx("res://Assets/Audio/merge.wav")
	
	# Verificar victoria después de cada fusión
	call_deferred("check_victory_deferred")
	
	# También verificar por posición visual
	call_deferred("check_victory_by_position")

# Función para añadir una fila adicional al tablero
func add_extra_row():
	if extra_rows_added >= max_extra_rows:
		return false  # No se pueden añadir más filas
	
	GLOBAL.rows += 1
	extra_rows_added += 1
	
	# En lugar de recalcular el tamaño de las celdas, aumentamos el tamaño total del puzzle
	var viewport_size = get_viewport_rect().size
	puzzle_height = cell_size.y * GLOBAL.rows  # Mantenemos el tamaño de celda original
	
	# Recalcular el offset para centrar el puzzle con su nuevo tamaño
	puzzle_offset = (viewport_size - Vector2(puzzle_width, puzzle_height)) * 0.5
	
	# Actualizar la posición de todas las piezas para reflejar el nuevo offset
	for piece_obj in pieces:
		piece_obj.node.position = puzzle_offset + piece_obj.current_cell * cell_size
		# Ya no modificamos la escala de las piezas
	
	return true

# Función para verificar si hay espacio suficiente para un grupo
func check_space_for_group(leader: Piece, target_cell: Vector2) -> bool:
	for p in leader.group:
		var offset = p.original_pos - leader.original_pos
		var p_target = target_cell + offset
		
		# Si la celda está fuera de los límites horizontales, no hay espacio
		if p_target.x < 0 or p_target.x >= GLOBAL.columns:
			return false
			
		# Si la celda está fuera de los límites verticales, verificamos si podemos añadir filas
		if p_target.y >= GLOBAL.rows:
			# Si ya hemos alcanzado el máximo de filas adicionales, no hay espacio
			if extra_rows_added >= max_extra_rows:
				return false
			# Si no, consideramos que podemos añadir filas
	
	return true

# Función para encontrar una posición válida para un grupo
func find_valid_position_for_group(leader: Piece) -> Vector2:
	# Primero intentamos con la posición actual
	var current_pos = get_cell_of_piece(leader)
	
	# Si la posición actual es válida, la usamos
	if check_space_for_group(leader, current_pos):
		return current_pos
	
	# Si no, buscamos una posición válida en todo el tablero
	for r in range(GLOBAL.rows):
		for c in range(GLOBAL.columns):
			var test_pos = Vector2(c, r)
			if check_space_for_group(leader, test_pos):
				return test_pos
	
	# Si no encontramos una posición válida, intentamos añadir una fila
	if add_extra_row():
		# Buscar en la nueva fila
		for c in range(GLOBAL.columns):
			var test_pos = Vector2(c, GLOBAL.rows - 1)
			if check_space_for_group(leader, test_pos):
				return test_pos
		
		# Si aún no encontramos, buscamos recursivamente
		return find_valid_position_for_group(leader)
	
	# Si no podemos añadir más filas, usamos la posición actual y dejamos que el sistema
	# maneje las colisiones lo mejor que pueda
	return current_pos

# Función para mover todas las piezas que colisionan con un grupo
func move_colliding_pieces(leader: Piece, target_cell: Vector2) -> void:
	var occupied_cells = []
	var group_cells = []
	var occupants = []
	
	# Recopilar todas las celdas que ocupará el grupo
	for p in leader.group:
		var offset = p.original_pos - leader.original_pos
		var p_target = target_cell + offset
		
		# Asegurarse de que la celda está dentro de los límites horizontales
		p_target.x = clamp(p_target.x, 0, GLOBAL.columns - 1)
		
		# Para los límites verticales, verificamos si necesitamos añadir filas
		if p_target.y >= GLOBAL.rows:
			if not add_extra_row():
				p_target.y = GLOBAL.rows - 1  # Si no podemos añadir más filas, usamos la última
		
		group_cells.append(p_target)
	
	# Encontrar todas las piezas que colisionan con el grupo
	for p_target in group_cells:
		var occupant = get_piece_at(p_target)
		if occupant != null and not (occupant in leader.group):
			occupied_cells.append(p_target)
			if not (occupant in occupants):  # Evitar duplicados
				occupants.append(occupant)
	
	# Si hay colisiones, mover las piezas que colisionan
	if occupied_cells.size() > 0:
		# Verificar si todas las piezas ocupantes están solas (no en grupos)
		var all_occupants_single = true
		for occupant in occupants:
			if occupant.group.size() > 1:
				all_occupants_single = false
				break
		
		# Si todas las piezas ocupantes están solas y su número coincide con el tamaño del grupo,
		# podemos intercambiar las posiciones (pero esto se maneja en place_group)
		if all_occupants_single and occupants.size() == leader.group.size():
			# No hacemos nada aquí, el intercambio se maneja en place_group
			push_warning("Detectadas piezas individuales que podrían intercambiarse")
			return
		
		# Si no se pueden intercambiar, mover las piezas ocupantes a celdas libres
		# Primero, intentamos encontrar celdas libres para las piezas que colisionan
		var free_cells = find_free_cells(occupants.size())
		
		# Si no hay suficientes celdas libres, añadimos filas hasta encontrar suficientes
		while free_cells.size() < occupants.size():
			if not add_extra_row():
				break  # Si no podemos añadir más filas, usamos las celdas que tenemos
			
			# Buscar celdas libres en la nueva fila
			for c in range(GLOBAL.columns):
				var cell = Vector2(c, GLOBAL.rows - 1)
				if get_piece_at(cell) == null and not (cell in free_cells) and not (cell in group_cells):
					free_cells.append(cell)
					if free_cells.size() >= occupants.size():
						break
			
			if free_cells.size() >= occupants.size():
				break
		
		# Mover las piezas que colisionan a las celdas libres
		for i in range(min(occupants.size(), free_cells.size())):
			var occupant = occupants[i]
			if occupant != null:
				remove_piece_at(occupant.current_cell)
				set_piece_at(free_cells[i], occupant)
				occupant.node.position = puzzle_offset + free_cells[i] * cell_size

# Función para encontrar celdas libres
func find_free_cells(count: int) -> Array:
	var free_cells = []
	
	# Buscar celdas libres en todo el tablero
	for r in range(GLOBAL.rows):
		for c in range(GLOBAL.columns):
			var cell = Vector2(c, r)
			if get_piece_at(cell) == null:
				free_cells.append(cell)
				if free_cells.size() >= count:
					return free_cells
	
	return free_cells

func place_group(piece: Piece):
	# Obtener el líder del grupo
	var leader = get_group_leader(piece)
	
	# Calcular la celda destino para la pieza principal (líder)
	var target_cell = get_cell_of_piece(leader)
	
	# Verificar si hay espacio para el grupo en la posición actual
	if not check_space_for_group(leader, target_cell):
		# Si no hay espacio, intentamos añadir filas si es necesario
		# Calculamos cuántas filas necesitamos para acomodar el grupo
		var max_y = 0
		for p in leader.group:
			var offset = p.original_pos - leader.original_pos
			var p_target_y = target_cell.y + offset.y
			max_y = max(max_y, p_target_y)
		
		# Si necesitamos más filas de las que tenemos, las añadimos
		while max_y >= GLOBAL.rows and add_extra_row():
			pass
		
		# Buscar una posición válida para el grupo
		target_cell = find_valid_position_for_group(leader)
	
	# Crear una copia del grupo para evitar modificaciones durante la iteración
	var group_copy = leader.group.duplicate()
	
	# Recopilar información sobre las piezas que colisionan con el grupo
	var occupied_cells = []
	var group_cells = []
	var occupants = []
	
	# Recopilar todas las celdas que ocupará el grupo
	for p in group_copy:
		var offset = p.original_pos - leader.original_pos
		var p_target = target_cell + offset
		
		# Asegurarse de que la celda está dentro de los límites horizontales
		p_target.x = clamp(p_target.x, 0, GLOBAL.columns - 1)
		
		# Para los límites verticales, verificamos si necesitamos añadir filas
		if p_target.y >= GLOBAL.rows:
			if not add_extra_row():
				p_target.y = GLOBAL.rows - 1  # Si no podemos añadir más filas, usamos la última
		
		group_cells.append(p_target)
	
	# Encontrar todas las piezas que colisionan con el grupo
	for p_target in group_cells:
		var occupant = get_piece_at(p_target)
		if occupant != null and not (occupant in group_copy):
			occupied_cells.append(p_target)
			if not (occupant in occupants):  # Evitar duplicados
				occupants.append(occupant)
	
	# Verificar si todas las piezas ocupantes están solas (no en grupos)
	var all_occupants_single = true
	for occupant in occupants:
		if occupant.group.size() > 1:
			all_occupants_single = false
			push_warning("No se puede intercambiar con una pieza que está en un grupo")
			show_error_message("No se puede intercambiar: hay piezas destino en grupos")
			break
	
	# Si todas las piezas ocupantes están solas y su número coincide con el tamaño del grupo,
	# podemos intercambiar las posiciones
	if all_occupants_single and occupants.size() > 0 and occupants.size() == group_copy.size():
		# Guardar las posiciones originales de las piezas ocupantes
		var occupant_positions = []
		for occupant in occupants:
			occupant_positions.append(occupant.current_cell)
		
		# Liberar las celdas ocupadas por ambos grupos
		for p in group_copy:
			remove_piece_at(p.current_cell)
		
		for occupant in occupants:
			remove_piece_at(occupant.current_cell)
		
		# Colocar las piezas ocupantes en las posiciones originales del grupo
		for i in range(occupants.size()):
			var occupant = occupants[i]
			var orig_cell = group_copy[i].current_cell
			set_piece_at(orig_cell, occupant)
			occupant.node.position = puzzle_offset + orig_cell * cell_size
		
		# Colocar las piezas del grupo en las posiciones de las ocupantes
		for i in range(group_copy.size()):
			var p = group_copy[i]
			var new_cell = occupant_positions[i]
			set_piece_at(new_cell, p)
			p.node.position = puzzle_offset + new_cell * cell_size
		
		# Generar un error para depuración
		push_warning("Intercambiando grupo de " + str(group_copy.size()) + " piezas con " + str(occupants.size()) + " piezas individuales")
		
		# Mostrar mensaje de éxito
		show_success_message("¡Grupo intercambiado con " + str(occupants.size()) + " piezas!")
	else:
		# Si no se pueden intercambiar, mover las piezas que colisionan con el grupo
		move_colliding_pieces(leader, target_cell)
		
		# Liberar las celdas ocupadas por las piezas del grupo
		for p in group_copy:
			remove_piece_at(p.current_cell)
		
		# Colocar cada pieza del grupo en su posición relativa
		for p in group_copy:
			var offset = p.original_pos - leader.original_pos
			var p_target = target_cell + offset
			
			# Asegurarse de que la celda está dentro de los límites horizontales
			p_target.x = clamp(p_target.x, 0, GLOBAL.columns - 1)
			
			# Para los límites verticales, intentamos añadir filas si es necesario
			if p_target.y >= GLOBAL.rows:
				if not add_extra_row():
					p_target.y = GLOBAL.rows - 1  # Si no podemos añadir más filas, usamos la última
			
			var occupant = get_piece_at(p_target)
			if occupant != null and not (occupant in group_copy):
				# Si hay una pieza ocupando la celda, moverla a una celda libre
				var free_cells = find_free_cells(1)
				if free_cells.size() > 0:
					remove_piece_at(occupant.current_cell)
					set_piece_at(free_cells[0], occupant)
					occupant.node.position = puzzle_offset + free_cells[0] * cell_size
				elif add_extra_row():
					# Si no hay celdas libres, intentamos añadir una fila
					free_cells = find_free_cells(1)
					if free_cells.size() > 0:
						remove_piece_at(occupant.current_cell)
						set_piece_at(free_cells[0], occupant)
						occupant.node.position = puzzle_offset + free_cells[0] * cell_size
			
			# Colocar la pieza en su posición
			set_piece_at(p_target, p)
			p.node.position = puzzle_offset + p_target * cell_size
	
	# Verificar que todas las piezas del grupo estén correctamente colocadas en el grid
	for p in group_copy:
		if not grid.has(cell_key(p.current_cell)) or grid[cell_key(p.current_cell)] != p:
			# Si la pieza no está en el grid o hay otra pieza en su lugar, recolocarla
			var free_cells = find_free_cells(1)
			if free_cells.size() > 0:
				set_piece_at(free_cells[0], p)
				p.node.position = puzzle_offset + free_cells[0] * cell_size
	
	# Intentar fusionar el grupo con piezas adyacentes fuera del grupo
	var merged = true
	while merged:
		merged = false
		# Usar una copia actualizada del grupo para la iteración
		var updated_group = get_group_leader(leader).group.duplicate()
		for p in updated_group:
			var adjacent = find_adjacent_pieces(p, p.current_cell)
			for adj in adjacent:
				if are_pieces_mergeable(p, adj):
					merge_pieces(p, adj)
					merged = true
					break
			if merged:
				break
	
	# Al final del place_group, verificar si se pueden formar más grupos
	check_all_groups()
	
	# Verificar que todas las piezas estén en el grid
	verify_all_pieces_in_grid()
	
	# Verificar victoria después de colocar el grupo
	call_deferred("check_victory_deferred")

# Nueva función para verificar que todas las piezas estén en el grid
func verify_all_pieces_in_grid():
	var pieces_in_grid = []
	
	# Recopilar todas las piezas que están en el grid
	for cell_k in grid.keys():
		var piece = grid[cell_k]
		if piece != null and not (piece in pieces_in_grid):
			pieces_in_grid.append(piece)
	
	# Verificar si hay piezas que no están en el grid
	for piece in pieces:
		if not (piece in pieces_in_grid):
			# Encontrar una celda libre para la pieza
			var free_cells = find_free_cells(1)
			if free_cells.size() > 0:
				set_piece_at(free_cells[0], piece)
				piece.node.position = puzzle_offset + free_cells[0] * cell_size
			else:
				# Si no hay celdas libres, intentar añadir una fila
				if add_extra_row():
					free_cells = find_free_cells(1)
					if free_cells.size() > 0:
						set_piece_at(free_cells[0], piece)
						piece.node.position = puzzle_offset + free_cells[0] * cell_size

func check_victory():
	# Primero verificar y corregir el estado del grid
	verify_and_fix_grid()
	
	# Verificar si todas las piezas están en su posición original
	var all_in_place = true
	var pieces_close_to_original = 0
	var total_pieces = pieces.size()
	
	for piece_obj in pieces:
		if piece_obj.current_cell != piece_obj.original_pos:
			all_in_place = false
			
			# Verificar si la pieza está cerca de su posición original
			var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
			var distance = piece_obj.node.position.distance_to(expected_position)
			
			if distance <= cell_size.length() * 0.4:  # 40% del tamaño de celda como margen de error
				pieces_close_to_original += 1
	
	# Si todas las piezas están en su posición original
	if all_in_place:
		print("¡Victoria por posición exacta en el grid!")
		_on_puzzle_completed()
		return true
	
	# Si más del 90% de las piezas están cerca de su posición original, consideramos victoria
	if pieces_close_to_original >= total_pieces * 0.9:
		print("¡Victoria! Más del 90% de las piezas están cerca de su posición original")
		
		# Ajustar todas las piezas a su posición exacta
		for piece_obj in pieces:
			var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
			piece_obj.node.position = expected_position
			remove_piece_at(piece_obj.current_cell)
			piece_obj.current_cell = piece_obj.original_pos
			set_piece_at(piece_obj.original_pos, piece_obj)
		
		_on_puzzle_completed()
		return true
	
	return false

# Función diferida para verificar victoria (evita problemas de recursión)
func check_victory_deferred():
	# Verificar si todas las piezas están en su posición original
	var all_in_place = true
	for piece_obj in pieces:
		if piece_obj.current_cell != piece_obj.original_pos:
			all_in_place = false
			break
	
	# Si todas las piezas están en su lugar, mostrar pantalla de victoria
	if all_in_place:
		print("¡Victoria! (diferida)")
		_on_puzzle_completed()
	else:
		# Verificar también por posición visual (a veces el grid puede no estar actualizado)
		check_victory_by_position()

# Nueva función para verificación periódica de victoria
func check_victory_periodic():
	# Verificar y corregir el grid primero
	verify_and_fix_grid()
	
	# Imprimir información de depuración
	print("Verificación periódica de victoria...")
	
	# Contar cuántas piezas están en su posición correcta
	var pieces_in_place = 0
	var total_pieces = pieces.size()
	
	for piece_obj in pieces:
		var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
		var distance = piece_obj.node.position.distance_to(expected_position)
		
		if distance <= cell_size.length() * 0.5:  # 50% del tamaño de celda como margen de error (más tolerante)
			pieces_in_place += 1
	
	print("Piezas en posición correcta: ", pieces_in_place, " de ", total_pieces)
	
	# Si más del 95% de las piezas están en su lugar, considerar victoria
	if pieces_in_place >= total_pieces * 0.95:
		print("¡Victoria detectada en verificación periódica!")
		
		# Ajustar todas las piezas a su posición exacta
		for piece_obj in pieces:
			var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
			piece_obj.node.position = expected_position
			remove_piece_at(piece_obj.current_cell)
			piece_obj.current_cell = piece_obj.original_pos
			set_piece_at(piece_obj.original_pos, piece_obj)
		
		# Cambiar a la pantalla de victoria
		_on_puzzle_completed()
		return true
	
	# Intentar verificar victoria por posición visual primero
	if not check_victory_by_position():
		# Si no hay victoria por posición, verificar por el grid
		check_victory()

# Nueva función para verificar victoria por posición visual
func check_victory_by_position():
	var all_in_place = true
	var margin_of_error = cell_size.length() * 0.4  # 40% del tamaño de celda como margen de error (más tolerante)
	var pieces_in_place = 0
	var total_pieces = pieces.size()
	
	for piece_obj in pieces:
		# Calcular dónde debería estar la pieza visualmente
		var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
		
		# Verificar si la pieza está en su posición visual correcta (con un margen de error)
		var distance = piece_obj.node.position.distance_to(expected_position)
		if distance <= margin_of_error:
			pieces_in_place += 1
		else:
			print("Pieza fuera de posición: ", piece_obj.original_pos, " - Distancia: ", distance)
			all_in_place = false
	
	print("Verificación visual: ", pieces_in_place, " de ", total_pieces, " piezas en posición correcta")
	
	# Si todas las piezas están visualmente en su lugar correcto
	if all_in_place:
		print("¡Victoria por posición visual! Distancia máxima permitida: ", margin_of_error)
		
		# Corregir el grid para que coincida con las posiciones visuales
		for piece_obj in pieces:
			remove_piece_at(piece_obj.current_cell)
			piece_obj.current_cell = piece_obj.original_pos
			set_piece_at(piece_obj.original_pos, piece_obj)
		
		# Mostrar pantalla de victoria
		_on_puzzle_completed()
		return true
	
	# Si más del 95% de las piezas están en su lugar, considerar victoria
	if pieces_in_place >= total_pieces * 0.95:
		print("¡Victoria! Más del 95% de las piezas están en su posición visual correcta")
		
		# Corregir el grid para que coincida con las posiciones visuales
		for piece_obj in pieces:
			var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
			piece_obj.node.position = expected_position
			remove_piece_at(piece_obj.current_cell)
			piece_obj.current_cell = piece_obj.original_pos
			set_piece_at(piece_obj.original_pos, piece_obj)
		
		# Mostrar pantalla de victoria
		_on_puzzle_completed()
		return true
	
	return false

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

func check_all_groups() -> void:
	# Recorrer una copia de la lista de piezas
	var pieces_copy = pieces.duplicate()
	var merged_any = true
	
	# Seguir intentando fusionar hasta que no se pueda fusionar más
	while merged_any:
		merged_any = false
		
		for i in range(pieces_copy.size()):
			if i >= pieces_copy.size():
				break
				
			var piece_obj = pieces_copy[i]
			var adjacents = find_adjacent_pieces(piece_obj, piece_obj.current_cell)
			
			for adj in adjacents:
				if are_pieces_mergeable(piece_obj, adj):
					merge_pieces(piece_obj, adj)
					merged_any = true
					
					# Actualizar la lista de piezas después de la fusión
					pieces_copy = pieces.duplicate()
					break
			
			if merged_any:
				break
	
	# Verificar y corregir el estado del grid después de todas las fusiones
	verify_and_fix_grid()
	
	# Verificar victoria después de verificar todos los grupos
	call_deferred("check_victory_deferred")
	
	# También verificar por posición visual
	call_deferred("check_victory_by_position")

func on_flip_button_pressed() -> void:
	# Ciclo por cada pieza y, si el nodo de la pieza soporta flip_piece, lo invoco
	for piece_obj in pieces:
		if piece_obj.node.has_method("flip_piece"):
			piece_obj.node.flip_piece()

# Función para volver a la selección de puzzles
func _on_PuzzleSelected():
	print("PuzzleGame: Volviendo a la selección de puzzles")
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn")

# Nueva función para manejar el cambio de dificultad
func _on_difficulty_changed(columns, rows):
	print("PuzzleGame: Dificultad cambiada a " + str(columns) + "x" + str(rows))
	
	# Actualizar las variables globales
	GLOBAL.columns = columns
	GLOBAL.rows = rows
	
	# Mostrar un mensaje al usuario
	show_success_message("Cambiando a dificultad " + str(columns) + "x" + str(rows))
	
	# Esperar un momento antes de reiniciar el puzzle
	await get_tree().create_timer(0.5).timeout
	
	# Limpiar las piezas actuales
	for piece_obj in pieces:
		if piece_obj.node != null:
			piece_obj.node.queue_free()
	
	# Limpiar las listas
	grid.clear()
	pieces.clear()
	
	# Guardar el número original de filas
	original_rows = GLOBAL.rows
	extra_rows_added = 0
	
	# Reiniciar el puzzle con la nueva dificultad
	var puzzle_back = await generate_back_texture_from_viewport(viewport_scene_path)
	load_and_create_pieces(puzzle_back)

# Nueva función para verificar y corregir el estado del grid
func verify_and_fix_grid():
	# 1. Verificar que todas las piezas estén en el grid
	verify_all_pieces_in_grid()
	
	# 2. Verificar que no haya celdas con referencias a piezas incorrectas
	var cells_to_fix = []
	
	for cell_k in grid.keys():
		var piece = grid[cell_k]
		if piece == null:
			# Eliminar entradas nulas
			cells_to_fix.append(cell_k)
		else:
			# Verificar que la pieza tenga la celda correcta
			var expected_key = cell_key(piece.current_cell)
			if expected_key != cell_k:
				cells_to_fix.append(cell_k)
	
	# Corregir las celdas problemáticas
	for cell_k in cells_to_fix:
		grid.erase(cell_k)
	
	# 3. Verificar que cada pieza esté en la celda que dice estar
	for piece in pieces:
		var key = cell_key(piece.current_cell)
		if not grid.has(key) or grid[key] != piece:
			# La pieza no está donde dice estar, buscar una celda libre
			var free_cells = find_free_cells(1)
			if free_cells.size() > 0:
				set_piece_at(free_cells[0], piece)
				piece.node.position = puzzle_offset + free_cells[0] * cell_size
			else:
				# Si no hay celdas libres, intentar añadir una fila
				if add_extra_row():
					free_cells = find_free_cells(1)
					if free_cells.size() > 0:
						set_piece_at(free_cells[0], piece)
						piece.node.position = puzzle_offset + free_cells[0] * cell_size
	
	# 4. Verificar que no haya piezas superpuestas
	var occupied_positions = {}
	for piece in pieces:
		var pos_key = "%d_%d" % [int(piece.node.position.x), int(piece.node.position.y)]
		if occupied_positions.has(pos_key):
			# Hay una pieza superpuesta, moverla a una celda libre
			var free_cells = find_free_cells(1)
			if free_cells.size() > 0:
				remove_piece_at(piece.current_cell)
				set_piece_at(free_cells[0], piece)
				piece.node.position = puzzle_offset + free_cells[0] * cell_size
		else:
			occupied_positions[pos_key] = piece
	
	# Verificar victoria después de corregir el grid
	call_deferred("check_victory_deferred")
	
	# También verificar por posición visual
	call_deferred("check_victory_by_position")

# Función para crear un botón de verificación de victoria
func create_verify_button():
	# Crear un contenedor para el botón que use anclajes
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	# Ajustar tamaño y posición según el dispositivo
	if is_mobile:
		container.size = Vector2(220, 80)
		container.position = Vector2(-230, -90)  # Offset desde la esquina inferior derecha
	else:
		container.size = Vector2(180, 60)
		container.position = Vector2(-190, -70)  # Offset desde la esquina inferior derecha
	
	# Crear el botón
	var button = Button.new()
	button.text = "¿Completado?"
	
	# Configurar el botón para que llene el contenedor
	button.size_flags_horizontal = Control.SIZE_FILL
	button.size_flags_vertical = Control.SIZE_FILL
	
	# Estilo del botón
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.8, 0.8)  # Azul semitransparente
	
	# Configurar bordes
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	
	style.border_color = Color(1, 1, 1, 0.9)  # Borde blanco
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	
	# Añadir padding para mejor experiencia táctil en móviles
	if is_mobile:
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 15
		style.content_margin_bottom = 15
	else:
		style.content_margin_left = 15
		style.content_margin_right = 15
		style.content_margin_top = 10
		style.content_margin_bottom = 10
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", Color(1, 1, 1))  # Texto blanco
	button.add_theme_color_override("font_hover_color", Color(1, 1, 0))  # Amarillo al pasar el mouse
	
	# Aumentar el tamaño de la fuente para dispositivos móviles
	if is_mobile:
		button.add_theme_font_size_override("font_size", 32)
	else:
		button.add_theme_font_size_override("font_size", 20)
	
	# Usar UIScaler si está disponible
	if ResourceLoader.exists("res://Scripts/UIScaler.gd"):
		var UIScaler = load("res://Scripts/UIScaler.gd")
		UIScaler.scale_button(button)
	
	button.connect("pressed", Callable(self, "force_victory_check"))
	
	# Añadir el botón al contenedor y el contenedor a la escena
	container.add_child(button)
	add_child(container)
	
	return container

# Función para forzar la verificación de victoria
func force_victory_check():
	print("Verificación de victoria forzada por el usuario")
	
	# Primero, intentar corregir cualquier problema en el grid
	verify_and_fix_grid()
	
	# Verificar si todas las piezas están visualmente cerca de su posición correcta
	var all_pieces_close = true
	var pieces_to_adjust = []
	var pieces_in_place = 0
	var total_pieces = pieces.size()
	
	for piece_obj in pieces:
		# Calcular dónde debería estar la pieza
		var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
		
		# Verificar si la pieza está cerca de su posición correcta
		var distance = piece_obj.node.position.distance_to(expected_position)
		
		# Usar un margen de error más grande para la verificación manual
		var margin_of_error = cell_size.length() * 0.6  # 60% del tamaño de celda como margen de error
		
		if distance <= margin_of_error:
			# La pieza está cerca, la añadimos a la lista para ajustar
			pieces_to_adjust.append({"piece": piece_obj, "expected_pos": expected_position})
			pieces_in_place += 1
		else:
			all_pieces_close = false
			print("Pieza en posición incorrecta: ", piece_obj.original_pos, " - Distancia: ", distance)
	
	print("Verificación manual: ", pieces_in_place, " de ", total_pieces, " piezas en posición correcta")
	
	# Si todas las piezas están cerca de su posición correcta o al menos el 90%
	if all_pieces_close or pieces_in_place >= total_pieces * 0.9:
		print("Suficientes piezas están cerca de su posición correcta. ¡Forzando victoria!")
		
		# Ajustar todas las piezas a su posición exacta
		for piece_obj in pieces:
			var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
			piece_obj.node.position = expected_position
			remove_piece_at(piece_obj.current_cell)
			piece_obj.current_cell = piece_obj.original_pos
			set_piece_at(piece_obj.original_pos, piece_obj)
		
		# Verificar victoria después de ajustar todas las piezas
		print("¡Victoria forzada!")
		_on_puzzle_completed()
		return true
	else:
		# Si no todas las piezas están en su lugar, intentar con los métodos normales
		var victory_by_grid = check_victory()
		
		if not victory_by_grid:
			# Si no se detectó victoria por el grid, intentar por posición visual
			var victory_by_position = check_victory_by_position()
			
			if not victory_by_position:
				# Mostrar un mensaje al usuario
				print("El puzzle aún no está completo")
				
				# Crear un mensaje temporal en pantalla
				var label = Label.new()
				label.text = "El puzzle aún no está completo"
				label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
				
				# Ajustar tamaño de fuente y posición según el dispositivo
				if is_mobile:
					label.add_theme_font_size_override("font_size", 28)
				else:
					label.add_theme_font_size_override("font_size", 18)
				
				# Centrar horizontalmente y ajustar el ancho para que quepa el texto
				var viewport_size = get_viewport_rect().size
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.size.x = viewport_size.x * 0.8
				label.position.x = viewport_size.x * 0.1
				label.position.y = 60
				
				add_child(label)
				
				# Crear un temporizador para eliminar el mensaje después de 3 segundos
				var timer = Timer.new()
				timer.wait_time = 3.0
				timer.one_shot = true
				timer.connect("timeout", Callable(label, "queue_free"))
				add_child(timer)
				timer.start()
				
				return false
			
			return true
		
		return true

# Función para alternar entre la vista de imagen y texto
func _on_toggle_view_pressed():
	# Invertir la visibilidad de las vistas
	victory_image_view.visible = !victory_image_view.visible
	victory_text_view.visible = !victory_text_view.visible
	
	# Actualizar el texto del botón según la vista actual
	if victory_text_view.visible:
		victory_toggle_button.text = "Imagen"
	else:
		victory_toggle_button.text = "Texto"

# Función para cambiar de escena de manera segura
func safe_change_scene(scene_path: String) -> void:
	# Verificar que get_tree() no sea nulo
	if get_tree() != null:
		# Usar call_deferred para cambiar la escena de manera segura
		get_tree().call_deferred("change_scene_to_file", scene_path)
	else:
		push_error("No se pudo cambiar a la escena: " + scene_path)

# Función llamada cuando se mueve una pieza
func _on_piece_moved(piece, old_cell, new_cell):
	total_moves += 1
	
	# Reproducir sonido de movimiento
	audio_move.play()
	
	# Verificar si el puzzle está completo
	if check_victory():
		# Esperar un momento antes de mostrar la pantalla de victoria
		await get_tree().create_timer(0.5).timeout
		_on_puzzle_completed()

# Función llamada cuando se completa el puzzle
func _on_puzzle_completed():
	print("¡Puzzle completado!")
	
	# Verificar que tenemos los IDs necesarios
	if current_pack_id.is_empty() or current_puzzle_id.is_empty():
		print("ERROR: No se pueden guardar el progreso, faltan los IDs del pack o puzzle")
		return
	
	# Marcar el puzzle como completado en el ProgressManager
	print("PuzzleGame: Marcando puzzle como completado - Pack: " + current_pack_id + ", Puzzle: " + current_puzzle_id)
	progress_manager.complete_puzzle(current_pack_id, current_puzzle_id)
	
	# Desbloquear el siguiente puzzle inmediatamente
	var next_puzzle = progress_manager.get_next_unlocked_puzzle(current_pack_id, current_puzzle_id)
	if next_puzzle != null:
		print("PuzzleGame: Siguiente puzzle desbloqueado: " + next_puzzle.name)
	else:
		print("PuzzleGame: No hay siguiente puzzle disponible")
	
	# Forzar el guardado de los datos de progresión
	progress_manager.save_progress_data()
	print("PuzzleGame: Datos de progresión guardados")
	
	# Mostrar pantalla de victoria
	show_victory_screen()

# Función para mostrar la pantalla de victoria
func show_victory_screen():
	print("Cambiando a la pantalla de victoria")
	
	# Guardar los datos necesarios en GLOBAL para que la escena de victoria pueda acceder a ellos
	GLOBAL.victory_data = {
		"puzzle": GLOBAL.selected_puzzle,
		"pack": GLOBAL.selected_pack,
		"total_moves": total_moves,
		"pack_id": current_pack_id,
		"puzzle_id": current_puzzle_id,
		"is_mobile": is_mobile  # Añadir información sobre el dispositivo
	}
	
	# Usar la función safe_change_scene para cambiar a la escena de victoria
	safe_change_scene("res://Scenes/VictoryScreen.tscn")

# Función para mostrar un mensaje de error temporal
func show_error_message(message: String, duration: float = 2.0):
	var label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Rojo claro
	
	# Ajustar tamaño de fuente para dispositivos móviles
	if is_mobile:
		label.add_theme_font_size_override("font_size", 28)
	else:
		label.add_theme_font_size_override("font_size", 18)
	
	# Posicionar en la parte superior de la pantalla
	var viewport_size = get_viewport_rect().size
	
	# Centrar horizontalmente y ajustar el ancho para que quepa el texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size.x = viewport_size.x * 0.8
	label.position.x = viewport_size.x * 0.1
	label.position.y = 60
	
	# Añadir a la escena
	add_child(label)
	
	# Crear un temporizador para eliminar el mensaje después del tiempo especificado
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.connect("timeout", Callable(label, "queue_free"))
	add_child(timer)
	timer.start()

# Función para mostrar un mensaje de éxito temporal
func show_success_message(message: String, duration: float = 1.5):
	var label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))  # Verde claro
	
	# Ajustar tamaño de fuente para dispositivos móviles
	if is_mobile:
		label.add_theme_font_size_override("font_size", 28)
	else:
		label.add_theme_font_size_override("font_size", 18)
	
	# Posicionar en la parte superior de la pantalla
	var viewport_size = get_viewport_rect().size
	
	# Centrar horizontalmente y ajustar el ancho para que quepa el texto
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size.x = viewport_size.x * 0.8
	label.position.x = viewport_size.x * 0.1
	label.position.y = 60
	
	# Añadir a la escena
	add_child(label)
	
	# Crear un temporizador para eliminar el mensaje después del tiempo especificado
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.connect("timeout", Callable(label, "queue_free"))
	add_child(timer)
	timer.start()
