# PuzzleRankingManager.gd
# Sistema de ranking y persistencia de puntuaciones
# Gestiona el almacenamiento local y sincronización del ranking global

extends Node
class_name PuzzleRankingManager

# Señales
signal ranking_updated()
signal score_saved(puzzle_id: String, score: int)
signal best_score_achieved(puzzle_id: String, old_score: int, new_score: int)

# Rutas de archivos
const SCORES_FILE_PATH = "user://puzzle_scores.json"
const RANKING_FILE_PATH = "user://global_ranking.json"
const PLAYER_DATA_PATH = "user://player_data.json"

# Datos del jugador
var player_data: Dictionary = {
	"player_id": "",
	"player_name": "",
	"total_score": 0,
	"puzzles_completed": 0,
	"creation_date": ""
}

# Puntuaciones por puzzle
var puzzle_scores: Dictionary = {}

# Ranking global (local cache)
var global_ranking: Array = []

# Estados
var is_initialized: bool = false

func initialize():
	"""Inicializa el sistema de ranking"""
	print("PuzzleRankingManager: Inicializando sistema de ranking...")
	
	# Cargar datos del jugador
	_load_player_data()
	
	# Cargar puntuaciones guardadas
	_load_puzzle_scores()
	
	# Cargar ranking global (cache local)
	_load_global_ranking()
	
	is_initialized = true
	print("PuzzleRankingManager: Sistema de ranking inicializado")

# === GESTIÓN DE PUNTUACIONES POR PUZZLE ===

func save_puzzle_score(pack_id: String, puzzle_id: String, score_data: Dictionary):
	"""
	Guarda la puntuación de un puzzle
	@param pack_id: ID del pack del puzzle
	@param puzzle_id: ID del puzzle
	@param score_data: Datos de la puntuación (score, moves, time, etc.)
	"""
	if not is_initialized:
		print("PuzzleRankingManager: Error - Sistema no inicializado")
		return
	
	var puzzle_key = pack_id + "_" + puzzle_id
	var current_time = Time.get_unix_time_from_system()
	
	# Preparar datos completos de la puntuación
	var complete_score_data = {
		"score": score_data.get("final_score", 0),
		"pieces_placed": score_data.get("pieces_placed", 0),
		"groups_connected": score_data.get("groups_connected", 0),
		"total_moves": score_data.get("total_moves", 0),
		"invalid_moves": score_data.get("invalid_moves", 0),
		"flip_uses": score_data.get("flip_uses", 0),
		"had_errors": score_data.get("had_errors", false),
		"used_flip": score_data.get("used_flip", false),
		"completion_time": score_data.get("completion_time", 0.0),
		"date": current_time,
		"pack_id": pack_id,
		"puzzle_id": puzzle_id
	}
	
	# Verificar si es una nueva mejor puntuación
	var is_new_best = false
	var old_score = 0
	
	if puzzle_scores.has(puzzle_key):
		old_score = puzzle_scores[puzzle_key].score
		if complete_score_data.score > old_score:
			is_new_best = true
			print("PuzzleRankingManager: ¡Nueva mejor puntuación! ", complete_score_data.score, " > ", old_score)
		else:
			print("PuzzleRankingManager: Puntuación guardada, pero no supera la mejor: ", complete_score_data.score, " <= ", old_score)
	else:
		is_new_best = true
		print("PuzzleRankingManager: Primera puntuación para este puzzle: ", complete_score_data.score)
	
	# Guardar solo si es la mejor puntuación o es la primera vez
	if is_new_best:
		puzzle_scores[puzzle_key] = complete_score_data
		_save_puzzle_scores()
		
		# Actualizar estadísticas del jugador
		_update_player_stats()
		
		# Emitir señales
		if old_score > 0:
			best_score_achieved.emit(puzzle_id, old_score, complete_score_data.score)
		
		score_saved.emit(puzzle_id, complete_score_data.score)
		
		print("PuzzleRankingManager: Puntuación guardada exitosamente")
	else:
		print("PuzzleRankingManager: Puntuación no guardada (no es la mejor)")

func get_puzzle_best_score(pack_id: String, puzzle_id: String) -> Dictionary:
	"""Retorna la mejor puntuación para un puzzle específico"""
	var puzzle_key = pack_id + "_" + puzzle_id
	
	if puzzle_scores.has(puzzle_key):
		return puzzle_scores[puzzle_key]
	else:
		return {}

func get_all_puzzle_scores() -> Dictionary:
	"""Retorna todas las puntuaciones guardadas"""
	return puzzle_scores

# === GESTIÓN DE ESTADÍSTICAS DEL JUGADOR ===

func _update_player_stats():
	"""Actualiza las estadísticas generales del jugador"""
	var total_score = 0
	var puzzles_completed = 0
	
	for puzzle_key in puzzle_scores.keys():
		var score_data = puzzle_scores[puzzle_key]
		total_score += score_data.score
		puzzles_completed += 1
	
	player_data.total_score = total_score
	player_data.puzzles_completed = puzzles_completed
	
	_save_player_data()
	
	print("PuzzleRankingManager: Stats actualizadas - Total: ", total_score, ", Puzzles: ", puzzles_completed)

func get_player_stats() -> Dictionary:
	"""Retorna las estadísticas del jugador"""
	return player_data

func set_player_name(name: String):
	"""Establece el nombre del jugador"""
	player_data.player_name = name
	_save_player_data()
	print("PuzzleRankingManager: Nombre del jugador establecido: ", name)

# === SISTEMA DE RANKING GLOBAL ===

func update_global_ranking():
	"""Actualiza el ranking global con los datos locales del jugador"""
	# TODO: Implementar sincronización con servidor
	# Por ahora, actualizar el cache local
	
	var player_entry = {
		"player_id": player_data.player_id,
		"player_name": player_data.player_name,
		"total_score": player_data.total_score,
		"puzzles_completed": player_data.puzzles_completed,
		"last_update": Time.get_unix_time_from_system()
	}
	
	# Buscar si el jugador ya está en el ranking
	var found_index = -1
	for i in range(global_ranking.size()):
		if global_ranking[i].player_id == player_data.player_id:
			found_index = i
			break
	
	# Actualizar o añadir entrada
	if found_index >= 0:
		global_ranking[found_index] = player_entry
	else:
		global_ranking.append(player_entry)
	
	# Ordenar por puntuación total (descendente)
	global_ranking.sort_custom(func(a, b): return a.total_score > b.total_score)
	
	# Guardar ranking actualizado
	_save_global_ranking()
	
	ranking_updated.emit()
	print("PuzzleRankingManager: Ranking global actualizado")

func get_global_ranking(limit: int = 50) -> Array:
	"""Retorna el ranking global (limitado a top N)"""
	var limited_ranking = global_ranking.slice(0, limit)
	return limited_ranking

func get_player_ranking_position() -> int:
	"""Retorna la posición del jugador en el ranking global (1-indexed)"""
	for i in range(global_ranking.size()):
		if global_ranking[i].player_id == player_data.player_id:
			return i + 1
	return -1

# === PERSISTENCIA DE DATOS ===

func _load_player_data():
	"""Carga los datos del jugador desde archivo"""
	if FileAccess.file_exists(PLAYER_DATA_PATH):
		var file = FileAccess.open(PLAYER_DATA_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var loaded_data = json.data
				if loaded_data is Dictionary:
					player_data = loaded_data
					print("PuzzleRankingManager: Datos del jugador cargados")
					return
	
	# Si no existe archivo o hay error, crear datos por defecto
	_create_default_player_data()

func _create_default_player_data():
	"""Crea datos por defecto para un nuevo jugador"""
	player_data = {
		"player_id": _generate_player_id(),
		"player_name": "Jugador_" + str(randi() % 10000),
		"total_score": 0,
		"puzzles_completed": 0,
		"creation_date": Time.get_unix_time_from_system()
	}
	_save_player_data()
	print("PuzzleRankingManager: Datos de jugador creados por defecto")

func _save_player_data():
	"""Guarda los datos del jugador en archivo"""
	var file = FileAccess.open(PLAYER_DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(player_data))
		file.close()

func _load_puzzle_scores():
	"""Carga las puntuaciones de puzzles desde archivo"""
	if FileAccess.file_exists(SCORES_FILE_PATH):
		var file = FileAccess.open(SCORES_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var loaded_data = json.data
				if loaded_data is Dictionary:
					puzzle_scores = loaded_data
					print("PuzzleRankingManager: ", puzzle_scores.size(), " puntuaciones cargadas")
					return
	
	# Si no existe archivo, inicializar diccionario vacío
	puzzle_scores = {}
	print("PuzzleRankingManager: Inicializando nuevo archivo de puntuaciones")

func _save_puzzle_scores():
	"""Guarda las puntuaciones en archivo"""
	var file = FileAccess.open(SCORES_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(puzzle_scores))
		file.close()

func _load_global_ranking():
	"""Carga el ranking global desde archivo"""
	if FileAccess.file_exists(RANKING_FILE_PATH):
		var file = FileAccess.open(RANKING_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var loaded_data = json.data
				if loaded_data is Array:
					global_ranking = loaded_data
					print("PuzzleRankingManager: Ranking global cargado (", global_ranking.size(), " entradas)")
					return
	
	# Si no existe archivo, inicializar array vacío
	global_ranking = []
	print("PuzzleRankingManager: Inicializando nuevo ranking global")

func _save_global_ranking():
	"""Guarda el ranking global en archivo"""
	var file = FileAccess.open(RANKING_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(global_ranking))
		file.close()

func _generate_player_id() -> String:
	"""Genera un ID único para el jugador"""
	var timestamp = Time.get_unix_time_from_system()
	var random_part = randi() % 100000
	return "player_" + str(timestamp) + "_" + str(random_part)

# === FUNCIONES DE UTILIDAD ===

func export_scores_to_csv() -> String:
	"""Exporta las puntuaciones a formato CSV para análisis"""
	var csv_content = "Pack,Puzzle,Score,Moves,Time,Errors,Flips,Date\n"
	
	for puzzle_key in puzzle_scores.keys():
		var score_data = puzzle_scores[puzzle_key]
		csv_content += "%s,%s,%d,%d,%.2f,%s,%d,%s\n" % [
			score_data.pack_id,
			score_data.puzzle_id,
			score_data.score,
			score_data.total_moves,
			score_data.completion_time,
			str(score_data.had_errors),
			score_data.flip_uses,
			Time.get_datetime_string_from_unix_time(score_data.date)
		]
	
	return csv_content

func clear_all_scores():
	"""Borra todas las puntuaciones (para testing o reset)"""
	puzzle_scores.clear()
	_save_puzzle_scores()
	
	player_data.total_score = 0
	player_data.puzzles_completed = 0
	_save_player_data()
	
	print("PuzzleRankingManager: Todas las puntuaciones han sido borradas") 
