extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var area2d: Area2D = $Area2D

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

var only_vertical: bool = false  # Si true, el grupo solo se mueve verticalmente

# Variables para el borde
var border_color: Color = Color(1, 1, 1, 0.8)  # Blanco semitransparente por defecto
var border_width: float = 3.0
var is_correct_position: bool = false
var border_node: Line2D
var group_id: int = -1  # Para identificar a qué grupo pertenece
var is_edge_piece: bool = false  # Si es pieza de borde en un grupo

func _ready():
	# Ajustar para recibir eventos de entrada
	# El Area2D está para colisiones, pero usaremos _input_event
	area2d.input_pickable = true
	pieces_group = [self]
	group_id = get_instance_id()  # Cada pieza comienza en su propio grupo
	
	# Crear el borde
	create_border()
	
	# Inicialmente todas las piezas son de borde
	is_edge_piece = true

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
	else:
		atlas_tex.atlas = puzzle_front
	atlas_tex.region = fragment_region
	sprite.texture = atlas_tex

func flip_piece():
	flipped = !flipped
	update_visual()

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

# EVENTOS DE ENTRADA
#
# func _input_event(viewport, event, shape_idx):
#	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
#		if event.pressed:
#			# Iniciar drag
#			dragging = true
#			drag_offset = global_position - event.position
#			bring_to_front()
#		else:
#			if dragging:
#				dragging = false
#				# Al soltar, avisar a PuzzleGame
#				if get_parent().has_method("place_piece"):
#					get_parent().place_piece(self)
#				if get_parent().has_method("on_piece_moved"):
#					get_parent().on_piece_moved()
#
#	elif event is InputEventMouseMotion and dragging:
#		# Mover el grupo entero (todas las piezas fusionadas)
#		var delta = event.relative
#		for p in pieces_group:
#			if only_vertical:
#				p.global_position.y += delta.y
#			else:
#				p.global_position += delta

#
# FUNCIONES DE APOYO
#
func bring_to_front():
	# Elevar este nodo para que se dibuje por encima de otros
	z_index = 999999
	if is_instance_valid(border_node):
		border_node.z_index = 999998  # El borde justo debajo de la pieza

# Función para actualizar el grupo de piezas
func update_pieces_group(new_group: Array):
	pieces_group = new_group
	update_border()
	update_border_color()
