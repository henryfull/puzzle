extends Node

@export var panelColor = PanelContainer
@export var headerColor = Panel
@export var title = Label
@export var subtitle = Label
@export var size = Label
@export var imagePuzzle = TextureRect
@export var playButton = Button
@export var goalPuzzle = Label
@export var panelInfoGame = PanelContainer

const PUZZLE_IMAGE_KEYS := ["image_path", "image", "imagen", "thumbnail", "icon"]

@onready var noImageLabel: Label = $CanvasLayer/PanelContainerColor/MarginContainer/VBoxContainer/BorderImage/NoImageLabel
@onready var maxTimeRow: HBoxContainer = $CanvasLayer/PanelValues/MarginContainer/VBoxContainer/HBoxMaxTime
@onready var maxTimeValue: Label = $CanvasLayer/PanelValues/MarginContainer/VBoxContainer/HBoxMaxTime/LabelMaxTimeValue
@onready var maxMovesRow: HBoxContainer = $CanvasLayer/PanelValues/MarginContainer/VBoxContainer/HBoxMaxMoves
@onready var maxMovesValue: Label = $CanvasLayer/PanelValues/MarginContainer/VBoxContainer/HBoxMaxMoves/LabelMaxMovesValue
@onready var limitsSeparator: HSeparator = $CanvasLayer/PanelValues/MarginContainer/VBoxContainer/HSeparator2
@onready var limitsInnerSeparator: HSeparator = $CanvasLayer/PanelValues/MarginContainer/VBoxContainer/HSeparator3

func _ready() -> void:
	panelInfoGame.visible = false
	updateLayout()

func _check_and_clear_saved_state_if_different():
	"""Verifica si el estado guardado corresponde al puzzle actual y lo limpia si es diferente"""
	var puzzle_state_manager = get_node_or_null("/root/PuzzleStateManager")
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

func updateLayout(_columns = 0, _rows = 0) -> void:
	var global_size = str(GLOBAL.columns) + " x " + str(GLOBAL.rows)
	var global_gamemode = GLOBAL.gamemode
	
	# GLOBAL.setColorMode(panelColor, headerColor)


	title.text = GLOBAL.modes[global_gamemode].name
	var global_difficult = GLOBAL.current_difficult
	subtitle.text = tr(GLOBAL.difficulties[global_difficult].name) + " (" + global_size + ")"
	playButton.text = tr("common_play").to_upper()
	if GLOBAL.selected_puzzle != null:
		size.text = GLOBAL.selected_puzzle.name
	
	# Actualizar el GoalPuzzle cuando se actualiza el layout

	goalPuzzle.set_puzzle_limits(GLOBAL.columns, GLOBAL.rows, GLOBAL.gamemode)
	
	# Verificar si la configuración actual es diferente al estado guardado
	_check_and_clear_saved_state_if_different()
	_update_limits(global_gamemode)
	_update_puzzle_preview()

func _update_limits(game_mode: int) -> void:
	var show_max_time := game_mode == 3 or game_mode == 4
	var show_max_moves := game_mode == 4

	maxTimeRow.visible = show_max_time
	maxMovesRow.visible = show_max_moves
	limitsSeparator.visible = show_max_time or show_max_moves
	limitsInnerSeparator.visible = show_max_time and show_max_moves

	if show_max_time:
		maxTimeValue.text = _format_limit_time(GLOBAL.puzzle_limits.max_time)

	if show_max_moves:
		maxMovesValue.text = str(GLOBAL.puzzle_limits.max_moves)

func _update_puzzle_preview() -> void:
	var preview_texture := _get_selected_puzzle_texture()
	var has_preview := _has_played_current_puzzle() and preview_texture != null

	imagePuzzle.visible = has_preview
	imagePuzzle.texture = preview_texture if has_preview else null
	noImageLabel.visible = not has_preview

func _has_played_current_puzzle() -> bool:
	var current_pack_id = GLOBAL.selected_pack.id if GLOBAL.selected_pack else ""
	var current_puzzle_id = GLOBAL.selected_puzzle.id if GLOBAL.selected_puzzle else ""

	if current_pack_id.is_empty() or current_puzzle_id.is_empty():
		return false

	var progress_manager = get_node_or_null("/root/ProgressManager")
	if progress_manager:
		if progress_manager.has_method("is_puzzle_completed") and progress_manager.is_puzzle_completed(current_pack_id, current_puzzle_id):
			return true

		if progress_manager.has_method("get_puzzle_stats"):
			var puzzle_stats: Dictionary = progress_manager.get_puzzle_stats(current_pack_id, current_puzzle_id)
			if not puzzle_stats.is_empty():
				return true

	return _has_saved_state_for_current_puzzle()

func _has_saved_state_for_current_puzzle() -> bool:
	var puzzle_state_manager = get_node_or_null("/root/PuzzleStateManager")
	if not puzzle_state_manager or not puzzle_state_manager.has_saved_state():
		return false

	var current_pack_id = GLOBAL.selected_pack.id if GLOBAL.selected_pack else ""
	var current_puzzle_id = GLOBAL.selected_puzzle.id if GLOBAL.selected_puzzle else ""

	return puzzle_state_manager.get_saved_pack_id() == current_pack_id and puzzle_state_manager.get_saved_puzzle_id() == current_puzzle_id

func _get_selected_puzzle_texture() -> Texture2D:
	if GLOBAL.selected_puzzle == null:
		return null

	for key in PUZZLE_IMAGE_KEYS:
		if GLOBAL.selected_puzzle.has(key):
			var texture_path = GLOBAL.selected_puzzle[key]
			if typeof(texture_path) == TYPE_STRING and not texture_path.is_empty():
				var loaded_texture := _load_texture_from_path(texture_path)
				if loaded_texture:
					return loaded_texture

	if GLOBAL.selected_puzzle.has("id"):
		var puzzle_id = str(GLOBAL.selected_puzzle.id)
		var fallback_paths := [
			"res://Assets/Images/puzzles/" + puzzle_id + ".png",
			"res://Assets/Images/puzzles/" + puzzle_id + ".jpg",
			"res://Assets/Images/" + puzzle_id + ".png",
			"res://Assets/Images/" + puzzle_id + ".jpg"
		]

		for fallback_path in fallback_paths:
			var fallback_texture := _load_texture_from_path(fallback_path)
			if fallback_texture:
				return fallback_texture

	return null

func _load_texture_from_path(path: String) -> Texture2D:
	if path.is_empty():
		return null

	if path.begins_with("user://"):
		if not FileAccess.file_exists(path):
			return null

		var image := Image.new()
		var err := image.load(path)
		if err != OK:
			return null

		return ImageTexture.create_from_image(image)

	if not ResourceLoader.exists(path):
		return null

	return load(path) as Texture2D

func _format_limit_time(limit_seconds: float) -> String:
	var total_seconds := int(ceil(max(limit_seconds, 0.0)))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d min" % [minutes, seconds]

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
	goalPuzzle.set_puzzle_limits(columns, rows, GLOBAL.gamemode)


func _on_button_show_info_button_down() -> void:
	panelInfoGame.visible = true


func _on_button_show_info_button_up() -> void:
	panelInfoGame.visible = false
