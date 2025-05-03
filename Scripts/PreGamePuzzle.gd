extends Node

@export var panelColor = PanelContainer
@export var headerColor = Panel
@export var title = Label
@export var subtitle = Label
@export var size = Label
@export var tiki = TextureRect
@export var description = Label
@export var playButton = Button

func _ready() -> void:
	updateLayout()
	# Conectar la señal de cambio de dificultad
	

func updateLayout(colums =0, rows = 0) -> void:
	var global_size = str(GLOBAL.columns) + " x " + str(GLOBAL.rows)
	var global_gamemode = GLOBAL.gamemode
	var global_description_mode = GLOBAL.modes[global_gamemode].description
	var global_tiki = GLOBAL.modes[global_gamemode].tiki
	
	GLOBAL.setColorMode(panelColor, headerColor)


	description.text = global_description_mode
	title.text = GLOBAL.modes[global_gamemode].name
	var global_difficult = GLOBAL.current_difficult
	subtitle.text = tr(GLOBAL.difficulties[global_difficult].name) + " (" + global_size + ")"
	tiki.texture = load("res://Assets/Images/tikis/" + global_tiki + ".png")
	playButton.text = tr("common_play").to_upper()
	if GLOBAL.selected_puzzle != null:
		size.text = GLOBAL.selected_puzzle.name
	
	# Actualizar el GoalPuzzle cuando se actualiza el layout
	var goal_puzzle = $CanvasLayer/PanelContainerColor/MarginContainer/VBoxContainer/PanelContainer/GoalPuzzle
	if goal_puzzle:
		goal_puzzle.set_puzzle_limits(GLOBAL.columns, GLOBAL.rows, GLOBAL.gamemode)

func _on_play_button_pressed() -> void:
	if ResourceLoader.exists("res://Scenes/PuzzleGame.tscn"):
		print("PuzzleGrid: La escena PuzzleGame.tscn existe, cambiando...")
		get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")
	else:
		print("PuzzleGrid: ERROR - La escena PuzzleGame.tscn no existe")
		# Intentar con otra ruta
		if ResourceLoader.exists("res://Scenes/PuzzleGame.tscn"):
			print("PuzzleGrid: Intentando con ruta alternativa...")
			get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")
		else:
			print("PuzzleGrid: ERROR - No se pudo encontrar la escena del juego")


func _on_button_close_pressed() -> void:
	self.queue_free()


func _on_button_difficult_pressed() -> void:
	$CanvasLayer/DifficultyPanel.get_child(0).visible = true
	$CanvasLayer/DifficultyPanel.connect("difficulty_changed", Callable(self, "updateLayout"))
	$CanvasLayer/DifficultyPanel.connect("difficulty_changed", Callable(self, "_update_goal_puzzle"))

# Nueva función para actualizar específicamente el GoalPuzzle cuando cambia la dificultad
func _update_goal_puzzle(columns, rows) -> void:
	var goal_puzzle = $CanvasLayer/PanelContainerColor/MarginContainer/VBoxContainer/PanelContainer/GoalPuzzle
	if goal_puzzle:
		goal_puzzle.set_puzzle_limits(columns, rows, GLOBAL.gamemode)
