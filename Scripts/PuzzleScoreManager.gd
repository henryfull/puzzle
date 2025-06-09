# PuzzleScoreManager.gd
# Sistema de puntuaciones para puzzles
# Implementa el sistema detallado en README_PUNTUACIONES_PUZZLE.md

extends Node
class_name PuzzleScoreManager

# Señales para comunicación con otros managers
signal score_updated(new_score: int)
signal streak_updated(streak_count: int)
signal bonus_applied(bonus_type: String, points: int)

# Referencias
var puzzle_game: PuzzleGame
var game_state_manager: PuzzleGameStateManager

# === PUNTUACIÓN ACTUAL ===
var current_score: int = 0
var streak_count: int = 0

# === CONSTANTES DE PUNTUACIÓN ===
# Puntos por acciones positivas
const POINTS_PIECE_PLACED: int = 2
const POINTS_GROUP_UNION: int = 5
const POINTS_PUZZLE_COMPLETED: int = 20
const POINTS_NO_ERRORS: int = 15
const POINTS_NO_FLIP: int = 10

# Puntos por rachas
const STREAK_3_BONUS: int = 1
const STREAK_5_BONUS: int = 2
const STREAK_10_BONUS: int = 3

# Penalizaciones
const PENALTY_INVALID_MOVE: int = -1
const PENALTY_FLIP_USE: int = -5
const PENALTY_UNDO: int = -2
const PENALTY_FLOATING_PIECES: int = -3

# === TRACKING DE ESTADO ===
var total_moves: int = 0
var invalid_moves: int = 0
var flip_uses: int = 0
var undo_uses: int = 0
var groups_connected: int = 0
var pieces_placed_correctly: int = 0

# Estado del puzzle para bonificaciones finales
var had_errors: bool = false
var used_flip: bool = false

func initialize(game: PuzzleGame, state_manager: PuzzleGameStateManager):
	puzzle_game = game
	game_state_manager = state_manager
	
	print("PuzzleScoreManager: Sistema de puntuaciones inicializado")
	_reset_score()
	
	# Conectar con señales relevantes si existen
	_connect_game_signals()

func _connect_game_signals():
	# Estas conexiones se harán cuando estén disponibles los managers correspondientes
	pass

# === FUNCIONES DE PUNTUACIÓN ===

func _reset_score():
	"""Reinicia toda la puntuación y contadores"""
	current_score = 0
	streak_count = 0
	total_moves = 0
	invalid_moves = 0
	flip_uses = 0
	undo_uses = 0
	groups_connected = 0
	pieces_placed_correctly = 0
	had_errors = false
	used_flip = false
	
	score_updated.emit(current_score)
	streak_updated.emit(streak_count)
	
	print("PuzzleScoreManager: Puntuación reiniciada")

func add_piece_placed_correctly(connected_to_group: bool = false):
	"""
	Se llama cuando una pieza se coloca correctamente con movimiento real
	@param connected_to_group: Si la pieza se conectó a un grupo existente
	"""
	pieces_placed_correctly += 1
	total_moves += 1
	
	# Incrementar racha
	streak_count += 1
	
	# Puntos base por colocar pieza
	var points_gained = POINTS_PIECE_PLACED
	
	# Bonus por racha si aplica
	var streak_bonus = _calculate_streak_bonus()
	if streak_bonus > 0:
		points_gained += streak_bonus
		bonus_applied.emit("streak", streak_bonus)
	
	_add_points(points_gained)
	
	print("PuzzleScoreManager: Pieza colocada correctamente (+", points_gained, " puntos) - Racha: ", streak_count)
	
	streak_updated.emit(streak_count)

func add_group_moved_successfully(group_size: int):
	"""
	Se llama cuando un grupo se mueve exitosamente Y logra progreso real en el puzzle
	(ej: pieza individual se conecta, se logra nueva configuración útil)
	@param group_size: Tamaño del grupo movido
	"""
	pieces_placed_correctly += group_size  # Para estadísticas: contar piezas colocadas
	total_moves += 1  # Para estadísticas: contar como UN solo movimiento
	
	# Incrementar racha en 1 (no por cada pieza del grupo)
	streak_count += 1
	
	# Puntos base: +2 por cada pieza del grupo movido
	var base_points = POINTS_PIECE_PLACED * group_size
	var points_gained = base_points
	
	# Bonus por racha si aplica (solo UNA vez por movimiento)
	var streak_bonus = _calculate_streak_bonus()
	if streak_bonus > 0:
		points_gained += streak_bonus
		bonus_applied.emit("streak", streak_bonus)
	
	_add_points(points_gained)
	
	print("PuzzleScoreManager: Grupo de ", group_size, " pieza(s) movido exitosamente (+", points_gained, " puntos) - Racha: ", streak_count)
	
	streak_updated.emit(streak_count)

func add_piece_moved_without_progress():
	"""
	Se llama cuando una pieza se mueve pero vuelve a la misma posición (sin puntos)
	"""
	print("PuzzleScoreManager: Movimiento sin progreso detectado - No se otorgan puntos")
	# No incrementar puntos, pero sí contar como movimiento para estadísticas
	total_moves += 1

func add_attempted_move_no_progress():
	"""
	Se llama cuando hay un intento de movimiento inválido que vuelve al origen
	No se rompe la racha porque técnicamente no hubo movimiento real
	"""
	print("PuzzleScoreManager: Intento de movimiento sin progreso - Racha se mantiene: ", streak_count)
	# Contar como movimiento para estadísticas, pero NO romper la racha
	total_moves += 1
	# La racha se mantiene intacta

func add_move_without_grouping():
	"""
	Se llama cuando una pieza se mueve exitosamente pero no se agrupa con nada
	Según especificaciones: "Movimiento inválido - La pieza movida no se agrupa con nada - –1 punto"
	"""
	invalid_moves += 1
	total_moves += 1
	had_errors = true
	
	# En modo relax, no resetear racha ni aplicar penalizaciones
	if should_apply_penalties():
		# Resetear racha por movimiento sin agrupamiento
		streak_count = 0
		_subtract_points(-PENALTY_INVALID_MOVE)  # Restar 1 punto
		print("PuzzleScoreManager: Movimiento sin agrupamiento (", PENALTY_INVALID_MOVE, " puntos) - Racha reiniciada")
	else:
		print("PuzzleScoreManager: Movimiento sin agrupamiento en modo relax - Sin penalización")
	
	streak_updated.emit(streak_count)

func add_placement_attempt_failed():
	"""
	Se llama cuando un intento de colocación falla la validación (ej: espacio ocupado)
	No se considera movimiento inválido - es como si no hubiera pasado nada
	"""
	print("PuzzleScoreManager: Intento de colocación fallido - Sin efecto en puntos ni racha (Racha: ", streak_count, ")")
	# NO contar como movimiento, NO afectar racha, NO penalizar
	# Es completamente neutro - como si el jugador no hubiera hecho nada

func add_groups_connected():
	"""Se llama cuando dos grupos se conectan mediante una pieza"""
	groups_connected += 1
	
	# Los puntos de unión de grupos son adicionales a los de colocar pieza
	_add_points(POINTS_GROUP_UNION)
	bonus_applied.emit("group_union", POINTS_GROUP_UNION)
	
	print("PuzzleScoreManager: Grupos conectados (+", POINTS_GROUP_UNION, " puntos)")

func add_invalid_move():
	"""
	Se llama cuando el jugador hace un movimiento realmente inválido (con cambio de posición)
	NOTA: Esta función está reservada para movimientos que sí cambiaron la posición pero fueron inválidos.
	Para intentos de colocación que fallan la validación, usar add_placement_attempt_failed()
	"""
	invalid_moves += 1
	total_moves += 1
	had_errors = true
	
	# En modo relax, no resetear racha ni aplicar penalizaciones
	if should_apply_penalties():
		# Resetear racha SOLO para movimientos inválidos reales
		streak_count = 0
		_subtract_points(-PENALTY_INVALID_MOVE)  # Restar puntos (penalty es negativo)
		print("PuzzleScoreManager: Movimiento inválido real (", PENALTY_INVALID_MOVE, " puntos) - Racha reiniciada")
	else:
		print("PuzzleScoreManager: Movimiento inválido en modo relax - Sin penalización")
	
	streak_updated.emit(streak_count)

func add_flip_use():
	"""Se llama cuando el jugador usa la función flip"""
	flip_uses += 1
	used_flip = true
	
	# En modo relax, no resetear racha ni aplicar penalizaciones
	if should_apply_penalties():
		# Resetear racha
		streak_count = 0
		_subtract_points(-PENALTY_FLIP_USE)  # Restar puntos
		print("PuzzleScoreManager: Flip usado (", PENALTY_FLIP_USE, " puntos) - Racha reiniciada")
	else:
		print("PuzzleScoreManager: Flip usado en modo relax - Sin penalización")
	
	streak_updated.emit(streak_count)

func add_undo_use():
	"""Se llama cuando el jugador usa la función undo (si está implementada)"""
	undo_uses += 1
	
	_subtract_points(-PENALTY_UNDO)  # Restar puntos
	
	print("PuzzleScoreManager: Undo usado (", PENALTY_UNDO, " puntos)")

func apply_floating_pieces_penalty(floating_count: int):
	"""Aplica penalización por piezas flotantes"""
	if floating_count > 0:
		var penalty = PENALTY_FLOATING_PIECES * floating_count
		_subtract_points(-penalty)
		
		print("PuzzleScoreManager: Penalización por ", floating_count, " piezas flotantes (", penalty, " puntos)")

func complete_puzzle():
	"""Se llama cuando el puzzle se completa"""
	var final_bonus = POINTS_PUZZLE_COMPLETED
	
	# Bonus por no tener errores
	if not had_errors:
		final_bonus += POINTS_NO_ERRORS
		bonus_applied.emit("no_errors", POINTS_NO_ERRORS)
		print("PuzzleScoreManager: Bonus sin errores (+", POINTS_NO_ERRORS, " puntos)")
	
	# Bonus por no usar flip
	if not used_flip:
		final_bonus += POINTS_NO_FLIP
		bonus_applied.emit("no_flip", POINTS_NO_FLIP)
		print("PuzzleScoreManager: Bonus sin flip (+", POINTS_NO_FLIP, " puntos)")
	
	_add_points(final_bonus)
	
	print("PuzzleScoreManager: ¡Puzzle completado! Bonus total: +", final_bonus, " puntos")
	print("PuzzleScoreManager: PUNTUACIÓN FINAL: ", current_score)
	
	# Guardar puntuación
	_save_score()

# === FUNCIONES AUXILIARES ===

func _calculate_streak_bonus() -> int:
	"""Calcula el bonus por racha actual"""
	if streak_count >= 10:
		return STREAK_10_BONUS
	elif streak_count >= 5:
		return STREAK_5_BONUS
	elif streak_count >= 3:
		return STREAK_3_BONUS
	else:
		return 0

func _add_points(points: int):
	"""Añade puntos al score actual"""
	current_score += points
	current_score = max(0, current_score)  # No permitir score negativo
	score_updated.emit(current_score)

func _subtract_points(points: int):
	"""Resta puntos del score actual (points debe ser positivo)"""
	current_score -= points
	current_score = max(0, current_score)  # No permitir score negativo
	score_updated.emit(current_score)

func _save_score():
	"""Guarda la puntuación en el sistema de persistencia"""
	# TODO: Implementar guardado de puntuaciones
	# Esta función se conectará con el sistema de guardado existente
	pass

func get_score_summary() -> Dictionary:
	"""Retorna un resumen completo de la puntuación"""
	return {
		"final_score": current_score,
		"pieces_placed": pieces_placed_correctly,
		"groups_connected": groups_connected,
		"total_moves": total_moves,
		"invalid_moves": invalid_moves,
		"flip_uses": flip_uses,
		"undo_uses": undo_uses,
		"had_errors": had_errors,
		"used_flip": used_flip,
		"max_streak": _get_max_streak_achieved()
	}

func _get_max_streak_achieved() -> int:
	"""Retorna la racha máxima alcanzada (por implementar tracking)"""
	# TODO: Implementar tracking de racha máxima
	return streak_count

# === FUNCIONES PARA MODO RELAX ===

func is_scoring_enabled() -> bool:
	"""Retorna si el sistema de puntuación está activo según el modo de juego"""
	if not game_state_manager:
		return true
	
	# El sistema de puntuación SIEMPRE está activo
	# En modo relax, simplemente no se aplican penalizaciones (ver should_apply_penalties())
	return true

func should_apply_penalties() -> bool:
	"""Retorna si se deben aplicar penalizaciones según el modo"""
	if not game_state_manager:
		return true
		
	# En modo relax, no aplicar penalizaciones
	return not game_state_manager.relax_mode 
