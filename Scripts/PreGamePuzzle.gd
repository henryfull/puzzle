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
	_check_and_clear_saved_state_if_different()

func _check_and_clear_saved_state_if_different():
	"""Verifica si el estado guardado corresponde al puzzle actual y lo limpia si es diferente"""
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if not puzzle_state_manager or not puzzle_state_manager.has_saved_state():
		return
	
	var saved_pack_id = puzzle_state_manager.get_saved_pack_id()
	var saved_puzzle_id = puzzle_state_manager.get_saved_puzzle_id()
	var saved_game_mode = puzzle_state_manager.puzzle_state.game_mode
	var saved_difficulty = puzzle_state_manager.puzzle_state.difficulty
	
	var current_pack_id = GLOBAL.selected_pack.id if GLOBAL.selected_pack else ""
	var current_puzzle_id = GLOBAL.selected_puzzle.id if GLOBAL.selected_puzzle else ""
	var current_game_mode = GLOBAL.gamemode
	var current_difficulty = GLOBAL.current_difficult
	
	print("PreGamePuzzle: Verificando compatibilidad con estado guardado...")
	print("  - Guardado: Pack=", saved_pack_id, ", Puzzle=", saved_puzzle_id, ", Modo=", saved_game_mode, ", Dificultad=", saved_difficulty)
	print("  - Actual: Pack=", current_pack_id, ", Puzzle=", current_puzzle_id, ", Modo=", current_game_mode, ", Dificultad=", current_difficulty)
	
	# Verificar si hay alguna diferencia
	if (saved_pack_id != current_pack_id or 
		saved_puzzle_id != current_puzzle_id or 
		saved_game_mode != current_game_mode or 
		saved_difficulty != current_difficulty):
		
		print("PreGamePuzzle: ❌ Configuración actual es diferente al estado guardado, limpiando...")
		puzzle_state_manager.clear_all_state()
	else:
		print("PreGamePuzzle: ✅ Configuración actual coincide con el estado guardado")

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
	
	# Verificar si la configuración actual es diferente al estado guardado
	_check_and_clear_saved_state_if_different()

func _on_play_button_pressed() -> void:
	GLOBAL.change_scene_with_loading("res://Scenes/PuzzleGame.tscn")


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
