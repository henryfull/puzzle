extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var area2d: Area2D = $Area2D
@onready var number_label: Label = $NumberLabel
@onready var background_rect: ColorRect = $BackgroundRect

var puzzle_image: Texture2D
var fragment_region: Rect2
var original_grid_position: Vector2
var cell_size: Vector2

var pieces_group: Array = []
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var puzzle_front: Texture2D
var puzzle_back: Texture2D
var flipped: bool = false
var order_number: int = 0  # Número de orden de la pieza

var only_vertical: bool = false  # Si true, el grupo solo se mueve verticalmente

# Variables para el borde
var border_color: Color = Color(1, 1, 1, 0.8)  # Blanco semitransparente por defecto
var border_width: float = 3.0
var is_correct_position: bool = false
var border_node: Line2D
var group_id: int = -1  # Para identificar a qué grupo pertenece
var is_edge_piece: bool = false  # Si es pieza de borde en un grupo

# Variables exportables para personalización
@export var background_color: Color = Color(0.2, 0.2, 0.2, 1.0)  # Color de fondo para el lado trasero
@export var number_color: Color = Color(1, 1, 1, 1)  # Color del número
@export var number_font_size: int = 42  # Tamaño de fuente del número

func _ready():
	# Ajustar para recibir eventos de entrada
	# El Area2D está para colisiones, pero usaremos _input_event
	area2d.input_pickable = true
	pieces_group = [self]
	group_id = get_instance_id()  # Cada pieza comienza en su propio grupo
	
	# Crear el borde
	create_border()
	
	# Configurar label del número
	setup_number_label()
	
	# Inicialmente todas las piezas son de borde
	is_edge_piece = true
	
	# Establecer el orden de los nodos
	if background_rect:
		background_rect.z_index = 10
		# Asegurarse de que el ColorRect no bloquee los eventos de entrada
		background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if number_label:
		number_label.z_index = 11  # El número debe estar encima del fondo
		# Asegurarse de que el Label no bloquee los eventos de entrada
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup_number_label():
	# Configurar el Label del número (ya debe existir en la escena)
	if number_label:
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number_label.add_theme_font_size_override("font_size", number_font_size)
		number_label.add_theme_color_override("font_color", number_color)
		number_label.visible = false
	
	# Configurar el rectángulo de fondo
	if background_rect:
		background_rect.color = background_color
		print("Color del fondo configurado a: ", background_color)
		background_rect.visible = false

func set_order_number(number: int):
	order_number = number
	if number_label:
		number_label.text = str(number)

func set_piece_data(front_tex: Texture2D, back_tex: Texture2D, region: Rect2):
	puzzle_front = front_tex
	puzzle_back = back_tex
	fragment_region = region
	update_visual()
	update_border()

func update_visual():
	var atlas_tex = AtlasTexture.new()
	# Si la pieza está volteada, usamos la textura trasera
	if flipped:
		atlas_tex.atlas = puzzle_back
		if number_label:
			number_label.visible = true
		if background_rect:
			background_rect.visible = true
			background_rect.color = background_color  # Asegurar que el color es correcto
			# Asegurarnos de que el background_rect no bloquee los eventos de entrada
			background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		atlas_tex.atlas = puzzle_front
		if number_label:
			number_label.visible = false
		if background_rect:
			background_rect.visible = false
	atlas_tex.region = fragment_region
	sprite.texture = atlas_tex
	
	# Asegurar que el tamaño del número y el fondo se ajusten al tamaño del sprite
	if sprite.texture:
		var texture_size = sprite.texture.get_size() * sprite.scale
		if background_rect:
			background_rect.size = texture_size
			background_rect.position = sprite.position - texture_size/2
		if number_label:
			number_label.size = texture_size
			number_label.position = sprite.position - texture_size/2
			
	# Actualizar la posición del área de colisión para asegurar que coincida con el sprite
	if area2d and sprite.texture:
		area2d.position = sprite.position

func flip_piece():
	flipped = !flipped
	update_visual()
	
	# Reproducir efecto de sonido de flip
	if get_parent().has_method("play_flip_sound"):
		get_parent().play_flip_sound()

# Función para crear el borde de la pieza
func create_border():
	# Crear un nodo Line2D para el borde
	border_node = Line2D.new()
	border_node.width = border_width
	border_node.default_color = border_color
	border_node.z_index = 1  # Para que se dibuje por encima del sprite
	add_child(border_node)
	
	# Actualizar el borde
	update_border()

# Función para actualizar el borde según la posición y tamaño del sprite
func update_border():
	if not is_instance_valid(border_node) or not is_instance_valid(sprite) or sprite.texture == null:
		return
	
	# Si la pieza no es de borde en un grupo, no mostramos su borde
	if not is_edge_piece:
		border_node.visible = false
		return
	
	# Obtener el tamaño del sprite
	var texture_size = sprite.texture.get_size() * sprite.scale
	
	# Calcular las coordenadas del borde
	var half_width = texture_size.x / 2
	var half_height = texture_size.y / 2
	var center = sprite.position
	
	# Crear los puntos del borde (rectángulo)
	var points = [
		center + Vector2(-half_width, -half_height),  # Esquina superior izquierda
		center + Vector2(half_width, -half_height),   # Esquina superior derecha
		center + Vector2(half_width, half_height),    # Esquina inferior derecha
		center + Vector2(-half_width, half_height),   # Esquina inferior izquierda
		center + Vector2(-half_width, -half_height)   # Cerrar el rectángulo (volver al inicio)
	]
	
	# Asignar los puntos al borde
	border_node.points = points
	border_node.visible = true
	
	# Actualizar el color del borde según si está en la posición correcta
	update_border_color()
	
	# Actualizar el área de colisión para que coincida con el sprite
	if area2d and area2d.has_node("CollisionShape2D"):
		var collision_shape = area2d.get_node("CollisionShape2D")
		if collision_shape:
			# Ajustar la posición del área de colisión
			area2d.position = center
			
			# Ajustar el tamaño de la colisión para que coincida con el sprite
			# Convertir el tamaño del sprite a la escala del CollisionShape2D
			var shape_scale = collision_shape.scale
			collision_shape.scale.x = texture_size.x / 336.38  # Dividir por el tamaño base en la escena
			collision_shape.scale.y = texture_size.y / 308.67  # Dividir por el tamaño base en la escena

# Función para actualizar el color del borde según la posición
func update_border_color():
	if not is_instance_valid(border_node):
		return
	
	# Si la pieza está en un grupo (más de una pieza), el borde es transparente
	if pieces_group.size() > 1:
		border_node.default_color = Color(0, 1, 0, 0) if is_correct_position else Color(1, 0.3, 0.3, 0)
	else:
		# Si es una pieza individual, mostrar el borde normal
		border_node.default_color = Color(10, 10, 10, 0.7) if is_correct_position else Color(20, 20, 20, 0.7)

# Función para establecer si la pieza está en la posición correcta
func set_correct_position(correct: bool):
	is_correct_position = correct
	update_border_color()

# Función para establecer el identificador del grupo
func set_group_id(id: int):
	group_id = id
	update_border()

# Función para establecer si es una pieza de borde en un grupo
func set_edge_piece(is_edge: bool):
	is_edge_piece = is_edge
	update_border()

# Sobreescribir _process para asegurar que el borde se actualiza si cambia la escala o posición
func _process(_delta):
	if is_instance_valid(border_node) and is_instance_valid(sprite) and sprite.texture != null:
		update_border()
		
	# Verificar que el color del fondo es correcto si la pieza está volteada
	if flipped and is_instance_valid(background_rect):
		background_rect.color = background_color

# Función para actualizar el grupo de piezas
func update_pieces_group(new_group: Array):
	pieces_group = new_group
	update_border()
	update_border_color()

# Método para manejar los eventos de entrada en el área de colisión
func _input_event(_viewport, event, _shape_idx):
	# Asegurarse que el evento sea de tipo InputEvent
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		# Delegar el manejo de eventos al nodo padre (PuzzleGame)
		if get_parent().has_method("process_piece_click"):
			get_parent().process_piece_click(event)
