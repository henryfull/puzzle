# Scripts/VictoryChecker.gd
class_name VictoryChecker
extends Node

signal puzzle_is_complete

# --- Referencias a ser establecidas por PuzzleGame ---
var pieces_ref: Array
var puzzle_offset_ref: Vector2
var cell_size_ref: Vector2
var grid_ref: Dictionary
var original_rows_ref: int # Usado para restaurar GLOBAL.rows
var progress_manager_ref: Node
var audio_merge_ref: AudioStreamPlayer

# Callables a métodos de PuzzleGame
var show_success_message_func_ref: Callable
var update_piece_position_state_func_ref: Callable
var change_scene_func_ref: Callable # Para cambiar a VictoryScreen
var stop_game_timer_func_ref: Callable
var get_game_state_for_victory_func_ref: Callable # Para obtener total_moves, elapsed_time, etc.
var on_puzzle_completed_func_ref: Callable # Para manejar la lógica de completar puzzle

# --- Estado Interno ---
var puzzle_completed_internally: bool = false

# --- Funciones Auxiliares ---
func cell_key(cell: Vector2) -> String:
	return "%d_%d" % [int(cell.x), int(cell.y)]

func _remove_piece_at_from_grid(cell: Vector2):
	if grid_ref.has(cell_key(cell)):
		grid_ref.erase(cell_key(cell))

func _set_piece_at_in_grid(cell: Vector2, piece_obj): # La clase Piece es local a PuzzleGame
	grid_ref[cell_key(cell)] = piece_obj
	if piece_obj != null: # piece_obj podría ser null si se está limpiando
		piece_obj.current_cell = cell


# --- Métodos Públicos a ser llamados por PuzzleGame ---
func initialize(params: Dictionary):
	pieces_ref = params.pieces
	puzzle_offset_ref = params.puzzle_offset
	cell_size_ref = params.cell_size
	grid_ref = params.grid
	original_rows_ref = params.original_rows
	progress_manager_ref = params.progress_manager
	audio_merge_ref = params.audio_merge
	show_success_message_func_ref = params.show_success_message_func
	update_piece_position_state_func_ref = params.update_piece_position_state_func
	change_scene_func_ref = params.change_scene_func
	stop_game_timer_func_ref = params.stop_game_timer_func
	get_game_state_for_victory_func_ref = params.get_game_state_for_victory_func
	if params.has("on_puzzle_completed_func"):
		on_puzzle_completed_func_ref = params.on_puzzle_completed_func

func run_check_victory_deferred():
	if puzzle_completed_internally:
		return

	print("VictoryChecker: Ejecutando verificación de victoria...")
	
	var all_in_place = true
	if pieces_ref == null or pieces_ref.is_empty(): # Añadir comprobación por si las piezas no están cargadas
		all_in_place = false
		print("VictoryChecker: No hay piezas o pieces_ref es null")
	else:
		var pieces_in_correct_position = 0
		for piece_obj in pieces_ref:
			if piece_obj.current_cell == piece_obj.original_pos:
				pieces_in_correct_position += 1
			else:
				all_in_place = false
		
		print("VictoryChecker: ", pieces_in_correct_position, " de ", pieces_ref.size(), " piezas en posición correcta")
	
	if all_in_place:
		print("VictoryChecker: ¡Victoria detectada (comprobación diferida)!")
		var game_state = get_game_state_for_victory_func_ref.call()
		_resolve_puzzle_completion(game_state)
	else:
		print("VictoryChecker: No todas las piezas están en su lugar absoluto, verificando por posiciones relativas...")
		if not run_check_victory_by_relative_position():
			print("VictoryChecker: Victoria relativa no encontrada, verificando por posición visual...")
			run_check_victory_by_position()


func run_check_victory_by_position() -> bool:
	if puzzle_completed_internally:
		return false

	var all_in_place = true
	# Asegurarse de que cell_size_ref no es nulo antes de usarlo
	if cell_size_ref == null or cell_size_ref.x == 0 or cell_size_ref.y == 0: # Comprobación más robusta
		#print("VictoryChecker: cell_size_ref no está inicializado o es cero.")
		return false # No se puede calcular el margen de error
		
	var margin_of_error = cell_size_ref.length() * 0.4
	var pieces_in_place_count = 0
	
	if pieces_ref == null or pieces_ref.is_empty(): # Evitar error si pieces_ref está vacío
		return false
		
	var total_pieces_count = pieces_ref.size()

	for piece_obj in pieces_ref:
		if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node): # Comprobación de validez
			#print("VictoryChecker: Pieza o nodo de pieza inválido durante la comprobación de victoria.")
			all_in_place = false # Considerar como fuera de lugar si es inválida
			continue
		update_piece_position_state_func_ref.call(piece_obj)
		
		var expected_position = puzzle_offset_ref + piece_obj.original_pos * cell_size_ref
		var distance = piece_obj.node.position.distance_to(expected_position)

		if distance <= margin_of_error:
			pieces_in_place_count += 1
		else:
			all_in_place = false
	
	print("VictoryChecker: Verificación por posición - ", pieces_in_place_count, " de ", total_pieces_count, " piezas en posición visual correcta")
	
	if all_in_place and total_pieces_count > 0 : # Asegurar que haya piezas
		print("VictoryChecker: ¡Victoria por posición visual! Distancia máxima permitida: ", margin_of_error)
		for piece_obj in pieces_ref:
			if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node): continue # Saltar inválidas
			_remove_piece_at_from_grid(piece_obj.current_cell)
			piece_obj.current_cell = piece_obj.original_pos
			_set_piece_at_in_grid(piece_obj.original_pos, piece_obj)
			if piece_obj.node.has_method("set_correct_position"):
				piece_obj.node.set_correct_position(true)
		
		var game_state = get_game_state_for_victory_func_ref.call()
		_resolve_puzzle_completion(game_state)
		return true
	
	if total_pieces_count > 0 and pieces_in_place_count >= total_pieces_count * 0.95:
		print("VictoryChecker: ¡Victoria! Más del 95% de las piezas en posición visual correcta.")
		for piece_obj in pieces_ref:
			if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node): continue # Saltar inválidas
			var expected_position = puzzle_offset_ref + piece_obj.original_pos * cell_size_ref
			piece_obj.node.position = expected_position
			_remove_piece_at_from_grid(piece_obj.current_cell)
			piece_obj.current_cell = piece_obj.original_pos
			_set_piece_at_in_grid(piece_obj.original_pos, piece_obj)
			if piece_obj.node.has_method("set_correct_position"):
				piece_obj.node.set_correct_position(true)

		var game_state = get_game_state_for_victory_func_ref.call()
		_resolve_puzzle_completion(game_state)
		return true
		
	return false

func run_check_victory_by_relative_position() -> bool:
	if puzzle_completed_internally:
		return false
	
	if pieces_ref == null or pieces_ref.is_empty():
		return false
	
	var total_pieces_count = pieces_ref.size()
	if total_pieces_count == 0:
		return false
	
	# Verificar que todas las piezas están en las posiciones correctas RELATIVAS entre sí
	# Esto significa que cada pieza está en la posición correcta respecto a las demás piezas
	var pieces_in_correct_relative_position = 0
	
	for piece_obj in pieces_ref:
		if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node):
			continue
		
		# Verificar si la pieza está en la posición correcta relativa a las demás
		var is_in_correct_relative_position = true
		var expected_neighbors = _get_expected_neighbors(piece_obj)
		
		# Si la pieza no tiene vecinos esperados (ej: puzzle de 1x1), considerar como correcta
		if expected_neighbors.size() == 0:
			is_in_correct_relative_position = true
		else:
			for expected_neighbor_pos in expected_neighbors:
				var actual_neighbor = grid_ref.get(cell_key(piece_obj.current_cell + expected_neighbor_pos), null)
				var expected_neighbor = _find_piece_by_original_position(piece_obj.original_pos + expected_neighbor_pos)
				
				if actual_neighbor != expected_neighbor:
					is_in_correct_relative_position = false
					if OS.is_debug_build():
						print("VictoryChecker: Pieza en ", piece_obj.original_pos, " (actual: ", piece_obj.current_cell, ") no tiene vecino correcto en dirección ", expected_neighbor_pos)
					break
		
		if is_in_correct_relative_position:
			pieces_in_correct_relative_position += 1
		elif OS.is_debug_build():
			print("VictoryChecker: Pieza en ", piece_obj.original_pos, " (actual: ", piece_obj.current_cell, ") no está en posición relativa correcta")
	
	print("VictoryChecker: Verificación por posición relativa - ", pieces_in_correct_relative_position, " de ", total_pieces_count, " piezas en posición relativa correcta")
	
	# Si todas las piezas están en posición relativa correcta, es victoria
	if pieces_in_correct_relative_position == total_pieces_count:
		print("VictoryChecker: ¡Victoria por posición relativa! Todas las piezas están correctamente posicionadas entre sí")
		
		# Verificación adicional: asegurarse de que todas las piezas forman un solo grupo
		if _verify_single_complete_group():
			# Actualizar las posiciones en el grid para que coincidan con las posiciones originales
			# pero manteniendo el desplazamiento del puzzle completo
			_normalize_puzzle_position()
			
			var game_state = get_game_state_for_victory_func_ref.call()
			_resolve_puzzle_completion(game_state)
			return true
		else:
			print("VictoryChecker: Las piezas no forman un grupo único y completo")
	
	return false

# Función auxiliar para obtener los desplazamientos esperados de los vecinos de una pieza
func _get_expected_neighbors(piece_obj) -> Array:
	var neighbors = []
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	
	for dir in directions:
		var neighbor_original_pos = piece_obj.original_pos + dir
		# Verificar que el vecino está dentro de los límites del puzzle original
		if neighbor_original_pos.x >= 0 and neighbor_original_pos.x < GLOBAL.columns and \
		   neighbor_original_pos.y >= 0 and neighbor_original_pos.y < original_rows_ref:
			neighbors.append(dir)
	
	return neighbors

# Función auxiliar para encontrar una pieza por su posición original
func _find_piece_by_original_position(original_pos: Vector2):
	for piece_obj in pieces_ref:
		if piece_obj.original_pos == original_pos:
			return piece_obj
	return null

# Función auxiliar para normalizar la posición del puzzle completado
func _normalize_puzzle_position():
	# Encontrar la pieza que debería estar en (0,0)
	var top_left_piece = _find_piece_by_original_position(Vector2(0, 0))
	if not top_left_piece:
		return
	
	# Calcular el desplazamiento necesario para mover el puzzle a su posición original
	var offset_difference = top_left_piece.original_pos - top_left_piece.current_cell
	
	# Aplicar el desplazamiento a todas las piezas
	for piece_obj in pieces_ref:
		if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node):
			continue
		
		# Actualizar la posición en el grid
		_remove_piece_at_from_grid(piece_obj.current_cell)
		var new_cell = piece_obj.current_cell + offset_difference
		piece_obj.current_cell = new_cell
		_set_piece_at_in_grid(new_cell, piece_obj)
		
		# Actualizar la posición visual
		var expected_position = puzzle_offset_ref + new_cell * cell_size_ref
		piece_obj.node.position = expected_position
		
		# Marcar como en posición correcta
		if piece_obj.node.has_method("set_correct_position"):
			piece_obj.node.set_correct_position(true)
		
		# Actualizar el estado de la pieza
		update_piece_position_state_func_ref.call(piece_obj)

# Función auxiliar para verificar que todas las piezas forman un solo grupo contíguo
func _verify_single_complete_group() -> bool:
	if pieces_ref.size() == 0:
		return false
	
	# Obtener la primera pieza válida como punto de partida
	var first_piece = null
	for piece_obj in pieces_ref:
		if is_instance_valid(piece_obj) and is_instance_valid(piece_obj.node):
			first_piece = piece_obj
			break
	
	if not first_piece:
		return false
	
	# Usar BFS para verificar que todas las piezas están conectadas
	var visited = {}
	var queue = [first_piece]
	var visited_count = 0
	
	while queue.size() > 0:
		var current_piece = queue.pop_front()
		var piece_key = str(current_piece.current_cell)
		
		if piece_key in visited:
			continue
		
		visited[piece_key] = true
		visited_count += 1
		
		# Buscar todas las piezas adyacentes
		var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
		for dir in directions:
			var neighbor_cell = current_piece.current_cell + dir
			var neighbor_piece = grid_ref.get(cell_key(neighbor_cell), null)
			
			if neighbor_piece and is_instance_valid(neighbor_piece) and is_instance_valid(neighbor_piece.node):
				var neighbor_key = str(neighbor_piece.current_cell)
				if not (neighbor_key in visited):
					queue.append(neighbor_piece)
	
	# Verificar que visitamos todas las piezas
	var all_connected = (visited_count == pieces_ref.size())
	
	if OS.is_debug_build():
		print("VictoryChecker: Verificación de grupo único - visitadas: ", visited_count, " de ", pieces_ref.size(), " piezas, conectadas: ", all_connected)
	
	return all_connected

func _resolve_puzzle_completion(game_state: Dictionary):
	if puzzle_completed_internally:
		return
	
	print("VictoryChecker: Resolviendo completar puzzle...")
	puzzle_completed_internally = true
	emit_signal("puzzle_is_complete")

	if audio_merge_ref and is_instance_valid(audio_merge_ref):
		audio_merge_ref.play()
	
	show_success_message_func_ref.call("¡Puzzle Completado!", 1.0)
	
	# Restaurar el número original de filas
	GLOBAL.rows = original_rows_ref
	
	# Si existe la función de completar puzzle, usarla en lugar de manejar todo aquí
	if on_puzzle_completed_func_ref and on_puzzle_completed_func_ref.is_valid():
		# Usar la función de PuzzleGame que ya maneja todo el flujo
		on_puzzle_completed_func_ref.call()
	else:
		# Fallback al método original si no está disponible
		var gamemode = 0 
		if game_state.relax_mode:
			gamemode = 1
		elif game_state.timer_mode:
			gamemode = 3
		elif game_state.challenge_mode:
			gamemode = 4
		elif game_state.normal_mode: 
			gamemode = 2

		var victory_data = {
			"puzzle": GLOBAL.selected_puzzle,
			"pack": GLOBAL.selected_pack,
			"total_moves": game_state.total_moves,
			"elapsed_time": game_state.elapsed_time,
			"difficulty": {"columns": GLOBAL.columns, "rows": GLOBAL.rows},
			"pack_id": game_state.current_pack_id,
			"puzzle_id": game_state.current_puzzle_id,
			"flip_count": game_state.flip_count,
			"flip_move_count": game_state.flip_move_count,
			"gamemode": gamemode
		}
		
		GLOBAL.victory_data = victory_data
		
		if progress_manager_ref and is_instance_valid(progress_manager_ref):
			if progress_manager_ref.has_method("complete_puzzle"):
				progress_manager_ref.complete_puzzle(game_state.current_pack_id, game_state.current_puzzle_id)
		
		change_scene_func_ref.call("res://Scenes/VictoryScreen.tscn") 
