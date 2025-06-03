extends Node2D
@export var cols : int = 4
@export var rows : int = 6

@export_group("Control Tetris")
@export var fall_speed: float = 400.0  # Píxeles por segundo de caída
@export var piece_scale: float = 0.8
@export var container : Node2D 

# Señal que se emite cuando se completa el puzzle
signal puzzle_completed

var list_images = [
	"res://Assets/Images/arte1.jpg",
	"res://Assets/Images/arte2.jpg",
	"res://Assets/Images/paisaje1.jpg",
	"res://Assets/Images/paisaje2.jpg"
]

var target_texture : Texture2D
@onready var debug_label : Label = $DebugLabel
@onready var status_label : Label = $StatusLabel
@onready var count_label : Label = $CountLabel

# Variables del sistema Tetris
var all_pieces_data = []  # Cola de piezas por caer
var current_falling_piece : Node2D = null
var pieces_landed = []  # Piezas que ya aterrizaron
var piece_width : float
var piece_height : float
var is_running : bool = false

func _ready():
	debug_label.text = "Sistema Tetris Real"
	status_label.text = "Preparando..."
	start_tetris_puzzle()

func start_tetris_puzzle():
	# Limpiar todo
	for child in container.get_children():
		child.queue_free()
	
	all_pieces_data.clear()
	pieces_landed.clear()
	current_falling_piece = null
	
	await get_tree().process_frame
	
	# Cargar imagen aleatoria
	var random_index = randi() % list_images.size()
	target_texture = load(list_images[random_index])
	
	if target_texture == null:
		debug_label.text = "ERROR: No se pudo cargar imagen"
		return
	
	# Calcular tamaños
	var image_size = target_texture.get_size()
	piece_width = image_size.x / cols
	piece_height = image_size.y / rows
	
	# Crear datos de todas las piezas (sin crearlas aún)
	create_pieces_queue()
	
	debug_label.text = "Iniciando caída Tetris..."
	status_label.text = "Piezas cayendo..."
	is_running = true
	
	# Empezar el ciclo Tetris
	tetris_loop()

func create_pieces_queue():
	# Crear la cola de piezas en orden (fila por fila)
	for row in range(rows):
		for col in range(cols):
			var piece_data = {
				"col": col,
				"row": row,
				"texture": create_piece_texture(col, row),
				"final_pos": calculate_final_position(col, row)
			}
			all_pieces_data.append(piece_data)
	
	# ¡ORDEN ALEATORIO! Mezclar las piezas
	all_pieces_data.shuffle()
	
	count_label.text = "Piezas: " + str(all_pieces_data.size()) + " (orden aleatorio)"

func create_piece_texture(col: int, row: int) -> Texture2D:
	# Crear la textura de la pieza
	var image = target_texture.get_image()
	var piece_image = Image.create(int(piece_width), int(piece_height), false, Image.FORMAT_RGB8)
	
	var src_rect = Rect2i(
		col * int(piece_width),
		row * int(piece_height),
		int(piece_width),
		int(piece_height)
	)
	
	piece_image.blit_rect(image, src_rect, Vector2i.ZERO)
	var piece_texture = ImageTexture.new()
	piece_texture.set_image(piece_image)
	
	return piece_texture

func calculate_final_position(col: int, row: int) -> Vector2:
	var scaled_width = piece_width * piece_scale
	var scaled_height = piece_height * piece_scale
	
	var total_width = cols * scaled_width
	var offset_x = (730 - total_width) / 2
	
	var final_x = offset_x + (col * scaled_width) + (scaled_width / 2)
	var final_y = 200 + (row * scaled_height) + (scaled_height / 2)
	
	return Vector2(final_x, final_y)

func tetris_loop():
	while all_pieces_data.size() > 0 and is_running:
		# Sacar la siguiente pieza de la cola
		var piece_data = all_pieces_data.pop_front()
		
		# Crear y soltar la pieza
		drop_next_piece(piece_data)
		
		# Esperar a que termine de caer
		await piece_landed
		
		# Pequeña pausa entre piezas (como Tetris)
		await get_tree().create_timer(0.1)
	
	# Todas las piezas han caído
	if is_running:
		puzzle_complete()

signal piece_landed

func drop_next_piece(piece_data: Dictionary):
	# Crear la pieza física
	current_falling_piece = Node2D.new()
	current_falling_piece.name = "FallingPiece"
	
	var sprite = Sprite2D.new()
	sprite.texture = piece_data.texture
	sprite.scale = Vector2(piece_scale, piece_scale)
	sprite.centered = true
	
	current_falling_piece.add_child(sprite)
	
	# Posición inicial: arriba de la pantalla, en su columna correcta
	var start_pos = Vector2(piece_data.final_pos.x, -100)
	current_falling_piece.position = start_pos
	
	# Guardar destino
	current_falling_piece.set_meta("target_y", piece_data.final_pos.y)
	current_falling_piece.set_meta("piece_data", piece_data)
	
	container.add_child(current_falling_piece)
	
	debug_label.text = "Pieza " + str(pieces_landed.size() + 1) + "/" + str(pieces_landed.size() + all_pieces_data.size() + 1) + " cayendo..."

func _physics_process(delta):
	if current_falling_piece == null or not is_running:
		return
	
	# Hacer caer la pieza actual
	var target_y = current_falling_piece.get_meta("target_y")
	var current_pos = current_falling_piece.position
	
	# Mover hacia abajo
	var new_y = current_pos.y + (fall_speed * delta)
	
	# Verificar si llegó al destino
	if new_y >= target_y:
		# La pieza aterrizó
		current_falling_piece.position.y = target_y
		piece_has_landed()
	else:
		# Seguir cayendo
		current_falling_piece.position.y = new_y

func piece_has_landed():
	if current_falling_piece == null:
		return
	
	# Agregar a piezas aterrizadas
	pieces_landed.append(current_falling_piece)
	
	# Efecto visual de aterrizaje
	var sprite = current_falling_piece.get_child(0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.2, 1.2, 0.9), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	# Limpiar referencia
	current_falling_piece = null
	
	# Emitir señal de que aterrizó
	piece_landed.emit()

func puzzle_complete():
	is_running = false
	
	debug_label.text = "¡Puzzle Tetris completado!"
	status_label.text = "¡LISTO!"
	count_label.text = "Todas las " + str(pieces_landed.size()) + " piezas aterrizaron"
	
	# Efecto final
	for piece in pieces_landed:
		var sprite = piece.get_child(0)
		var tween = create_tween()
		await get_tree().create_timer(0.05)  # Efecto escalonado
		tween.tween_property(sprite, "modulate", Color(1.3, 1.3, 1.3), 0.15)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
	puzzle_completed.emit()

func restart_animation():
	is_running = false
	await get_tree().create_timer(0.1)
	start_tetris_puzzle()

# Función para detener inmediatamente la animación del loading
func stop_animation():
	print("LoadingPuzzle: Deteniendo animación...")
	is_running = false
	current_falling_piece = null

# Función para hacer fade out suave del loading puzzle
func fade_out() -> void:
	print("LoadingPuzzle: Iniciando fade out...")
	
	# Detener inmediatamente cualquier animación en curso
	stop_animation()
	
	# Obtener el CanvasLayer para hacer fade out
	var canvas_layer = $CanvasLayer
	if canvas_layer:
		var tween = create_tween()
		tween.tween_property(canvas_layer, "modulate", Color(1, 1, 1, 0), 0.3)
		await tween.finished
		print("LoadingPuzzle: Fade out completado")
	else:
		print("LoadingPuzzle: No se encontró CanvasLayer para fade out")
		# Pequeña pausa para simular el fade
		await get_tree().create_timer(0.3).timeout

# Función para hacer que el loading se detenga inmediatamente sin animación
func stop_immediately():
	print("LoadingPuzzle: Deteniendo inmediatamente...")
	stop_animation()
	modulate = Color(1, 1, 1, 0)  # Hacer invisible inmediatamente
