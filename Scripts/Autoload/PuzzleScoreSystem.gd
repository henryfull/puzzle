# PuzzleScoreSystem.gd
# Singleton para gestionar el sistema de puntuaciones global
# Maneja la configuración, rankings y persistencia a nivel global

extends Node

# Precargar el script del ranking manager
var PuzzleRankingManagerScene = preload("res://Scripts/PuzzleRankingManager.gd")

# Referencias a los managers
var ranking_manager

# Configuración global del sistema
var scoring_enabled: bool = true
var global_config = {
	"enable_scoring_in_relax": false,
	"show_rankings": true,
	"auto_save_scores": true,
	"enable_leaderboards": true
}

# Constantes de configuración
const CONFIG_FILE_PATH = "user://score_system_config.json"

signal ranking_changed()
signal new_high_score(puzzle_id: String, score: int)

func _ready():
	print("PuzzleScoreSystem: Inicializando sistema global de puntuaciones...")
	_load_config()
	_initialize_ranking_manager()

func _initialize_ranking_manager():
	"""Inicializa el ranking manager global"""
	ranking_manager = PuzzleRankingManagerScene.new()
	add_child(ranking_manager)
	ranking_manager.initialize()
	
	# Conectar señales
	ranking_manager.best_score_achieved.connect(_on_new_high_score)
	ranking_manager.ranking_updated.connect(_on_ranking_updated)
	
	print("PuzzleScoreSystem: Ranking manager inicializado")

func _on_new_high_score(puzzle_id: String, old_score: int, new_score: int):
	"""Se llama cuando se alcanza una nueva mejor puntuación"""
	print("PuzzleScoreSystem: ¡Nueva mejor puntuación! Puzzle: ", puzzle_id, " - ", old_score, " → ", new_score)
	new_high_score.emit(puzzle_id, new_score)

func _on_ranking_updated():
	"""Se llama cuando el ranking se actualiza"""
	print("PuzzleScoreSystem: Ranking actualizado")
	ranking_changed.emit()

# === FUNCIONES PÚBLICAS ===

func is_scoring_enabled_for_mode(game_mode: String) -> bool:
	"""Determina si la puntuación está habilitada para un modo específico"""
	if not scoring_enabled:
		return false
	
	match game_mode:
		"relax", "learning":
			return global_config.enable_scoring_in_relax
		"normal", "challenge", "timer":
			return true
		_:
			return true

func save_puzzle_score(pack_id: String, puzzle_id: String, score_data: Dictionary):
	"""Guarda una puntuación de puzzle"""
	if ranking_manager:
		ranking_manager.save_puzzle_score(pack_id, puzzle_id, score_data)

func get_puzzle_best_score(pack_id: String, puzzle_id: String) -> Dictionary:
	"""Obtiene la mejor puntuación para un puzzle"""
	if ranking_manager:
		return ranking_manager.get_puzzle_best_score(pack_id, puzzle_id)
	return {}

func get_global_ranking(limit: int = 50) -> Array:
	"""Obtiene el ranking global"""
	if ranking_manager:
		return ranking_manager.get_global_ranking(limit)
	return []

func get_player_stats() -> Dictionary:
	"""Obtiene las estadísticas del jugador actual"""
	if ranking_manager:
		return ranking_manager.get_player_stats()
	return {}

func set_player_name(name: String):
	"""Establece el nombre del jugador"""
	if ranking_manager:
		ranking_manager.set_player_name(name)

func export_scores_csv() -> String:
	"""Exporta las puntuaciones a CSV"""
	if ranking_manager:
		return ranking_manager.export_scores_to_csv()
	return ""

# === CONFIGURACIÓN ===

func _load_config():
	"""Carga la configuración del sistema"""
	if FileAccess.file_exists(CONFIG_FILE_PATH):
		var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var loaded_config = json.data
				if loaded_config is Dictionary:
					# Fusionar configuración cargada con valores por defecto
					for key in loaded_config.keys():
						if key in global_config:
							global_config[key] = loaded_config[key]
					
					if "scoring_enabled" in loaded_config:
						scoring_enabled = loaded_config.scoring_enabled
					
					print("PuzzleScoreSystem: Configuración cargada")
					return
	
	# Si no hay archivo, crear configuración por defecto
	_save_config()
	print("PuzzleScoreSystem: Configuración por defecto creada")

func _save_config():
	"""Guarda la configuración del sistema"""
	var config_data = global_config.duplicate()
	config_data["scoring_enabled"] = scoring_enabled
	
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config_data))
		file.close()

func set_config_value(key: String, value):
	"""Establece un valor de configuración"""
	if key == "scoring_enabled":
		scoring_enabled = value
	elif key in global_config:
		global_config[key] = value
	
	_save_config()
	print("PuzzleScoreSystem: Configuración actualizada - ", key, ": ", value)

func get_config_value(key: String):
	"""Obtiene un valor de configuración"""
	if key == "scoring_enabled":
		return scoring_enabled
	elif key in global_config:
		return global_config[key]
	else:
		return null

# === FUNCIONES DE DEPURACIÓN ===

func clear_all_scores():
	"""Borra todas las puntuaciones (para testing)"""
	if ranking_manager:
		ranking_manager.clear_all_scores()
		print("PuzzleScoreSystem: Todas las puntuaciones borradas")

func debug_print_rankings():
	"""Imprime información de debug sobre los rankings"""
	if not ranking_manager:
		print("PuzzleScoreSystem: Ranking manager no disponible")
		return
	
	var rankings = get_global_ranking(10)
	var player_stats = get_player_stats()
	
	print("PuzzleScoreSystem: === DEBUG RANKINGS ===")
	print("Jugador actual: ", player_stats.get("player_name", "Sin nombre"))
	print("Puntuación total: ", player_stats.get("total_score", 0))
	print("Puzzles completados: ", player_stats.get("puzzles_completed", 0))
	print("")
	print("Top 10 ranking global:")
	
	for i in range(rankings.size()):
		var entry = rankings[i]
		print(str(i + 1), ". ", entry.player_name, " - ", entry.total_score, " puntos")

func get_score_statistics() -> Dictionary:
	"""Obtiene estadísticas detalladas del sistema de puntuación"""
	if not ranking_manager:
		return {}
	
	var all_scores = ranking_manager.get_all_puzzle_scores()
	var stats = {
		"total_puzzles_played": all_scores.size(),
		"total_score": 0,
		"average_score": 0,
		"best_single_score": 0,
		"total_moves": 0,
		"total_time": 0.0,
		"total_flips": 0,
		"puzzles_with_no_errors": 0,
		"puzzles_with_no_flips": 0
	}
	
	for puzzle_key in all_scores.keys():
		var score_data = all_scores[puzzle_key]
		stats.total_score += score_data.score
		stats.best_single_score = max(stats.best_single_score, score_data.score)
		stats.total_moves += score_data.total_moves
		stats.total_time += score_data.completion_time
		stats.total_flips += score_data.flip_uses
		
		if not score_data.had_errors:
			stats.puzzles_with_no_errors += 1
		
		if not score_data.used_flip:
			stats.puzzles_with_no_flips += 1
	
	if stats.total_puzzles_played > 0:
		stats.average_score = stats.total_score / stats.total_puzzles_played
	
	return stats 