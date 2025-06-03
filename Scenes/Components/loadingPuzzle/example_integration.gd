extends Control

# Script de ejemplo para mostrar cómo integrar el LoadingPuzzle

@onready var loading_puzzle_scene = preload("res://Scenes/Components/loadingPuzzle/loading_puzzle.tscn")
var current_puzzle_instance

func _ready():
	# Ejemplo de uso básico
	show_loading_puzzle()

func show_loading_puzzle():
	# Crear instancia del puzzle
	current_puzzle_instance = loading_puzzle_scene.instantiate()
	
	# Configurar propiedades si es necesario
	current_puzzle_instance.cols = 6
	current_puzzle_instance.rows = 8
	current_puzzle_instance.duration = 2.0
	
	# Conectar señal de completado
	current_puzzle_instance.puzzle_completed.connect(_on_puzzle_completed)
	
	# Añadir a la escena
	add_child(current_puzzle_instance)
	
	# Posicionar en el centro
	current_puzzle_instance.position = Vector2(100, 100)

func _on_puzzle_completed():
	print("¡El puzzle se completó!")
	
	# Esperar un poco y reiniciar automáticamente
	await get_tree().create_timer(2.0).timeout
	if current_puzzle_instance:
		current_puzzle_instance.restart_animation()

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Espacio o Enter
		if current_puzzle_instance:
			current_puzzle_instance.restart_animation()
	
	if event.is_action_pressed("ui_cancel"):  # Escape
		# Cambiar a una imagen específica
		if current_puzzle_instance:
			current_puzzle_instance.set_specific_image("res://Assets/Images/paisaje1.jpg")

# Ejemplo de uso desde código
func show_custom_puzzle(image_path: String, cols: int = 8, rows: int = 10):
	# Limpiar puzzle anterior si existe
	if current_puzzle_instance:
		current_puzzle_instance.queue_free()
	
	# Crear nuevo puzzle
	current_puzzle_instance = loading_puzzle_scene.instantiate()
	current_puzzle_instance.cols = cols
	current_puzzle_instance.rows = rows
	current_puzzle_instance.duration = 1.5
	
	# Conectar señales
	current_puzzle_instance.puzzle_completed.connect(_on_puzzle_completed)
	
	add_child(current_puzzle_instance)
	current_puzzle_instance.position = Vector2(50, 50)
	
	# Usar imagen específica
	current_puzzle_instance.set_specific_image(image_path)

# Ejemplo de monitoreo de progreso
func _process(_delta):
	if current_puzzle_instance:
		var progress = current_puzzle_instance.get_animation_progress()
		# Aquí podrías actualizar una barra de progreso
		# progress_bar.value = progress * 100 