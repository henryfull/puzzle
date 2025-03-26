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

# Parámetros de control del tablero
@export_range(0.1, 2.0, 0.1) var pan_sensitivity: float = 1.0  # Sensibilidad del desplazamiento

# Parámetros para efectos de animación
@export_range(0.1, 1.0, 0.05) var tween_duration: float = 0.3  # Duración de la animación Tween
@export var use_tween_effect: bool = true  # Activar/desactivar el efecto
@export_range(0.05, 0.5, 0.05) var flip_speed: float = 0.01  # Velocidad de la animación de flip

# Variables para el paneo del tablero (simplificadas)
var is_panning := false
var last_pan_position := Vector2.ZERO
var board_offset := Vector2.ZERO  # Desplazamiento actual del tablero
var touch_points := {}  # Para rastrear múltiples puntos de contacto en táctil

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
var audio_flip: AudioStreamPlayer

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
	var order_number: int  # Número de orden de la pieza

	func _init(_node: Node2D, _sprite: Sprite2D, _orig: Vector2, _order: int):
		node = _node
		sprite = _sprite
		original_pos = _orig
		current_cell = _orig
		order_number = _order
		group = [self]  # Inicialmente, cada pieza está en su propio grupo

#
# === FUNCIÓN _ready(): se llama al iniciar la escena ===
#
func _ready():
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Cargar preferencias del usuario
	load_user_preferences()
	
	# Ajustar la interfaz para dispositivos móviles
	adjust_ui_for_device()
	
	# Crear el botón de opciones
	create_options_button()
	
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
	audio_move.stream = load("res://Assets/Sounds/SFX/plop.mp3")
	audio_move.volume_db = -10
	audio_move.bus = "SFX"
	add_child(audio_move)
	
	audio_merge = AudioStreamPlayer.new()
	audio_merge.stream = load("res://Assets/Sounds/SFX/bubble.wav")
	audio_merge.volume_db = -5
	audio_merge.bus = "SFX"
	add_child(audio_merge)
	
	# Añadir sonido de flip
	audio_flip = AudioStreamPlayer.new()
	audio_flip.stream = load("res://Assets/Sounds/SFX/flip.wav")
	audio_flip.volume_db = -8
	audio_flip.bus = "SFX"
	add_child(audio_flip)

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
			var piece_obj = Piece.new(piece_node, piece_node.get_node("Sprite2D"), Vector2(col_i, row_i), index + 1)
			pieces.append(piece_obj)
			
			# Asignar el número de orden a la pieza
			if piece_node.has_method("set_order_number"):
				piece_node.set_order_number(index + 1)
			
			# Posición inicial: la celda "desordenada"
			var random_cell = cell_list[index]
			index += 1
			
			# Ubicar la pieza en pantalla
			var piece_pos = puzzle_offset + random_cell * cell_size
			piece_node.position = piece_pos
			
			# Registrar en grid
			set_piece_at(random_cell, piece_obj)
			
			# Actualizar el estado inicial de la pieza
			update_piece_position_state(piece_obj)
			
			# Cada pieza comienza como pieza de borde en su propio grupo
			if piece_obj.node.has_method("set_edge_piece"):
				piece_obj.node.set_edge_piece(true)

	# Activar la captura de eventos de mouse a nivel global
	# (Podrías usar _input() o unhandled_input(), en este ejemplo iremos con _unhandled_input)
	set_process_unhandled_input(true)
	check_all_groups()

#
# === GESTIÓN DE EVENTOS DE RATÓN / TECLADO ===
#
func _unhandled_input(event: InputEvent) -> void:
	# Manejo de eventos táctiles para dispositivos móviles
	if event is InputEventScreenTouch:
		# Guardamos la información del toque en nuestro diccionario
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
			
		# Para paneo en dispositivos móviles necesitamos DOS dedos
		if is_mobile:
			if touch_points.size() >= 2 and event.pressed:
				# Iniciar paneo con dos dedos
				is_panning = true
				# Usamos el punto medio entre los dos dedos como punto de referencia
				last_pan_position = get_touch_center()
			elif touch_points.size() < 2:
				# Si hay menos de dos dedos, terminar el paneo
				is_panning = false
		
		# Si es un solo dedo, procesamos como un evento normal de clic de pieza
		if touch_points.size() == 1 and is_mobile:
			if event.pressed:
				# Debemos pasar la posición específica del evento de toque, no el evento genérico
				process_piece_click_touch(event.position, event.index)
			else:
				process_piece_release()
	
	elif event is InputEventScreenDrag:
		# Actualizar la posición del punto de contacto
		touch_points[event.index] = event.position
		
		# Para paneo en dispositivos móviles necesitamos DOS dedos
		if is_mobile and touch_points.size() >= 2 and is_panning:
			# En lugar de usar el centro de los dedos, usamos directamente la posición del dedo 
			# que se está moviendo, lo que da un control más directo
			var current_pos = event.position
			var prev_pos = current_pos - event.relative
			
			# El delta es exactamente el movimiento real del dedo
			var delta = event.relative
			
			# Aplicamos directamente el delta del movimiento del dedo, manteniendo
			# la misma dirección que el gesto del usuario, pero ajustando por la sensibilidad
			board_offset += delta * pan_sensitivity
			
			last_pan_position = current_pos
			update_board_position()
		
		# Si estamos arrastrando con un solo dedo y no estamos en modo paneo, movernos piezas
		elif is_mobile and touch_points.size() == 1 and not is_panning:
			# Procesar como arrastre de pieza
			for piece_obj in pieces:
				if piece_obj.dragging:
					var group_leader = get_group_leader(piece_obj)
					
					# En lugar de usar event.relative, calculamos la nueva posición basada
					# en la posición actual del dedo y el offset guardado al comenzar el arrastre
					var touch_pos = event.position
					
					for p in group_leader.group:
						# Aplicar la nueva posición con el offset original
						p.node.global_position = touch_pos + p.drag_offset
					
					break
	
	# Manejo de eventos de ratón para PC
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:  # Botón derecho para paneo en PC
			if event.pressed:
				# Iniciar paneo con botón derecho
				is_panning = true
				last_pan_position = event.position
			else:
				# Finalizar paneo
				is_panning = false
		
		# Manejo de click izquierdo para las piezas
		elif event.button_index == MOUSE_BUTTON_LEFT:
			process_piece_click(event)
	
	elif event is InputEventMouseMotion:
		if is_panning:
			# Actualizar posición del tablero durante el paneo
			var delta = event.relative
			# Aplicar la sensibilidad al desplazamiento
			board_offset += delta * pan_sensitivity
			last_pan_position = event.position
			update_board_position()
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# Si estamos arrastrando una pieza
			for piece_obj in pieces:
				if piece_obj.dragging:
					var group_leader = get_group_leader(piece_obj)
					var delta = event.relative
					for p in group_leader.group:
						p.node.global_position += delta
					break

func update_board_position() -> void:
	# Actualizar la posición de todas las piezas según el desplazamiento del tablero
	position = board_offset
	
	# Limitar el desplazamiento para que el tablero no se aleje demasiado
	var viewport_size = get_viewport_rect().size
	var board_size = Vector2(puzzle_width, puzzle_height)
	
	# Calcular límites de desplazamiento
	# Permitimos desplazar el tablero dentro de límites razonables,
	# pero siempre asegurándose de que parte del tablero sea visible
	var margin = 100.0  # Margen de píxeles para que siempre quede algo visible
	var min_x = min(-board_size.x + margin, -board_size.x * 0.75)
	var max_x = max(viewport_size.x - margin, viewport_size.x - board_size.x * 0.25)
	var min_y = min(-board_size.y + margin, -board_size.y * 0.75)
	var max_y = max(viewport_size.y - margin, viewport_size.y - board_size.y * 0.25)
	
	# Limitar el desplazamiento
	position.x = clamp(position.x, min_x, max_x)
	position.y = clamp(position.y, min_y, max_y)
	
	# Actualizar el board_offset para reflejar la posición ajustada
	board_offset = position

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
	var cell = get_cell_of_piece(piece_obj)  # Usamos get_cell_of_piece que ya tiene en cuenta el desplazamiento
	
	# Clampeamos para que no se salga de la grid
	var cell_x = clamp(int(cell.x), 0, GLOBAL.columns - 1)
	var cell_y = clamp(int(cell.y), 0, GLOBAL.rows - 1)
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
	
	# Calcular la posición física de la pieza teniendo en cuenta el desplazamiento del tablero
	var target_position = puzzle_offset + new_cell * cell_size
	
	# Actualizar el estado de la pieza (si está en la posición correcta o no)
	update_piece_position_state(piece_obj)
	
	# Aplicar efecto de Tween si está activado
	if use_tween_effect:
		apply_tween_effect(piece_obj.node, target_position)
	else:
		piece_obj.node.position = target_position

	# 4) Fusionar con piezas adyacentes, si es posible
	var adjacent = find_adjacent_pieces(piece_obj, new_cell)
	for adj in adjacent:
		if are_pieces_mergeable(piece_obj, adj):
			merge_pieces(piece_obj, adj)

# Función para aplicar el efecto de Tween
func apply_tween_effect(node: Node2D, target_position: Vector2):
	# Crear un nuevo Tween
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUINT)  # Transición suave
	
	# Animar la posición
	tween.tween_property(node, "position", target_position, tween_duration)
	
	# Opcionalmente, añadir un efecto de escala para dar sensación de "rebote"
	var original_scale = node.scale
	tween.parallel().tween_property(node, "scale", original_scale * 1.1, tween_duration * 0.5)
	tween.tween_property(node, "scale", original_scale, tween_duration * 0.5)

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

	# Reposicionar con efecto Tween
	var target_pos_a = puzzle_offset + cell_b * cell_size
	var target_pos_b = puzzle_offset + cell_a * cell_size
	
	# Actualizar el estado de posición de ambas piezas
	update_piece_position_state(a)
	update_piece_position_state(b)
	
	if use_tween_effect:
		apply_tween_effect(a.node, target_pos_a)
		apply_tween_effect(b.node, target_pos_b)
	else:
		a.node.position = target_pos_a
		b.node.position = target_pos_b
	
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
	# Ajustar la posición de la pieza teniendo en cuenta el desplazamiento del tablero
	# Primero obtenemos la posición global de la pieza
	var global_pos = piece_obj.node.global_position
	
	# Luego restamos la posición global del nodo raíz (que contiene el desplazamiento)
	var adjusted_pos = global_pos - global_position
	
	# Ahora calculamos la celda usando las coordenadas ajustadas
	var px = adjusted_pos.x - puzzle_offset.x
	var py = adjusted_pos.y - puzzle_offset.y
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
	
	# Generar un ID de grupo único (usamos el ID de la primera pieza)
	var group_id = piece1.node.get_instance_id()
	
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
		
		# Calcular posición objetivo y aplicar Tween
		var target_position = puzzle_offset + target_cell * cell_size
		
		# Actualizar el estado de la pieza (si está en la posición correcta o no)
		update_piece_position_state(p)
		
		# Actualizar el ID de grupo de la pieza
		if p.node.has_method("set_group_id"):
			p.node.set_group_id(group_id)
		
		# Actualizar el pieces_group en el nodo de la pieza
		if p.node.has_method("update_pieces_group"):
			p.node.pieces_group = new_group
		
		if use_tween_effect:
			apply_tween_effect(p.node, target_position)
		else:
			p.node.position = target_position
	
	# Identificar las piezas de borde en el grupo
	update_edge_pieces_in_group(new_group)
	
	# Reproducir sonido de fusión (usando directamente el reproductor de audio)
	audio_merge.play()
	
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
	
	# Calcular la celda destino para la pieza principal (líder) usando get_cell_of_piece
	# que ya tiene en cuenta el desplazamiento del tablero
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
			
			# Aplicar efecto Tween
			var target_position = puzzle_offset + orig_cell * cell_size
			if use_tween_effect:
				apply_tween_effect(occupant.node, target_position)
			else:
				occupant.node.position = target_position
		
		# Colocar las piezas del grupo en las posiciones de las ocupantes
		for i in range(group_copy.size()):
			var p = group_copy[i]
			var new_cell = occupant_positions[i]
			set_piece_at(new_cell, p)
			
			# Aplicar efecto Tween
			var target_position = puzzle_offset + new_cell * cell_size
			if use_tween_effect:
				apply_tween_effect(p.node, target_position)
			else:
				p.node.position = target_position
		
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
					
					# Aplicar efecto Tween
					var target_position = puzzle_offset + free_cells[0] * cell_size
					if use_tween_effect:
						apply_tween_effect(occupant.node, target_position)
					else:
						occupant.node.position = target_position
						
				elif add_extra_row():
					# Si no hay celdas libres, intentamos añadir una fila
					free_cells = find_free_cells(1)
					if free_cells.size() > 0:
						remove_piece_at(occupant.current_cell)
						set_piece_at(free_cells[0], occupant)
						
						# Aplicar efecto Tween
						var target_position = puzzle_offset + free_cells[0] * cell_size
						if use_tween_effect:
							apply_tween_effect(occupant.node, target_position)
						else:
							occupant.node.position = target_position
			
			# Colocar la pieza en su posición
			set_piece_at(p_target, p)
			
			# Aplicar efecto Tween
			var target_position = puzzle_offset + p_target * cell_size
			if use_tween_effect:
				apply_tween_effect(p.node, target_position)
			else:
				p.node.position = target_position
	
	# Verificar que todas las piezas del grupo estén correctamente colocadas en el grid
	for p in group_copy:
		if not grid.has(cell_key(p.current_cell)) or grid[cell_key(p.current_cell)] != p:
			# Si la pieza no está en el grid o hay otra pieza en su lugar, recolocarla
			var free_cells = find_free_cells(1)
			if free_cells.size() > 0:
				set_piece_at(free_cells[0], p)
				
				# Aplicar efecto Tween
				var target_position = puzzle_offset + free_cells[0] * cell_size
				if use_tween_effect:
					apply_tween_effect(p.node, target_position)
				else:
					p.node.position = target_position
	
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
		# Actualizar el estado de posición de la pieza
		update_piece_position_state(piece_obj)
		
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
			
			# Marcar todas las piezas como en posición correcta
			if piece_obj.node.has_method("set_correct_position"):
				piece_obj.node.set_correct_position(true)
		
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
			
			# Marcar todas las piezas como en posición correcta
			if piece_obj.node.has_method("set_correct_position"):
				piece_obj.node.set_correct_position(true)
		
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
		# Actualizar el estado de posición de la pieza
		update_piece_position_state(piece_obj)
		
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
			
			# Marcar todas las piezas como en posición correcta
			if piece_obj.node.has_method("set_correct_position"):
				piece_obj.node.set_correct_position(true)
		
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
			
			# Marcar todas las piezas como en posición correcta
			if piece_obj.node.has_method("set_correct_position"):
				piece_obj.node.set_correct_position(true)
		
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
	
	# Actualizar las piezas de borde en todos los grupos
	var processed_groups = []  # Para evitar procesar dos veces el mismo grupo
	
	for piece_obj in pieces:
		var leader = get_group_leader(piece_obj)
		if not (leader in processed_groups):
			update_edge_pieces_in_group(leader.group)
			processed_groups.append(leader)
	
	# Verificar y corregir el estado del grid después de todas las fusiones
	verify_and_fix_grid()
	
	# Verificar victoria después de verificar todos los grupos
	call_deferred("check_victory_deferred")
	
	# También verificar por posición visual
	call_deferred("check_victory_by_position")

# Nueva función para identificar las piezas de borde en un grupo
func update_edge_pieces_in_group(group: Array):
	if group.size() <= 1:
		# Si solo hay una pieza en el grupo, es una pieza de borde
		for piece in group:
			if piece.node.has_method("set_edge_piece"):
				piece.node.set_edge_piece(true)
		return
	
	# Para grupos de más de una pieza, identificar las piezas de borde
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	
	# Primero, marcar todas las piezas como no borde
	for piece in group:
		if piece.node.has_method("set_edge_piece"):
			piece.node.set_edge_piece(false)
	
	# Luego, identificar las piezas que realmente son borde
	for piece in group:
		var cell = piece.current_cell
		var is_edge = false
		
		# Una pieza es de borde si en alguna dirección no tiene una pieza del mismo grupo
		for dir in directions:
			var neighbor_cell = cell + dir
			var has_neighbor = false
			
			# Buscar si hay una pieza del mismo grupo en esta dirección
			for other_piece in group:
				if other_piece.current_cell == neighbor_cell:
					has_neighbor = true
					break
			
			# Si no hay vecino en esta dirección, es una pieza de borde
			if not has_neighbor:
				is_edge = true
				break
		
		# Actualizar el estado de "edge" de la pieza
		if piece.node.has_method("set_edge_piece"):
			piece.node.set_edge_piece(is_edge)

func on_flip_button_pressed() -> void:
	# Variable para rastrear si encontramos una pieza seleccionada
	var target_piece = null
	
	# Primero intentamos encontrar una pieza que esté siendo arrastrada
	for piece_obj in pieces:
		if piece_obj.dragging:
			target_piece = piece_obj
			break
	
	# Si no hay pieza seleccionada, voltear todas las piezas (comportamiento original)
	if target_piece == null:
		# Crear un tween para la animación
		var tween = create_tween()
		
		# Voltear todas las piezas con animación
		for piece_obj in pieces:
			if piece_obj.node.has_method("flip_piece"):
				# Animar la escala para dar efecto de volteo
				tween.parallel().tween_property(piece_obj.node, "scale", Vector2(0, 1), flip_speed)
				
				# A la mitad de la animación, cambiar la textura
				tween.tween_callback(func():
					piece_obj.node.flip_piece()
				).set_delay(flip_speed)
				
				# Restaurar la escala
				tween.parallel().tween_property(piece_obj.node, "scale", Vector2(1, 1), flip_speed).set_delay(flip_speed)
	else:
		# Si hay una pieza seleccionada, voltear solo su grupo
		var group_pieces = target_piece.group
		
		# Crear un tween para la animación
		var tween = create_tween()
		
		# Voltear cada pieza del grupo con una animación
		for piece_obj in group_pieces:
			if piece_obj.node.has_method("flip_piece"):
				# Animar la escala para dar efecto de volteo
				tween.parallel().tween_property(piece_obj.node, "scale", Vector2(0, 1), flip_speed)
				
				# A la mitad de la animación, cambiar la textura
				tween.tween_callback(func():
					piece_obj.node.flip_piece()
				).set_delay(flip_speed)
				
				# Restaurar la escala
				tween.parallel().tween_property(piece_obj.node, "scale", Vector2(1, 1), flip_speed).set_delay(flip_speed)

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
	if puzzle_back:
		load_and_create_pieces(puzzle_back)
	else:
		# Si falla la generación de la textura trasera, recargamos la escena
		print("PuzzleGame: Error al generar textura trasera, recargando escena...")
		get_tree().reload_current_scene()

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
	
	# Ya no reproducimos el sonido de movimiento aquí
	# audio_move.play()
	
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

# Función para mostrar el menú de opciones
func show_options_menu():
	if has_node("/root/OptionsManager"):
		get_node("/root/OptionsManager").show_options(self)

# Nueva función para ajustar la interfaz según el tipo de dispositivo
func adjust_ui_for_device():
	var hbox = $CanvasLayer/HBoxContainer
	var button_difficult = $CanvasLayer/HBoxContainer/ButtonDifficult
	
	if is_mobile:
		# En dispositivos móviles, especialmente con isla (notch), añadir más margen superior
		var safe_area = DisplayServer.get_display_safe_area()
		var window_size = DisplayServer.window_get_size()
		
		# Calcular el margen superior necesario
		var top_margin = 50  # Margen base
		
		# Si hay una diferencia significativa entre el área segura y el tamaño de la ventana,
		# probablemente hay una isla o notch
		if safe_area.position.y > 10:  # Si hay un margen de seguridad superior
			top_margin = max(top_margin, safe_area.position.y + 20)  # Añadir margen adicional
			
		print("PuzzleGame: Margen superior ajustado a ", top_margin, " para dispositivo móvil")
		
		# Aplicar el margen superior
		hbox.position.y = top_margin
		
		# Ajustar también la posición del botón de dificultad
	else:
		# En ordenadores, usar un margen estándar
		hbox.position.y = 20
		button_difficult.position.y = 80
		
		print("PuzzleGame: Usando margen estándar para ordenador")

func process_piece_click_touch(touch_position: Vector2, touch_index: int) -> void:
	# Usar la posición del toque sin ajustar
	var mouse_pos = touch_position
	var clicked_piece = null
	
	# Encontrar la pieza clickeada
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
		var group_leader = get_group_leader(clicked_piece)
		
		# Mover todo el grupo desde cualquier pieza
		for p in group_leader.group:
			p.dragging = true
			# Guardar el offset (diferencia entre posición de la pieza y posición del toque)
			p.drag_offset = p.node.global_position - mouse_pos
			p.node.z_index = 9999
			if p.node.get_parent() != null:
				p.node.get_parent().move_child(p.node, p.node.get_parent().get_child_count() - 1)

func process_piece_release() -> void:
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
		
		# Guardar la posición actual antes de colocar el grupo
		var old_position = group_leader.current_cell
		
		# Colocar el grupo - aquí ocurre la magia
		place_group(group_leader)
		total_moves += 1
		
		# Reproducir sonido de movimiento solo si la posición cambió
		if old_position != group_leader.current_cell:
			AudioManager.play_sfx("res://Assets/Sounds/SFX/plop.mp3")
		
		# Verificar y corregir el estado del grid después de cada movimiento
		verify_and_fix_grid()
		
		# Verificar victoria después de cada movimiento
		check_victory()
		
		# También verificar por posición visual
		call_deferred("check_victory_by_position")

# Función para obtener el centro entre todos los puntos de contacto
func get_touch_center() -> Vector2:
	var center = Vector2.ZERO
	if touch_points.size() > 0:
		for point in touch_points.values():
			center += point
		center /= touch_points.size()
	return center

func process_piece_click(event: InputEvent) -> void:
	if event.pressed:
		# Usar la posición global del mouse sin ajustar por el desplazamiento
		var mouse_pos = event.position
		var clicked_piece = null
		
		# Encontrar la pieza clickeada
		for piece_obj in pieces:
			# Convertir la posición global del mouse a local de cada pieza
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
			var group_leader = get_group_leader(clicked_piece)
			
			# Mover todo el grupo desde cualquier pieza
			for p in group_leader.group:
				p.dragging = true
				p.drag_offset = p.node.global_position - mouse_pos
				p.node.z_index = 9999
				if p.node.get_parent() != null:
					p.node.get_parent().move_child(p.node, p.node.get_parent().get_child_count() - 1)
	else:
		# Al soltar, procesar el final del arrastre de la pieza
		process_piece_release()

# Función para cambiar la sensibilidad del desplazamiento
func set_pan_sensitivity(value: float) -> void:
	pan_sensitivity = clamp(value, 0.1, 2.0)
	# Si existe un sistema de guardado de preferencias, guardar el valor
	if has_node("/root/OptionsManager"):
		var options_manager = get_node("/root/OptionsManager")
		if options_manager.has_method("save_option"):
			options_manager.save_option("pan_sensitivity", pan_sensitivity)

# Función para cargar las preferencias del usuario
func load_user_preferences() -> void:
	if has_node("/root/OptionsManager"):
		var options_manager = get_node("/root/OptionsManager")
		if options_manager.has_method("get_option"):
			var saved_sensitivity = options_manager.get_option("pan_sensitivity", pan_sensitivity)
			pan_sensitivity = saved_sensitivity

# Función para crear un botón de opciones que muestre un panel de ajustes
func create_options_button():
	# Crear un botón de opciones
	var options_button = Button.new()
	options_button.text = "Opciones"
	
	# Ajustar tamaño y posición según el dispositivo
	if is_mobile:
		options_button.size = Vector2(150, 60)
		options_button.position = Vector2(get_viewport_rect().size.x - 160, 20)
	else:
		options_button.size = Vector2(120, 40)
		options_button.position = Vector2(get_viewport_rect().size.x - 130, 20)
	
	# Estilo del botón
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.8, 0.8)  # Azul semitransparente
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.9)  # Borde blanco
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	
	options_button.add_theme_stylebox_override("normal", style)
	options_button.add_theme_color_override("font_color", Color(1, 1, 1))
	
	# Conectar la señal pressed
	options_button.connect("pressed", Callable(self, "show_options_panel"))
	
	# Añadir a la escena
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "OptionsLayer"
	add_child(canvas_layer)
	canvas_layer.add_child(options_button)

# Función para mostrar el panel de opciones
func show_options_panel():
	# Verificar si ya existe un panel de opciones
	if has_node("OptionsLayer/OptionsPanel"):
		# Si existe, simplemente mostrarlo
		get_node("OptionsLayer/OptionsPanel").visible = true
		return
	
	# Crear un panel para las opciones
	var panel = Panel.new()
	panel.name = "OptionsPanel"
	
	# Ajustar tamaño y posición
	var viewport_size = get_viewport_rect().size
	panel.size = Vector2(viewport_size.x * 0.8, viewport_size.y * 0.6)
	panel.position = Vector2(viewport_size.x * 0.1, viewport_size.y * 0.2)
	
	# Estilo del panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)  # Fondo oscuro semitransparente
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.8, 0.9)  # Borde gris claro
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	
	panel.add_theme_stylebox_override("panel", style)
	
	# Crear un contenedor vertical para los controles
	var vbox = VBoxContainer.new()
	vbox.size = Vector2(panel.size.x * 0.9, panel.size.y * 0.9)
	vbox.position = Vector2(panel.size.x * 0.05, panel.size.y * 0.05)
	panel.add_child(vbox)
	
	# Añadir un título
	var title = Label.new()
	title.text = "Opciones"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(title)
	
	# Añadir un separador
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(separator)
	
	# Añadir control para la sensibilidad del desplazamiento
	var sensitivity_hbox = HBoxContainer.new()
	vbox.add_child(sensitivity_hbox)
	
	var sensitivity_label = Label.new()
	sensitivity_label.text = "Sensibilidad del desplazamiento:"
	sensitivity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sensitivity_label.add_theme_color_override("font_color", Color(1, 1, 1))
	sensitivity_hbox.add_child(sensitivity_label)
	
	var sensitivity_slider = HSlider.new()
	sensitivity_slider.name = "SensitivitySlider"
	sensitivity_slider.min_value = 0.1
	sensitivity_slider.max_value = 2.0
	sensitivity_slider.step = 0.1
	sensitivity_slider.value = pan_sensitivity
	sensitivity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sensitivity_hbox.add_child(sensitivity_slider)
	
	var sensitivity_value = Label.new()
	sensitivity_value.name = "SensitivityValue"
	sensitivity_value.text = str(pan_sensitivity)
	sensitivity_value.add_theme_color_override("font_color", Color(1, 1, 1))
	sensitivity_value.custom_minimum_size = Vector2(50, 0)
	sensitivity_hbox.add_child(sensitivity_value)
	
	# Conectar la señal value_changed del slider
	sensitivity_slider.connect("value_changed", Callable(self, "_on_sensitivity_changed"))
	
	# Añadir separador
	var separator2 = HSeparator.new()
	separator2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(separator2)
	
	# Añadir opción para activar/desactivar el efecto Tween
	var tween_check_hbox = HBoxContainer.new()
	vbox.add_child(tween_check_hbox)
	
	var tween_check_label = Label.new()
	tween_check_label.text = "Efecto de movimiento suave:"
	tween_check_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tween_check_label.add_theme_color_override("font_color", Color(1, 1, 1))
	tween_check_hbox.add_child(tween_check_label)
	
	var tween_check = CheckBox.new()
	tween_check.name = "TweenCheck"
	tween_check.button_pressed = use_tween_effect
	tween_check_hbox.add_child(tween_check)
	
	# Conectar la señal toggled del checkbox
	tween_check.connect("toggled", Callable(self, "_on_tween_toggled"))
	
	# Añadir control para la duración del efecto Tween
	var tween_duration_hbox = HBoxContainer.new()
	vbox.add_child(tween_duration_hbox)
	
	var tween_duration_label = Label.new()
	tween_duration_label.text = "Duración del efecto:"
	tween_duration_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tween_duration_label.add_theme_color_override("font_color", Color(1, 1, 1))
	tween_duration_hbox.add_child(tween_duration_label)
	
	var tween_duration_slider = HSlider.new()
	tween_duration_slider.name = "TweenDurationSlider"
	tween_duration_slider.min_value = 0.1
	tween_duration_slider.max_value = 1.0
	tween_duration_slider.step = 0.05
	tween_duration_slider.value = tween_duration
	tween_duration_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tween_duration_hbox.add_child(tween_duration_slider)
	
	var tween_duration_value = Label.new()
	tween_duration_value.name = "TweenDurationValue"
	tween_duration_value.text = str(tween_duration) + "s"
	tween_duration_value.add_theme_color_override("font_color", Color(1, 1, 1))
	tween_duration_value.custom_minimum_size = Vector2(50, 0)
	tween_duration_hbox.add_child(tween_duration_value)
	
	# Conectar la señal value_changed del slider
	tween_duration_slider.connect("value_changed", Callable(self, "_on_tween_duration_changed"))
	
	# Añadir un separador antes del botón de cerrar
	var separator3 = HSeparator.new()
	separator3.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(separator3)
	
	# Añadir un botón para cerrar el panel
	var close_button = Button.new()
	close_button.text = "Cerrar"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.connect("pressed", Callable(self, "_on_close_options"))
	vbox.add_child(close_button)
	
	# Añadir el panel a la capa de opciones
	get_node("OptionsLayer").add_child(panel)

# Función para manejar el cambio de sensibilidad
func _on_sensitivity_changed(value: float):
	set_pan_sensitivity(value)
	
	# Actualizar el texto del valor
	if has_node("OptionsLayer/OptionsPanel/SensitivityValue"):
		get_node("OptionsLayer/OptionsPanel/SensitivityValue").text = str(value)

# Función para cerrar el panel de opciones
func _on_close_options():
	if has_node("OptionsLayer/OptionsPanel"):
		get_node("OptionsLayer/OptionsPanel").visible = false


func _on_BackButton_pressed() -> void:
	# Volver al menú principal
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn")

# Nueva función para actualizar el estado de posición de una pieza
func update_piece_position_state(piece_obj: Piece):
	if is_instance_valid(piece_obj) and is_instance_valid(piece_obj.node):
		var is_correct = piece_obj.current_cell == piece_obj.original_pos
		
		# Si la pieza tiene el método para establecer el estado de posición, usarlo
		if piece_obj.node.has_method("set_correct_position"):
			piece_obj.node.set_correct_position(is_correct)

func play_flip_sound():
	if audio_flip and not audio_flip.playing:
		audio_flip.play()
