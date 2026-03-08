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

	update_ui_texts()

func _format_time_value(time_in_seconds: float) -> String:
	var minutes = int(time_in_seconds) / 60
	var seconds = int(time_in_seconds) % 60
	return "%02d:%02d" % [minutes, seconds]

func update_ui_texts():
	if not defeat_data:
		return

	var lines: Array[String] = []
	if defeat_data.has("total_moves"):
		lines.append(TranslationServer.translate("defeat_moves") % int(defeat_data.total_moves))
	if defeat_data.has("elapsed_time"):
		lines.append(TranslationServer.translate("defeat_time") % _format_time_value(defeat_data.elapsed_time))
	if defeat_data.has("flip_count"):
		lines.append(TranslationServer.translate("defeat_flips") % int(defeat_data.flip_count))
	if defeat_data.has("flip_move_count"):
		lines.append(TranslationServer.translate("defeat_flip_moves") % int(defeat_data.flip_move_count))

	stats_label.text = "\n".join(lines)

	if defeat_data.has("reason"):
		reason_label.text = TranslationServer.translate(str(defeat_data.reason))
	else:
		reason_label.text = TranslationServer.translate("common_unknown")

	if retry_button:
		retry_button.text = TranslationServer.translate("common_repeat")

	if back_button:
		back_button.text = TranslationServer.translate("common_back")

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		update_ui_texts()


func _on_retry_pressed():
	# Volver a jugar el mismo puzzle
	if defeat_data.has("scene_path"):
		GLOBAL.change_scene_with_loading(defeat_data.scene_path)
	else:
		GLOBAL.change_scene_with_loading("res://Scenes/PuzzleGame.tscn")

func _on_back_pressed():
	# Volver a la selección de puzzles
	GLOBAL.change_scene_with_loading("res://Scenes/PuzzleSelection.tscn")
