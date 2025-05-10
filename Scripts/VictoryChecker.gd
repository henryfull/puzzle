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

func run_check_victory_deferred():
	if puzzle_completed_internally:
		return

	var all_in_place = true
	if pieces_ref == null or pieces_ref.is_empty(): # Añadir comprobación por si las piezas no están cargadas
		all_in_place = false
	else:
		for piece_obj in pieces_ref:
			if piece_obj.current_cell != piece_obj.original_pos:
				all_in_place = false
				break
	
	if all_in_place:
		#print("VictoryChecker: ¡Victoria detectada (comprobación diferida)!")
		var game_state = get_game_state_for_victory_func_ref.call()
		_resolve_puzzle_completion(game_state)
	else:
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
	
	if all_in_place and total_pieces_count > 0 : # Asegurar que haya piezas
		#print("VictoryChecker: ¡Victoria por posición visual! Distancia máxima permitida: ", margin_of_error)
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
		#print("VictoryChecker: ¡Victoria! Más del 95% de las piezas en posición visual correcta.")
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

func _resolve_puzzle_completion(game_state: Dictionary):
	if puzzle_completed_internally:
		return
	
	puzzle_completed_internally = true
	emit_signal("puzzle_is_complete")

	stop_game_timer_func_ref.call()
	
	if audio_merge_ref and is_instance_valid(audio_merge_ref):
		audio_merge_ref.play()
	
	show_success_message_func_ref.call("¡Puzzle Completado!", 1.0)
	
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
	
	GLOBAL.rows = original_rows_ref 
	GLOBAL.victory_data = victory_data
	
	if progress_manager_ref and is_instance_valid(progress_manager_ref):
		if progress_manager_ref.has_method("complete_puzzle"):
			progress_manager_ref.complete_puzzle(game_state.current_pack_id, game_state.current_puzzle_id)
		#else:
			#print("VictoryChecker: ProgressManager no tiene el método complete_puzzle.")
	#else:
		#print("VictoryChecker: La referencia a ProgressManager no es válida.")
	
	change_scene_func_ref.call("res://Scenes/VictoryScreen.tscn") 
