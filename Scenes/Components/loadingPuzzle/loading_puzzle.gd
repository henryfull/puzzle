extends Node2D
@export var cols : int = 4
@export var rows : int = 6

@export_group("Control Tetris")
@export var fall_speed: float = 400.0  # Píxeles por segundo de caída
@export var piece_scale: float = 0.8
@export var time_between_pieces: float = 0.01  # Tiempo entre cada pieza
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

# Variables para centrado automático
var puzzle_center_x : float
var puzzle_center_y : float
var screen_size : Vector2

# Variables para animaciones más suaves
var landing_animation_duration : float = 0.4
var landing_scale_bounce : float = 1.2

func _ready():
	debug_label.text = "Sistema Tetris Real"
	status_label.text = "Preparando..."
	# Obtener el tamaño de la pantalla para centrado
	update_screen_size()
	# Conectar señal para actualizar cuando cambie el tamaño de ventana
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	start_tetris_puzzle()

func update_screen_size():
	screen_size = get_viewport().get_visible_rect().size
	print("LoadingPuzzle: Tamaño de pantalla actualizado: ", screen_size)

func _on_viewport_size_changed():
	update_screen_size()
	# Si está corriendo, reiniciar para recentrar
	if is_running:
		restart_animation()

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
	
	# Calcular tamaños con precisión de punto flotante
	var image_size = target_texture.get_size()
	piece_width = float(image_size.x) / float(cols)
	piece_height = float(image_size.y) / float(rows)
	
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
	# Crear la textura de la pieza con cálculos más precisos
	var image = target_texture.get_image()
	var image_size = image.get_size()
	
	# Calcular el tamaño exacto de cada pieza usando flotantes
	var exact_piece_width = float(image_size.x) / float(cols)
	var exact_piece_height = float(image_size.y) / float(rows)
	
	# Calcular las coordenadas exactas de recorte
	var src_x = int(col * exact_piece_width)
	var src_y = int(row * exact_piece_height)
	var src_width = int((col + 1) * exact_piece_width) - src_x
	var src_height = int((row + 1) * exact_piece_height) - src_y
	
	# Crear la imagen de la pieza con el tamaño exacto calculado
	var piece_image = Image.create(src_width, src_height, false, Image.FORMAT_RGB8)
	
	var src_rect = Rect2i(src_x, src_y, src_width, src_height)
	
	piece_image.blit_rect(image, src_rect, Vector2i.ZERO)
	var piece_texture = ImageTexture.new()
	piece_texture.set_image(piece_image)
	
	return piece_texture

func calculate_final_position(col: int, row: int) -> Vector2:
	# Usar el tamaño escalado para el espaciado
	# para que las piezas queden perfectamente juntas
	var spacing_width = piece_width * piece_scale
	var spacing_height = piece_height * piece_scale
	
	# Calcular el tamaño total del puzzle usando el espaciado escalado
	var total_puzzle_width = cols * spacing_width
	var total_puzzle_height = rows * spacing_height
	
	# Centrar el puzzle perfectamente en la pantalla
	var puzzle_start_x = (screen_size.x - total_puzzle_width) / 2
	var puzzle_start_y = (screen_size.y - total_puzzle_height) / 2
	
	# Calcular la posición específica de esta pieza usando el espaciado escalado
	var final_x = puzzle_start_x + (col * spacing_width) + (spacing_width / 2)
	var final_y = puzzle_start_y + (row * spacing_height) + (spacing_height / 2)
	
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
		await get_tree().create_timer(time_between_pieces)
	
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
	sprite.scale = Vector2.ZERO  # Empezar desde escala 0 para animación natural
	sprite.centered = true
	sprite.modulate = Color(1, 1, 1, 0)  # Empezar transparente
	
	current_falling_piece.add_child(sprite)
	
	# Posición inicial: arriba de la pantalla, en la columna correcta de la pieza
	# Usar un offset proporcional al tamaño de pantalla
	var start_y = -screen_size.y * 0.1  # 10% de la altura de pantalla por encima
	var start_pos = Vector2(piece_data.final_pos.x, start_y)
	current_falling_piece.position = start_pos
	
	# Guardar destino y escala final
	current_falling_piece.set_meta("target_y", piece_data.final_pos.y)
	current_falling_piece.set_meta("piece_data", piece_data)
	current_falling_piece.set_meta("final_scale", piece_scale)
	
	container.add_child(current_falling_piece)
	
	# Animación natural: aparece de pequeño a grande con fade-in suave
	var sprite_ref = sprite
	var appear_tween = create_tween()
	appear_tween.set_ease(Tween.EASE_OUT)
	appear_tween.set_trans(Tween.TRANS_BACK)
	appear_tween.parallel().tween_property(sprite_ref, "modulate", Color.WHITE, 0.5)
	appear_tween.parallel().tween_property(sprite_ref, "scale", Vector2(piece_scale, piece_scale), 0.5)
	
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
	
	# SIN efectos visuales - la pieza simplemente se queda en su lugar
	var sprite = current_falling_piece.get_child(0)
	var final_scale = current_falling_piece.get_meta("final_scale")
	
	# Asegurar que la pieza esté en su tamaño correcto y completamente visible
	sprite.scale = Vector2(final_scale, final_scale)
	sprite.modulate = Color.WHITE
	
	# Limpiar referencia
	current_falling_piece = null
	
	# Emitir señal de que aterrizó
	piece_landed.emit()

func puzzle_complete():
	is_running = false
	
	debug_label.text = "¡Puzzle Tetris completado!"
	status_label.text = "¡LISTO!"
	count_label.text = "Todas las " + str(pieces_landed.size()) + " piezas aterrizaron"
	
	# SIN efectos visuales - las piezas se quedan exactamente como están
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
