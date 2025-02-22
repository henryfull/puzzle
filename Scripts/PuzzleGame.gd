extends Node2D

var total_moves: int = 0
var time_elapsed: float = 0.0
var puzzle_completed: bool = false
var puzzle = null

func _ready():
	# Inicializar el puzzle: cargar piezas, establecer posiciones e iniciar el cronómetro
	print("Iniciando PuzzleGame")
	load_puzzle()
	# Aquí se podrían instanciar las piezas, por ejemplo, usando load("res://Scenes/PuzzlePiece.tscn")
	pass
	
func load_puzzle():
	puzzle = GLOBAL.selected_puzzle
	print('puzzle', puzzle)

func _process(delta):
	if not puzzle_completed:
		time_elapsed += delta

func on_piece_moved():
	total_moves += 1
	print("Movimiento realizado. Total movimientos: " + str(total_moves))

func check_victory():
	var completed = true
	# Suponemos que cada pieza es un hijo que tiene el método is_in_correct_position
	for piece in get_children():
		if piece.has_method("is_in_correct_position") and not piece.is_in_correct_position():
			completed = false
			break
	if completed:
		on_puzzle_completed()

func on_puzzle_completed():
	puzzle_completed = true
	print("Puzzle completado en " + str(total_moves) + " movimientos y " + str(time_elapsed) + " segundos.")
	# Ejemplo de desbloqueo de logro:
	if total_moves > 0 and !AchievementsManager.achievements["primer_paso"]["unlocked"]:
		AchievementsManager.unlock_achievement("primer_paso")
	# Se pueden agregar otras comprobaciones de logros según condiciones específicas
	get_tree().change_scene_to_file("res://Scenes/VictoryScreen.tscn") 
