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

# Variables para efectos visuales (reemplazando el sistema de bordes)
var is_correct_position: bool = false
var group_id: int = -1  # Para identificar a qué grupo pertenece
var is_edge_piece: bool = false  # Si es pieza de borde en un grupo

# Variables para efectos visuales de agrupación
var grouped_opacity: float = 1.0  # Opacidad para piezas agrupadas (color vivo)
var single_opacity: float = 0.8   # Opacidad para piezas sueltas (más apagado)
var grouped_brightness: float = 1.0  # Brillo para piezas agrupadas
var single_brightness: float = 0.9   # Brillo para piezas sueltas
var correct_position_glow: float = 1.1  # Brillo extra para posición correcta

# Nuevas variables para los colores de los grupos
var single_piece_color: Color = Color(0.2, 0.2, 0.2, 1.0)  # Color para piezas sueltas
var group_colors: Array = [
	Color(0.95, 0.3, 0.3, 1.0),   # Rojo
	Color(0.3, 0.8, 0.3, 1.0),    # Verde
	Color(0.3, 0.3, 0.95, 1.0),   # Azul
	Color(0.95, 0.95, 0.3, 1.0),  # Amarillo
	Color(0.95, 0.6, 0.3, 1.0),   # Naranja
	Color(0.7, 0.3, 0.95, 1.0),   # Púrpura
	Color(0.3, 0.95, 0.95, 1.0),  # Cian
	Color(0.95, 0.3, 0.6, 1.0),   # Rosa
	Color(0.5, 0.8, 0.2, 1.0),    # Verde lima
	Color(0.5, 0.2, 0.8, 1.0)     # Violeta
]

# Variables exportables para personalización
@export var background_color: Color = Color(0.2, 0.2, 0.2, 1.0)  # Color de fondo para el lado trasero
@export var number_color: Color = Color(1, 1, 1, 1)  # Color del número
@export var number_font_size: int = 42  # Tamaño de fuente del número
@export var use_color_groups: bool = true  # Si es false, se usará el color por defecto para todas las piezas
@export var single_piece_color_override: Color = Color(0.2, 0.2, 0.2, 1.0)  # Color para piezas sueltas (configurable desde el editor)

# Variables para efectos visuales exportables - CONFIGURACIÓN FÁCIL
@export_group("Efectos Visuales")
@export var enable_visual_effects: bool = true  # Activar/desactivar efectos visuales

@export_subgroup("Opacidad")
@export_range(0.1, 1.0, 0.05) var single_piece_opacity: float = 0.7   # Opacidad para piezas sueltas
@export_range(0.1, 1.0, 0.05) var grouped_piece_opacity: float = 1.0  # Opacidad para piezas agrupadas

@export_subgroup("Brillo y Contraste")
@export_range(0.3, 1.5, 0.05) var single_piece_brightness: float = 0.85   # Brillo para piezas sueltas
@export_range(0.3, 1.5, 0.05) var grouped_piece_brightness: float = 1.0   # Brillo para piezas agrupadas
@export_range(1.0, 2.0, 0.05) var correct_position_brightness: float = 1.15  # Brillo extra para posición correcta
@export_range(1.0, 2.0, 0.05) var dragging_brightness: float = 1.1     # Brillo cuando se arrastra

@export_subgroup("Configuración Avanzada")
@export var brightness_variation: float = 0.4   # Variación de brillo (OBSOLETO - usar variables específicas arriba)

func _ready():
	# Ajustar para recibir eventos de entrada
	# El Area2D está para colisiones, pero usaremos _input_event
	area2d.input_pickable = true
	pieces_group = [self]
	group_id = get_instance_id()  # Cada pieza comienza en su propio grupo
	
	# Si hay un color personalizado para piezas sueltas, usarlo
	if single_piece_color_override != Color(0.2, 0.2, 0.2, 1.0):
		single_piece_color = single_piece_color_override
	
	# Configurar efectos visuales iniciales
	setup_visual_effects()
	
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

func setup_visual_effects():
	# Configurar los valores de efectos visuales desde las variables exportables
	single_opacity = single_piece_opacity
	grouped_opacity = grouped_piece_opacity
	single_brightness = single_piece_brightness
	grouped_brightness = grouped_piece_brightness
	
	# Aplicar efectos iniciales (pieza suelta al inicio)
	update_visual_effects()

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

func update_visual():
	var atlas_tex = AtlasTexture.new()
	# Si la pieza está volteada, usamos la textura trasera
	if flipped:
		atlas_tex.atlas = puzzle_back
		if number_label:
			number_label.visible = true
		if background_rect:
			background_rect.visible = true
			# Asignar color según si es parte de un grupo o no
			update_background_color()
			# Asegurarnos de que el background_rect no bloquee los eventos de entrada
			background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		atlas_tex.atlas = puzzle_front
		if number_label:
			number_label.visible = false
		if background_rect:
			background_rect.visible = false
	atlas_tex.region = fragment_region
	
	# Configurar filtrado de textura para evitar bordes (Godot 4)
	# En Godot 4, el filtrado se controla a nivel del sprite, no de la textura
	
	sprite.texture = atlas_tex
	
	# Asegurar que el sprite no tenga filtrado
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Asegurar que el tamaño del número y el fondo se ajusten al tamaño del sprite escalado
	if sprite.texture:
		var texture_size = sprite.texture.get_size() * sprite.scale
		if background_rect:
			# Usar el tamaño escalado completo para cubrir exactamente la misma área que el sprite
			background_rect.size = texture_size
			# Centrar el background_rect ya que el sprite está en (0,0)
			background_rect.position = -texture_size * 0.5
		if number_label:
			# El número debe cubrir la misma área que el sprite escalado
			number_label.size = texture_size
			# Centrar el number_label ya que el sprite está en (0,0)
			number_label.position = -texture_size * 0.5
			
	# Actualizar el área de colisión para que coincida exactamente con el sprite
	if area2d and sprite.texture:
		var texture_size = sprite.texture.get_size() * sprite.scale
		# El área de colisión debe estar centrada en el nodo padre (posición 0,0)
		area2d.position = Vector2.ZERO
		
		# Actualizar el CollisionShape2D para que coincida con el tamaño del sprite
		var collision_shape = area2d.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape is RectangleShape2D:
			var rect_shape = collision_shape.shape as RectangleShape2D
			rect_shape.size = texture_size
			# Centrar la forma de colisión
			collision_shape.position = Vector2.ZERO
			collision_shape.scale = Vector2.ONE
	
	# Actualizar efectos visuales después de cambiar la textura
	update_visual_effects()

# Método para obtener los datos de la pieza para serialización (alias también disponible como get_data)
func get_puzzle_piece_data() -> Dictionary:
	var group_piece_ids = []
	for piece in pieces_group:
		if piece != null and piece.has_method("get_instance_id"):
			group_piece_ids.append(piece.get_instance_id())
	
	var data = {
		"order_number": order_number,
		"original_grid_position": {
			"x": original_grid_position.x,
			"y": original_grid_position.y
		},
		"current_position": {
			"x": global_position.x,
			"y": global_position.y
		},
		"local_position": {
			"x": position.x,
			"y": position.y
		},
		"flipped": flipped,
		"group_id": group_id,
		"is_correct_position": is_correct_position,
		"is_edge_piece": is_edge_piece,
		"dragging": dragging,
		"group_piece_ids": group_piece_ids,
		"only_vertical": only_vertical,
		"fragment_region": {
			"x": fragment_region.position.x,
			"y": fragment_region.position.y,
			"width": fragment_region.size.x,
			"height": fragment_region.size.y
		}
	}
	
	# Debug: imprimir datos de la pieza al serializar
	print("PuzzlePiece: Serializando pieza ", order_number, " en posición global: ", global_position, ", local: ", position)
	
	return data

# Método para restaurar los datos de la pieza desde serialización
func set_puzzle_piece_data(data: Dictionary):
	print("PuzzlePiece: Restaurando datos de pieza ", data.get("order_number", "?"))
	
	if data.has("order_number"):
		order_number = data.order_number
		set_order_number(order_number)
	
	if data.has("original_grid_position"):
		var orig_pos_data = data.original_grid_position
		if typeof(orig_pos_data) == TYPE_DICTIONARY and orig_pos_data.has("x") and orig_pos_data.has("y"):
			original_grid_position = Vector2(orig_pos_data.x, orig_pos_data.y)
		else:
			original_grid_position = orig_pos_data  # Fallback para formato anterior
	
	# Restaurar posición - intentar global primero, luego local como respaldo
	if data.has("current_position"):
		var current_pos_data = data.current_position
		if typeof(current_pos_data) == TYPE_DICTIONARY and current_pos_data.has("x") and current_pos_data.has("y"):
			global_position = Vector2(current_pos_data.x, current_pos_data.y)
			print("PuzzlePiece: Posición global restaurada a: ", global_position)
		else:
			global_position = current_pos_data  # Fallback para formato anterior
			print("PuzzlePiece: Posición global restaurada (formato anterior) a: ", global_position)
	elif data.has("local_position"):
		var local_pos_data = data.local_position
		if typeof(local_pos_data) == TYPE_DICTIONARY and local_pos_data.has("x") and local_pos_data.has("y"):
			position = Vector2(local_pos_data.x, local_pos_data.y)
			print("PuzzlePiece: Posición local restaurada a: ", position)
		else:
			position = local_pos_data  # Fallback para formato anterior
			print("PuzzlePiece: Posición local restaurada (formato anterior) a: ", position)
	
	if data.has("flipped"):
		flipped = data.flipped
		update_visual()
	
	if data.has("group_id"):
		group_id = data.group_id
	
	if data.has("is_correct_position"):
		is_correct_position = data.is_correct_position
	
	if data.has("is_edge_piece"):
		is_edge_piece = data.is_edge_piece
	
	if data.has("only_vertical"):
		only_vertical = data.only_vertical
	
	if data.has("fragment_region"):
		var region_data = data.fragment_region
		fragment_region = Rect2(
			Vector2(region_data.x, region_data.y),
			Vector2(region_data.width, region_data.height)
		)
		update_visual()
	
	# Forzar actualización visual después de restaurar datos
	call_deferred("_force_visual_update")
	
	print("PuzzlePiece: Datos restaurados para pieza ", order_number, " en posición final: ", global_position)
	
	# Los grupos se restaurarán en una segunda pasada
	# porque necesitamos que todas las piezas estén cargadas primero

# Método auxiliar para forzar actualización visual
func _force_visual_update():
	update_visual()
	# Asegurar que la posición se mantenga
	if has_method("update_visual_effects"):
		update_visual_effects()

# Nueva función para actualizar efectos visuales basados en agrupación
func update_visual_effects():
	if not enable_visual_effects or not is_instance_valid(sprite):
		return
	
	var is_grouped = pieces_group.size() > 1
	var target_opacity = grouped_opacity if is_grouped else single_opacity
	var target_brightness = grouped_brightness if is_grouped else single_brightness
	
	# Aplicar brillo extra si está en posición correcta
	if is_correct_position:
		target_brightness *= correct_position_brightness
	
	# Aplicar opacidad al sprite
	sprite.modulate.a = target_opacity
	
	# Aplicar brillo/contraste modificando los valores RGB
	var brightness_color = Color(target_brightness, target_brightness, target_brightness, target_opacity)
	sprite.modulate = brightness_color
	
	# Si está volteado, también aplicar efectos al fondo y número
	if flipped:
		if is_instance_valid(background_rect):
			background_rect.modulate.a = target_opacity
		if is_instance_valid(number_label):
			number_label.modulate.a = target_opacity

# Nueva función para actualizar el color del fondo según el grupo
func update_background_color():
	if not is_instance_valid(background_rect):
		return
	
	# Si no se quiere usar colores de grupo, usar el color base
	if not use_color_groups:
		background_rect.color = background_color
		return
		
	if pieces_group.size() > 1:
		# Si pertenece a un grupo, asignar un color basado en el group_id
		var color_index = abs(group_id) % group_colors.size()
		background_rect.color = group_colors[color_index]
	else:
		# Si es una pieza suelta, usar el color personalizado
		background_rect.color = single_piece_color

func flip_piece():
	flipped = !flipped
	update_visual()
	
	# Reproducir efecto de sonido de flip
	if get_parent().has_method("play_flip_sound"):
		get_parent().play_flip_sound()

# Función para establecer si la pieza está en la posición correcta
func set_correct_position(correct: bool):
	is_correct_position = correct
	update_visual_effects()

# Función para establecer el identificador del grupo
func set_group_id(id: int):
	group_id = id
	# También actualizamos el color del fondo siempre (independientemente de si está volteado)
	update_background_color()
	update_visual_effects()

# Función para establecer si es una pieza de borde en un grupo
func set_edge_piece(is_edge: bool):
	is_edge_piece = is_edge
	# Ya no necesitamos actualizar bordes, pero mantenemos la función por compatibilidad

# Sobreescribir _process para asegurar que los efectos se mantienen actualizados
func _process(_delta):
	# Verificar que los efectos visuales son correctos si la pieza está volteada
	if flipped and is_instance_valid(background_rect):
		update_background_color()

# Función para actualizar el grupo de piezas
func update_pieces_group(new_group: Array):
	pieces_group = new_group
	update_visual_effects()
	# Actualizar el color del fondo si la pieza está volteada
	if flipped:
		update_background_color()

# Método para manejar los eventos de entrada en el área de colisión
func _input_event(_viewport, event, _shape_idx):
	# Asegurarse que el evento sea de tipo InputEvent
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		# Delegar el manejo de eventos al nodo padre (PuzzleGame)
		if get_parent().has_method("process_piece_click"):
			get_parent().process_piece_click(event)

# Función para actualizar el z-index cuando se arrastra o se suelta la pieza
func set_dragging(is_dragging: bool):
	dragging = is_dragging
	if is_dragging:
		z_index = 2000  # Poner la pieza al frente con z-index de 2000
		
		# Actualizar z-index del fondo y número si la pieza está volteada
		if flipped:
			if is_instance_valid(background_rect):
				background_rect.z_index = 2010  # Por encima de la pieza
			if is_instance_valid(number_label):
				number_label.z_index = 2011  # Por encima del fondo
		
		# Aplicar efecto visual de "levantado" cuando se arrastra
		if enable_visual_effects:
			sprite.modulate = Color(dragging_brightness, dragging_brightness, dragging_brightness, 1.0)  # Más brillante cuando se arrastra
	else:
		z_index = 0  # Valor normal cuando no se arrastra
		
		# Restaurar z-index normal del fondo y número
		if flipped:
			if is_instance_valid(background_rect):
				background_rect.z_index = 10
			if is_instance_valid(number_label):
				number_label.z_index = 11
		
		# Restaurar efectos visuales normales
		update_visual_effects()
	
	# Actualizar visualmente
	if is_instance_valid(sprite):
		sprite.z_index = z_index

# Método para actualizar toda la visualización de la pieza (incluido efectos visuales)
func update_all_visuals():
	update_visual()
	update_background_color()
	update_visual_effects()
	
	# Asegurar que los z-index son correctos
	if flipped:
		if is_instance_valid(background_rect):
			background_rect.z_index = 10
		if is_instance_valid(number_label):
			number_label.z_index = 11
	
	# Actualizar si está en modo de arrastre
	if dragging:
		set_dragging(true)

# Funciones de compatibilidad (para mantener la API existente)
func create_border():
	# Ya no creamos bordes, pero mantenemos la función por compatibilidad
	pass

func update_border():
	# Ya no actualizamos bordes, pero mantenemos la función por compatibilidad
	pass

func update_border_color():
	# Ya no actualizamos colores de borde, pero mantenemos la función por compatibilidad
	pass
