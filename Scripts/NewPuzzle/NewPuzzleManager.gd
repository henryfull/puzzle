# NewPuzzleManager.gd
# Orquesta la nueva mecánica: carga, construcción, input, feedback y victoria

extends Node2D
class_name NewPuzzleManager

@export var image_path: String = "res://Assets/Images/arte1.jpg"
@export var rows: int = 4
@export var cols: int = 6
@export var device_scale: float = 0.9

@export var pieces_container: Node2D

var piece_manager
var input_handler
var ex

func _ready():
	# Crear managers
	piece_manager = load("res://Scripts/NewPuzzle/NewPieceManager.gd").new()
	add_child(piece_manager)

	input_handler = load("res://Scripts/NewPuzzle/NewInputHandler.gd").new()
	add_child(input_handler)
	input_handler.initialize(piece_manager)

	# Cargar imagen (método clásico)
	var tex: Texture2D = load(image_path)
	var viewport_size = get_viewport_rect().size

	# Inicializar piezas
	if pieces_container == null:
		pieces_container = Node2D.new()
		pieces_container.name = "NewPiecesContainer"
		add_child(pieces_container)

	piece_manager.initialize(pieces_container, tex, rows, cols, viewport_size, device_scale)

	# Servicios
	var audio_mgr = null
	if has_node("/root/AudioService"):
		audio_mgr = get_node("/root/AudioService")
	elif has_node("/root/AudioManager"):
		audio_mgr = get_node("/root/AudioManager")
	var global_node = null
	if has_node("/root/GLOBAL"):
		global_node = get_node("/root/GLOBAL")
	piece_manager.set_services(audio_mgr, global_node)

	# Señales
	piece_manager.piece_merged.connect(_on_piece_merged)
	piece_manager.invalid_move.connect(_on_invalid_move)
	piece_manager.puzzle_completed.connect(_on_puzzle_completed)

func _on_piece_merged(_count: int):
	# Podrías actualizar UI de progreso aquí
	pass

func _on_invalid_move():
	# Mostrar feedback si hace falta
	pass

func _on_puzzle_completed():
	# Pequeña animación y cambio de escena
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(func():
		if has_node("/root/GLOBAL"):
			GLOBAL.change_scene_with_loading("res://Scenes/VictoryScreen.tscn")
	)
