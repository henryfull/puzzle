extends Control

@export var labelInit: Label
@export var labelPack: Label
@export var labelPuzzle: Label
@export var labelAchivement: Label
@export var labelStats: Label

# Variable estática para mantener el label activo entre instancias
static var active_label: String = "init"

func _ready() -> void:
	# Al iniciar, aplicamos el label que estaba activo
	set_active_label(active_label)

# Activa solo el label especificado y oculta los demás
func set_active_label(label_name: String) -> void:
	# Guardamos el label activo para futuras instancias
	active_label = label_name
	
	# Ocultar todos los labels primero
	labelInit.visible = false
	labelPack.visible = false
	labelPuzzle.visible = false
	labelAchivement.visible = false
	labelStats.visible = false
	
	# Activar solo el label solicitado
	match label_name:
		"pack":
			labelPack.visible = true
		"puzzle":
			labelPuzzle.visible = true
		"achievement":
			labelAchivement.visible = true
		"stats":
			labelStats.visible = true
		"init", _:
			labelInit.visible = true

func _on_button_pressed_init() -> void:
	go("res://Scenes/MainMenu.tscn", "init")

func _on_button_pressed_packs() -> void:
	go("res://Scenes/PackSelection.tscn", "pack")

func _on_button_pressed_puzzles() -> void:
	go("res://Scenes/PuzzleSelection.tscn", "puzzle")

func _on_button_pressed_achivements() -> void:
	go("res://Scenes/Achievements.tscn", "achievement")

func _on_button_pressed_statistics() -> void:
	go("res://Scenes/StatsScreen.tscn", "stats")

func go(path: String, label_name: String = "init"):
	# Guardamos el label que debe estar activo antes de cambiar la escena
	active_label = label_name
	
	if has_node("/root/OptionsManager") and get_node("/root/OptionsManager").is_visible():
		get_node("/root/OptionsManager").hide_options()
		await get_tree().create_timer(0.3).timeout  # Esperar a que termine la animación
	await get_tree().process_frame
		
	GLOBAL.change_scene_with_loading(path)
	
	
