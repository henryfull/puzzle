extends Control

# Referencias a nodos
@onready var stats_label: Label = $Panel/StatsLabel
@onready var reason_label: Label = $Panel/ReasonLabel
@onready var retry_button: Button = $Panel/RetryButton
@onready var back_button: Button = $Panel/BackButton

var defeat_data = {}

func _ready():
	# Obtener datos de derrota desde GLOBAL
	defeat_data = GLOBAL.defeat_data if "defeat_data" in GLOBAL else {}
	
	if(!defeat_data):
		return

	# Mostrar estadísticas
	var stats_text = ""
	if defeat_data.has("total_moves"):
		stats_text += "Movimientos: %d\n" % defeat_data.total_moves
	if defeat_data.has("elapsed_time"):
		var minutes = int(defeat_data.elapsed_time) / 60
		var seconds = int(defeat_data.elapsed_time) % 60
		stats_text += "Tiempo: %02d:%02d\n" % [minutes, seconds]
	if defeat_data.has("flip_count"):
		stats_text += "Flips: %d\n" % defeat_data.flip_count
	if defeat_data.has("flip_move_count"):
		stats_text += "Movimientos en flip: %d\n" % defeat_data.flip_move_count
	stats_label.text = stats_text

	# Motivo de derrota
	if defeat_data.has("reason"):
		reason_label.text = defeat_data.reason
	else:
		reason_label.text = "desconocido"


func _on_retry_pressed():
	# Volver a jugar el mismo puzzle
	if defeat_data.has("scene_path"):
		GLOBAL.change_scene_with_loading(defeat_data.scene_path)
	else:
		GLOBAL.change_scene_with_loading("res://Scenes/PuzzleGame.tscn")

func _on_back_pressed():
	# Volver a la selección de puzzles
	GLOBAL.change_scene_with_loading("res://Scenes/PuzzleSelection.tscn")
