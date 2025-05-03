extends Control
@export var description : Label

# Variables para límites del puzzle
var max_moves: int = 0
var max_time: float = 0.0


func _ready():
	set_puzzle_limits(GLOBAL.columns, GLOBAL.rows, GLOBAL.gamemode)

# Método para configurar límites del puzzle según dificultad
func set_puzzle_limits(columns: int = -1, rows: int = -1, game_mode: int = -1) -> void:
	# Si no se especifican columnas o filas, usar las del global
	if columns < 0:
		columns = GLOBAL.columns
	if rows < 0:
		rows = GLOBAL.rows
	if game_mode < 0:
		game_mode = GLOBAL.gamemode
	
	# Llamar a la función global para calcular los límites
	GLOBAL.calculate_puzzle_limits(game_mode)
	
	# Actualizar variables locales con los valores del global
	max_moves = GLOBAL.puzzle_limits.max_moves
	max_time = GLOBAL.puzzle_limits.max_time
	
	# Actualizar la descripción con el objetivo
	update_description(game_mode)

# Actualiza la descripción del puzzle según el modo de juego
func update_description(game_mode: int) -> void:
	if description:
		description.text = GLOBAL.get_puzzle_goal_description(game_mode)

# Guarda los límites en el global para acceso desde cualquier lugar
func save_limits_to_global() -> void:
	GLOBAL.puzzle_limits.max_moves = max_moves
	GLOBAL.puzzle_limits.max_time = max_time
	GLOBAL.save_settings()

# Estos métodos ya no son necesarios porque ahora usamos las funciones del GLOBAL
# Se mantienen por compatibilidad pero redirigen a las funciones globales
func calculate_max_flips() -> int:
	return GLOBAL.puzzle_limits.max_flips

func calculate_max_flip_moves() -> int:
	return GLOBAL.puzzle_limits.max_flip_moves
