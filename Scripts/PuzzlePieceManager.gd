# PuzzlePieceManager.gd
# Manager para gestionar todas las piezas del puzzle, grupos, fusiones y colocación

extends Node
class_name PuzzlePieceManager

# Referencias al juego principal
var puzzle_game: PuzzleGame

# Variables para las piezas
var grid := {}  # Diccionario para saber qué pieza está en cada celda
var pieces := []  # Array para almacenar todas las piezas creadas
var original_rows: int  # Para guardar el número original de filas
var original_columns: int  # Para guardar el número original de columnas
var current_rows: int  # Filas actuales del puzzle (puede cambiar durante el juego)
var current_columns: int  # Columnas actuales del puzzle (no cambia)
var extra_rows_added: int = 0  # Contador de filas adicionales añadidas
var rows_added_top: int = 0  # Filas añadidas hacia arriba
var rows_added_bottom: int = 0  # Filas añadidas hacia abajo
var ungrouped_pieces: int = 0  # Número de piezas sin agrupar
var just_placed_piece: bool = false  # Variable para rastrear si una pieza fue colocada

# Configuración
var use_tween_effect: bool = true  # Activar/desactivar el efecto
var tween_duration: float = 0.3  # Duración de la animación Tween
var flip_speed: float = 0.01  # Velocidad de la animación de flip

# 🎯 CONFIGURACIÓN DE CENTRADO AUTOMÁTICO - AJUSTABLE PARA PRUEBAS
# Incrementa este valor si el puzzle sigue apareciendo mal centrado al cargar
var auto_center_delay: float = 1.5  # Retraso en segundos antes del centrado automático

# Variables para límites visuales
var border_areas: Array = []
var background_limits_container: Node2D = null  # 🆕 Contenedor para los límites que siempre está centrado
var original_area_color: Color = Color(0,0,0, 0.1)  # Verde claro para área original
var expandable_area_color: Color = Color(0,0,0, 0.1)  # Amarillo para área expandible
var limit_area_color: Color = Color(0,0,0, 0.1)  # Rojo muy suave para límites absolutos

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
	var drag_start_cell := Vector2.ZERO  # Celda desde donde comenzó el arrastre
	var group := []  # Lista de piezas en el mismo grupo
	var order_number: int  # Número de orden de la pieza

	func _init(_node: Node2D, _sprite: Sprite2D, _orig: Vector2, _order: int):
		node = _node
		sprite = _sprite
		original_pos = _orig
		current_cell = _orig
		drag_start_cell = _orig  # Inicialmente, la celda de inicio es la misma que la original
		order_number = _order
		group = [self]  # Inicialmente, cada pieza está en su propio grupo

func initialize(game: PuzzleGame):
	puzzle_game = game
	# Usar los valores default del juego en lugar de GLOBAL (que puede tener valores acumulados)
	original_rows = puzzle_game.default_rows
	original_columns = puzzle_game.default_columns
	current_rows = original_rows
	current_columns = original_columns
	
	print("PuzzlePieceManager: Inicializado con tamaño original: ", original_columns, "x", original_rows)
	
	# Inicializar contadores de expansión
	rows_added_top = 0
	rows_added_bottom = 0
	extra_rows_added = 0
	load_user_preferences()

func load_user_preferences() -> void:
	# Cargar preferencias desde GLOBAL
	if has_node("/root/GLOBAL"):
		var global = GLOBAL
		if "puzzle" in global.settings:
			# Cargar configuración del efecto tween
			if "use_tween_effect" in global.settings.puzzle:
				use_tween_effect = global.settings.puzzle.use_tween_effect
			
			# Cargar duración del efecto tween
			if "tween_duration" in global.settings.puzzle:
				tween_duration = global.settings.puzzle.tween_duration

# 🎯 FUNCIÓN PARA AJUSTAR EL RETRASO DEL CENTRADO AUTOMÁTICO
func set_auto_center_delay(new_delay: float):
	auto_center_delay = new_delay
	print("PuzzlePieceManager: ⏰ Retraso de centrado automático cambiado a: ", auto_center_delay, " segundos")

func get_auto_center_delay() -> float:
	return auto_center_delay

func load_and_create_pieces(image_path: String, puzzle_back: Texture2D):
	# IMPORTANTE: Reinicializar tamaño del puzzle al empezar nueva partida
	print("PuzzlePieceManager: Reinicializando tamaño del puzzle")
	current_rows = original_rows
	current_columns = original_columns
	extra_rows_added = 0
	rows_added_top = 0
	rows_added_bottom = 0
	print("PuzzlePieceManager: Tamaño reiniciado a: ", current_columns, "x", current_rows)
	
	# 1) Cargar la textura
	var puzzle_texture = load(image_path) if load(image_path) else null
	if puzzle_texture == null:
		push_warning("No se pudo cargar la imagen en: %s" % image_path)
		return

	# 2) Calcular escalado
	var viewport_size = puzzle_game.get_viewport_rect().size
	var original_w = float(puzzle_texture.get_width())
	var original_h = float(puzzle_texture.get_height())

	# Ajustar el factor de escala según el dispositivo
	var device_scale_factor = 1.0
	if puzzle_game.is_mobile:
		# En dispositivos móviles, usar un porcentaje mayor del espacio disponible
		device_scale_factor = 0.95
	else:
		device_scale_factor = puzzle_game.max_scale_percentage
	
	# Factor para no exceder el porcentaje máximo de la pantalla
	var scale_factor_w = (viewport_size.x * device_scale_factor) / original_w
	var scale_factor_h = (viewport_size.y * device_scale_factor) / original_h
	var final_scale_factor = min(scale_factor_w, scale_factor_h, 1.0)

	var puzzle_width = original_w * final_scale_factor
	var puzzle_height = original_h * final_scale_factor

	# 3) Definir el tamaño de cada celda
	var cell_size = Vector2(puzzle_width / current_columns, puzzle_height / current_rows)

	# 4) Calcular offset para centrar el puzzle perfectamente
	# Simplificar el cálculo de centrado para evitar desplazamientos
	var puzzle_offset = (viewport_size - Vector2(puzzle_width, puzzle_height)) * 0.5
	
	print("PuzzlePieceManager: Datos de centrado:")
	print("  - Viewport size: ", viewport_size)
	print("  - Puzzle size: ", Vector2(puzzle_width, puzzle_height))
	print("  - Calculated offset: ", puzzle_offset)

	# Actualizar datos del puzzle en el juego principal
	puzzle_game.set_puzzle_data(puzzle_texture, puzzle_width, puzzle_height, cell_size, puzzle_offset)

	# Construir el diccionario de parámetros para VictoryChecker
	var current_victory_params = {
		"pieces": pieces,
		"puzzle_offset": puzzle_offset,
		"cell_size": cell_size,
		"grid": grid,
		"original_rows": original_rows, 
		"progress_manager": puzzle_game.progress_manager,
		"audio_merge": puzzle_game.audio_merge,
		"show_success_message_func": Callable(puzzle_game, "show_success_message"),
		"update_piece_position_state_func": Callable(self, "update_piece_position_state"),
		"change_scene_func": Callable(puzzle_game, "safe_change_scene"),
		"stop_game_timer_func": Callable(puzzle_game.game_state_manager, "stop_game_timer"),
		"get_game_state_for_victory_func": Callable(puzzle_game.game_state_manager, "get_current_game_state_for_victory"),
		"on_puzzle_completed_func": Callable(puzzle_game, "_on_puzzle_completed")
	}
	puzzle_game.victory_checker.initialize(current_victory_params)

	# 5) Generar la lista de celdas y "desordenarlas"
	grid.clear()
	pieces.clear()
	var cell_list: Array[Vector2] = []
	for r in range(current_rows):
		for c in range(current_columns):
			cell_list.append(Vector2(c, r))

	# Desordenar completamente el cell_list
	cell_list.shuffle()

	# 6) Crear cada pieza (rows x columns)
	var piece_scene = load("res://Scenes/Components/PuzzlePiece/PuzzlePiece.tscn")
	if piece_scene == null:
		push_warning("No se pudo cargar PuzzlePiece.tscn")
		return
	
	var index = 0
	for row_i in range(current_rows):
		for col_i in range(current_columns):
			# Instanciar PuzzlePiece.tscn
			var piece_node = piece_scene.instantiate()
			puzzle_game.pieces_container.add_child(piece_node)
			
			# Asegurar que las piezas se muestren por encima del fondo
			piece_node.z_index = 5
			
			# Definir la región original (SIN escalado) para la parte de la textura
			var piece_orig_w = original_w / current_columns
			var piece_orig_h = original_h / current_rows
			var region_rect = Rect2(
				col_i * piece_orig_w,
				row_i * piece_orig_h,
				piece_orig_w,
				piece_orig_h
			)
			
			# Configurar la pieza con la textura frontal y la trasera (puzzle_back)
			piece_node.set_piece_data(puzzle_texture, puzzle_back, region_rect)
			
			# Calcular y aplicar la escala para que la pieza se ajuste EXACTAMENTE a la celda
			# Añadir un factor de solapamiento agresivo para eliminar gaps completamente
			var overlap_factor = 1.01  # 1% de solapamiento para eliminar gaps
			var scale_x = (cell_size.x / piece_orig_w) * overlap_factor
			var scale_y = (cell_size.y / piece_orig_h) * overlap_factor
			piece_node.get_node("Sprite2D").scale = Vector2(scale_x, scale_y)
			
			# ELIMINADO: offset_compensation que causaba el doble desplazamiento
			# Todo el posicionamiento se hace a nivel del nodo principal para centrado correcto
			piece_node.get_node("Sprite2D").position = Vector2.ZERO
			
			# NUEVO: Asegurar que el sprite está perfectamente centrado
			_ensure_sprite_centered(piece_node)
			
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
			
			# Establecer ID único para cada pieza individual inicialmente
			var initial_group_id = piece_node.get_instance_id()
			if piece_node.has_method("set_group_id"):
				piece_node.set_group_id(initial_group_id)
			
			# Actualizar el pieces_group inicial
			if piece_node.has_method("update_pieces_group"):
				piece_node.update_pieces_group([piece_obj])
			
			# Cada pieza comienza como pieza de borde en su propio grupo
			if piece_node.has_method("set_edge_piece"):
				piece_node.set_edge_piece(true)
			
			# Aplicar efectos visuales iniciales
			if piece_node.has_method("update_visual_effects"):
				piece_node.update_visual_effects()
	
	# Inicializar el contador de grupos: al inicio, cada pieza es su propio grupo
	ungrouped_pieces = pieces.size()
	if OS.is_debug_build():
		print("Puzzle inicializado con ", ungrouped_pieces, " grupos individuales")
	
	# Actualizar las visuales de todas las piezas para que muestren los colores correctos
	for piece_obj in pieces:
		if piece_obj.node.has_method("update_all_visuals"):
			piece_obj.node.update_all_visuals()
	
	# Crear límites visuales
	create_visual_borders()
	
	# Verificar posicionamiento para diagnóstico
	_verify_piece_positioning()
	
	# Si hay problemas de centrado, aplicar corrección automática
	if not _verify_piece_positioning():
		print("PuzzlePieceManager: ⚠️  Detectado problema de centrado - Aplicando corrección automática...")
		_apply_smart_centering_correction()
	
	check_all_groups()
	
	# IMPORTANTE: Ahora que TODAS las piezas están completamente cargadas, 
	# aplicar centrado automático para asegurar posicionamiento perfecto
	print("PuzzlePieceManager: ✅ Todas las piezas cargadas. Aplicando centrado automático final...")
	
	# Esperar un frame para asegurar que todo está completamente estabilizado
	await puzzle_game.get_tree().process_frame
	
	# 🎯 RETRASO CONFIGURABLE - Ajusta auto_center_delay si sigue fallando
	print("PuzzlePieceManager: ⏰ Esperando ", auto_center_delay, " segundos antes del centrado automático...")
	await puzzle_game.get_tree().create_timer(auto_center_delay).timeout
	
	# Aplicar centrado automático silencioso
	puzzle_game.force_complete_recenter(true)
	
	# Mostrar mensaje de confirmación del centrado automático
	print("PuzzlePieceManager: 🎯 Centrado automático completado al cargar el puzzle")
	
	# Mostrar mensaje breve al usuario
	await puzzle_game.get_tree().create_timer(0.5).timeout
	puzzle_game.show_success_message("🎯 Puzzle centrado automáticamente", 1.5)

# === GRID: GET/SET/REMOVE PIEZA EN CELDA ===
func cell_key(cell: Vector2) -> String:
	return "%d_%d" % [int(cell.x), int(cell.y)]

func set_piece_at(cell: Vector2, piece_obj: Piece):
	grid[cell_key(cell)] = piece_obj
	piece_obj.current_cell = cell

func get_piece_at(cell: Vector2) -> Piece:
	return grid.get(cell_key(cell), null)

func remove_piece_at(cell: Vector2):
	grid.erase(cell_key(cell))

# === OBTENER LA CELDA DE UNA PIEZA POR SU POSICIÓN ===
func get_cell_of_piece(piece_obj: Piece) -> Vector2:
	# Ajustar la posición de la pieza teniendo en cuenta el desplazamiento del tablero
	var global_pos = piece_obj.node.global_position
	
	# Para un mejor diagnóstico
	if OS.is_debug_build():
		print("Posición global de pieza: ", global_pos)
		print("Posición global del nodo: ", puzzle_game.global_position)
		print("Posición del contenedor: ", puzzle_game.pieces_container.global_position if puzzle_game.pieces_container else Vector2.ZERO)
	
	# El posicionamiento ha cambiado ya que las piezas están dentro del contenedor
	var adjusted_pos
	if puzzle_game.pieces_container:
		# Si estamos usando el contenedor, necesitamos tener en cuenta su posición global
		adjusted_pos = global_pos - puzzle_game.pieces_container.global_position
	else:
		# Para compatibilidad con la versión anterior
		adjusted_pos = global_pos - puzzle_game.global_position
	
	# Obtener datos del puzzle
	var puzzle_data = puzzle_game.get_puzzle_data()
	
	# Ahora calculamos la celda usando las coordenadas ajustadas
	var px = adjusted_pos.x - puzzle_data.offset.x
	var py = adjusted_pos.y - puzzle_data.offset.y
	var cx = int(round(px / puzzle_data.cell_size.x))
	var cy = int(round(py / puzzle_data.cell_size.y))
	
	return Vector2(cx, cy)

# Función para aplicar el efecto de Tween
func apply_tween_effect(node: Node2D, target_position: Vector2):
	# Crear un nuevo Tween
	var tween = puzzle_game.create_tween()
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
		# Eliminar la restricción de límites del tablero - esto permitirá encontrar piezas
		# en cualquier posición, incluso fuera de los límites originales
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
		var current_diff = piece2.current_cell - piece1.current_cell
		# Usar una comparación con un epsilon para mayor precisión
		var epsilon = 0.1
		return abs(current_diff.x - diff.x) < epsilon and abs(current_diff.y - diff.y) < epsilon
	return false

# Función para añadir una fila adicional al tablero (hacia abajo)
func add_extra_row():
	if extra_rows_added >= puzzle_game.max_extra_rows:
		return false  # No se pueden añadir más filas
	
	# Modificar variables locales del puzzle, NO el GLOBAL
	current_rows += 1
	extra_rows_added += 1
	rows_added_bottom += 1
	
	print("PuzzlePieceManager: Fila añadida hacia abajo. Filas actuales: ", current_rows, " (original: ", original_rows, ")")
	
	var puzzle_data = puzzle_game.get_puzzle_data()
	
	# En lugar de recalcular el tamaño de las celdas, aumentamos el tamaño total del puzzle
	var viewport_size = puzzle_game.get_viewport_rect().size
	var puzzle_height = puzzle_data.cell_size.y * current_rows  # Usar las filas actuales del puzzle
	
	# 🔧 FIX: MANTENER el offset actual sin recalcularlo para evitar movimiento no deseado
	# El puzzle debe mantener su posición actual cuando se expande
	var puzzle_offset = puzzle_data.offset  # Mantener offset actual
	
	print("PuzzlePieceManager: Manteniendo offset actual para expansión: ", puzzle_offset)
	
	# Actualizar datos del puzzle con la nueva altura pero el mismo offset
	puzzle_game.set_puzzle_data(puzzle_data.texture, puzzle_data.width, puzzle_height, puzzle_data.cell_size, puzzle_offset)
	
	# Actualizar la posición de todas las piezas para reflejar el nuevo offset
	var updated_puzzle_data = puzzle_game.get_puzzle_data()
	for piece_obj in pieces:
		piece_obj.node.position = updated_puzzle_data.offset + piece_obj.current_cell * updated_puzzle_data.cell_size
	
	# Actualizar límites visuales
	update_visual_borders()
	
	return true

# Nueva función para añadir una fila adicional al tablero (hacia arriba)
func add_extra_row_top():
	if extra_rows_added >= puzzle_game.max_extra_rows:
		return false  # No se pueden añadir más filas
	
	# Modificar variables locales del puzzle, NO el GLOBAL
	current_rows += 1
	extra_rows_added += 1
	rows_added_top += 1
	
	print("PuzzlePieceManager: Añadiendo fila en la parte superior. Filas totales: ", current_rows, " (original: ", original_rows, ")")
	
	# Mover todas las piezas una fila hacia abajo para hacer espacio arriba
	var old_grid = grid.duplicate()
	grid.clear()
	
	print("PuzzlePieceManager: Moviendo ", pieces.size(), " piezas una fila hacia abajo")
	
	# Actualizar posiciones de todas las piezas
	for piece_obj in pieces:
		var old_pos = piece_obj.current_cell
		# Incrementar la posición Y (mover hacia abajo)
		piece_obj.current_cell.y += 1
		# Actualizar el grid con la nueva posición
		set_piece_at(piece_obj.current_cell, piece_obj)
		print("PuzzlePieceManager: Pieza movida de ", old_pos, " a ", piece_obj.current_cell)
	
	var puzzle_data = puzzle_game.get_puzzle_data()
	
	# Aumentar el tamaño total del puzzle
	var viewport_size = puzzle_game.get_viewport_rect().size
	var puzzle_height = puzzle_data.cell_size.y * current_rows  # Usar las filas actuales del puzzle
	
	# 🔧 FIX: MANTENER el offset actual sin recalcularlo
	# Cuando se añade una fila arriba, el offset debe ajustarse hacia arriba por una celda
	# para compensar que las piezas se mueven hacia abajo pero queremos mantener el puzzle en la misma posición visual
	var puzzle_offset = puzzle_data.offset
	puzzle_offset.y -= puzzle_data.cell_size.y  # Ajustar offset hacia arriba por el tamaño de una celda
	
	print("PuzzlePieceManager: Ajustando offset para fila superior:")
	print("  - Offset anterior: ", puzzle_data.offset)
	print("  - Nuevo offset: ", puzzle_offset)
	print("  - Viewport size: ", viewport_size)
	print("  - New puzzle size: ", Vector2(puzzle_data.width, puzzle_height))
	
	# Actualizar datos del puzzle
	puzzle_game.set_puzzle_data(puzzle_data.texture, puzzle_data.width, puzzle_height, puzzle_data.cell_size, puzzle_offset)
	
	# Actualizar la posición visual de todas las piezas
	var updated_puzzle_data = puzzle_game.get_puzzle_data()
	for piece_obj in pieces:
		piece_obj.node.position = updated_puzzle_data.offset + piece_obj.current_cell * updated_puzzle_data.cell_size
	
	# Actualizar límites visuales
	update_visual_borders()
	
	print("PuzzlePieceManager: Fila superior añadida exitosamente")
	return true

# Obtener acceso a datos para otros managers
func get_pieces() -> Array:
	return pieces

func get_pieces_data():
	return {
		"pieces": pieces,
		"grid": grid,
		"ungrouped_pieces": ungrouped_pieces,
		"original_rows": original_rows,
		"extra_rows_added": extra_rows_added
	}

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

# Nueva función para actualizar el estado de posición de una pieza
func update_piece_position_state(piece_obj: Piece):
	if is_instance_valid(piece_obj) and is_instance_valid(piece_obj.node):
		var is_correct = piece_obj.current_cell == piece_obj.original_pos
		
		# Si la pieza tiene el método para establecer el estado de posición, usarlo
		if piece_obj.node.has_method("set_correct_position"):
			piece_obj.node.set_correct_position(is_correct)

# === Continúa con las funciones de fusión y colocación ===
# (Debido al límite de caracteres, continuaré en el siguiente archivo)

# Exportar funciones principales para acceso externo
func merge_pieces(piece1: Piece, piece2: Piece):
	_handle_merge_pieces(piece1, piece2)

func place_group(piece: Piece):
	_handle_place_group(piece)

func check_all_groups() -> void:
	_handle_check_all_groups()

func reorganize_pieces():
	# Reorganiza solo las piezas que están fuera del área original del puzzle
	# Mantiene las piezas dentro del área en sus posiciones actuales
	# Preserva toda la funcionalidad de colocación después de la reorganización
	
	print("PuzzlePieceManager: INICIANDO reorganización - SIN REINICIAR JUEGO")
	
	# IMPORTANTE: Solo reorganizar piezas, NO reiniciar el juego
	# No tocar timers, contadores ni estadísticas del juego
	_handle_reorganize_pieces()
	
	print("PuzzlePieceManager: REORGANIZACIÓN COMPLETADA - Estado del juego preservado")

# Nueva función para verificar si un grupo se puede colocar en una posición específica
# Útil para retroalimentación visual durante el arrastre
func can_place_group_at_position(piece: Piece, target_cell: Vector2) -> bool:
	var leader = get_group_leader(piece)
	
	# Verificar cada pieza del grupo
	for p in leader.group:
		var offset = p.original_pos - leader.original_pos
		var p_target = target_cell + offset
		
		# Verificar límites básicos - si está fuera de límites, se puede expandir el tablero
		if p_target.x < 0 or p_target.x >= current_columns:
			return false
		# Ya no limitamos p_target.y < 0 para permitir expansión hacia arriba
		# No limitamos p_target.y >= current_rows porque se puede añadir filas hacia abajo
	
	# Con la nueva lógica, siempre se puede colocar (desplazando ocupantes si es necesario)
	return true

# === FUNCIONES INTERNAS ===

func _handle_merge_pieces(piece1: Piece, piece2: Piece):
	# Indicar que se ha colocado/fusionado una pieza
	just_placed_piece = true
	
	# Combinar los grupos
	var new_group = []
	new_group.append_array(piece1.group)
	for p in piece2.group:
		if not (p in new_group):
			new_group.append(p)
	
	# Generar un ID único para el grupo basado en la primera pieza
	var group_id = piece1.node.get_instance_id()
	
	# Actualizar el grupo en todas las piezas
	for p in new_group:
		p.group = new_group
		# Asegurar que la posición es correcta
		var offset = p.original_pos - piece1.original_pos
		var target_cell = piece1.current_cell + offset
		
		# Asegurarse de que la celda está dentro de los límites
		target_cell.x = clamp(target_cell.x, 0, current_columns - 1)
		
		# Expandir hacia arriba si es necesario
		var local_rows_added = 0
		var original_y = target_cell.y
		while target_cell.y < 0:
			if not add_extra_row_top():
				target_cell.y = 0
				break
			local_rows_added += 1
			target_cell.y = original_y + local_rows_added  # Ajustar correctamente después de la expansión
		
		# Expandir hacia abajo si es necesario
		if target_cell.y >= current_rows:
			if not add_extra_row():
				target_cell.y = current_rows - 1
		
		# Actualizar la posición de la pieza
		remove_piece_at(p.current_cell)
		set_piece_at(target_cell, p)
		
		# Calcular posición objetivo y aplicar Tween
		var puzzle_data = puzzle_game.get_puzzle_data()
		var target_position = puzzle_data.offset + target_cell * puzzle_data.cell_size
		
		# Actualizar el estado de la pieza
		update_piece_position_state(p)
		
		# Actualizar el ID de grupo de la pieza para el sistema de colores
		if p.node.has_method("set_group_id"):
			p.node.set_group_id(group_id)
		
		# Actualizar el pieces_group en el nodo de la pieza para el sistema de colores
		if p.node.has_method("update_pieces_group"):
			p.node.update_pieces_group(new_group)
		
		if use_tween_effect:
			apply_tween_effect(p.node, target_position)
		else:
			p.node.position = target_position
	
	# Actualizar las piezas de borde en el grupo
	_update_edge_pieces_in_group(new_group)
	
	# Reproducir sonido de fusión
	print("PuzzlePieceManager: Reproduciendo sonido de fusión")
	puzzle_game.play_merge_sound()
	
	print("PuzzlePieceManager: Piezas fusionadas - nuevo grupo de ", new_group.size(), " piezas")

func _handle_place_group(piece: Piece):
	# Obtener el líder del grupo
	var leader = get_group_leader(piece)
	
	# Calcular la celda destino para la pieza principal
	var target_cell = get_cell_of_piece(leader)
	
	print("PuzzlePieceManager: Iniciando validación de colocación para grupo de ", leader.group.size(), " piezas en posición ", target_cell)
	
	# VALIDACIÓN PREVIA: Verificar si la colocación es válida
	if not _validate_placement(leader, target_cell):
		print("PuzzlePieceManager: Colocación inválida - devolviendo piezas a posición original")
		_rollback_to_original_position(leader)
		
		# Proporcionar retroalimentación específica sobre el límite
		var pieces_outside_horizontal = false
		var pieces_outside_vertical = false
		for group_piece in leader.group:
			var offset = group_piece.original_pos - leader.original_pos
			var p_target = target_cell + offset
			if p_target.x < 0 or p_target.x >= current_columns:
				pieces_outside_horizontal = true
			if (p_target.y >= current_rows or p_target.y < 0) and extra_rows_added >= puzzle_game.max_extra_rows:
				pieces_outside_vertical = true
		
		if pieces_outside_horizontal:
			puzzle_game.show_error_message("No se puede colocar fuera del área horizontal", 1.5)
		elif pieces_outside_vertical:
			puzzle_game.show_error_message("Se ha alcanzado el límite de expansión vertical", 1.5)
		else:
			puzzle_game.show_error_message("No se puede colocar aquí", 1.5)
		return
	
	# Indicar que se acaba de colocar una pieza o grupo
	just_placed_piece = true
	
	print("PuzzlePieceManager: Colocación válida - procediendo con sistema de onda expansiva")
	
	# NUEVA LÓGICA: Sistema de "onda expansiva"
	_place_group_with_wave_expansion(leader, target_cell)

func _handle_check_all_groups():
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
	var processed_groups = []
	for piece_obj in pieces:
		var leader = get_group_leader(piece_obj)
		if not (leader in processed_groups):
			_update_edge_pieces_in_group(leader.group)
			processed_groups.append(leader)
	
	# Verificar victoria después de todas las fusiones
	if just_placed_piece:
		print("PuzzlePieceManager: Llamando a verificación de victoria...")
		puzzle_game.victory_checker.run_check_victory_deferred()
		just_placed_piece = false

func _handle_reorganize_pieces():
	# Identificar grupos que están fuera del área original del puzzle
	var groups_to_reorganize = []
	var individual_pieces_to_reorganize = []
	var processed_leaders = []
	
	# Obtener datos del puzzle
	var puzzle_data = puzzle_game.get_puzzle_data()
	
	# Definir el área válida del puzzle original (sin filas extra)
	var min_x = 0
	var max_x = original_columns - 1
	var min_y = 0
	var max_y = original_rows - 1  # Usar las filas originales, no las expandidas
	
	print("PuzzlePieceManager: Reorganizando grupos fuera del área original (", min_x, ",", min_y, ") a (", max_x, ",", max_y, ")")
	
	# Encontrar todos los grupos que están (parcial o totalmente) fuera del área original
	for piece_obj in pieces:
		var leader = get_group_leader(piece_obj)
		
		# Si ya procesamos este líder, saltar
		if leader in processed_leaders:
			continue
		
		processed_leaders.append(leader)
		
		# Verificar si alguna pieza del grupo está fuera del área original
		var group_outside_area = false
		for group_piece in leader.group:
			var pos = group_piece.current_cell
			if pos.x < min_x or pos.x > max_x or pos.y < min_y or pos.y > max_y:
				group_outside_area = true
				break
		
		# Si el grupo está (parcial o totalmente) fuera del área, reorganizarlo
		if group_outside_area:
			# Separar piezas individuales de grupos multi-pieza
			if leader.group.size() == 1:
				individual_pieces_to_reorganize.append(leader)
			else:
				groups_to_reorganize.append(leader)
	
	if groups_to_reorganize.is_empty() and individual_pieces_to_reorganize.is_empty():
		print("PuzzlePieceManager: No hay grupos fuera del área original para reorganizar")
		puzzle_game.show_success_message("Todos los grupos ya están en el área del puzzle", 1.5)
		return
	
	var total_pieces = individual_pieces_to_reorganize.size()
	for group_leader in groups_to_reorganize:
		total_pieces += group_leader.group.size()
	
	print("PuzzlePieceManager: Encontrados ", groups_to_reorganize.size(), " grupos multi-pieza y ", individual_pieces_to_reorganize.size(), " piezas individuales (", total_pieces, " piezas total) fuera del área original")
	
	# PASO 1: Rellenar huecos internos con piezas individuales
	print("PuzzlePieceManager: PASO 1 - Rellenando huecos internos con piezas individuales")
	_fill_internal_gaps_with_individual_pieces(individual_pieces_to_reorganize)
	
	# PASO 2: Reorganizar piezas individuales restantes hacia el centro
	print("PuzzlePieceManager: PASO 2 - Reorganizando piezas individuales restantes hacia el centro")
	_reorganize_individual_pieces_to_center(individual_pieces_to_reorganize)
	
	# PASO 3: Reorganizar grupos multi-pieza manteniendo estructura
	print("PuzzlePieceManager: PASO 3 - Reorganizando grupos multi-pieza manteniendo estructura")
	groups_to_reorganize.sort_custom(func(a, b): return a.group.size() < b.group.size())
	
	for group_leader in groups_to_reorganize:
		print("PuzzlePieceManager: Reorganizando grupo de ", group_leader.group.size(), " piezas")
		
		# Buscar la mejor posición disponible para este grupo completo
		var best_anchor = _find_best_concentric_position_for_group(group_leader)
		
		if best_anchor != Vector2(-1, -1):
			# Mover el grupo completo manteniendo su estructura
			_move_group_to_anchor_preserving_structure(group_leader, best_anchor)
			print("PuzzlePieceManager: Grupo reubicado exitosamente en: ", best_anchor)
		else:
			print("PuzzlePieceManager: ADVERTENCIA - No se encontró espacio para el grupo, permanece en posición actual")
			# Por ahora, no expandir automáticamente durante la reorganización para evitar problemas
			# Solo reorganizar lo que se puede sin cambiar el tamaño del tablero
	
	print("PuzzlePieceManager: Reorganización completada manteniendo integridad de grupos")
	
	# Verificar estado final
	print("PuzzlePieceManager: Estado después de reorganización:")
	print("  - original_rows: ", original_rows)
	print("  - current_rows: ", current_rows)
	print("  - extra_rows_added: ", extra_rows_added)
	print("  - max_extra_rows permitidas: ", puzzle_game.max_extra_rows)

	puzzle_game.show_success_message("Reorganización completa: huecos rellenados y grupos centrados", 1.5)

# Funciones auxiliares privadas

# PASO 1: Función para rellenar huecos internos con piezas individuales
func _fill_internal_gaps_with_individual_pieces(individual_pieces: Array):
	if individual_pieces.is_empty():
		return
	
	print("PuzzlePieceManager: Identificando huecos internos en toda el área del puzzle")
	
	# Buscar TODOS los huecos en el área original del puzzle (método más simple y efectivo)
	var internal_gaps = []
	var center_row = original_rows / 2.0
	var center_col = original_columns / 2.0
	var center_pos = Vector2(center_col, center_row)
	
	# Buscar huecos en toda el área original, priorizando cercanía al centro
	for r in range(original_rows):
		for c in range(original_columns):
			var cell = Vector2(c, r)
			if get_piece_at(cell) == null:
				# Esta celda está vacía
				var distance_to_center = cell.distance_to(center_pos)
				internal_gaps.append({"cell": cell, "distance": distance_to_center})
	
	# Ordenar huecos por proximidad al centro del puzzle
	internal_gaps.sort_custom(func(a, b): return a.distance < b.distance)
	
	print("PuzzlePieceManager: Encontrados ", internal_gaps.size(), " huecos libres en el área original")
	
	# Rellenar huecos con piezas individuales, empezando por los más cercanos al centro
	var puzzle_data = puzzle_game.get_puzzle_data()
	var pieces_placed = 0
	
	for gap_data in internal_gaps:
		if individual_pieces.is_empty():
			break
		
		var gap = gap_data.cell
		
		# Verificar que la celda sigue libre (por si otra pieza la ocupó)
		if get_piece_at(gap) != null:
			continue
		
		# Tomar la primera pieza individual disponible
		var piece_leader = individual_pieces.pop_front()
		var piece = piece_leader.group[0]
		
		# Mover la pieza al hueco
		remove_piece_at(piece.current_cell)
		set_piece_at(gap, piece)
		
		# Actualizar posición visual
		var target_position = puzzle_data.offset + gap * puzzle_data.cell_size
		if use_tween_effect:
			apply_tween_effect(piece.node, target_position)
		else:
			piece.node.position = target_position
		
		# Actualizar estado
		update_piece_position_state(piece)
		pieces_placed += 1
		
		print("PuzzlePieceManager: Pieza individual colocada en hueco: ", gap, " (distancia al centro: ", gap_data.distance, ")")
	
	print("PuzzlePieceManager: ", pieces_placed, " piezas individuales colocadas en huecos del área original")

# PASO 2: Función para reorganizar piezas individuales restantes hacia el centro
func _reorganize_individual_pieces_to_center(individual_pieces: Array):
	if individual_pieces.is_empty():
		return
	
	print("PuzzlePieceManager: Reorganizando ", individual_pieces.size(), " piezas individuales hacia el centro")
	
	# Obtener posiciones disponibles ordenadas por cercanía al centro del área original
	var available_positions = _get_center_ordered_positions_for_individuals()
	
	var puzzle_data = puzzle_game.get_puzzle_data()
	var pieces_placed = 0
	
	# Colocar cada pieza individual en la posición más cercana al centro
	for piece_leader in individual_pieces:
		if available_positions.is_empty():
			print("PuzzlePieceManager: No hay más posiciones disponibles para piezas individuales")
			break
		
		var piece = piece_leader.group[0]
		var target_cell = available_positions.pop_front()
		
		# Mover la pieza
		remove_piece_at(piece.current_cell)
		set_piece_at(target_cell, piece)
		
		# Actualizar posición visual
		var target_position = puzzle_data.offset + target_cell * puzzle_data.cell_size
		if use_tween_effect:
			apply_tween_effect(piece.node, target_position)
		else:
			piece.node.position = target_position
		
		# Actualizar estado
		update_piece_position_state(piece)
		pieces_placed += 1
		
		print("PuzzlePieceManager: Pieza individual reubicada hacia el centro: ", target_cell)
	
	print("PuzzlePieceManager: ", pieces_placed, " piezas individuales reubicadas hacia el centro")

# PASO 3: Nueva función para encontrar posición usando ondas concéntricas desde el centro
func _find_best_concentric_position_for_group(leader: Piece) -> Vector2:
	# Calcular el centro del área original del puzzle
	var center_row = original_rows / 2.0
	var center_col = original_columns / 2.0
	var center_pos = Vector2(center_col, center_row)
	
	print("PuzzlePieceManager: Buscando posición concéntrica para grupo de ", leader.group.size(), " piezas desde centro: ", center_pos)
	
	# Usar búsqueda por ondas concéntricas: empezar desde el centro hacia afuera
	var max_distance = max(original_columns, current_rows)
	
	for distance in range(0, max_distance):
		# Crear lista de posiciones a esta distancia del centro
		var candidates_at_distance = []
		
		# Buscar primero en el área original
		for r in range(max(0, int(center_row) - distance), min(original_rows, int(center_row) + distance + 1)):
			for c in range(max(0, int(center_col) - distance), min(original_columns, int(center_col) + distance + 1)):
				var test_anchor = Vector2(c, r)
				var actual_distance = int(test_anchor.distance_to(center_pos))
				
				# Solo considerar posiciones exactamente a esta distancia
				if actual_distance == distance and _can_place_entire_group_at_anchor(leader, test_anchor):
					candidates_at_distance.append(test_anchor)
		
		# Si no encontramos en el área original, buscar en áreas expandidas
		if candidates_at_distance.is_empty() and distance > 0:
			for r in range(max(0, int(center_row) - distance), min(current_rows, int(center_row) + distance + 1)):
				for c in range(max(0, int(center_col) - distance), min(current_columns, int(center_col) + distance + 1)):
					var test_anchor = Vector2(c, r)
					var actual_distance = int(test_anchor.distance_to(center_pos))
					
					if actual_distance == distance and _can_place_entire_group_at_anchor(leader, test_anchor):
						candidates_at_distance.append(test_anchor)
		
		# Si encontramos candidatos a esta distancia, elegir el mejor
		if not candidates_at_distance.is_empty():
			# Ordenar por posición (preferir arriba-izquierda en caso de empate)
			candidates_at_distance.sort_custom(func(a, b): 
				if a.y != b.y:
					return a.y < b.y
				return a.x < b.x
			)
			
			var best_position = candidates_at_distance[0]
			print("PuzzlePieceManager: Posición concéntrica encontrada a distancia ", distance, ": ", best_position)
			return best_position
	
	print("PuzzlePieceManager: No se encontró posición concéntrica válida para el grupo")
	return Vector2(-1, -1)



# Función auxiliar para obtener posiciones libres ordenadas por proximidad al centro
func _get_center_ordered_positions_for_individuals() -> Array:
	var center_row = original_rows / 2.0
	var center_col = original_columns / 2.0
	var center_pos = Vector2(center_col, center_row)
	
	var available_positions = []
	
	# Buscar primero en el área original
	for r in range(original_rows):
		for c in range(original_columns):
			var cell = Vector2(c, r)
			if get_piece_at(cell) == null:
				var distance = cell.distance_to(center_pos)
				available_positions.append({"cell": cell, "distance": distance})
	
	# Si necesitamos más espacio, buscar en áreas expandidas
	for r in range(current_rows):
		if r >= 0 and r < original_rows:
			continue  # Ya incluidas arriba
		for c in range(current_columns):
			var cell = Vector2(c, r)
			if get_piece_at(cell) == null:
				var distance = cell.distance_to(center_pos)
				available_positions.append({"cell": cell, "distance": distance})
	
	# Ordenar por distancia al centro
	available_positions.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Extraer solo las celdas
	var result = []
	for pos_data in available_positions:
		result.append(pos_data.cell)
	
	return result

# Nueva función para encontrar la mejor posición centrada para un grupo
func _find_best_center_position_for_group(leader: Piece) -> Vector2:
	# Calcular el centro del área original del puzzle
	var center_row = original_rows / 2.0
	var center_col = original_columns / 2.0
	var center_pos = Vector2(center_col, center_row)
	
	print("PuzzlePieceManager: Buscando mejor posición centrada para grupo de ", leader.group.size(), " piezas")
	print("PuzzlePieceManager: Centro del puzzle: ", center_pos)
	
	# Crear lista de todas las posiciones posibles para el ancla del grupo, ordenadas por proximidad al centro
	var candidate_positions = []
	
	# Buscar primero en el área original
	for r in range(original_rows):
		for c in range(original_columns):
			var test_anchor = Vector2(c, r)
			if _can_place_entire_group_at_anchor(leader, test_anchor):
				var distance_to_center = test_anchor.distance_to(center_pos)
				candidate_positions.append({"anchor": test_anchor, "distance": distance_to_center})
	
	# Si no hay espacio en el área original, buscar en áreas expandidas
	if candidate_positions.is_empty():
		for r in range(current_rows):
			for c in range(current_columns):
				var test_anchor = Vector2(c, r)
				if _can_place_entire_group_at_anchor(leader, test_anchor):
					var distance_to_center = test_anchor.distance_to(center_pos)
					candidate_positions.append({"anchor": test_anchor, "distance": distance_to_center})
	
	# Ordenar por proximidad al centro (más cercano primero)
	candidate_positions.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Devolver la posición más cercana al centro donde el grupo quepa completo
	if candidate_positions.size() > 0:
		var best_position = candidate_positions[0].anchor
		print("PuzzlePieceManager: Mejor posición encontrada: ", best_position, " (distancia al centro: ", candidate_positions[0].distance, ")")
		return best_position
	
	print("PuzzlePieceManager: No se encontró posición válida para el grupo")
	return Vector2(-1, -1)

# Nueva función para verificar si un grupo completo puede colocarse en una posición ancla
func _can_place_entire_group_at_anchor(leader: Piece, anchor: Vector2) -> bool:
	# Verificar que todas las piezas del grupo pueden colocarse manteniendo su estructura relativa
	for piece in leader.group:
		var offset = piece.original_pos - leader.original_pos
		var target_cell = anchor + offset
		
		# Verificar límites horizontales (estrictos)
		if target_cell.x < 0 or target_cell.x >= current_columns:
			return false
		
		# Verificar límites verticales (permitir expansión hasta el máximo)
		if target_cell.y < 0:
			# Para expansión hacia arriba, verificar si aún tenemos margen de expansión
			var additional_rows_needed = abs(target_cell.y)
			if extra_rows_added + additional_rows_needed > puzzle_game.max_extra_rows:
				return false
		
		if target_cell.y >= current_rows:
			# Para expansión hacia abajo, verificar si aún tenemos margen de expansión
			var additional_rows_needed = target_cell.y - current_rows + 1
			if extra_rows_added + additional_rows_needed > puzzle_game.max_extra_rows:
				return false
		
		# Verificar que la celda esté libre o ocupada por el mismo grupo que se está moviendo
		var occupant = get_piece_at(target_cell)
		if occupant != null and not (occupant in leader.group):
			return false
	
	return true

# Nueva función para mover un grupo completo a una posición ancla preservando su estructura
func _move_group_to_anchor_preserving_structure(leader: Piece, anchor: Vector2):
	var puzzle_data = puzzle_game.get_puzzle_data()
	var group_id = leader.node.get_instance_id()
	
	print("PuzzlePieceManager: Moviendo grupo de ", leader.group.size(), " piezas a posición ancla: ", anchor)
	
	# Primero, expandir el tablero si es necesario para acomodar el grupo
	var expansion_needed_top = 0
	var expansion_needed_bottom = 0
	
	# Calcular cuánta expansión necesitamos
	for piece in leader.group:
		var offset = piece.original_pos - leader.original_pos
		var target_cell = anchor + offset
		
		if target_cell.y < 0:
			expansion_needed_top = max(expansion_needed_top, abs(target_cell.y))
		
		if target_cell.y >= current_rows:
			expansion_needed_bottom = max(expansion_needed_bottom, target_cell.y - current_rows + 1)
	
	# Expandir hacia arriba si es necesario
	for i in range(expansion_needed_top):
		if not add_extra_row_top():
			print("PuzzlePieceManager: ERROR - No se pudo expandir hacia arriba")
			break
	
	# Expandir hacia abajo si es necesario
	for i in range(expansion_needed_bottom):
		if not add_extra_row():
			print("PuzzlePieceManager: ERROR - No se pudo expandir hacia abajo")
			break
	
	# Liberar las posiciones actuales del grupo
	for piece in leader.group:
		remove_piece_at(piece.current_cell)
	
	# Colocar cada pieza del grupo en su nueva posición manteniendo la estructura relativa
	for piece in leader.group:
		var offset = piece.original_pos - leader.original_pos
		var target_cell = anchor + offset
		
		# Ajustar si hubo expansión hacia arriba
		if expansion_needed_top > 0:
			target_cell.y += expansion_needed_top
		
		# Verificar que la posición final está dentro de los límites
		target_cell.x = clamp(target_cell.x, 0, current_columns - 1)
		target_cell.y = clamp(target_cell.y, 0, current_rows - 1)
		
		# Colocar la pieza en el grid
		set_piece_at(target_cell, piece)
		
		# Mantener el grupo unido - NO cambiar piece.group
		# Actualizar colores de grupo manteniendo la cohesión visual
		if piece.node.has_method("set_group_id"):
			piece.node.set_group_id(group_id)
		if piece.node.has_method("update_pieces_group"):
			piece.node.update_pieces_group(leader.group)
		
		# Actualizar posición visual con animación
		var target_position = puzzle_data.offset + target_cell * puzzle_data.cell_size
		if use_tween_effect:
			apply_tween_effect(piece.node, target_position)
		else:
			piece.node.position = target_position
		
		# Actualizar estado de la pieza
		update_piece_position_state(piece)
		
		print("PuzzlePieceManager: Pieza movida a: ", target_cell)
	
	# Actualizar las piezas de borde del grupo y efectos visuales
	_update_edge_pieces_in_group(leader.group)
	
	# Actualizar efectos visuales para todas las piezas del grupo
	for piece in leader.group:
		if piece.node.has_method("update_visual_effects"):
			piece.node.update_visual_effects()
	
	print("PuzzlePieceManager: Grupo reubicado exitosamente manteniendo estructura y cohesión")

# Función para encontrar celdas libres dentro del área original del puzzle, priorizando el centro
func _find_free_cells_in_original_area() -> Array:
	var free_cells = []
	
	# Calcular el centro del área original
	var center_row = original_rows / 2.0
	var center_col = original_columns / 2.0
	
	# Crear lista de todas las celdas libres con su distancia al centro
	var cells_with_distance = []
	for r in range(original_rows):  # Solo filas originales
		for c in range(original_columns):
			var cell = Vector2(c, r)
			if get_piece_at(cell) == null:
				var distance_to_center = Vector2(c, r).distance_to(Vector2(center_col, center_row))
				cells_with_distance.append({"cell": cell, "distance": distance_to_center})
	
	# Ordenar por distancia al centro (más cercano primero)
	cells_with_distance.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Extraer solo las celdas ordenadas
	for cell_data in cells_with_distance:
		free_cells.append(cell_data.cell)
	
	return free_cells

# Función para encontrar posiciones cercanas al área del puzzle cuando no hay suficientes celdas libres
func _find_closest_available_positions_to_puzzle_area(needed_count: int) -> Array:
	var available_positions = []
	
	# Primero agregar todas las celdas libres del área original (ya ordenadas por proximidad al centro)
	available_positions.append_array(_find_free_cells_in_original_area())
	
	# Si necesitamos más posiciones, buscar en áreas expandidas cercanas al centro del puzzle original
	if available_positions.size() < needed_count:
		var center_row = original_rows / 2.0
		var center_col = original_columns / 2.0
		var expanded_cells_with_distance = []
		
		# Buscar en filas expandidas (por encima y por debajo del área original)
		for r in range(current_rows):
			# Saltar filas que ya están incluidas en el área original
			if r >= 0 and r < original_rows:
				continue
				
			for c in range(current_columns):
				var cell = Vector2(c, r)
				if get_piece_at(cell) == null:
					var distance_to_center = Vector2(c, r).distance_to(Vector2(center_col, center_row))
					expanded_cells_with_distance.append({"cell": cell, "distance": distance_to_center})
		
		# Ordenar por distancia al centro del puzzle original
		expanded_cells_with_distance.sort_custom(func(a, b): return a.distance < b.distance)
		
		# Agregar las celdas ordenadas hasta completar lo necesario
		for cell_data in expanded_cells_with_distance:
			available_positions.append(cell_data.cell)
			if available_positions.size() >= needed_count:
				break
	
	# Si aún necesitamos más posiciones, crear más filas si es posible
	while available_positions.size() < needed_count and extra_rows_added < puzzle_game.max_extra_rows:
		if add_extra_row():
			# Agregar las nuevas celdas libres de la fila recién creada, priorizando el centro
			var new_row = current_rows - 1
			var center_col = current_columns / 2.0
			var new_cells_with_distance = []
			
			for c in range(current_columns):
				var cell = Vector2(c, new_row)
				if get_piece_at(cell) == null:
					var distance_to_center_col = abs(c - center_col)
					new_cells_with_distance.append({"cell": cell, "distance": distance_to_center_col})
			
			# Ordenar por proximidad al centro de la columna
			new_cells_with_distance.sort_custom(func(a, b): return a.distance < b.distance)
			
			for cell_data in new_cells_with_distance:
				available_positions.append(cell_data.cell)
				if available_positions.size() >= needed_count:
					break
		else:
			break
	
	return available_positions

# Función para encontrar espacio contiguo para un grupo dentro de un área específica
func _find_contiguous_space_for_group_in_area(leader: Piece, available_cells: Array) -> Vector2:
	var group_size = leader.group.size()
	
	# Si es una sola pieza, cualquier celda libre sirve
	if group_size == 1:
		if available_cells.size() > 0:
			return available_cells[0]
		else:
			return Vector2(-1, -1)
	
	# Para grupos, necesitamos encontrar un área donde el grupo mantenga su estructura relativa
	# Calcular las dimensiones del grupo (bounding box)
	var min_offset = Vector2(INF, INF)
	var max_offset = Vector2(-INF, -INF)
	
	for piece in leader.group:
		var offset = piece.original_pos - leader.original_pos
		min_offset.x = min(min_offset.x, offset.x)
		min_offset.y = min(min_offset.y, offset.y)
		max_offset.x = max(max_offset.x, offset.x)
		max_offset.y = max(max_offset.y, offset.y)
	
	# Probar cada posición disponible como ancla potencial
	for anchor_cell in available_cells:
		var can_place_group = true
		
		# Verificar si todas las piezas del grupo caben en las celdas disponibles
		for piece in leader.group:
			var offset = piece.original_pos - leader.original_pos
			var target_cell = anchor_cell + offset
			
			# Verificar si esta posición está disponible
			if not (target_cell in available_cells) and get_piece_at(target_cell) != null:
				can_place_group = false
				break
		
		if can_place_group:
			return anchor_cell
	
	# Si no encontramos espacio contiguo, devolver posición inválida
	return Vector2(-1, -1)

func _check_space_for_group(leader: Piece, target_cell: Vector2) -> bool:
	for p in leader.group:
		var offset = p.original_pos - leader.original_pos
		var p_target = target_cell + offset
		
		# Solo verificar límites horizontales
		if p_target.x < 0 or p_target.x >= current_columns:
			return false
		
		# Permitir expansión vertical en ambas direcciones
		if p_target.y >= current_rows:
			if extra_rows_added >= puzzle_game.max_extra_rows:
				return false
		# Ya NO limitamos p_target.y < 0 para permitir expansión hacia arriba
	return true

func _find_valid_position_for_group(leader: Piece) -> Vector2:
	var current_pos = get_cell_of_piece(leader)
	
	if _check_space_for_group(leader, current_pos):
		return current_pos
	
	for r in range(current_rows):
		for c in range(current_columns):
			var test_pos = Vector2(c, r)
			if _check_space_for_group(leader, test_pos):
				return test_pos
	
	if add_extra_row():
		return _find_valid_position_for_group(leader)
	
	return current_pos

func _find_free_cells(count: int) -> Array:
	var free_cells = []
	for r in range(current_rows):
		for c in range(current_columns):
			var cell = Vector2(c, r)
			if get_piece_at(cell) == null:
				free_cells.append(cell)
				if free_cells.size() >= count:
					return free_cells
	return free_cells

# Las funciones de desplazamiento anterior han sido reemplazadas por el sistema de "onda expansiva"

# Función para validar si una colocación es permitida
func _validate_placement(leader: Piece, target_cell: Vector2) -> bool:
	print("PuzzlePieceManager: Validando colocación para grupo de ", leader.group.size(), " piezas en ", target_cell)
	
	# REGLA 1: Piezas individuales NO pueden colocarse sobre grupos existentes
	if leader.group.size() == 1:
		# Verificar si hay grupos en el área objetivo
		for piece in leader.group:
			var offset = piece.original_pos - leader.original_pos
			var p_target = target_cell + offset
			
			# Verificar límites básicos (solo horizontales)
			if p_target.x < 0 or p_target.x >= current_columns:
				print("PuzzlePieceManager: Rechazo por límite horizontal: p_target.x=", p_target.x)
				return false
			
			# Para expansión vertical, solo verificar si estamos en el límite absoluto de expansión
			if p_target.y >= current_rows and extra_rows_added >= puzzle_game.max_extra_rows:
				print("PuzzlePieceManager: Rechazo por límite de expansión hacia abajo: p_target.y=", p_target.y, ", current_rows=", current_rows, ", max_extra_rows=", puzzle_game.max_extra_rows)
				return false
			if p_target.y < 0 and extra_rows_added >= puzzle_game.max_extra_rows:
				print("PuzzlePieceManager: Rechazo por límite de expansión hacia arriba: p_target.y=", p_target.y, ", max_extra_rows=", puzzle_game.max_extra_rows)
				return false
			
			# Verificar si hay una pieza ocupando esa posición
			var occupant = get_piece_at(p_target)
			if occupant != null and not (occupant in leader.group):
				var occupant_leader = get_group_leader(occupant)
				# Si el ocupante es parte de un grupo (más de 1 pieza), rechazar
				if occupant_leader.group.size() > 1:
					print("PuzzlePieceManager: Pieza individual no puede colocarse sobre grupo de ", occupant_leader.group.size(), " piezas")
					return false
	
	# REGLA 2: Los grupos pueden colocarse en cualquier lugar (desplazando otros)
	# Verificar límites básicos para grupos (solo horizontales)
	for piece in leader.group:
		var offset = piece.original_pos - leader.original_pos
		var p_target = target_cell + offset
		
		# Verificar límites básicos (solo horizontales)
		if p_target.x < 0 or p_target.x >= current_columns:
			print("PuzzlePieceManager: Rechazo grupo por límite horizontal: p_target.x=", p_target.x)
			return false
		
		# Para expansión vertical, solo verificar si estamos en el límite absoluto de expansión
		if p_target.y >= current_rows and extra_rows_added >= puzzle_game.max_extra_rows:
			print("PuzzlePieceManager: Rechazo grupo por límite de expansión hacia abajo: p_target.y=", p_target.y, ", current_rows=", current_rows, ", max_extra_rows=", puzzle_game.max_extra_rows)
			return false
		if p_target.y < 0 and extra_rows_added >= puzzle_game.max_extra_rows:
			print("PuzzlePieceManager: Rechazo grupo por límite de expansión hacia arriba: p_target.y=", p_target.y, ", max_extra_rows=", puzzle_game.max_extra_rows)
			return false
	
	print("PuzzlePieceManager: Colocación validada exitosamente")
	return true

# Función para devolver un grupo a su posición original (rollback)
func _rollback_to_original_position(leader: Piece):
	print("PuzzlePieceManager: Ejecutando rollback para grupo de ", leader.group.size(), " piezas")
	
	var puzzle_data = puzzle_game.get_puzzle_data()
	var group_id = leader.node.get_instance_id()
	
	# Devolver cada pieza del grupo a su posición original guardada (drag_start_cell)
	for piece in leader.group:
		# Limpiar posición actual del grid
		remove_piece_at(piece.current_cell)
		
		# Restaurar a la posición desde donde se comenzó a arrastrar
		piece.current_cell = piece.drag_start_cell
		set_piece_at(piece.drag_start_cell, piece)
		
		# Actualizar posición visual con animación
		var target_position = puzzle_data.offset + piece.drag_start_cell * puzzle_data.cell_size
		if use_tween_effect:
			apply_tween_effect(piece.node, target_position)
		else:
			piece.node.position = target_position
		
		# Asegurar que mantiene la estructura visual del grupo
		if piece.node.has_method("set_group_id"):
			piece.node.set_group_id(group_id)
		if piece.node.has_method("update_pieces_group"):
			piece.node.update_pieces_group(leader.group)
		
		# Actualizar estado de la pieza
		update_piece_position_state(piece)
		
		# Asegurar que no está en modo dragging
		piece.dragging = false
		if piece.node.has_method("set_dragging"):
			piece.node.set_dragging(false)
	
	# Actualizar las piezas de borde en el grupo para mantener la visualización correcta
	_update_edge_pieces_in_group(leader.group)
	
	print("PuzzlePieceManager: Rollback completado, estructura de grupo mantenida")

# NUEVA FUNCIÓN: Sistema de "onda expansiva" para colocación de grupos
func _place_group_with_wave_expansion(leader: Piece, target_cell: Vector2):
	var puzzle_data = puzzle_game.get_puzzle_data()
	var group_copy = leader.group.duplicate()
	
	# PASO 1: Identificar todas las posiciones que necesita el grupo y expandir el tablero si es necesario
	var required_positions = []
	
	print("PuzzlePieceManager: Colocando grupo en target_cell: ", target_cell)
	
	# Primero, calcular todas las posiciones target sin expansión
	var initial_targets = []
	for p in group_copy:
		var offset = p.original_pos - leader.original_pos
		var p_target = target_cell + offset
		p_target.x = clamp(p_target.x, 0, current_columns - 1)
		initial_targets.append(p_target)
		print("PuzzlePieceManager: Posición inicial requerida para pieza: ", p_target)
	
	# Encontrar la Y mínima y máxima requeridas
	var min_y = 0
	var max_y = current_rows - 1
	for target in initial_targets:
		min_y = min(min_y, target.y)
		max_y = max(max_y, target.y)
	
	print("PuzzlePieceManager: Rango Y requerido: min=", min_y, ", max=", max_y, ", filas actuales=", current_rows)
	
	# Expandir hacia arriba si es necesario
	var rows_added_top = 0
	while min_y < 0:
		print("PuzzlePieceManager: Añadiendo fila superior, min_y=", min_y)
		if not add_extra_row_top():
			break
		rows_added_top += 1
		min_y += 1  # Después de añadir una fila arriba, min_y se incrementa
	
	# Expandir hacia abajo si es necesario
	while max_y >= current_rows:
		print("PuzzlePieceManager: Añadiendo fila inferior, max_y=", max_y)
		if not add_extra_row():
			max_y = current_rows - 1
			break
	
	print("PuzzlePieceManager: Filas añadidas arriba: ", rows_added_top, ", filas totales ahora: ", current_rows)
	
	# Ahora calcular las posiciones finales ajustadas
	for i in range(initial_targets.size()):
		var target = initial_targets[i]
		var adjusted_target = target
		# Solo ajustar si se añadieron filas arriba
		if rows_added_top > 0:
			adjusted_target.y += rows_added_top
		# Asegurar que está dentro de los límites finales
		adjusted_target.y = clamp(adjusted_target.y, 0, current_rows - 1)
		required_positions.append(adjusted_target)
		print("PuzzlePieceManager: Posición final ajustada para pieza: ", target, " -> ", adjusted_target)
	
	# PASO 2: Identificar todos los grupos afectados
	var affected_groups = {}  # group_leader -> group_positions
	var all_affected_pieces = []
	
	for pos in required_positions:
		var occupant = get_piece_at(pos)
		if occupant != null and not (occupant in group_copy):
			var occupant_leader = get_group_leader(occupant)
			if not (occupant_leader in affected_groups):
				affected_groups[occupant_leader] = []
				# Agregar todas las piezas del grupo afectado
				for piece_in_group in occupant_leader.group:
					affected_groups[occupant_leader].append(piece_in_group.current_cell)
					all_affected_pieces.append(piece_in_group)
	
	print("PuzzlePieceManager: Grupos afectados: ", affected_groups.size())
	
	# PASO 3: Liberar todas las posiciones (primero el grupo que se mueve, luego los afectados)
	for p in group_copy:
		remove_piece_at(p.current_cell)
	
	for affected_piece in all_affected_pieces:
		remove_piece_at(affected_piece.current_cell)
	
	# PASO 4: Colocar el grupo principal en su posición objetivo
	_place_group_at_positions(leader, group_copy, required_positions, target_cell)
	
	# PASO 5: Redistribuir grupos afectados con "onda expansiva"
	_redistribute_affected_groups(affected_groups)
	
	# PASO 6: Intentar fusiones automáticas
	_attempt_automatic_merges(leader)
	
	# PASO 7: Guardar el tamaño del grupo antes de verificar fusiones
	var initial_group_size = leader.group.size()
	
	# PASO 8: Verificar grupos al final
	check_all_groups()
	
	# PASO 9: Reproducir sonido apropiado
	# Si el grupo aumentó de tamaño, hubo fusión (ya se reprodujo audio_merge)
	# Si el grupo mantiene el tamaño, solo fue movimiento
	if leader.group.size() == initial_group_size:
		print("PuzzlePieceManager: Reproduciendo sonido de movimiento")
		puzzle_game.play_move_sound()

# Función para colocar un grupo en posiciones específicas
func _place_group_at_positions(leader: Piece, group_pieces: Array, positions: Array, leader_target: Vector2):
	var puzzle_data = puzzle_game.get_puzzle_data()
	var group_id = leader.node.get_instance_id()
	
	for i in range(group_pieces.size()):
		var p = group_pieces[i]
		var p_target = positions[i]
		
		# Colocar en grid
		set_piece_at(p_target, p)
		
		# Actualizar colores de grupo
		if p.node.has_method("set_group_id"):
			p.node.set_group_id(group_id)
		if p.node.has_method("update_pieces_group"):
			p.node.update_pieces_group(group_pieces)
		
		# Actualizar posición visual
		var target_position = puzzle_data.offset + p_target * puzzle_data.cell_size
		if use_tween_effect:
			apply_tween_effect(p.node, target_position)
		else:
			p.node.position = target_position
		
		# Actualizar estado
		update_piece_position_state(p)

# Función para redistribuir grupos afectados buscando posiciones más cercanas
func _redistribute_affected_groups(affected_groups: Dictionary):
	print("PuzzlePieceManager: Redistribuyendo ", affected_groups.size(), " grupos afectados buscando posiciones cercanas")
	
	# Ordenar grupos afectados por prioridad (grupos más pequeños primero para facilitar reubicación)
	var sorted_groups = []
	for group_leader in affected_groups.keys():
		sorted_groups.append(group_leader)
	
	sorted_groups.sort_custom(func(a, b): return a.group.size() < b.group.size())
	
	# Redistribuir cada grupo empezando por los más pequeños
	for group_leader in sorted_groups:
		var group_pieces = group_leader.group
		print("PuzzlePieceManager: Reubicando grupo de ", group_pieces.size(), " piezas desde posición: ", group_leader.current_cell)
		
		# Buscar la posición más cercana disponible
		var best_anchor_position = _find_contiguous_space_for_group(group_leader)
		
		if best_anchor_position != Vector2(-1, -1):
			_place_group_maintaining_structure(group_leader, group_pieces, best_anchor_position)
			print("PuzzlePieceManager: Grupo reubicado exitosamente en: ", best_anchor_position)
		else:
			print("PuzzlePieceManager: ERROR - No se pudo encontrar espacio para el grupo")
			# Como último recurso, expandir tablero y colocar en la posición más cercana posible
			if add_extra_row():
				best_anchor_position = _find_contiguous_space_for_group(group_leader)
				if best_anchor_position != Vector2(-1, -1):
					_place_group_maintaining_structure(group_leader, group_pieces, best_anchor_position)
					print("PuzzlePieceManager: Grupo reubicado en nueva fila: ", best_anchor_position)
				else:
					print("PuzzlePieceManager: ERROR CRÍTICO - No se pudo reubicar grupo incluso con nueva fila")

# Función para encontrar espacio contiguo más cercano donde un grupo pueda mantener su estructura
func _find_contiguous_space_for_group(leader: Piece) -> Vector2:
	var group_pieces = leader.group
	
	# Obtener la posición actual del líder como punto de referencia
	var current_leader_pos = leader.current_cell
	
	
	print("PuzzlePieceManager: Buscando espacio más cercano para grupo desde posición: ", current_leader_pos)
	
	# Crear lista de posiciones candidatas ordenadas por distancia
	var candidates = []
	for row in range(current_rows):
		for col in range(current_columns):
			var test_pos = Vector2(col, row)
			var distance = current_leader_pos.distance_squared_to(test_pos)
			candidates.append({"pos": test_pos, "distance": distance})
	
	# Ordenar por distancia (más cercano primero)
	candidates.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Probar cada posición empezando por la más cercana
	for candidate in candidates:
		var test_anchor = candidate.pos
		if _can_place_group_at_anchor_ignore_own_group(leader, test_anchor):
			print("PuzzlePieceManager: Espacio libre encontrado en: ", test_anchor, " (distancia: ", candidate.distance, ")")
			return test_anchor
	
	# Si no hay espacio libre inmediato, intentar crear espacio empujando
	for candidate in candidates:
		var test_anchor = candidate.pos
		var created_space = _try_create_space_by_pushing(leader, test_anchor)
		if created_space:
			print("PuzzlePieceManager: Espacio creado empujando en: ", test_anchor, " (distancia: ", candidate.distance, ")")
			return test_anchor
	
	# Como último recurso, añadir filas y buscar en la zona más cercana a la posición actual
	if add_extra_row():
		# Buscar en las nuevas filas cerca de la posición Y actual
		var new_candidates = []
		for row in range(current_rows - 1, current_rows):  # Solo la nueva fila
			for col in range(current_columns):
				var test_pos = Vector2(col, row)
				var distance = current_leader_pos.distance_squared_to(test_pos)
				new_candidates.append({"pos": test_pos, "distance": distance})
		
		new_candidates.sort_custom(func(a, b): return a.distance < b.distance)
		
		for candidate in new_candidates:
			var test_anchor = candidate.pos
			if _can_place_group_at_anchor_ignore_own_group(leader, test_anchor):
				print("PuzzlePieceManager: Espacio encontrado en nueva fila: ", test_anchor)
				return test_anchor
	
	print("PuzzlePieceManager: No se pudo encontrar espacio contiguo cercano")
	return Vector2(-1, -1)

# Función para verificar si un grupo puede colocarse en una posición ancla específica (ignorando su propio grupo)
func _can_place_group_at_anchor_ignore_own_group(leader: Piece, anchor: Vector2) -> bool:
	# Verificar que todas las posiciones necesarias estén libres o ocupadas por el mismo grupo
	for piece in leader.group:
		var offset = piece.original_pos - leader.original_pos
		var target_cell = anchor + offset
		
		# Verificar límites (solo horizontales, permitir expansión vertical)
		if target_cell.x < 0 or target_cell.x >= current_columns:
			return false
		# Ya no limitamos target_cell.y < 0 para permitir expansión hacia arriba
		# Permitimos target_cell.y >= current_rows para expansión hacia abajo
		
		# Verificar que la celda esté libre o ocupada por el mismo grupo que se está moviendo
		var occupant = get_piece_at(target_cell)
		if occupant != null and not (occupant in leader.group):
			return false
	
	return true

# Función para verificar si un grupo puede colocarse en una posición ancla específica (versión estricta)
func _can_place_group_at_anchor(leader: Piece, anchor: Vector2, min_offset: Vector2, max_offset: Vector2) -> bool:
	# Verificar que todas las posiciones necesarias estén libres
	for piece in leader.group:
		var offset = piece.original_pos - leader.original_pos
		var target_cell = anchor + offset
		
		# Verificar límites (solo horizontales, permitir expansión vertical)
		if target_cell.x < 0 or target_cell.x >= current_columns:
			return false
		# Ya no limitamos target_cell.y < 0 para permitir expansión hacia arriba
		# Permitimos target_cell.y >= current_rows para expansión hacia abajo
		
		# Verificar que la celda esté libre
		var occupant = get_piece_at(target_cell)
		if occupant != null:
			return false
	
	return true

# Función para intentar crear espacio empujando otras piezas/grupos
func _try_create_space_by_pushing(leader: Piece, anchor: Vector2) -> bool:
	print("PuzzlePieceManager: Intentando crear espacio en: ", anchor, " empujando otras piezas")
	
	# Identificar todas las posiciones que necesita el grupo
	var required_positions = []
	var blocking_pieces = []
	
	for piece in leader.group:
		var offset = piece.original_pos - leader.original_pos
		var target_cell = anchor + offset
		
		# Verificar límites (solo horizontales, permitir expansión vertical)
		if target_cell.x < 0 or target_cell.x >= current_columns:
			return false
		# Ya no limitamos target_cell.y < 0 para permitir expansión hacia arriba
		# Permitimos target_cell.y >= current_rows para expansión hacia abajo
		
		required_positions.append(target_cell)
		
		# Encontrar piezas que bloquean esta posición
		var occupant = get_piece_at(target_cell)
		if occupant != null and not (occupant in leader.group):
			var occupant_leader = get_group_leader(occupant)
			if not (occupant_leader in blocking_pieces):
				blocking_pieces.append(occupant_leader)
	
	# Si no hay piezas bloqueando, el espacio ya está libre
	if blocking_pieces.is_empty():
		return true
	
	print("PuzzlePieceManager: Intentando reubicar ", blocking_pieces.size(), " grupos que bloquean")
	
	# Intentar reubicar cada grupo bloqueante
	var backup_positions = {}  # Para restaurar si falla
	var successfully_moved = []
	
	for blocking_leader in blocking_pieces:
		# Guardar posiciones actuales para posible restauración
		backup_positions[blocking_leader] = []
		for piece in blocking_leader.group:
			backup_positions[blocking_leader].append(piece.current_cell)
		
		# Liberar temporalmente las posiciones del grupo bloqueante
		for piece in blocking_leader.group:
			remove_piece_at(piece.current_cell)
		
		# Buscar nuevo lugar para el grupo bloqueante (recursivo pero limitado)
		var new_position = _find_closest_free_space_for_group(blocking_leader, anchor)
		
		if new_position != Vector2(-1, -1):
			# Mover el grupo bloqueante a su nueva posición
			_place_group_at_anchor_simple(blocking_leader, new_position)
			successfully_moved.append(blocking_leader)
		else:
			# No se pudo reubicar este grupo, restaurar sus posiciones
			for i in range(blocking_leader.group.size()):
				var piece = blocking_leader.group[i]
				var old_cell = backup_positions[blocking_leader][i]
				set_piece_at(old_cell, piece)
			
			# Restaurar todos los grupos movidos anteriormente
			for moved_leader in successfully_moved:
				for i in range(moved_leader.group.size()):
					var piece = moved_leader.group[i]
					remove_piece_at(piece.current_cell)
					var old_cell = backup_positions[moved_leader][i]
					set_piece_at(old_cell, piece)
			
			print("PuzzlePieceManager: No se pudo crear espacio mediante empuje")
			return false
	
	print("PuzzlePieceManager: Espacio creado exitosamente mediante empuje")
	return true

# Función para encontrar el espacio libre más cercano para un grupo (sin empuje recursivo)
func _find_closest_free_space_for_group(leader: Piece, avoid_anchor: Vector2) -> Vector2:
	var current_pos = leader.current_cell
	
	# Crear lista de posiciones candidatas ordenadas por distancia
	var candidates = []
	for row in range(current_rows):
		for col in range(current_columns):
			var test_pos = Vector2(col, row)
			# Evitar el área que estamos tratando de liberar
			if test_pos.distance_squared_to(avoid_anchor) < 4:  # Radio de seguridad
				continue
			var distance = current_pos.distance_squared_to(test_pos)
			candidates.append({"pos": test_pos, "distance": distance})
	
	# Ordenar por distancia
	candidates.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Probar cada posición
	for candidate in candidates:
		var test_anchor = candidate.pos
		if _can_place_group_at_anchor_ignore_own_group(leader, test_anchor):
			return test_anchor
	
	return Vector2(-1, -1)

# Función simple para colocar un grupo en una posición específica
func _place_group_at_anchor_simple(leader: Piece, anchor: Vector2):
	var puzzle_data = puzzle_game.get_puzzle_data()
	var group_id = leader.node.get_instance_id()
	
	for piece in leader.group:
		var offset = piece.original_pos - leader.original_pos
		var target_cell = anchor + offset
		
		# Colocar en grid
		set_piece_at(target_cell, piece)
		
		# Actualizar posición visual
		var target_position = puzzle_data.offset + target_cell * puzzle_data.cell_size
		if use_tween_effect:
			apply_tween_effect(piece.node, target_position)
		else:
			piece.node.position = target_position

# Función para colocar un grupo manteniendo su estructura relativa
func _place_group_maintaining_structure(leader: Piece, group_pieces: Array, anchor_position: Vector2):
	var puzzle_data = puzzle_game.get_puzzle_data()
	var group_id = leader.node.get_instance_id()
	
	print("PuzzlePieceManager: Colocando grupo en estructura mantenida en: ", anchor_position)
	
	# Colocar cada pieza manteniendo su posición relativa al líder
	for piece in group_pieces:
		var offset = piece.original_pos - leader.original_pos
		var target_cell = anchor_position + offset
		
		# Verificación adicional de seguridad (solo horizontales, permitir expansión vertical)
		if target_cell.x >= 0 and target_cell.x < current_columns:
			# Colocar en grid
			set_piece_at(target_cell, piece)
			
			# Actualizar colores de grupo
			if piece.node.has_method("set_group_id"):
				piece.node.set_group_id(group_id)
			if piece.node.has_method("update_pieces_group"):
				piece.node.update_pieces_group(group_pieces)
			
			# Actualizar posición visual
			var target_position = puzzle_data.offset + target_cell * puzzle_data.cell_size
			if use_tween_effect:
				apply_tween_effect(piece.node, target_position)
			else:
				piece.node.position = target_position
			
			# Actualizar estado
			update_piece_position_state(piece)
		else:
			print("PuzzlePieceManager: ERROR - Posición fuera de límites para pieza: ", target_cell)

# Función para encontrar todas las celdas libres
func _find_all_free_cells() -> Array:
	var free_cells = []
	for r in range(current_rows):
		for c in range(current_columns):
			var cell = Vector2(c, r)
			if get_piece_at(cell) == null:
				free_cells.append(cell)
	return free_cells

# Función para intentar fusiones automáticas después de la colocación
func _attempt_automatic_merges(leader: Piece):
	var merged = true
	while merged:
		merged = false
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

func _update_edge_pieces_in_group(group: Array):
	if group.size() <= 1:
		for piece in group:
			if piece.node.has_method("set_edge_piece"):
				piece.node.set_edge_piece(true)
		return
	
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	
	for piece in group:
		if piece.node.has_method("set_edge_piece"):
			piece.node.set_edge_piece(false)
	
	for piece in group:
		var cell = piece.current_cell
		var is_edge = false
		
		for dir in directions:
			var neighbor_cell = cell + dir
			var has_neighbor = false
			
			for other_piece in group:
				if other_piece.current_cell == neighbor_cell:
					has_neighbor = true
					break
			
			if not has_neighbor:
				is_edge = true
				break
		
		if piece.node.has_method("set_edge_piece"):
			piece.node.set_edge_piece(is_edge)
		
		# Actualizar efectos visuales después de cambiar el estado de borde
		if piece.node.has_method("update_visual_effects"):
			piece.node.update_visual_effects() 

# === FUNCIONES PARA LÍMITES VISUALES ===

func create_visual_borders():
	# Limpiar bordes existentes
	clear_visual_borders()
	
	# Crear o obtener el contenedor BackgroundLimits
	_ensure_background_limits_container()
	
	var puzzle_data = puzzle_game.get_puzzle_data()
	var cell_size = puzzle_data.cell_size
	var offset = puzzle_data.offset
	
	# Crear bordes para mostrar el área expandible
	_create_expandable_area_borders(offset, cell_size)

func clear_visual_borders():
	# Limpiar solo las áreas, no el contenedor
	for border_area in border_areas:
		if is_instance_valid(border_area):
			border_area.queue_free()
	border_areas.clear()

func _ensure_background_limits_container():
	# Si no existe el contenedor, crearlo
	if background_limits_container == null or not is_instance_valid(background_limits_container):
		background_limits_container = Node2D.new()
		background_limits_container.name = "BackgroundLimits"
		background_limits_container.z_index = 0  # Muy detrás de las piezas
		
		# Añadir al BackgroundLayer para mantener la jerarquía correcta
		var background_layer = puzzle_game.get_node("BackgroundLayer")
		if background_layer:
			background_layer.add_child(background_limits_container)
			print("PuzzlePieceManager: Contenedor BackgroundLimits creado en BackgroundLayer")
		elif puzzle_game.pieces_container:
			# Fallback: añadir al contenedor de piezas si no existe BackgroundLayer
			puzzle_game.pieces_container.add_child(background_limits_container)
			print("PuzzlePieceManager: Contenedor BackgroundLimits creado en PiecesContainer (fallback)")
		else:
			puzzle_game.add_child(background_limits_container)
			print("PuzzlePieceManager: Contenedor BackgroundLimits creado directamente en juego")
	
	# 🔧 CLAVE: Mantener el contenedor siempre centrado horizontalmente
	var viewport_size = puzzle_game.get_viewport_rect().size
	var puzzle_data = puzzle_game.get_puzzle_data()
	
	# Centrar horizontalmente el contenedor en función del ancho del puzzle
	var horizontal_center = viewport_size.x * 0.5 - puzzle_data.width * 0.5
	background_limits_container.position.x = horizontal_center
	
	# El Y se mantiene en 0 para que las áreas usen posiciones absolutas en Y
	background_limits_container.position.y = 0
	
	print("PuzzlePieceManager: BackgroundLimits centrado horizontalmente en X=", horizontal_center)

func _create_expandable_area_borders(offset: Vector2, cell_size: Vector2):
	# Asegurar que tenemos el contenedor
	_ensure_background_limits_container()
	
	# Calcular las dimensiones del área usando las mismas coordenadas que las piezas
	var max_expansion_top = puzzle_game.max_extra_rows
	var max_expansion_bottom = puzzle_game.max_extra_rows
	
	# Calcular cuánta expansión queda disponible
	var remaining_expansion_top = max_expansion_top - extra_rows_added
	var remaining_expansion_bottom = max_expansion_bottom - extra_rows_added
	
	print("PuzzlePieceManager: Debug - offset: ", offset, ", cell_size: ", cell_size)
	print("PuzzlePieceManager: Debug - GLOBAL.rows: ", GLOBAL.rows, ", original_rows: ", original_rows, ", extra_rows_added: ", extra_rows_added)
	print("PuzzlePieceManager: Debug - rows_added_top: ", rows_added_top, ", rows_added_bottom: ", rows_added_bottom)
	
	# 🔧 CLAVE: Calcular posiciones RELATIVAS al contenedor BackgroundLimits
	# El contenedor ya está centrado horizontalmente, así que solo necesitamos posiciones Y absolutas
	
	# Área original del puzzle (usando las variables de seguimiento precisas)
	var original_area_top_y = offset.y + (rows_added_top * cell_size.y)
	var original_area_pos = Vector2(0, original_area_top_y)  # X=0 porque el contenedor ya está centrado
	var original_area_size = Vector2(GLOBAL.columns * cell_size.x, original_rows * cell_size.y)
	
	print("PuzzlePieceManager: Debug - original_area_pos (relativa): ", original_area_pos, ", original_area_size: ", original_area_size)
	
	# 1. Crear fondo para área original
	_create_border_area_in_container(original_area_pos, original_area_size, "original_area", original_area_color)
	
	# 2. Si hay expansión disponible hacia arriba, mostrar área expandible superior
	if remaining_expansion_top > 0:
		var expandable_top_pos = Vector2(0, offset.y + (rows_added_top * cell_size.y) - (remaining_expansion_top * cell_size.y))
		var expandable_top_size = Vector2(GLOBAL.columns * cell_size.x, remaining_expansion_top * cell_size.y)
		_create_border_area_in_container(expandable_top_pos, expandable_top_size, "expandable_top", expandable_area_color)
		print("PuzzlePieceManager: Debug - expandable_top_pos (relativa): ", expandable_top_pos, ", expandable_top_size: ", expandable_top_size)
	
	# 3. Si hay expansión disponible hacia abajo, mostrar área expandible inferior
	if remaining_expansion_bottom > 0:
		var expandable_bottom_pos = Vector2(0, original_area_top_y + original_area_size.y)
		var expandable_bottom_size = Vector2(GLOBAL.columns * cell_size.x, remaining_expansion_bottom * cell_size.y)
		_create_border_area_in_container(expandable_bottom_pos, expandable_bottom_size, "expandable_bottom", expandable_area_color)
		print("PuzzlePieceManager: Debug - expandable_bottom_pos (relativa): ", expandable_bottom_pos, ", expandable_bottom_size: ", expandable_bottom_size)
	
	# 4. Si ya hay filas expandidas actualmente, marcarlas con color diferente
	if current_rows > original_rows:
		# Área expandida hacia arriba (si existe)
		if rows_added_top > 0:
			var expanded_top_pos = Vector2(0, offset.y)
			var expanded_top_size = Vector2(GLOBAL.columns * cell_size.x, rows_added_top * cell_size.y)
			_create_border_area_in_container(expanded_top_pos, expanded_top_size, "expanded_top_area", limit_area_color)
			print("PuzzlePieceManager: Debug - expanded_top_pos (relativa): ", expanded_top_pos, ", expanded_top_size: ", expanded_top_size)
		
		# Área expandida hacia abajo (si existe)
		if rows_added_bottom > 0:
			var expanded_bottom_pos = Vector2(0, original_area_top_y + original_area_size.y)
			var expanded_bottom_size = Vector2(GLOBAL.columns * cell_size.x, rows_added_bottom * cell_size.y)
			_create_border_area_in_container(expanded_bottom_pos, expanded_bottom_size, "expanded_bottom_area", limit_area_color)
			print("PuzzlePieceManager: Debug - expanded_bottom_pos (relativa): ", expanded_bottom_pos, ", expanded_bottom_size: ", expanded_bottom_size)
	
	print("PuzzlePieceManager: Áreas visuales creadas en contenedor BackgroundLimits:")
	print("  - Área original: ", original_area_pos, " tamaño: ", original_area_size)
	print("  - Expansión restante: arriba=", remaining_expansion_top, " filas, abajo=", remaining_expansion_bottom, " filas")
	print("  - Contenedor position: ", background_limits_container.position)

func _create_border_area_in_container(position: Vector2, size: Vector2, area_name: String, color: Color):
	# Crear el área visual
	var border_area = ColorRect.new()
	border_area.name = area_name
	border_area.position = position  # Posición relativa al contenedor BackgroundLimits
	border_area.size = size
	border_area.color = color
	border_area.z_index = 0  # Heredará el z_index del contenedor
	border_area.mouse_filter = Control.MOUSE_FILTER_IGNORE  # No interceptar eventos de mouse
	
	# 🔧 CLAVE: Añadir al contenedor BackgroundLimits en lugar de directamente al BackgroundLayer
	if background_limits_container and is_instance_valid(background_limits_container):
		background_limits_container.add_child(border_area)
		border_areas.append(border_area)
		print("PuzzlePieceManager: Área '", area_name, "' añadida al contenedor BackgroundLimits en posición relativa: ", position)
	else:
		print("PuzzlePieceManager: ERROR - Contenedor BackgroundLimits no disponible para área '", area_name, "'")

# 🆕 Nueva función para destruir completamente el contenedor si es necesario
func destroy_background_limits_container():
	if background_limits_container and is_instance_valid(background_limits_container):
		background_limits_container.queue_free()
		background_limits_container = null
		border_areas.clear()  # Limpiar la lista ya que todas las áreas se destruirán con el contenedor
		print("PuzzlePieceManager: Contenedor BackgroundLimits destruido completamente")

func update_visual_borders():
	# 🔧 MEJORADO: Actualizar sin destruir el contenedor
	print("PuzzlePieceManager: Actualizando límites visuales manteniendo contenedor")
	
	# Solo limpiar las áreas, no el contenedor
	clear_visual_borders()
	
	# Recrear las áreas con los nuevos datos
	var puzzle_data = puzzle_game.get_puzzle_data()
	var cell_size = puzzle_data.cell_size
	var offset = puzzle_data.offset
	
	# Asegurar que el contenedor esté centrado correctamente
	_ensure_background_limits_container()
	
	# Crear las nuevas áreas
	_create_expandable_area_borders(offset, cell_size)

func toggle_visual_borders(visible: bool):
	# Alternar visibilidad de todo el contenedor
	if background_limits_container and is_instance_valid(background_limits_container):
		background_limits_container.visible = visible
		print("PuzzlePieceManager: Límites visuales ", "mostrados" if visible else "ocultados")
	else:
		print("PuzzlePieceManager: No hay contenedor de límites para alternar visibilidad")

func show_expansion_hint(direction: String):
	# Mostrar un mensaje temporalmente sobre la posibilidad de expansión
	var message = ""
	match direction:
		"up":
			if extra_rows_added < puzzle_game.max_extra_rows:
				message = "↑ Se puede expandir hacia arriba"
			else:
				message = "↑ Límite superior alcanzado"
		"down":
			if extra_rows_added < puzzle_game.max_extra_rows:
				message = "↓ Se puede expandir hacia abajo"
			else:
				message = "↓ Límite inferior alcanzado"
		"left":
			message = "← Límite lateral fijo"
		"right":
			message = "→ Límite lateral fijo"
	
	if message != "":
		puzzle_game.show_success_message(message, 1.0)

# 🆕 Función para obtener información del estado actual de límites visuales
func get_visual_borders_info() -> Dictionary:
	return {
		"container_exists": background_limits_container != null and is_instance_valid(background_limits_container),
		"container_position": background_limits_container.position if background_limits_container else Vector2.ZERO,
		"areas_count": border_areas.size(),
		"container_visible": background_limits_container.visible if background_limits_container else false
	}

# 🆕 Función para reinicializar completamente el sistema de límites visuales si es necesario
func reinitialize_visual_borders():
	print("PuzzlePieceManager: Reinicializando sistema de límites visuales...")
	destroy_background_limits_container()
	create_visual_borders()
	print("PuzzlePieceManager: Sistema de límites visuales reinicializado completamente")

# Función de diagnóstico para verificar el posicionamiento de las piezas
func _verify_piece_positioning():
	print("PuzzlePieceManager: =================== DIAGNÓSTICO COMPLETO ===================")
	var puzzle_data = puzzle_game.get_puzzle_data()
	var viewport_size = puzzle_game.get_viewport_rect().size
	
	print("📐 DATOS GENERALES:")
	print("  - Viewport size: ", viewport_size)
	print("  - Puzzle size: ", Vector2(puzzle_data.width, puzzle_data.height))
	print("  - Offset calculado: ", puzzle_data.offset)
	print("  - Tamaño de celda: ", puzzle_data.cell_size)
	print("  - PiecesContainer.position: ", puzzle_game.pieces_container.position if puzzle_game.pieces_container else "N/A")
	print("  - PuzzleGame.position: ", puzzle_game.position)
	
	# Verificar el centrado teórico
	var expected_center = viewport_size * 0.5
	var puzzle_center = puzzle_data.offset + Vector2(puzzle_data.width, puzzle_data.height) * 0.5
	print("  - Centro esperado de pantalla: ", expected_center)
	print("  - Centro calculado del puzzle: ", puzzle_center)
	print("  - Discrepancia de centrado: ", puzzle_center - expected_center)
	
	if pieces.size() > 0:
		print("\n🔍 ANÁLISIS DE PIEZAS:")
		var first_piece = pieces[0]
		var last_piece = pieces[-1]
		
		# Analizar primera pieza
		print("  📍 PRIMERA PIEZA:")
		print("    - Celda: ", first_piece.current_cell)
		print("    - Posición del nodo: ", first_piece.node.position)
		print("    - Posición del sprite: ", first_piece.node.get_node("Sprite2D").position if first_piece.node.has_node("Sprite2D") else "N/A")
		print("    - Posición global del nodo: ", first_piece.node.global_position)
		
		var expected_pos = puzzle_data.offset + first_piece.current_cell * puzzle_data.cell_size
		print("    - Posición esperada: ", expected_pos)
		print("    - Discrepancia: ", first_piece.node.position - expected_pos)
		
		# Analizar última pieza
		print("  📍 ÚLTIMA PIEZA:")
		print("    - Celda: ", last_piece.current_cell)
		print("    - Posición del nodo: ", last_piece.node.position)
		var expected_pos_last = puzzle_data.offset + last_piece.current_cell * puzzle_data.cell_size
		print("    - Posición esperada: ", expected_pos_last)
		print("    - Discrepancia: ", last_piece.node.position - expected_pos_last)
		
		# Verificar límites del puzzle
		var min_pos = Vector2(INF, INF)
		var max_pos = Vector2(-INF, -INF)
		for piece_obj in pieces:
			var pos = piece_obj.node.position
			min_pos.x = min(min_pos.x, pos.x)
			min_pos.y = min(min_pos.y, pos.y)
			max_pos.x = max(max_pos.x, pos.x + puzzle_data.cell_size.x)
			max_pos.y = max(max_pos.y, pos.y + puzzle_data.cell_size.y)
		
		print("\n📏 LÍMITES REALES DEL PUZZLE:")
		print("  - Esquina superior izquierda: ", min_pos)
		print("  - Esquina inferior derecha: ", max_pos)
		print("  - Tamaño real: ", max_pos - min_pos)
		print("  - Centro real: ", (min_pos + max_pos) * 0.5)
		print("  - Diferencia con centro de pantalla: ", (min_pos + max_pos) * 0.5 - expected_center)
	
	print("PuzzlePieceManager: ============= FIN DIAGNÓSTICO =============")
	
	# Determinar si necesitamos corrección
	if pieces.size() > 0:
		var actual_center = Vector2.ZERO
		var piece_count = 0
		for piece_obj in pieces:
			actual_center += piece_obj.node.position + puzzle_data.cell_size * 0.5
			piece_count += 1
		actual_center /= piece_count
		
		var center_discrepancy = actual_center - expected_center
		print("🎯 DIAGNÓSTICO FINAL:")
		print("  - Discrepancia del centro: ", center_discrepancy)
		if center_discrepancy.length() > 10:
			print("  ⚠️  SE REQUIERE CORRECCIÓN DE CENTRADO")
			return false
		else:
			print("  ✅ CENTRADO CORRECTO")
			return true
	
	return false

# Función para forzar el recentrado de todas las piezas (medida de seguridad)
func force_recenter_all_pieces():
	print("PuzzlePieceManager: Forzando recentrado de todas las piezas...")
	var puzzle_data = puzzle_game.get_puzzle_data()
	
	for piece_obj in pieces:
		# Recalcular la posición correcta para cada pieza
		var correct_position = puzzle_data.offset + piece_obj.current_cell * puzzle_data.cell_size
		piece_obj.node.position = correct_position
		
		# Asegurar que el sprite interno esté en (0,0)
		if piece_obj.node.has_node("Sprite2D"):
			piece_obj.node.get_node("Sprite2D").position = Vector2.ZERO
	
	print("PuzzlePieceManager: Recentrado forzado completado para ", pieces.size(), " piezas")

# Función para aplicar corrección inteligente de centrado
func _apply_smart_centering_correction():
	print("PuzzlePieceManager: 🔧 Iniciando corrección inteligente de centrado...")
	
	# Verificar que realmente tenemos piezas cargadas
	if pieces.size() == 0:
		print("PuzzlePieceManager: ⚠️ No hay piezas cargadas para centrar")
		return
	
	var viewport_size = puzzle_game.get_viewport_rect().size
	var expected_center = viewport_size * 0.5
	
	# Verificar que las piezas tienen posiciones válidas
	var invalid_pieces = 0
	for piece_obj in pieces:
		if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node):
			invalid_pieces += 1
	
	if invalid_pieces > 0:
		print("PuzzlePieceManager: ⚠️ ", invalid_pieces, " piezas inválidas encontradas, esperando...")
		return
	
	# Calcular el centro actual real de todas las piezas
	var actual_center = Vector2.ZERO
	var piece_count = 0
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for piece_obj in pieces:
		var pos = piece_obj.node.position
		actual_center += pos
		piece_count += 1
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	
	if piece_count == 0:
		print("PuzzlePieceManager: ⚠️ No se encontraron piezas válidas para centrar")
		return
	
	actual_center /= piece_count
	var puzzle_size = max_pos - min_pos
	var current_puzzle_center = min_pos + puzzle_size * 0.5
	
	# Calcular el desplazamiento necesario para centrar
	var correction_offset = expected_center - current_puzzle_center
	
	print("  - Centro actual del puzzle: ", current_puzzle_center)
	print("  - Centro esperado: ", expected_center)
	print("  - Corrección a aplicar: ", correction_offset)
	print("  - Piezas procesadas: ", piece_count)
	
	# Solo aplicar corrección si es significativa (más de 5 píxeles)
	if correction_offset.length() > 5.0:
		# Aplicar la corrección a todas las piezas
		for piece_obj in pieces:
			if is_instance_valid(piece_obj) and is_instance_valid(piece_obj.node):
				piece_obj.node.position += correction_offset
		
		# Actualizar el offset del puzzle en los datos globales
		var puzzle_data = puzzle_game.get_puzzle_data()
		var new_offset = puzzle_data.offset + correction_offset
		puzzle_game.set_puzzle_data(puzzle_data.texture, puzzle_data.width, puzzle_data.height, puzzle_data.cell_size, new_offset)
		
		print("  - Nuevo offset del puzzle: ", new_offset)
		print("PuzzlePieceManager: ✅ Corrección de centrado completada")
	else:
		print("PuzzlePieceManager: ✅ El puzzle ya está suficientemente centrado (offset: ", correction_offset.length(), ")")
	
	# Verificar que la corrección funcionó
	var verification_result = _verify_piece_positioning()
	if verification_result:
		print("PuzzlePieceManager: ✅ Corrección verificada exitosamente")
	else:
		print("PuzzlePieceManager: ⚠️  La corrección no fue completamente exitosa")

# Función para asegurar que cada sprite esté perfectamente centrado en su nodo padre
func _ensure_sprite_centered(piece_node: Node2D):
	if not piece_node.has_node("Sprite2D"):
		return
	
	var sprite = piece_node.get_node("Sprite2D")
	
	# Forzar posición del sprite a (0,0)
	sprite.position = Vector2.ZERO
	
	# Asegurar que no hay rotación
	sprite.rotation = 0.0
	
	# Verificar y corregir cualquier offset de la textura
	if sprite.texture and sprite.texture is AtlasTexture:
		var atlas_tex = sprite.texture as AtlasTexture
		# La textura atlas ya debería manejar su propio centrado
		# Solo aseguramos que el sprite está en (0,0)
		sprite.position = Vector2.ZERO
	
	# Asegurar filtrado correcto
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Si tiene algún offset o centrado extraño en la escena original, lo eliminamos
	sprite.offset = Vector2.ZERO
	sprite.centered = true  # Esto asegura que el sprite se centre automáticamente
	
	# Verificar otros nodos problemáticos
	if piece_node.has_node("Area2D"):
		var area2d = piece_node.get_node("Area2D")
		area2d.position = Vector2.ZERO  # Asegurar que el área de colisión también esté centrada
		
		if area2d.has_node("CollisionShape2D"):
			var collision = area2d.get_node("CollisionShape2D")
			# Corregir la posición problemática del CollisionShape2D de la escena original
			collision.position = Vector2.ZERO
			# Mantener solo un scale razonable
			collision.scale = Vector2.ONE
