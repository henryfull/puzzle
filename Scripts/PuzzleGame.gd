# PuzzleGame.gd
# Script completo en una sola escena de tipo Node2D

extends Node2D
class_name PuzzleGame

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")

# Variable para rastrear si una pieza fue colocada
var just_placed_piece: bool = false

# Referencias a nodos de audio preexistentes en la escena
@onready var audio_move: AudioStreamPlayer = $AudioMove
@onready var audio_merge: AudioStreamPlayer = $AudioMerge
@onready var audio_flip: AudioStreamPlayer = $AudioFlip

# Referencia al timer de verificación de victoria
@onready var victory_timer: Timer = $VictoryTimer

# Referencia al contenedor de piezas
@export var pieces_container: Node2D
@export var UILayer: CanvasLayer
@export var movesLabel: Label
@export var maxMovesLabel: Label
@export var maxMovesFlipLabel: Label
@export var maxFlipsPanel: Panel
@export var maxFlipsLabel: Label

var confirm_dialog_scene = preload("res://Scenes/ConfirmExitDialog.tscn")

# Variables para gestionar el doble toque
var last_touch_time: float = 0.0
var double_tap_threshold: float = 0.3  # Tiempo en segundos para considerar un doble tap
var last_touch_position: Vector2 = Vector2.ZERO
var double_tap_distance_threshold: float = 50.0  # Distancia máxima para considerar un doble tap

# Variables para el sistema de pausa
var is_paused: bool = false  # Estado actual de pausa
var is_flip: bool = false # Estado actual del flip
var pause_start_time: float = 0.0  # Momento en que se pausó el juego
var accumulated_time: float = 0.0  # Tiempo acumulado en pausa
var is_options_menu_open: bool = false  # Estado del menú de opciones
var ungrouped_pieces: int = GLOBAL.columns * GLOBAL.rows  # Número de piezas sin agrupar

#
# === PROPIEDADES EXPORTADAS (modificables en el Inspector) ===
#
@export var image_path: String = "res://Assets/Images/arte1.jpg"
@export var panelPaused: Panel 

@export var max_scale_percentage: float = 0.9  # Aumentado para aprovechar más espacio
@export var viewport_scene_path: String = "res://Scenes/TextViewport.tscn"
@export var max_extra_rows: int = 5  # Máximo número de filas adicionales que se pueden añadir

# Parámetros de control del tablero
@export_range(0.1, 2.0, 0.1) var pan_sensitivity: float = 1.0  # Sensibilidad del desplazamiento

# Parámetros para efectos de animación
@export_range(0.1, 1.0, 0.05) var tween_duration: float = 0.3  # Duración de la animación Tween
@export var use_tween_effect: bool = true  # Activar/desactivar el efecto
@export_range(0.05, 0.5, 0.05) var flip_speed: float = 0.01  # Velocidad de la animación de flip

# Referencias a mensajes de éxito/error que deberían estar en la escena
@onready var success_message_label: Label = $UILayer/SuccessMessage
@onready var error_message_label: Label = $UILayer/ErrorMessage

# Variables para el paneo del tablero (simplificadas)
var is_panning := false
var last_pan_position := Vector2.ZERO
var board_offset := Vector2.ZERO  # Desplazamiento actual del tablero
var touch_points := {}  # Para rastrear múltiples puntos de contacto en táctil

var default_rows : int = 0
var default_columns : int = 0

#
# === VARIABLES INTERNAS ===
#
var puzzle_texture: Texture2D
var puzzle_width: float
var puzzle_height: float
var cell_size: Vector2
var puzzle_offset: Vector2
var original_rows: int  # Para guardar el número original de filas
var extra_rows_added: int = 0  # Contador de filas adicionales añadidas
var is_mobile: bool = false  # Para detectar si estamos en un dispositivo móvil

# Diccionario para saber qué pieza está en cada celda
# Clave: "col_fila" (String), Valor: referencia a la pieza
var grid := {}

# Array para almacenar todas las piezas creadas (por si se quiere iterar)
var pieces := []

# Para contar movimientos o verificar victoria
var total_moves: int = 0

# === VARIABLES PARA MODOS DE JUEGO ===
var relax_mode: bool = false
var normal_mode: bool = false
var timer_mode: bool = false
var challenge_mode: bool = false

# Límites y contadores para modos especiales
var flip_count: int = 0
var flip_move_count: int = 0
var max_flips: int = 0
var max_flip_moves: int = 0
var max_moves: int = 0
var time_left: float = 0.0
var defeat_reason: String = ""
var timer_countdown: Timer = null

# === VARIABLES PARA GESTIÓN DE PROGRESIÓN ===
var current_pack_id: String = ""
var current_puzzle_id: String = ""

# Variables para la pantalla de victoria
var victory_image_view: Control
var victory_text_view: Control
var victory_toggle_button: Button

# Referencias a botones en la UI
@export var button_options: Button
@export var flip_button: Button

# Nueva variable para controlar el estado de las piezas
var pieces_flipped: bool = false

# Variables para registro de estadísticas
var start_time: float = 0.0  # Tiempo de inicio en segundos
var elapsed_time: float = 0.0  # Tiempo transcurrido en segundos
var is_timer_active: bool = false  # Para controlar si el temporizador está activo

# Nueva variable para controlar si el puzzle ya ha sido completado
var puzzle_completed = false

#
# === SUBCLASE: Piece ===
# Representa cada pieza del puzzle como un Node2D con Sprite2D integrado.
#
class Piece:
	var node: Node2D
	var sprite: Sprite2D
	var original_pos: Vector2
	var current_cell: Vector2
	var dragging := false
	var drag_offset := Vector2.ZERO
	var drag_start_cell := Vector2.ZERO  # Celda desde donde comenzó el arrastre
	var group := []  # Lista de piezas en el mismo grupo
	var order_number: int  # Número de orden de la pieza

	func _init(_node: Node2D, _sprite: Sprite2D, _orig: Vector2, _order: int):
		node = _node
		sprite = _sprite
		original_pos = _orig
		current_cell = _orig
		drag_start_cell = _orig  # Inicialmente, la celda de inicio es la misma que la original
		order_number = _order
		group = [self]  # Inicialmente, cada pieza está en su propio grupo

#
# === FUNCIÓN _ready(): se llama al iniciar la escena ===
#
func _ready():
	print("PuzzleGame: Iniciando juego...")
	default_rows = GLOBAL.rows
	default_columns = GLOBAL.columns
	
	# Asegurarnos que el panel de pausa esté oculto al inicio
	if panelPaused:
		panelPaused.visible = false
	
	# Inicializar el botón de flip
	if flip_button:
		flip_button.rotation_degrees = 0
	
	# Inicializar las etiquetas de mensaje (limpiarlas)
	if success_message_label:
		success_message_label.text = ""
	
	# Reiniciar el estado de completado
	puzzle_completed = false
	
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Cargar preferencias del usuario
	load_user_preferences()
	
	# Conectar la señal "options_closed" del OptionsManager para reanudar el juego
	if has_node("/root/OptionsManager"):
		var options_manager = get_node("/root/OptionsManager")
		if !options_manager.is_connected("options_closed", Callable(self, "_on_options_closed")):
			options_manager.connect("options_closed", Callable(self, "_on_options_closed"))
	

	# Configurar el puzzle según los datos seleccionados
	if GLOBAL.selected_puzzle != null:
		image_path = GLOBAL.selected_puzzle.image
		
		# Guardar los IDs para la progresión
		if GLOBAL.selected_pack != null:
			current_pack_id = GLOBAL.selected_pack.id
		
		if GLOBAL.selected_puzzle != null:
			current_puzzle_id = GLOBAL.selected_puzzle.id
	
	# Ocultar los mensajes al inicio
	if success_message_label:
		success_message_label.visible = false
	if error_message_label:
		error_message_label.visible = false
	
	# Crear o verificar el contenedor de piezas
	if not pieces_container:
		pieces_container = Node2D.new()
		pieces_container.name = "PiecesContainer"
		pieces_container.z_index = 5  # Asegurar que el z-index sea 5
		add_child(pieces_container)
		print("Creado contenedor de piezas dinámicamente")
	else:
		print("Usando contenedor de piezas existente:", pieces_container.name)
		# Asegurar que el z-index sea el correcto
		pieces_container.z_index = 5
	
	# Guardar el número original de filas
	original_rows = GLOBAL.rows

	# Primero, obtenemos la textura trasera usando la escena del Viewport y esperando un frame
	var puzzle_back = await generate_back_texture_from_viewport(viewport_scene_path)
	# Luego cargamos y creamos las piezas con la parte frontal normal
	load_and_create_pieces(puzzle_back)
	


	# Iniciar el temporizador para medir el tiempo de juego
	start_game_timer()

	# --- Lógica de modos de juego ---
	match GLOBAL.gamemode:
		0:
			relax_mode = true
			# Ocultar contadores y reloj
			if has_node("UILayer/TimerLabel"):
				$UILayer/TimerLabel.visible = false
				movesLabel.visible = false
				maxMovesLabel.visible = false
				maxMovesFlipLabel.visible = false
				maxFlipsPanel.visible = false
		1:
			relax_mode = true
			# Ocultar contadores y reloj
			if has_node("UILayer/TimerLabel"):
				$UILayer/TimerLabel.visible = false
				movesLabel.visible = false
				maxMovesLabel.visible = false
				maxMovesFlipLabel.visible = false
				maxFlipsPanel.visible = false

		2:
			normal_mode = true
			# Mostrar contadores normales
			if has_node("UILayer/TimerLabel"):
				$UILayer/TimerLabel.visible = true
				movesLabel.visible = true
				maxMovesLabel.visible = false
				maxMovesFlipLabel.visible = false
				maxFlipsPanel.visible = false

			# Si hay otros contadores, mostrar aquí
		3:
			timer_mode = true
			# Definir tiempo límite (ejemplo: 180 segundos)
			time_left = 180.0
			max_flip_moves = 10 # ejemplo, puedes ajustar
			max_flips = 5
			flip_move_count = 0
			
			# Mostrar reloj en cuenta atrás
			if has_node("UILayer/TimerLabel"):
				$UILayer/TimerLabel.visible = true
				movesLabel.visible = true
				maxMovesLabel.visible = false
				maxMovesFlipLabel.visible = true
				maxMovesFlipLabel.text = str(max_flip_moves)
				maxFlipsPanel.visible = true
				maxFlipsLabel.text = str(max_flips)
			# Crear un timer para cuenta atrás
			timer_countdown = Timer.new()
			timer_countdown.wait_time = 1.0
			timer_countdown.one_shot = false
			timer_countdown.connect("timeout", Callable(self, "_on_timer_countdown"))
			add_child(timer_countdown)
			timer_countdown.start()
		4:
			challenge_mode = true
			max_moves = 50 # ejemplo, puedes ajustar
			max_flips = 3 # ejemplo
			flip_move_count = 0
			max_flip_moves = 10 # ejemplo
			maxMovesLabel.text = str(max_moves)
			maxMovesFlipLabel.text = str(max_flip_moves)
			maxFlipsLabel.text = str(max_flips)
			# Mostrar contadores
			if has_node("UILayer/TimerLabel"):
				$UILayer/TimerLabel.visible = true
				movesLabel.visible = false
				maxMovesLabel.visible = true
				maxMovesFlipLabel.visible = true
				maxMovesFlipLabel.text = str(flip_move_count)
				maxFlipsPanel.visible = true

			# Si hay otros contadores, mostrar aquí


func generate_back_texture_from_viewport(viewport_scene_path: String) -> Texture2D:
	# 1) Cargar la escena del viewport
	var vp_scene = load(viewport_scene_path)
	if not vp_scene:
		push_warning("No se pudo cargar la escena de Viewport: %s" % viewport_scene_path)
		return null

	# 2) Instanciarla y añadirla temporalmente; el nodo raíz debe ser de tipo Viewport
	var vp_instance = vp_scene.instantiate() as SubViewport
	add_child(vp_instance)

	# Asignar la descripción al Label del TextViewport usando GLOBAL.selected_puzzle
	if GLOBAL.selected_puzzle != null:
		var puzzle_data = GLOBAL.selected_puzzle
		var label = vp_instance.get_node("Label")
		if label:
			# Ajustar el tamaño de la fuente según el dispositivo
			if is_mobile:
				label.add_theme_font_size_override("font_size", 24)
			
			label.text = puzzle_data.description
			# Centrar el texto
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	await get_tree().process_frame # Esperar un frame para que el viewport se inicialice

	# 3) Esperar un frame para que Godot dibuje el texto en el Viewport
	await get_tree().process_frame

	# 4) Asegurarnos de que el viewport tenga una textura válida
	var viewport_texture = vp_instance.get_texture()
	if not viewport_texture:
		push_warning("No se pudo obtener la textura del viewport")
		vp_instance.queue_free()
		return null
		
	var vp_image: Image = viewport_texture.get_image()
	var back_texture = ImageTexture.create_from_image(vp_image)

	# 5) Quitar el viewport de la escena (ya no lo necesitamos)
	vp_instance.queue_free()

	return back_texture

#
# === CARGA DE IMAGEN Y CREACIÓN DE PIEZAS ===
#
func load_and_create_pieces(puzzle_back: Texture2D):
	# 1) Cargar la textura
	puzzle_texture = load(image_path) if load(image_path) else null
	if puzzle_texture == null:
		push_warning("No se pudo cargar la imagen en: %s" % image_path)
		return

	# 2) Calcular escalado
	var viewport_size = get_viewport_rect().size
	var original_w = float(puzzle_texture.get_width())
	var original_h = float(puzzle_texture.get_height())

	# Ajustar el factor de escala según el dispositivo
	var device_scale_factor = 1.0
	if is_mobile:
		# En dispositivos móviles, usar un porcentaje mayor del espacio disponible
		device_scale_factor = 0.95
	else:
		device_scale_factor = max_scale_percentage
	
	# Factor para no exceder el porcentaje máximo de la pantalla
	var scale_factor_w = (viewport_size.x * device_scale_factor) / original_w
	var scale_factor_h = (viewport_size.y * device_scale_factor) / original_h
	var final_scale_factor = min(scale_factor_w, scale_factor_h, 1.0)

	puzzle_width = original_w * final_scale_factor
	puzzle_height = original_h * final_scale_factor

	# 3) Definir el tamaño de cada celda
	cell_size = Vector2(puzzle_width / GLOBAL.columns, puzzle_height / GLOBAL.rows)

	# 4) Calcular offset para centrar el puzzle
	puzzle_offset = (viewport_size - Vector2(puzzle_width, puzzle_height)) * 0.5

	# 5) Generar la lista de celdas y "desordenarlas" (solo columnas por fila)
	grid.clear()
	pieces.clear()
	var cell_list: Array[Vector2] = []
	for r in range(GLOBAL.rows):
		for c in range(GLOBAL.columns):
			cell_list.append(Vector2(c, r))

	# Desordenar completamente el cell_list
	cell_list.shuffle()

	# 6) Crear cada pieza (rows x columns)
	var piece_scene = load("res://Scenes/Components/PuzzlePiece/PuzzlePiece.tscn")
	if piece_scene == null:
		push_warning("No se pudo cargar PuzzlePiece.tscn")
		return
	
	var index = 0
	for row_i in range(GLOBAL.rows):
		for col_i in range(GLOBAL.columns):
			# Instanciar PuzzlePiece.tscn
			var piece_node = piece_scene.instantiate()
			pieces_container.add_child(piece_node)  # Añadir al contenedor en lugar de al nodo raíz
			
			# Asegurar que las piezas se muestren por encima del fondo
			piece_node.z_index = 5
			
			# Definir la región original (SIN escalado) para la parte de la textura
			var piece_orig_w = original_w / GLOBAL.columns
			var piece_orig_h = original_h / GLOBAL.rows
			var region_rect = Rect2(
				col_i * piece_orig_w,
				row_i * piece_orig_h,
				piece_orig_w,
				piece_orig_h
			)
			
			# Configurar la pieza con la textura frontal y la trasera (puzzle_back)
			piece_node.set_piece_data(puzzle_texture, puzzle_back, region_rect)
			
			# Calcular y aplicar la escala para que la pieza se ajuste a la celda
			var scale_x = cell_size.x / piece_orig_w
			var scale_y = cell_size.y / piece_orig_h
			piece_node.get_node("Sprite2D").scale = Vector2(scale_x, scale_y)
			
			# Centrar el sprite en su nodo padre
			piece_node.get_node("Sprite2D").position = cell_size * 0.5
			
			# Crear la instancia de la clase "Piece" para el manejo de grid
			var piece_obj = Piece.new(piece_node, piece_node.get_node("Sprite2D"), Vector2(col_i, row_i), index + 1)
			pieces.append(piece_obj)
			
			# Asignar el número de orden a la pieza
			if piece_node.has_method("set_order_number"):
				piece_node.set_order_number(index + 1)
			
			# Posición inicial: la celda "desordenada"
			var random_cell = cell_list[index]
			index += 1
			
			# Ubicar la pieza en pantalla
			var piece_pos = puzzle_offset + random_cell * cell_size
			piece_node.position = piece_pos
			
			# Registrar en grid
			set_piece_at(random_cell, piece_obj)
			
			# Actualizar el estado inicial de la pieza
			update_piece_position_state(piece_obj)
			
			# Cada pieza comienza como pieza de borde en su propio grupo
			if piece_node.has_method("set_edge_piece"):
				piece_node.set_edge_piece(true)
	
	# Inicializar el contador de grupos: al inicio, cada pieza es su propio grupo
	ungrouped_pieces = pieces.size()
	if OS.is_debug_build():
		print("Puzzle inicializado con ", ungrouped_pieces, " grupos individuales")
	
	# Activar la captura de eventos de mouse a nivel global
	# (Podrías usar _input() o unhandled_input(), en este ejemplo iremos con _unhandled_input)
	set_process_unhandled_input(true)
	check_all_groups()

#
# === GESTIÓN DE EVENTOS DE RATÓN / TECLADO ===
#
func _unhandled_input(event: InputEvent) -> void:
	# Manejo de eventos táctiles para dispositivos móviles
	if event is InputEventScreenTouch:
		# Detectar doble toque
		if event.pressed:
			var current_time = Time.get_ticks_msec() / 1000.0
			var time_diff = current_time - last_touch_time
			var position_diff = event.position.distance_to(last_touch_position)
			
			# Si el tiempo entre toques es menor al umbral y la distancia es pequeña, es un doble tap
			if time_diff < double_tap_threshold and position_diff < double_tap_distance_threshold:
				# Es un doble tap, reorganizar las piezas
				reorganize_pieces()
				# Reiniciar el tiempo del último toque
				last_touch_time = 0.0
			else:
				# Guardar el tiempo y posición del toque actual para el próximo
				last_touch_time = current_time
				last_touch_position = event.position
		
		# Guardamos la información del toque en nuestro diccionario
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
			
		# Para paneo en dispositivos móviles necesitamos DOS dedos
		if is_mobile:
			if touch_points.size() >= 2 and event.pressed:
				# Iniciar paneo con dos dedos
				is_panning = true
				# Usamos el punto medio entre los dos dedos como punto de referencia
				last_pan_position = get_touch_center()
			elif touch_points.size() < 2:
				# Si hay menos de dos dedos, terminar el paneo
				is_panning = false
		
		# Si es un solo dedo, procesamos como un evento normal de clic de pieza
		if touch_points.size() == 1 and is_mobile:
			if event.pressed:
				# Debemos pasar la posición específica del evento de toque, no el evento genérico
				process_piece_click_touch(event.position, event.index)
			else:
				process_piece_release()
	
	elif event is InputEventScreenDrag:
		# Actualizar la posición del punto de contacto
		touch_points[event.index] = event.position
		
		# Para paneo en dispositivos móviles necesitamos DOS dedos
		if is_mobile and touch_points.size() >= 2 and is_panning:
			# En lugar de usar el centro de los dedos, usamos directamente la posición del dedo 
			# que se está moviendo, lo que da un control más directo
			var current_pos = event.position
			var prev_pos = current_pos - event.relative
			
			# El delta es exactamente el movimiento real del dedo
			var delta = event.relative
			
			# Aplicamos directamente el delta del movimiento del dedo, manteniendo
			# la misma dirección que el gesto del usuario, pero ajustando por la sensibilidad
			board_offset += delta * pan_sensitivity
			
			last_pan_position = current_pos
			update_board_position()
		
		# Si estamos arrastrando con un solo dedo y no estamos en modo paneo, movernos piezas
		elif is_mobile and touch_points.size() == 1 and not is_panning:
			# Procesar como arrastre de pieza
			for piece_obj in pieces:
				if piece_obj.dragging:
					var group_leader = get_group_leader(piece_obj)
					
					# En lugar de usar event.relative, calculamos la nueva posición basada
					# en la posición actual del dedo y el offset guardado al comenzar el arrastre
					var touch_pos = event.position
					
					for p in group_leader.group:
						# Aplicar la nueva posición con el offset original
						p.node.global_position = touch_pos + p.drag_offset
						
						# Asegurar que la pieza tenga el z-index adecuado 
						# mientras se está arrastrando
						if p.node.has_method("set_dragging"):
							p.node.set_dragging(true)
						
						# Si la pieza tiene padre, asegurarse de que esté al frente
						if p.node.get_parent() != null:
							p.node.get_parent().move_child(p.node, p.node.get_parent().get_child_count() - 1)
					
					break
	
	# Manejo de eventos de ratón para PC
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:  # Botón derecho para paneo en PC
			if event.pressed:
				# Iniciar paneo con botón derecho
				is_panning = true
				last_pan_position = event.position
			else:
				# Finalizar paneo
				is_panning = false
		
		# Manejo de doble clic para reorganizar piezas
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			reorganize_pieces()
		
		# Manejo de click izquierdo para las piezas
		elif event.button_index == MOUSE_BUTTON_LEFT:
			process_piece_click(event)
	
	elif event is InputEventMouseMotion:
		if is_panning:
			# Actualizar posición del tablero durante el paneo
			var delta = event.relative
			# Aplicar la sensibilidad al desplazamiento
			board_offset += delta * pan_sensitivity
			last_pan_position = event.position
			update_board_position()
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# Si estamos arrastrando una pieza
			for piece_obj in pieces:
				if piece_obj.dragging:
					var group_leader = get_group_leader(piece_obj)
					var delta = event.relative
					for p in group_leader.group:
						p.node.global_position += delta
						
						# Asegurar que la pieza tenga el z-index adecuado 
						# mientras se está arrastrando
						if p.node.has_method("set_dragging"):
							p.node.set_dragging(true)
							
						# Asegurar que la pieza esté al frente moviendo su nodo al final del árbol
						if p.node.get_parent() != null:
							p.node.get_parent().move_child(p.node, p.node.get_parent().get_child_count() - 1)
					break

func update_board_position() -> void:
	# Actualizar la posición del contenedor de piezas según el desplazamiento del tablero
	if pieces_container:
		pieces_container.position = board_offset
	else:
		position = board_offset
	
	# Limitar el desplazamiento para que el tablero no se aleje demasiado
	var viewport_size = get_viewport_rect().size
	var board_size = Vector2(puzzle_width, puzzle_height)
	
	# Calcular límites de desplazamiento
	# Permitimos desplazar el tablero dentro de límites razonables,
	# pero siempre asegurándose de que parte del tablero sea visible
	var margin = 100.0  # Margen de píxeles para que siempre quede algo visible
	var min_x = min(-board_size.x + margin, -board_size.x * 0.75)
	var max_x = max(viewport_size.x - margin, viewport_size.x - board_size.x * 0.25)
	var min_y = min(-board_size.y + margin, -board_size.y * 0.75)
	var max_y = max(viewport_size.y - margin, viewport_size.y - board_size.y * 0.25)
	
	# Limitar el desplazamiento
	if pieces_container:
		pieces_container.position.x = clamp(pieces_container.position.x, min_x, max_x)
		pieces_container.position.y = clamp(pieces_container.position.y, min_y, max_y)
	else:
		position.x = clamp(position.x, min_x, max_x)
		position.y = clamp(position.y, min_y, max_y)
	
	# Actualizar el board_offset para reflejar la posición ajustada
	board_offset = pieces_container.position if pieces_container else position

#
# === DETECCIÓN DE CLIC SOBRE LA PIEZA ===
#
func is_mouse_over_piece(piece_obj: Piece, mouse_pos: Vector2) -> bool:
	# Verificaciones de seguridad
	if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node) or not is_instance_valid(piece_obj.sprite):
		return false
		
	var sprite = piece_obj.sprite
	if sprite.texture == null:
		return false

	# Convertir mouse_pos a espacio local de la pieza
	var local_pos = piece_obj.node.to_local(mouse_pos)
	
	# Para diagnóstico
	if OS.is_debug_build() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		print("Mouse pos: ", mouse_pos)
		print("Local pos en pieza: ", local_pos)
		print("Sprite pos: ", sprite.position)
		print("Sprite scale: ", sprite.scale)
		print("Texture size: ", sprite.texture.get_size())
	
	# Crear un rectángulo que represente el área del sprite
	var tex_rect = Rect2(
		sprite.position - sprite.texture.get_size() * sprite.scale * 0.5,
		sprite.texture.get_size() * sprite.scale
	)
	
	# Verificar si el punto local está dentro del rectángulo
	return tex_rect.has_point(local_pos)

#
# === COLOCAR LA PIEZA (SNAP A CELDA) ===
#
func place_piece(piece_obj: Piece):
	# Indicar que se acaba de colocar una pieza
	just_placed_piece = true
	
	# 1) Calcular la celda según la posición actual
	var cell = get_cell_of_piece(piece_obj)  # Usamos get_cell_of_piece que ya tiene en cuenta el desplazamiento
	
	# Clampeamos para que no se salga de la grid
	var cell_x = clamp(int(cell.x), 0, GLOBAL.columns - 1)
	var cell_y = clamp(int(cell.y), 0, GLOBAL.rows - 1)
	var new_cell = Vector2(cell_x, cell_y)

	# 2) Ver si hay otra pieza en esa celda
	var occupant = get_piece_at(new_cell)
	if occupant != null and occupant != piece_obj:
		# Verificar si pueden fusionarse
		if are_pieces_mergeable(piece_obj, occupant):
			merge_pieces(piece_obj, occupant)
			return
		else:
			# Verificar si la pieza está en un grupo con otras piezas
			if piece_obj.group.size() > 1:
				# Si está en un grupo, mantener el comportamiento actual
				# (no intercambiar, solo mover el grupo completo)
				# audio_move.play()
				show_error_message("No se puede intercambiar: la pieza está en un grupo")
				return
			
			# Si el ocupante está en un grupo con otras piezas, no intercambiar
			if occupant.group.size() > 1:
				# Generar un error para depuración
				push_warning("No se puede intercambiar con una pieza que está en un grupo")
				show_error_message("No se puede intercambiar: la pieza destino está en un grupo")
				return
			
			# Si ninguna está en un grupo, intercambiar las piezas
			swap_pieces(piece_obj, occupant)
			return

	# 3) Si no hay ocupante, simplemente colocar la pieza
	remove_piece_at(piece_obj.current_cell)
	set_piece_at(new_cell, piece_obj)
	
	# Calcular la posición física de la pieza teniendo en cuenta el desplazamiento del tablero
	var target_position = puzzle_offset + new_cell * cell_size
	
	# Actualizar el estado de la pieza (si está en la posición correcta o no)
	update_piece_position_state(piece_obj)
	
	# Aplicar efecto de Tween si está activado
	if use_tween_effect:
		apply_tween_effect(piece_obj.node, target_position)
	else:
		piece_obj.node.position = target_position

	# 4) Fusionar con piezas adyacentes, si es posible
	var adjacent = find_adjacent_pieces(piece_obj, new_cell)
	for adj in adjacent:
		if are_pieces_mergeable(piece_obj, adj):
			merge_pieces(piece_obj, adj)

# Función para aplicar el efecto de Tween
func apply_tween_effect(node: Node2D, target_position: Vector2):
	# Crear un nuevo Tween
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUINT)  # Transición suave
	
	# Animar la posición
	tween.tween_property(node, "position", target_position, tween_duration)
	
	# Opcionalmente, añadir un efecto de escala para dar sensación de "rebote"
	var original_scale = node.scale
	tween.parallel().tween_property(node, "scale", original_scale * 1.1, tween_duration * 0.5)
	tween.tween_property(node, "scale", original_scale, tween_duration * 0.5)

func find_adjacent_pieces(piece: Piece, cell: Vector2) -> Array:
	var adjacent = []
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	
	for dir in directions:
		var check_cell = cell + dir
		# Eliminar la restricción de límites del tablero - esto permitirá encontrar piezas
		# en cualquier posición, incluso fuera de los límites originales
		var other = get_piece_at(check_cell)
		if other != null and other != piece and not (other in piece.group):
			adjacent.append(other)
	
	return adjacent

func are_pieces_mergeable(piece1: Piece, piece2: Piece) -> bool:
	# Verificar si las piezas son adyacentes en su posición original
	var diff = piece2.original_pos - piece1.original_pos
	var are_adjacent = (abs(diff.x) == 1 and diff.y == 0) or (abs(diff.y) == 1 and diff.x == 0)
	
	# También verificar que sus posiciones actuales coincidan aproximadamente con la diferencia original
	if are_adjacent:
		var current_diff = piece2.current_cell - piece1.current_cell
		# Usar una comparación con un epsilon para mayor precisión
		var epsilon = 0.1
		return abs(current_diff.x - diff.x) < epsilon and abs(current_diff.y - diff.y) < epsilon
	return false

#
# === INTERCAMBIAR DOS PIEZAS ===
#
func swap_pieces(a: Piece, b: Piece):
	var cell_a = a.current_cell
	var cell_b = b.current_cell

	remove_piece_at(cell_a)
	remove_piece_at(cell_b)

	set_piece_at(cell_b, a)
	set_piece_at(cell_a, b)

	# Reposicionar con efecto Tween
	var target_pos_a = puzzle_offset + cell_b * cell_size
	var target_pos_b = puzzle_offset + cell_a * cell_size
	
	# Actualizar el estado de posición de ambas piezas
	update_piece_position_state(a)
	update_piece_position_state(b)
	
	if use_tween_effect:
		apply_tween_effect(a.node, target_pos_a)
		apply_tween_effect(b.node, target_pos_b)
	else:
		a.node.position = target_pos_a
		b.node.position = target_pos_b
	
	# Mostrar mensaje de éxito
	show_success_message("¡Piezas intercambiadas!")
	
	# Generar un error para depuración
	push_warning("Intercambiando pieza en " + str(cell_a) + " con pieza en " + str(cell_b))

#
# === GRID: GET/SET/REMOVE PIEZA EN CELDA ===
#
func cell_key(cell: Vector2) -> String:
	return "%d_%d" % [int(cell.x), int(cell.y)]

func set_piece_at(cell: Vector2, piece_obj: Piece):
	grid[cell_key(cell)] = piece_obj
	piece_obj.current_cell = cell

func get_piece_at(cell: Vector2) -> Piece:
	return grid.get(cell_key(cell), null)

func remove_piece_at(cell: Vector2):
	grid.erase(cell_key(cell))

#
# === OBTENER LA CELDA DE UNA PIEZA POR SU POSICIÓN ===
#
func get_cell_of_piece(piece_obj: Piece) -> Vector2:
	# Ajustar la posición de la pieza teniendo en cuenta el desplazamiento del tablero
	# Primero obtenemos la posición global de la pieza
	var global_pos = piece_obj.node.global_position
	
	# Para un mejor diagnóstico
	if OS.is_debug_build():
		print("Posición global de pieza: ", global_pos)
		print("Posición global del nodo: ", global_position)
		print("Posición del contenedor: ", pieces_container.global_position if pieces_container else Vector2.ZERO)
	
	# El posicionamiento ha cambiado ya que las piezas están dentro del contenedor
	var adjusted_pos
	if pieces_container:
		# Si estamos usando el contenedor, necesitamos tener en cuenta su posición global
		adjusted_pos = global_pos - pieces_container.global_position
	else:
		# Para compatibilidad con la versión anterior
		adjusted_pos = global_pos - global_position
	
	# Ahora calculamos la celda usando las coordenadas ajustadas
	var px = adjusted_pos.x - puzzle_offset.x
	var py = adjusted_pos.y - puzzle_offset.y
	var cx = int(round(px / cell_size.x))
	var cy = int(round(py / cell_size.y))
	
	return Vector2(cx, cy)

#
# === (OPCIONAL) LÓGICA DE FUSIÓN O VICTORIA ===
#
# Si quisieras fusionar piezas o verificar la victoria,
# podrías añadir funciones aquí que revisen celdas adyacentes
# y unan las piezas en un solo "grupo".
#

func merge_pieces(piece1: Piece, piece2: Piece):
	# Indicar que se ha colocado/fusionado una pieza
	just_placed_piece = true
	
	# Obtener tamaños de los grupos originales para contar correctamente
	var group1_size = piece1.group.size()
	var group2_size = piece2.group.size()
	
	# Combinar los grupos
	var new_group = []
	new_group.append_array(piece1.group)
	for p in piece2.group:
		if not (p in new_group):
			new_group.append(p)
	
	# Generar un ID de grupo único (usamos el ID de la primera pieza)
	var group_id = piece1.node.get_instance_id()
	
	# Actualizar el grupo en todas las piezas
	for p in new_group:
		p.group = new_group
		# Asegurar que la posición es correcta
		var offset = p.original_pos - piece1.original_pos
		var target_cell = piece1.current_cell + offset
		
		# Asegurarse de que la celda está dentro de los límites
		target_cell.x = clamp(target_cell.x, 0, GLOBAL.columns - 1)
		if target_cell.y >= GLOBAL.rows:
			if not add_extra_row():
				target_cell.y = GLOBAL.rows - 1
		
		# Actualizar la posición de la pieza
		remove_piece_at(p.current_cell)
		set_piece_at(target_cell, p)
		
		# Calcular posición objetivo y aplicar Tween
		var target_position = puzzle_offset + target_cell * cell_size
		
		# Actualizar el estado de la pieza (si está en la posición correcta o no)
		update_piece_position_state(p)
		
		# Actualizar el ID de grupo de la pieza
		if p.node.has_method("set_group_id"):
			p.node.set_group_id(group_id)
		
		# Actualizar el pieces_group en el nodo de la pieza
		if p.node.has_method("update_pieces_group"):
			p.node.pieces_group = new_group
		
		if use_tween_effect:
			apply_tween_effect(p.node, target_position)
		else:
			p.node.position = target_position
	
	# Identificar las piezas de borde en el grupo
	update_edge_pieces_in_group(new_group)
	
	# Reproducir sonido de fusión (usando directamente el reproductor de audio)
	audio_merge.play()
	
	# Activar la animación de partículas solo en la pieza que se está moviendo
	if piece1.node.has_node("CPUParticles2D"):
		var particles = piece1.node.get_node("CPUParticles2D")
		
		# Ajustar la posición de las partículas al centro de la pieza
		if piece1.node.has_node("Sprite2D"):
			var sprite = piece1.node.get_node("Sprite2D")
			particles.position = sprite.position
		
		particles.emitting = true
	
	# Decrementar ungrouped_pieces: cuando se juntan dos grupos, se reduce en 1 el número total de grupos
	# Estábamos contando grupos individuales, ahora se han convertido en uno solo
	ungrouped_pieces -= 1
	
	if OS.is_debug_build():
		print("Se ha unido un grupo de " + str(group1_size) + " piezas con otro de " + str(group2_size) + " piezas")
		print("Grupos restantes: " + str(ungrouped_pieces))
	
	# Verificar si solo queda un grupo (victoria)
	if ungrouped_pieces <= 1:
		# Verificar que realmente todas las piezas están en un solo grupo
		var all_pieces_in_one_group = false
		for p in pieces:
			if p.group.size() == pieces.size():
				all_pieces_in_one_group = true
				break
				
		if all_pieces_in_one_group:
			print("¡Victoria por agrupación completa de piezas!")
			call_deferred("_on_puzzle_completed")
		else:
			# Recalcular la cantidad real de grupos
			count_unique_groups()

# Función para añadir una fila adicional al tablero
func add_extra_row():
	if extra_rows_added >= max_extra_rows:
		return false  # No se pueden añadir más filas
	
	GLOBAL.rows += 1
	extra_rows_added += 1
	
	# En lugar de recalcular el tamaño de las celdas, aumentamos el tamaño total del puzzle
	var viewport_size = get_viewport_rect().size
	puzzle_height = cell_size.y * GLOBAL.rows  # Mantenemos el tamaño de celda original
	
	# Recalcular el offset para centrar el puzzle con su nuevo tamaño
	puzzle_offset = (viewport_size - Vector2(puzzle_width, puzzle_height)) * 0.5
	
	# Actualizar la posición de todas las piezas para reflejar el nuevo offset
	for piece_obj in pieces:
		piece_obj.node.position = puzzle_offset + piece_obj.current_cell * cell_size
		# Ya no modificamos la escala de las piezas
	
	return true

# Función para verificar si hay espacio suficiente para un grupo
func check_space_for_group(leader: Piece, target_cell: Vector2) -> bool:
	for p in leader.group:
		var offset = p.original_pos - leader.original_pos
		var p_target = target_cell + offset
		
		# Si la celda está fuera de los límites horizontales, no hay espacio
		if p_target.x < 0 or p_target.x >= GLOBAL.columns:
			return false
			
		# Si la celda está fuera de los límites verticales, verificamos si podemos añadir filas
		if p_target.y >= GLOBAL.rows:
			# Si ya hemos alcanzado el máximo de filas adicionales, no hay espacio
			if extra_rows_added >= max_extra_rows:
				return false
			# Si no, consideramos que podemos añadir filas
	
	return true

# Función para encontrar una posición válida para un grupo
func find_valid_position_for_group(leader: Piece) -> Vector2:
	# Primero intentamos con la posición actual
	var current_pos = get_cell_of_piece(leader)
	
	# Si la posición actual es válida, la usamos
	if check_space_for_group(leader, current_pos):
		return current_pos
	
	# Si no, buscamos una posición válida en todo el tablero
	for r in range(GLOBAL.rows):
		for c in range(GLOBAL.columns):
			var test_pos = Vector2(c, r)
			if check_space_for_group(leader, test_pos):
				return test_pos
	
	# Si no encontramos una posición válida, intentamos añadir una fila
	if add_extra_row():
		# Buscar en la nueva fila
		for c in range(GLOBAL.columns):
			var test_pos = Vector2(c, GLOBAL.rows - 1)
			if check_space_for_group(leader, test_pos):
				return test_pos
		
		# Si aún no encontramos, buscamos recursivamente
		return find_valid_position_for_group(leader)
	
	# Si no podemos añadir más filas, usamos la posición actual y dejamos que el sistema
	# maneje las colisiones lo mejor que pueda
	return current_pos

# Función para mover todas las piezas que colisionan con un grupo
func move_colliding_pieces(leader: Piece, target_cell: Vector2) -> void:
	var occupied_cells = []
	var group_cells = []
	var occupants = []
	
	# Recopilar todas las celdas que ocupará el grupo
	for p in leader.group:
		var offset = p.original_pos - leader.original_pos
		var p_target = target_cell + offset
		
		# Asegurarse de que la celda está dentro de los límites horizontales
		p_target.x = clamp(p_target.x, 0, GLOBAL.columns - 1)
		
		# Para los límites verticales, verificamos si necesitamos añadir filas
		if p_target.y >= GLOBAL.rows:
			if not add_extra_row():
				p_target.y = GLOBAL.rows - 1  # Si no podemos añadir más filas, usamos la última
		
		group_cells.append(p_target)
	
	# Encontrar todas las piezas que colisionan con el grupo
	for p_target in group_cells:
		var occupant = get_piece_at(p_target)
		if occupant != null and not (occupant in leader.group):
			occupied_cells.append(p_target)
			if not (occupant in occupants):  # Evitar duplicados
				occupants.append(occupant)
	
	# Si hay colisiones, mover las piezas que colisionan
	if occupied_cells.size() > 0:
		# Verificar si todas las piezas ocupantes están solas (no en grupos)
		var all_occupants_single = true
		for occupant in occupants:
			if occupant.group.size() > 1:
				all_occupants_single = false
				break
		
		# Si todas las piezas ocupantes están solas y su número coincide con el tamaño del grupo,
		# podemos intercambiar las posiciones (pero esto se maneja en place_group)
		if all_occupants_single and occupants.size() == leader.group.size():
			# No hacemos nada aquí, el intercambio se maneja en place_group
			push_warning("Detectadas piezas individuales que podrían intercambiarse")
			return
		
		# Si no se pueden intercambiar, mover las piezas ocupantes a celdas libres
		# Primero, intentamos encontrar celdas libres para las piezas que colisionan
		var free_cells = find_free_cells(occupants.size())
		
		# Si no hay suficientes celdas libres, añadimos filas hasta encontrar suficientes
		while free_cells.size() < occupants.size():
			if not add_extra_row():
				break  # Si no podemos añadir más filas, usamos las celdas que tenemos
			
			# Buscar celdas libres en la nueva fila
			for c in range(GLOBAL.columns):
				var cell = Vector2(c, GLOBAL.rows - 1)
				if get_piece_at(cell) == null and not (cell in free_cells) and not (cell in group_cells):
					free_cells.append(cell)
					if free_cells.size() >= occupants.size():
						break
			
			if free_cells.size() >= occupants.size():
				break
		
		# Mover las piezas que colisionan a las celdas libres
		for i in range(min(occupants.size(), free_cells.size())):
			var occupant = occupants[i]
			if occupant != null:
				remove_piece_at(occupant.current_cell)
				set_piece_at(free_cells[i], occupant)
				occupant.node.position = puzzle_offset + free_cells[i] * cell_size

# Función para encontrar celdas libres
func find_free_cells(count: int) -> Array:
	var free_cells = []
	
	# Buscar celdas libres en todo el tablero
	for r in range(GLOBAL.rows):
		for c in range(GLOBAL.columns):
			var cell = Vector2(c, r)
			if get_piece_at(cell) == null:
				free_cells.append(cell)
				if free_cells.size() >= count:
					return free_cells
	
	return free_cells

func place_group(piece: Piece):
	# Indicar que se acaba de colocar una pieza o grupo
	just_placed_piece = true
	
	# Obtener el líder del grupo
	var leader = get_group_leader(piece)
	
	# Calcular la celda destino para la pieza principal (líder) usando get_cell_of_piece
	# que ya tiene en cuenta el desplazamiento del tablero
	var target_cell = get_cell_of_piece(leader)
	
	# Verificar si hay espacio para el grupo en la posición actual
	if not check_space_for_group(leader, target_cell):
		# Si no hay espacio, intentamos añadir filas si es necesario
		# Calculamos cuántas filas necesitamos para acomodar el grupo
		var max_y = 0
		for p in leader.group:
			var offset = p.original_pos - leader.original_pos
			var p_target_y = target_cell.y + offset.y
			max_y = max(max_y, p_target_y)
		
		# Si necesitamos más filas de las que tenemos, las añadimos
		while max_y >= GLOBAL.rows and add_extra_row():
			pass
		
		# Buscar una posición válida para el grupo
		target_cell = find_valid_position_for_group(leader)
	
	# Crear una copia del grupo para evitar modificaciones durante la iteración
	var group_copy = leader.group.duplicate()
	
	# Recopilar información sobre las piezas que colisionan con el grupo
	var occupied_cells = []
	var group_cells = []
	var occupants = []
	var occupant_groups = {}  # Mapa de grupos ocupantes: Clave = ID de grupo, Valor = lista de piezas
	
	# Recopilar todas las celdas que ocupará el grupo
	for p in group_copy:
		var offset = p.original_pos - leader.original_pos
		var p_target = target_cell + offset
		
		# Asegurarse de que la celda está dentro de los límites horizontales
		p_target.x = clamp(p_target.x, 0, GLOBAL.columns - 1)
		
		# Para los límites verticales, verificamos si necesitamos añadir filas
		if p_target.y >= GLOBAL.rows:
			if not add_extra_row():
				p_target.y = GLOBAL.rows - 1  # Si no podemos añadir más filas, usamos la última
		
		group_cells.append(p_target)
	
	# Encontrar todas las piezas que colisionan con el grupo
	for p_target in group_cells:
		var occupant = get_piece_at(p_target)
		if occupant != null and not (occupant in group_copy):
			occupied_cells.append(p_target)
			if not (occupant in occupants):  # Evitar duplicados
				occupants.append(occupant)
				
				# Verificar si esta pieza pertenece a un grupo
				if occupant.group.size() > 1:
					# Obtener el líder del grupo para identificarlo
					var occupant_leader = get_group_leader(occupant)
					var group_id = occupant_leader.node.get_instance_id()
					
					# Agregar al mapa de grupos ocupantes
					if not occupant_groups.has(group_id):
						occupant_groups[group_id] = []
					
					# Añadir todas las piezas del grupo si no están ya añadidas
					for occ_piece in occupant_leader.group:
						if not (occ_piece in occupant_groups[group_id]):
							occupant_groups[group_id].append(occ_piece)
	
	# Ahora verificamos si podemos intercambiar grupos o desplazar piezas
	if occupant_groups.size() > 0:
		# Caso especial: hay exactamente un grupo ocupante que ocupa exactamente las mismas celdas
		if occupant_groups.size() == 1 and occupants.size() == group_copy.size():
			var occupant_group_id = occupant_groups.keys()[0]
			var occupant_group = occupant_groups[occupant_group_id]
			
			# Si ambos grupos tienen el mismo tamaño, permitimos intercambiarlos
			if occupant_group.size() == group_copy.size():
				push_warning("Intercambiando grupos de igual tamaño")
				show_success_message("¡Intercambiando grupos!")
				
				# Guardar posiciones originales de ambos grupos
				var group_positions = {}
				var occupant_positions = {}
				
				for p in group_copy:
					group_positions[p] = p.current_cell
					remove_piece_at(p.current_cell)
				
				for p in occupant_group:
					occupant_positions[p] = p.current_cell
					remove_piece_at(p.current_cell)
				
				# Colocar grupo entrante en posiciones del grupo ocupante
				for p in group_copy:
					var offset = p.original_pos - leader.original_pos
					var occupant_leader = get_group_leader(occupant_group[0])
					var occupant_offset = occupant_group[0].original_pos - occupant_leader.original_pos
					
					# Calcular posición relativa en el grupo ocupante
					var index = -1
					for i in range(group_copy.size()):
						if group_copy[i] == p:
							index = i
							break
					
					if index >= 0 and index < occupant_group.size():
						var target_pos = occupant_positions[occupant_group[index]]
						set_piece_at(target_pos, p)
						var visual_pos = puzzle_offset + target_pos * cell_size
						if use_tween_effect:
							apply_tween_effect(p.node, visual_pos)
						else:
							p.node.position = visual_pos
				
				# Colocar grupo ocupante en posiciones del grupo entrante
				for p in occupant_group:
					var index = -1
					for i in range(occupant_group.size()):
						if occupant_group[i] == p:
							index = i
							break
					
					if index >= 0 and index < group_copy.size():
						var target_pos = group_positions[group_copy[index]]
						set_piece_at(target_pos, p)
						var visual_pos = puzzle_offset + target_pos * cell_size
						if use_tween_effect:
							apply_tween_effect(p.node, visual_pos)
						else:
							p.node.position = visual_pos
				
				# Reproducir sonido
				if audio_merge and not audio_merge.playing:
					audio_move.play()
				
				check_all_groups()
				verify_all_pieces_in_grid()
				return
			
			# Si el grupo entrante es más grande, desplazamos el grupo ocupante
			elif group_copy.size() > occupant_group.size():
				push_warning("Desplazando grupo más pequeño")
				show_success_message("¡Desplazando grupo más pequeño!")
				
				# Encontrar un espacio coherente para el grupo ocupante
				var avoid_cells = group_cells  # Evitar las celdas que ocupará nuestro grupo
				var target_cells = find_space_for_group(occupant_group, avoid_cells)
				
				# Si no hay suficiente espacio coherente para el grupo ocupante
				if target_cells.size() < occupant_group.size():
					push_warning("No hay suficiente espacio coherente para desplazar el grupo")
					show_error_message("No hay suficiente espacio para el grupo")
					
					# Devolver cada pieza del grupo a su posición original de inicio del arrastre
					for p in group_copy:
						var orig_cell = p.drag_start_cell
						
						# Comprobar que la celda original está disponible
						var current_occupant = get_piece_at(orig_cell)
						if current_occupant != null and current_occupant != p:
							# Si la posición original ya está ocupada, buscar una celda libre cercana
							var backup_free_cells = find_free_cells(1)
							if backup_free_cells.size() > 0:
								orig_cell = backup_free_cells[0]
						
						remove_piece_at(p.current_cell)
						set_piece_at(orig_cell, p)
						
						# Aplicar efecto Tween para mover la pieza a su posición original
						var target_position = puzzle_offset + orig_cell * cell_size
						if use_tween_effect:
							apply_tween_effect(p.node, target_position)
						else:
							p.node.position = target_position
					
					return
				
				# Quitar todas las piezas del grupo ocupante de sus posiciones actuales
				for p in occupant_group:
					remove_piece_at(p.current_cell)
				
				# Calcular la posición base del grupo ocupante (donde irá el líder)
				var occupant_leader = get_group_leader(occupant_group[0])
				
				# Colocar las piezas del grupo ocupante en las celdas coherentes
				for i in range(occupant_group.size()):
					var p = occupant_group[i]
					var offset = p.original_pos - occupant_leader.original_pos
					var leader_cell = target_cells[0]  # La celda para el líder
					var target_piece_position = leader_cell + offset
					
					# Asegurarnos de que la celda esté dentro de los límites
					target_piece_position.x = clamp(target_piece_position.x, 0, GLOBAL.columns - 1)
					if target_piece_position.y >= GLOBAL.rows:
						if not add_extra_row():
							target_piece_position.y = GLOBAL.rows - 1
					
					set_piece_at(target_piece_position, p)
					
					# Aplicar efecto Tween
					var target_position = puzzle_offset + target_piece_position * cell_size
					if use_tween_effect:
						apply_tween_effect(p.node, target_position)
					else:
						p.node.position = target_position
				
				# Liberar las celdas ocupadas por las piezas del grupo
				for p in group_copy:
					remove_piece_at(p.current_cell)
				
				# Colocar cada pieza del grupo en su posición relativa
				var group_leader_pos = target_cell  # Renombramos la variable para evitar conflictos
				for p in group_copy:
					var offset = p.original_pos - leader.original_pos
					var destination_cell = group_leader_pos + offset
					
					# Asegurarse de que la celda está dentro de los límites horizontales
					destination_cell.x = clamp(destination_cell.x, 0, GLOBAL.columns - 1)
					
					# Para los límites verticales, verificar si necesitamos añadir filas
					if destination_cell.y >= GLOBAL.rows:
						if not add_extra_row():
							destination_cell.y = GLOBAL.rows - 1
					
					set_piece_at(destination_cell, p)
					
					# Aplicar efecto Tween
					var target_position = puzzle_offset + destination_cell * cell_size
					if use_tween_effect:
						apply_tween_effect(p.node, target_position)
					else:
						p.node.position = target_position
				
				# Reproducir sonido
				# if audio_merge and not audio_merge.playing:
				# 	audio_merge.play()
				
				check_all_groups()
				verify_all_pieces_in_grid()
				return
				
			else:
				# Si el grupo entrante es más pequeño, no permitir la colocación
				push_warning("No se puede colocar grupo más pequeño sobre uno más grande")
				show_error_message("El grupo es demasiado pequeño")
				
				# Devolver cada pieza del grupo a su posición original de inicio del arrastre
				for p in group_copy:
					var orig_cell = p.drag_start_cell
					
					# Comprobar que la celda original está disponible
					var current_occupant = get_piece_at(orig_cell)
					if current_occupant != null and current_occupant != p:
						# Si la posición original ya está ocupada, buscar una celda libre cercana
						var backup_free_cells = find_free_cells(1)
						if backup_free_cells.size() > 0:
							orig_cell = backup_free_cells[0]
					
					remove_piece_at(p.current_cell)
					set_piece_at(orig_cell, p)
					
					# Aplicar efecto Tween para mover la pieza a su posición original
					var target_position = puzzle_offset + orig_cell * cell_size
					if use_tween_effect:
						apply_tween_effect(p.node, target_position)
					else:
						p.node.position = target_position
				
				return
		else:
			# Caso con múltiples grupos o grupos que no coinciden exactamente:
			# Verificar si el grupo entrante es más grande que todos los grupos ocupantes juntos
			var total_occupant_pieces = 0
			for group_id in occupant_groups:
				total_occupant_pieces += occupant_groups[group_id].size()
			
			if group_copy.size() > total_occupant_pieces:
				push_warning("Desplazando múltiples grupos/piezas")
				show_success_message("¡Desplazando grupos más pequeños!")
				
				# Recopilar todas las piezas ocupantes
				var all_occupant_pieces = []
				var separated_groups = {}  # Mapa: ID de grupo -> lista de piezas

				# Primero agrupar todas las piezas por sus grupos
				for group_id in occupant_groups:
					var group_pieces = occupant_groups[group_id]
					separated_groups[group_id] = group_pieces
					
					# No añadimos las piezas aquí para procesarlas por grupos

				# Añadir piezas individuales que no estén en grupos
				for occupant in occupants:
					if occupant.group.size() == 1 and not any_group_contains(separated_groups, occupant):
						all_occupant_pieces.append(occupant)

				# Procesar cada grupo de manera coherente
				var all_failed = false
				var processed_cells = []  # Para llevar un registro de qué celdas están ocupadas
				
				# Primero, ocupamos las celdas con nuestro grupo actual
				for cell in group_cells:
					processed_cells.append(cell)
				
				# Ahora procesamos los grupos
				for group_id in separated_groups:
					var group_pieces = separated_groups[group_id]
					
					# Encontrar un espacio coherente para este grupo
					var target_group_cells = find_space_for_group(group_pieces, processed_cells)
					
					# Si no hay suficiente espacio coherente para este grupo
					if target_group_cells.size() < group_pieces.size():
						all_failed = true
						break
					
					# Quitar todas las piezas del grupo de sus posiciones actuales
					for p in group_pieces:
						remove_piece_at(p.current_cell)
					
					# Calcular la posición base del grupo (donde irá el líder)
					var group_leader = get_group_leader(group_pieces[0])
					
					# Colocar las piezas del grupo en las celdas coherentes
					for i in range(group_pieces.size()):
						var p = group_pieces[i]
						var offset = p.original_pos - group_leader.original_pos
						var leader_cell = target_group_cells[0]  # La celda para el líder
						var target_piece_cell = leader_cell + offset
						
						# Asegurarnos de que la celda esté dentro de los límites
						target_piece_cell.x = clamp(target_piece_cell.x, 0, GLOBAL.columns - 1)
						if target_piece_cell.y >= GLOBAL.rows:
							if not add_extra_row():
								target_piece_cell.y = GLOBAL.rows - 1
						
						set_piece_at(target_piece_cell, p)
						
						# Aplicar efecto Tween
						var target_position = puzzle_offset + target_piece_cell * cell_size
						if use_tween_effect:
							apply_tween_effect(p.node, target_position)
						else:
							p.node.position = target_position
						
						# Añadir a la lista de celdas a evitar para los siguientes grupos
						processed_cells.append(target_piece_cell)

				# Para las piezas individuales, buscar celdas libres normales
				if not all_failed and all_occupant_pieces.size() > 0:
					var free_cells = []
					
					# Buscar celdas libres (que no estén en processed_cells)
					for r in range(GLOBAL.rows):
						for c in range(GLOBAL.columns):
							var check_cell = Vector2(c, r)
							var cell_key_str = cell_key(check_cell)
							
							if not grid.has(cell_key_str) and not (check_cell in processed_cells):
								free_cells.append(check_cell)
								
								if free_cells.size() >= all_occupant_pieces.size():
									break
						
						if free_cells.size() >= all_occupant_pieces.size():
							break
					
					# Si no hay suficientes celdas libres, intentar añadir filas
					while free_cells.size() < all_occupant_pieces.size():
						if not add_extra_row():
							break
						
						# Buscar celdas libres en la nueva fila
						for c in range(GLOBAL.columns):
							var check_cell = Vector2(c, GLOBAL.rows - 1)
							var cell_key_str = cell_key(check_cell)
							
							if not grid.has(cell_key_str) and not (check_cell in processed_cells):
								free_cells.append(check_cell)
								
								if free_cells.size() >= all_occupant_pieces.size():
									break
					
					# Si no hay suficientes celdas libres, fallar
					if free_cells.size() < all_occupant_pieces.size():
						all_failed = true
					else:
						# Primero quitar todas las piezas de sus posiciones actuales
						for idx in range(all_occupant_pieces.size()):
							var piece_to_move = all_occupant_pieces[idx]
							remove_piece_at(piece_to_move.current_cell)
						
						# Luego, en un bucle separado, colocar cada pieza en su nueva posición
						for idx in range(all_occupant_pieces.size()):
							var piece_to_place = all_occupant_pieces[idx]
							var free_cell = free_cells[idx]
							
							set_piece_at(free_cell, piece_to_place)
							
							# Aplicar efecto Tween
							var target_position = puzzle_offset + free_cell * cell_size
							if use_tween_effect:
								apply_tween_effect(piece_to_place.node, target_position)
							else:
								piece_to_place.node.position = target_position
							
							# Añadir a la lista de celdas procesadas
							processed_cells.append(free_cell)

				# Si alguna parte falló, devolver el grupo a su posición original
				if all_failed:
					push_warning("No hay suficientes celdas libres para desplazar los grupos")
					show_error_message("No hay suficiente espacio libre")
					
					# Devolver cada pieza del grupo a su posición original de inicio del arrastre
					for p in group_copy:
						var orig_cell = p.drag_start_cell
						
						# Comprobar que la celda original está disponible
						var current_occupant = get_piece_at(orig_cell)
						if current_occupant != null and current_occupant != p:
							# Si la posición original ya está ocupada, buscar una celda libre cercana
							var backup_free_cells = find_free_cells(1)
							if backup_free_cells.size() > 0:
								orig_cell = backup_free_cells[0]
						
						remove_piece_at(p.current_cell)
						set_piece_at(orig_cell, p)
						
						# Aplicar efecto Tween para mover la pieza a su posición original
						var target_position = puzzle_offset + orig_cell * cell_size
						if use_tween_effect:
							apply_tween_effect(p.node, target_position)
						else:
							p.node.position = target_position
					
					return
				
				# Si todo salió bien, continuar con la colocación del grupo principal
				# Liberar las celdas ocupadas por las piezas del grupo
				for p in group_copy:
					remove_piece_at(p.current_cell)
				
				# Colocar cada pieza del grupo en su posición relativa
				var leader_target_pos = target_cell  # Usamos la variable que ya tenemos
				for p in group_copy:
					var offset = p.original_pos - leader.original_pos
					var destination_cell = leader_target_pos + offset
					
					# Asegurarse de que la celda está dentro de los límites horizontales
					destination_cell.x = clamp(destination_cell.x, 0, GLOBAL.columns - 1)
					
					# Para los límites verticales, verificar si necesitamos añadir filas
					if destination_cell.y >= GLOBAL.rows:
						if not add_extra_row():
							destination_cell.y = GLOBAL.rows - 1
					
					set_piece_at(destination_cell, p)
					
					# Aplicar efecto Tween
					var target_position = puzzle_offset + destination_cell * cell_size
					if use_tween_effect:
						apply_tween_effect(p.node, target_position)
					else:
						p.node.position = target_position
				
				# Reproducir sonido
				# if audio_merge and not audio_merge.playing:
				# 	audio_merge.play()
				
				check_all_groups()
				verify_all_pieces_in_grid()
				return
			else:
				# Si el grupo entrante es más pequeño, no permitir la colocación
				push_warning("No se puede colocar sobre múltiples grupos")
				show_error_message("No se puede colocar sobre múltiples grupos")
				
				# Devolver cada pieza del grupo a su posición original de inicio del arrastre
				for p in group_copy:
					var orig_cell = p.drag_start_cell
					
					# Comprobar que la celda original está disponible
					var current_occupant = get_piece_at(orig_cell)
					if current_occupant != null and current_occupant != p:
						# Si la posición original ya está ocupada, buscar una celda libre cercana
						var backup_free_cells = find_free_cells(1)
						if backup_free_cells.size() > 0:
							orig_cell = backup_free_cells[0]
					
					remove_piece_at(p.current_cell)
					set_piece_at(orig_cell, p)
					
					# Aplicar efecto Tween para mover la pieza a su posición original
					var target_position = puzzle_offset + orig_cell * cell_size
					if use_tween_effect:
						apply_tween_effect(p.node, target_position)
					else:
						p.node.position = target_position
				
				return
	
	# Verificar si todas las piezas ocupantes están solas (no en grupos)
	var all_occupants_single = true
	for occupant in occupants:
		if occupant.group.size() > 1:
			all_occupants_single = false
			push_warning("No se puede intercambiar con una pieza que está en un grupo")
			show_error_message("No se puede intercambiar: hay piezas destino en grupos")
			break
	
	# Si todas las piezas ocupantes están solas y su número coincide con el tamaño del grupo,
	# podemos intercambiar las posiciones
	if all_occupants_single and occupants.size() > 0 and occupants.size() == group_copy.size():
		# Guardar las posiciones originales de las piezas ocupantes
		var occupant_positions = []
		for occupant in occupants:
			occupant_positions.append(occupant.current_cell)
		
		# Liberar las celdas ocupadas por ambos grupos
		for p in group_copy:
			remove_piece_at(p.current_cell)
		
		for occupant in occupants:
			remove_piece_at(occupant.current_cell)
		
		# Colocar las piezas ocupantes en las posiciones originales del grupo
		for i in range(occupants.size()):
			var occupant = occupants[i]
			var orig_cell = group_copy[i].current_cell
			set_piece_at(orig_cell, occupant)
			
			# Aplicar efecto Tween
			var target_position = puzzle_offset + orig_cell * cell_size
			if use_tween_effect:
				apply_tween_effect(occupant.node, target_position)
			else:
				occupant.node.position = target_position
		
		# Colocar las piezas del grupo en las posiciones de las ocupantes
		for i in range(group_copy.size()):
			var p = group_copy[i]
			var new_cell = occupant_positions[i]
			set_piece_at(new_cell, p)
			
			# Aplicar efecto Tween
			var target_position = puzzle_offset + new_cell * cell_size
			if use_tween_effect:
				apply_tween_effect(p.node, target_position)
			else:
				p.node.position = target_position
		
		# Generar un error para depuración
		push_warning("Intercambiando grupo de " + str(group_copy.size()) + " piezas con " + str(occupants.size()) + " piezas individuales")
		
		# Mostrar mensaje de éxito
		show_success_message("¡Grupo intercambiado con " + str(occupants.size()) + " piezas!")
	else:
		# Si no se pueden intercambiar, mover las piezas que colisionan con el grupo
		move_colliding_pieces(leader, target_cell)
		
		# Liberar las celdas ocupadas por las piezas del grupo
		for p in group_copy:
			remove_piece_at(p.current_cell)
		
		# Colocar cada pieza del grupo en su posición relativa
		for p in group_copy:
			var offset = p.original_pos - leader.original_pos
			var p_target = target_cell + offset
			
			# Asegurarse de que la celda está dentro de los límites horizontales
			p_target.x = clamp(p_target.x, 0, GLOBAL.columns - 1)
			
			# Para los límites verticales, intentamos añadir filas si es necesario
			if p_target.y >= GLOBAL.rows:
				if not add_extra_row():
					p_target.y = GLOBAL.rows - 1  # Si no podemos añadir más filas, usamos la última
			
			var occupant = get_piece_at(p_target)
			if occupant != null and not (occupant in group_copy):
				# Si hay una pieza ocupando la celda, moverla a una celda libre
				var free_cells = find_free_cells(1)
				if free_cells.size() > 0:
					remove_piece_at(occupant.current_cell)
					set_piece_at(free_cells[0], occupant)
					
					# Aplicar efecto Tween
					var target_position = puzzle_offset + free_cells[0] * cell_size
					if use_tween_effect:
						apply_tween_effect(occupant.node, target_position)
					else:
						occupant.node.position = target_position
						
				elif add_extra_row():
					# Si no hay celdas libres, intentamos añadir una fila
					free_cells = find_free_cells(1)
					if free_cells.size() > 0:
						remove_piece_at(occupant.current_cell)
						set_piece_at(free_cells[0], occupant)
						
						# Aplicar efecto Tween
						var target_position = puzzle_offset + free_cells[0] * cell_size
						if use_tween_effect:
							apply_tween_effect(occupant.node, target_position)
						else:
							occupant.node.position = target_position
			
			# Colocar la pieza en su posición
			set_piece_at(p_target, p)
			
			# Aplicar efecto Tween
			var target_position = puzzle_offset + p_target * cell_size
			if use_tween_effect:
				apply_tween_effect(p.node, target_position)
			else:
				p.node.position = target_position
	
	# Verificar que todas las piezas del grupo estén correctamente colocadas en el grid
	for p in group_copy:
		if not grid.has(cell_key(p.current_cell)) or grid[cell_key(p.current_cell)] != p:
			# Si la pieza no está en el grid o hay otra pieza en su lugar, recolocarla
			var free_cells = find_free_cells(1)
			if free_cells.size() > 0:
				set_piece_at(free_cells[0], p)
				
				# Aplicar efecto Tween
				var target_position = puzzle_offset + free_cells[0] * cell_size
				if use_tween_effect:
					apply_tween_effect(p.node, target_position)
				else:
					p.node.position = target_position
	
	# Intentar fusionar el grupo con piezas adyacentes fuera del grupo
	var merged = true
	while merged:
		merged = false
		# Usar una copia actualizada del grupo para la iteración
		var updated_group = get_group_leader(leader).group.duplicate()
		for p in updated_group:
			var adjacent = find_adjacent_pieces(p, p.current_cell)
			for adj in adjacent:
				if are_pieces_mergeable(p, adj):
					merge_pieces(p, adj)
					merged = true
					break
			if merged:
				break
	if !merged:
		audio_move.play()
	
	# Al final del place_group, verificar si se pueden formar más grupos
	check_all_groups()
	
	# Verificar que todas las piezas estén en el grid
	verify_all_pieces_in_grid()
	
	# Verificar victoria solo cuando realmente se ha colocado una pieza
	if just_placed_piece:
		call_deferred("check_victory_deferred")
		call_deferred("check_victory_by_position")
		just_placed_piece = false  # Reiniciar el flag después de verificar

# Nueva función para verificar que todas las piezas estén en el grid
func verify_all_pieces_in_grid():
	var pieces_in_grid = []
	
	# Recopilar todas las piezas que están en el grid
	for cell_k in grid.keys():
		var piece = grid[cell_k]
		if piece != null and not (piece in pieces_in_grid):
			pieces_in_grid.append(piece)
	
	# Verificar si hay piezas que no están en el grid
	for piece in pieces:
		if not (piece in pieces_in_grid):
			# Encontrar una celda libre para la pieza
			var free_cells = find_free_cells(1)
			if free_cells.size() > 0:
				set_piece_at(free_cells[0], piece)
				piece.node.position = puzzle_offset + free_cells[0] * cell_size
			else:
				# Si no hay celdas libres, intentar añadir una fila
				if add_extra_row():
					free_cells = find_free_cells(1)
					if free_cells.size() > 0:
						set_piece_at(free_cells[0], piece)
						piece.node.position = puzzle_offset + free_cells[0] * cell_size

func check_victory():
	# Primero verificar y corregir el estado del grid
	verify_and_fix_grid()
	
	# Verificar si todas las piezas están en su posición original
	var all_in_place = true
	var pieces_close_to_original = 0
	var total_pieces = pieces.size()
	
	for piece_obj in pieces:
		# Actualizar el estado de posición de la pieza
		update_piece_position_state(piece_obj)
		
		if piece_obj.current_cell != piece_obj.original_pos:
			all_in_place = false
			
			# Verificar si la pieza está cerca de su posición original
			var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
			var distance = piece_obj.node.position.distance_to(expected_position)
			
			if distance <= cell_size.length() * 0.4:  # 40% del tamaño de celda como margen de error
				pieces_close_to_original += 1
	
	# Si todas las piezas están en su posición original
	if all_in_place:
		print("¡Victoria por posición exacta en el grid!")
		_on_puzzle_completed()
		return true
	
	# Si más del 90% de las piezas están cerca de su posición original, consideramos victoria
	if pieces_close_to_original >= total_pieces * 0.9:
		print("¡Victoria! Más del 90% de las piezas están cerca de su posición original")
		
		# Ajustar todas las piezas a su posición exacta
		for piece_obj in pieces:
			var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
			piece_obj.node.position = expected_position
			remove_piece_at(piece_obj.current_cell)
			piece_obj.current_cell = piece_obj.original_pos
			set_piece_at(piece_obj.original_pos, piece_obj)
			
			# Marcar todas las piezas como en posición correcta
			if piece_obj.node.has_method("set_correct_position"):
				piece_obj.node.set_correct_position(true)
		
		_on_puzzle_completed()
		return true
	
	return false

# Función diferida para verificar victoria (evita problemas de recursión)
func check_victory_deferred():
	# Verificar si todas las piezas están en su posición original
	var all_in_place = true
	for piece_obj in pieces:
		if piece_obj.current_cell != piece_obj.original_pos:
			all_in_place = false
			break
	
	# Si todas las piezas están en su lugar, mostrar pantalla de victoria
	if all_in_place:
		print("¡Victoria! (diferida)")
		_on_puzzle_completed()
	else:
		# Verificar también por posición visual (a veces el grid puede no estar actualizado)
		check_victory_by_position()

# Nueva función para verificar victoria por posición visual
func check_victory_by_position():
	var all_in_place = true
	var margin_of_error = cell_size.length() * 0.4  # 40% del tamaño de celda como margen de error (más tolerante)
	var pieces_in_place = 0
	var total_pieces = pieces.size()
	
	for piece_obj in pieces:
		# Actualizar el estado de posición de la pieza
		update_piece_position_state(piece_obj)
		
		# Calcular dónde debería estar la pieza visualmente
		var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
		
		# Verificar si la pieza está en su posición visual correcta (con un margen de error)
		var distance = piece_obj.node.position.distance_to(expected_position)
		if distance <= margin_of_error:
			pieces_in_place += 1
		else:
			print("Pieza fuera de posición: ", piece_obj.original_pos, " - Distancia: ", distance)
			all_in_place = false
	
	print("Verificación visual: ", pieces_in_place, " de ", total_pieces, " piezas en posición correcta")
	
	# Si todas las piezas están visualmente en su lugar correcto
	if all_in_place:
		print("¡Victoria por posición visual! Distancia máxima permitida: ", margin_of_error)
		
		# Corregir el grid para que coincida con las posiciones visuales
		for piece_obj in pieces:
			remove_piece_at(piece_obj.current_cell)
			piece_obj.current_cell = piece_obj.original_pos
			set_piece_at(piece_obj.original_pos, piece_obj)
			
			# Marcar todas las piezas como en posición correcta
			if piece_obj.node.has_method("set_correct_position"):
				piece_obj.node.set_correct_position(true)
		
		# Mostrar pantalla de victoria
		_on_puzzle_completed()
		return true
	
	# Si más del 95% de las piezas están en su lugar, considerar victoria
	if pieces_in_place >= total_pieces * 0.95:
		print("¡Victoria! Más del 95% de las piezas están en su posición visual correcta")
		
		# Corregir el grid para que coincida con las posiciones visuales
		for piece_obj in pieces:
			var expected_position = puzzle_offset + piece_obj.original_pos * cell_size
			piece_obj.node.position = expected_position
			remove_piece_at(piece_obj.current_cell)
			piece_obj.current_cell = piece_obj.original_pos
			set_piece_at(piece_obj.original_pos, piece_obj)
			
			# Marcar todas las piezas como en posición correcta
			if piece_obj.node.has_method("set_correct_position"):
				piece_obj.node.set_correct_position(true)
		
		# Mostrar pantalla de victoria
		_on_puzzle_completed()
		return true
	
	return false

# Agregar una nueva función para obtener el líder del grupo
func get_group_leader(piece: Piece) -> Piece:
	if piece.group.size() > 0:
		# Devolver la pieza con la posición original más baja (arriba-izquierda)
		var leader = piece.group[0]
		for p in piece.group:
			if p.original_pos.y < leader.original_pos.y or \
			   (p.original_pos.y == leader.original_pos.y and p.original_pos.x < leader.original_pos.x):
				leader = p
		return leader
	return piece

func check_all_groups() -> void:
	# Recorrer una copia de la lista de piezas
	var pieces_copy = pieces.duplicate()
	var merged_any = true
	
	# Seguir intentando fusionar hasta que no se pueda fusionar más
	while merged_any:
		merged_any = false
		
		for i in range(pieces_copy.size()):
			if i >= pieces_copy.size():
				break
				
			var piece_obj = pieces_copy[i]
			var adjacents = find_adjacent_pieces(piece_obj, piece_obj.current_cell)
			
			for adj in adjacents:
				if are_pieces_mergeable(piece_obj, adj):
					merge_pieces(piece_obj, adj)
					merged_any = true
					
					# Actualizar la lista de piezas después de la fusión
					pieces_copy = pieces.duplicate()
					break
			
			if merged_any:
				break
	
	# Actualizar las piezas de borde en todos los grupos
	var processed_groups = []  # Para evitar procesar dos veces el mismo grupo
	
	for piece_obj in pieces:
		var leader = get_group_leader(piece_obj)
		if not (leader in processed_groups):
			update_edge_pieces_in_group(leader.group)
			processed_groups.append(leader)
	
	# Verificar y corregir el estado del grid después de todas las fusiones
	verify_and_fix_grid()
	
	# Recalcular la cantidad real de grupos
	count_unique_groups()
	
	# Verificar victoria solo cuando realmente se ha colocado una pieza
	if just_placed_piece:
		call_deferred("check_victory_deferred")
		call_deferred("check_victory_by_position")
		just_placed_piece = false  # Reiniciar el flag después de verificar

# Nueva función para identificar las piezas de borde en un grupo
func update_edge_pieces_in_group(group: Array):
	if group.size() <= 1:
		# Si solo hay una pieza en el grupo, es una pieza de borde
		for piece in group:
			if piece.node.has_method("set_edge_piece"):
				piece.node.set_edge_piece(true)
		return
	
	# Para grupos de más de una pieza, identificar las piezas de borde
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	
	# Primero, marcar todas las piezas como no borde
	for piece in group:
		if piece.node.has_method("set_edge_piece"):
			piece.node.set_edge_piece(false)
	
	# Luego, identificar las piezas que realmente son borde
	for piece in group:
		var cell = piece.current_cell
		var is_edge = false
		
		# Una pieza es de borde si en alguna dirección no tiene una pieza del mismo grupo
		for dir in directions:
			var neighbor_cell = cell + dir
			var has_neighbor = false
			
			# Buscar si hay una pieza del mismo grupo en esta dirección
			for other_piece in group:
				if other_piece.current_cell == neighbor_cell:
					has_neighbor = true
					break
			
			# Si no hay vecino en esta dirección, es una pieza de borde
			if not has_neighbor:
				is_edge = true
				break
		
		# Actualizar el estado de "edge" de la pieza
		if piece.node.has_method("set_edge_piece"):
			piece.node.set_edge_piece(is_edge)

func on_flip_button_pressed() -> void:
	# Variable para rastrear si encontramos una pieza seleccionada
	var target_piece = null
	
	if(maxMovesFlipLabel.visible):
		if(!is_flip):
			if(max_flips > 0):
				max_flips -= 1
				maxFlipsLabel.text = str(max_flips)
			else:
				return
			
		
	is_flip = !is_flip
	
	# Animar el botón de flip con una rotación de 360 grados
	if flip_button:
		var rotation_direction = 1 if not pieces_flipped else -1
		var flip_button_tween = create_tween()
		flip_button_tween.tween_property(flip_button, "rotation_degrees", flip_button.rotation_degrees + (180 * rotation_direction), 0.5)
	
	# Primero intentamos encontrar una pieza que esté siendo arrastrada
	for piece_obj in pieces:
		if piece_obj.dragging:
			target_piece = piece_obj
			break
	
	# Si no hay pieza seleccionada, voltear todas las piezas (comportamiento original)
	if target_piece == null:
		# Crear un tween para la animación
		var tween = create_tween()
		
		# Voltear todas las piezas con animación
		for piece_obj in pieces:
			if piece_obj.node.has_method("flip_piece"):
				# Animar la escala para dar efecto de volteo
				tween.parallel().tween_property(piece_obj.node, "scale", Vector2(0, 1), flip_speed)
				
				# A la mitad de la animación, cambiar la textura
				tween.tween_callback(func():
					piece_obj.node.flip_piece()
				).set_delay(flip_speed)
				
				# Restaurar la escala
				tween.parallel().tween_property(piece_obj.node, "scale", Vector2(1, 1), flip_speed).set_delay(flip_speed)
		
		# Actualizar el estado de las piezas
		pieces_flipped = !pieces_flipped
		_increment_flip_count()
	else:
		# Si hay una pieza seleccionada, voltear solo su grupo
		var group_pieces = target_piece.group
		
		# Crear un tween para la animación
		var tween = create_tween()
		
		# Voltear cada pieza del grupo con una animación
		for piece_obj in group_pieces:
			if piece_obj.node.has_method("flip_piece"):
				# Animar la escala para dar efecto de volteo
				tween.parallel().tween_property(piece_obj.node, "scale", Vector2(0, 1), flip_speed)
				
				# A la mitad de la animación, cambiar la textura
				tween.tween_callback(func():
					piece_obj.node.flip_piece()
				).set_delay(flip_speed)
				
				# Restaurar la escala
				tween.parallel().tween_property(piece_obj.node, "scale", Vector2(1, 1), flip_speed).set_delay(flip_speed)
		
		# No actualizamos el estado general ya que solo estamos volteando un grupo

# Función para volver a la selección de puzzles
func _on_PuzzleSelected():
	print("PuzzleGame: Volviendo a la selección de puzzles")
	GLOBAL.change_scene_with_loading("res://Scenes/PuzzleSelection.tscn")

# Nueva función para manejar el cambio de dificultad
func _on_difficulty_changed(columns, rows):
	print("PuzzleGame: Dificultad cambiada a " + str(columns) + "x" + str(rows))
	
	# Actualizar las variables globales
	GLOBAL.columns = columns
	GLOBAL.rows = rows
	
	# Mostrar un mensaje al usuario
	show_success_message("Cambiando a dificultad " + str(columns) + "x" + str(rows))
	
	# Esperar un momento antes de reiniciar el puzzle
	await get_tree().create_timer(0.5).timeout
	
	# Limpiar las piezas actuales
	for piece_obj in pieces:
		if piece_obj.node != null:
			piece_obj.node.queue_free()
	
	# Limpiar las listas
	grid.clear()
	pieces.clear()
	
	# Guardar el número original de filas
	original_rows = GLOBAL.rows
	extra_rows_added = 0
	
	# Reiniciar el puzzle con la nueva dificultad
	var puzzle_back = await generate_back_texture_from_viewport(viewport_scene_path)
	if puzzle_back:
		load_and_create_pieces(puzzle_back)
	else:
		# Si falla la generación de la textura trasera, recargamos la escena
		print("PuzzleGame: Error al generar textura trasera, recargando escena...")
		get_tree().reload_current_scene()

# Nueva función para verificar y corregir el estado del grid
func verify_and_fix_grid():
	# 1. Verificar que todas las piezas estén en el grid
	verify_all_pieces_in_grid()
	
	# 2. Verificar que no haya celdas con referencias a piezas incorrectas
	var cells_to_fix = []
	
	for cell_k in grid.keys():
		var piece = grid[cell_k]
		if piece == null:
			# Eliminar entradas nulas
			cells_to_fix.append(cell_k)
		else:
			# Verificar que la pieza tenga la celda correcta
			var expected_key = cell_key(piece.current_cell)
			if expected_key != cell_k:
				cells_to_fix.append(cell_k)
	
	# Corregir las celdas problemáticas
	for cell_k in cells_to_fix:
		grid.erase(cell_k)
	
	# 3. Verificar que cada pieza esté en la celda que dice estar
	for piece in pieces:
		var key = cell_key(piece.current_cell)
		if not grid.has(key) or grid[key] != piece:
			# La pieza no está donde dice estar, buscar una celda libre
			var free_cells = find_free_cells(1)
			if free_cells.size() > 0:
				set_piece_at(free_cells[0], piece)
				piece.node.position = puzzle_offset + free_cells[0] * cell_size
			else:
				# Si no hay celdas libres, intentar añadir una fila
				if add_extra_row():
					free_cells = find_free_cells(1)
					if free_cells.size() > 0:
						set_piece_at(free_cells[0], piece)
						piece.node.position = puzzle_offset + free_cells[0] * cell_size
	
	# 4. Verificar que no haya piezas superpuestas
	var occupied_positions = {}
	for piece in pieces:
		var pos_key = "%d_%d" % [int(piece.node.position.x), int(piece.node.position.y)]
		if occupied_positions.has(pos_key):
			# Hay una pieza superpuesta, moverla a una celda libre
			var free_cells = find_free_cells(1)
			if free_cells.size() > 0:
				remove_piece_at(piece.current_cell)
				set_piece_at(free_cells[0], piece)
				piece.node.position = puzzle_offset + free_cells[0] * cell_size
		else:
			occupied_positions[pos_key] = piece
	
	# Verificar victoria después de corregir el grid
	call_deferred("check_victory_deferred")
	
	# También verificar por posición visual
	call_deferred("check_victory_by_position")

# Función para alternar entre la vista de imagen y texto
func _on_toggle_view_pressed():
	# Invertir la visibilidad de las vistas
	victory_image_view.visible = !victory_image_view.visible
	victory_text_view.visible = !victory_text_view.visible
	
	# Actualizar el texto del botón según la vista actual
	if victory_text_view.visible:
		victory_toggle_button.text = "Imagen"
	else:
		victory_toggle_button.text = "Texto"

# Función para cambiar de escena de manera segura
func safe_change_scene(scene_path: String) -> void:
	# Verificar que get_tree() no sea nulo
	if get_tree() != null:
		# Usar call_deferred para cambiar la escena de manera segura
		get_tree().call_deferred("change_scene_to_file", scene_path)
	else:
		push_error("No se pudo cambiar a la escena: " + scene_path)


# Función llamada cuando se ha completado el puzzle
func _on_puzzle_completed():
	# Evitar que se llame múltiples veces
	if puzzle_completed:
		return
	
	# Marcar como completado
	puzzle_completed = true
	
	# Detener el temporizador
	stop_game_timer()
	
	# Reproducir sonido de victoria
	if audio_merge:
		audio_merge.play()
	
	# Mostrar mensaje de victoria
	show_success_message("¡Puzzle Completado!", 1.0)
	
	# Determinar la modalidad de juego actual
	var gamemode = 0  # Modo normal por defecto
	if relax_mode:
		gamemode = 1  # Modo relajado
	elif timer_mode:
		gamemode = 3  # Modo contrarreloj
	elif challenge_mode:
		gamemode = 4  # Modo desafío
	
	# Preparar los datos para la pantalla de victoria
	var victory_data = {
		"puzzle": GLOBAL.selected_puzzle,
		"pack": GLOBAL.selected_pack,
		"total_moves": total_moves,
		"elapsed_time": elapsed_time,
		"difficulty": {"columns": GLOBAL.columns, "rows": GLOBAL.rows},
		"pack_id": current_pack_id,
		"puzzle_id": current_puzzle_id,
		"flip_count": flip_count,           # Nuevo: número de flips realizados
		"flip_move_count": flip_move_count, # Nuevo: movimientos durante flips
		"gamemode": gamemode                # Nuevo: modalidad de juego
	}
	
	# Guardar los datos para la pantalla de victoria
	GLOBAL.victory_data = victory_data
	
	# Marcar el puzzle como completado en el ProgressManager
	if progress_manager:
		progress_manager.complete_puzzle(current_pack_id, current_puzzle_id)
	
	# Cambiar a la pantalla de victoria después de un breve retraso
	get_tree().change_scene_to_file("res://Scenes/VictoryScreen.tscn")
	#await get_tree().create_timer(1.5).timeout
	#GLOBAL.change_scene_with_loading("res://Scenes/VictoryScreen.tscn")

# Función para mostrar la pantalla de victoria
func show_victory_screen():
	print("Cambiando a la pantalla de victoria")
	
	# Guardar los datos necesarios en GLOBAL para que la escena de victoria pueda acceder a ellos
	GLOBAL.victory_data = {
		"puzzle": GLOBAL.selected_puzzle,
		"pack": GLOBAL.selected_pack,
		"total_moves": total_moves,
		"elapsed_time": elapsed_time,
		"pack_id": current_pack_id,
		"puzzle_id": current_puzzle_id,
		"is_mobile": is_mobile,  # Añadir información sobre el dispositivo
		"difficulty": {
			"columns": GLOBAL.columns,
			"rows": GLOBAL.rows
		}
	}
	
	# Usar la función de cambio de escena con pantalla de carga
	GLOBAL.change_scene_with_loading("res://Scenes/VictoryScreen.tscn")

# Función para mostrar un mensaje de error temporal
func show_error_message(message: String, duration: float = 2.0):
	# Si tenemos un Label predefinido en la escena
	if error_message_label:
		error_message_label.text = message
		error_message_label.visible = true
		
		# Crear un temporizador para ocultar el mensaje después del tiempo especificado
		var timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		timer.connect("timeout", func(): error_message_label.visible = false)
		add_child(timer)
		timer.start()
	else:
		# Fallback al método antiguo si no existe el Label en la escena
		var label = Label.new()
		label.text = message
		label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Rojo claro
		
		# Ajustar tamaño de fuente para dispositivos móviles
		if is_mobile:
			label.add_theme_font_size_override("font_size", 28)
		else:
			label.add_theme_font_size_override("font_size", 18)
		
		# Posicionar en la parte superior de la pantalla
		var viewport_size = get_viewport_rect().size
		
		# Centrar horizontalmente y ajustar el ancho para que quepa el texto
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size.x = viewport_size.x * 0.8
		label.position.x = viewport_size.x * 0.1
		label.position.y = 60
		
		# Añadir a la escena
		add_child(label)
		
		# Crear un temporizador para eliminar el mensaje después del tiempo especificado
		var timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		timer.connect("timeout", Callable(label, "queue_free"))
		add_child(timer)
		timer.start()

# Función para mostrar un mensaje de éxito temporal
func show_success_message(message: String, duration: float = 1.5):
	# Si tenemos un Label predefinido en la escena
	if success_message_label:
		success_message_label.text = message
		success_message_label.visible = true
		
		# Crear un temporizador para ocultar el mensaje después del tiempo especificado
		var timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		timer.connect("timeout", func(): success_message_label.visible = false)
		add_child(timer)
		timer.start()
	else:
		# Fallback al método antiguo si no existe el Label en la escena
		var label = Label.new()
		label.text = message
		label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))  # Verde claro
		
		# Ajustar tamaño de fuente para dispositivos móviles
		if is_mobile:
			label.add_theme_font_size_override("font_size", 28)
		else:
			label.add_theme_font_size_override("font_size", 18)
		
		# Posicionar en la parte superior de la pantalla
		var viewport_size = get_viewport_rect().size
		
		# Centrar horizontalmente y ajustar el ancho para que quepa el texto
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size.x = viewport_size.x * 0.8
		label.position.x = viewport_size.x * 0.1
		label.position.y = 60
		
		# Añadir a la escena
		add_child(label)
		
		# Crear un temporizador para eliminar el mensaje después del tiempo especificado
		var timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		timer.connect("timeout", Callable(label, "queue_free"))
		add_child(timer)
		timer.start()

# Función para mostrar el menú de opciones
func show_options_menu():
	if !is_paused:
		pause_game()



func process_piece_click_touch(touch_position: Vector2, touch_index: int) -> void:
	# Usar la posición del toque sin ajustar
	var mouse_pos = touch_position
	var clicked_piece = null
	
	# Encontrar la pieza clickeada
	for piece_obj in pieces:
		# Convertir la posición global del toque a local de cada pieza
		var local_pos = piece_obj.node.to_local(mouse_pos)
		var sprite = piece_obj.sprite
		
		# Verificar si el punto está dentro del sprite
		if sprite.texture != null:
			var tex_rect = Rect2(
				sprite.position - sprite.texture.get_size() * sprite.scale * 0.5,
				sprite.texture.get_size() * sprite.scale
			)
			
			if tex_rect.has_point(local_pos):
				clicked_piece = piece_obj
				break
	
	if clicked_piece:
		# Obtener el líder del grupo
		var group_leader = get_group_leader(clicked_piece)
		
		# Guardar las posiciones originales de cada pieza del grupo antes de comenzar a arrastrar
		for p in group_leader.group:
			# Almacenamos la celda actual como punto de referencia para volver si es necesario
			p.drag_start_cell = p.current_cell
		
		# Mover todo el grupo desde cualquier pieza
		for p in group_leader.group:
			p.dragging = true
			# Guardar el offset (diferencia entre posición de la pieza y posición del toque)
			p.drag_offset = p.node.global_position - mouse_pos
			
			# Usar el nuevo método set_dragging para cambiar el z-index
			if p.node.has_method("set_dragging"):
				p.node.set_dragging(true)
			else:
				p.node.z_index = 9999
				
			# Asegurar que la pieza esté al frente moviendo su nodo al final del árbol
			if p.node.get_parent() != null:
				p.node.get_parent().move_child(p.node, p.node.get_parent().get_child_count() - 1)

func process_piece_release() -> void:
	# Al soltar, colocar todo el grupo
	var dragging_piece = null
	for piece_obj in pieces:
		if piece_obj.dragging:
			dragging_piece = piece_obj
			break
	
	if dragging_piece:
		var group_leader = get_group_leader(dragging_piece)
		for p in group_leader.group:
			p.dragging = false
			
			# Usar el nuevo método set_dragging para restaurar el z-index
			if p.node.has_method("set_dragging"):
				p.node.set_dragging(false)
			else:
				p.node.z_index = 0
		
		# Guardar la posición actual antes de colocar el grupo
		var old_position = group_leader.current_cell
		
		# Colocar el grupo - aquí ocurre la magia
		place_group(group_leader)

		
		# Reproducir sonido de movimiento solo si la posición cambió
		if old_position != group_leader.current_cell:
			_increment_move_count()
			movesLabel.text = str(total_moves)
		
		# Verificar y corregir el estado del grid después de cada movimiento
			verify_and_fix_grid()
		
		# La verificación de victoria ahora se maneja en place_group() a través de just_placed_piece

# Función para obtener el centro entre todos los puntos de contacto
func get_touch_center() -> Vector2:
	var center = Vector2.ZERO
	if touch_points.size() > 0:
		for point in touch_points.values():
			center += point
		center /= touch_points.size()
	return center

func process_piece_click(event: InputEvent) -> void:
	if event.pressed:
		# Usar la posición global del mouse sin ajustar por el desplazamiento
		var mouse_pos = event.position
		var clicked_piece = null
		
		# Para diagnóstico
		if OS.is_debug_build():
			print("Clic en posición: ", mouse_pos)
		
		# Encontrar la pieza clickeada
		for piece_obj in pieces:
			# Verificar si la pieza es válida
			if not is_instance_valid(piece_obj) or not is_instance_valid(piece_obj.node):
				continue
			
			# Verificar si el punto está dentro de la pieza usando to_local
			if is_mouse_over_piece(piece_obj, mouse_pos):
				clicked_piece = piece_obj
				if OS.is_debug_build():
					print("Pieza encontrada en: ", piece_obj.node.global_position)
				break
		
		if clicked_piece:
			# Obtener el líder del grupo
			var group_leader = get_group_leader(clicked_piece)
			
			# Guardar las posiciones originales de cada pieza del grupo antes de comenzar a arrastrar
			for p in group_leader.group:
				# Almacenamos la celda actual como punto de referencia para volver si es necesario
				p.drag_start_cell = p.current_cell
			
			# Mover todo el grupo desde cualquier pieza
			for p in group_leader.group:
				p.dragging = true
				p.drag_offset = p.node.global_position - mouse_pos
				
				# Usar el nuevo método set_dragging para cambiar el z-index
				if p.node.has_method("set_dragging"):
					p.node.set_dragging(true)
				else:
					p.node.z_index = 9999
					
				# Asegurar que la pieza esté al frente moviendo su nodo al final del árbol
				if p.node.get_parent() != null:
					p.node.get_parent().move_child(p.node, p.node.get_parent().get_child_count() - 1)

	else:
		# Al soltar, procesar el final del arrastre de la pieza
		process_piece_release()

# Función para cambiar la sensibilidad del desplazamiento
func set_pan_sensitivity(value: float) -> void:
	pan_sensitivity = clamp(value, 0.1, 2.0)
	
	# Guardar en GLOBAL (método preferido)
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		if not "puzzle" in global.settings:
			global.settings.puzzle = {}
		
		global.settings.puzzle.pan_sensitivity = pan_sensitivity
		
		if global.has_method("save_settings"):
			global.save_settings()
	
	# Para compatibilidad, también guardar en OptionsManager si existe
	elif has_node("/root/OptionsManager"):
		var options_manager = get_node("/root/OptionsManager")
		if options_manager.has_method("save_option"):
			options_manager.save_option("pan_sensitivity", pan_sensitivity)

# Función para cargar las preferencias del usuario
func load_user_preferences() -> void:
	# Cargar preferencias desde GLOBAL
	if has_node("/root/GLOBAL"):
		var global = GLOBAL
		if "puzzle" in global.settings:
			# Cargar sensibilidad de desplazamiento
			if "pan_sensitivity" in global.settings.puzzle:
				pan_sensitivity = global.settings.puzzle.pan_sensitivity
				print("PuzzleGame: Sensibilidad cargada desde GLOBAL: ", pan_sensitivity)
			
			# Cargar configuración del efecto tween
			if "use_tween_effect" in global.settings.puzzle:
				use_tween_effect = global.settings.puzzle.use_tween_effect
				print("PuzzleGame: Efecto tween cargado desde GLOBAL: ", use_tween_effect)
			
			# Cargar duración del efecto tween
			if "tween_duration" in global.settings.puzzle:
				tween_duration = global.settings.puzzle.tween_duration
				print("PuzzleGame: Duración del efecto tween cargada desde GLOBAL: ", tween_duration)
	
	# Para mantener compatibilidad, también intentar cargar desde OptionsManager si existe
	elif has_node("/root/OptionsManager"):
		var options_manager = get_node("/root/OptionsManager")
		if options_manager.has_method("get_option"):
			var saved_sensitivity = options_manager.get_option("pan_sensitivity", pan_sensitivity)
			pan_sensitivity = saved_sensitivity
			
			var saved_tween_effect = options_manager.get_option("use_tween_effect", use_tween_effect)
			use_tween_effect = saved_tween_effect
			
			var saved_tween_duration = options_manager.get_option("tween_duration", tween_duration)
			tween_duration = saved_tween_duration

# Función para cambiar la sensibilidad del desplazamiento

# Funciones modificadas para tween
func _on_tween_toggled(toggled):
	use_tween_effect = toggled
	
	# Guardar en GLOBAL (método preferido)
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		if not "puzzle" in global.settings:
			global.settings.puzzle = {}
		
		global.settings.puzzle.use_tween_effect = use_tween_effect
		
		if global.has_method("save_settings"):
			global.save_settings()
	
	# Para compatibilidad, también guardar en OptionsManager si existe
	elif has_node("/root/OptionsManager"):
		var options_manager = get_node("/root/OptionsManager")
		if options_manager.has_method("save_option"):
			options_manager.save_option("use_tween_effect", use_tween_effect)

func _on_tween_duration_changed(value):
	tween_duration = value
	
	# Actualizar el texto del valor
	if has_node("OptionsLayer/OptionsPanel/TweenDurationValue"):
		get_node("OptionsLayer/OptionsPanel/TweenDurationValue").text = str(value) + "s"
	
	# Guardar en GLOBAL (método preferido)
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		if not "puzzle" in global.settings:
			global.settings.puzzle = {}
		
		global.settings.puzzle.tween_duration = tween_duration
		
		if global.has_method("save_settings"):
			global.save_settings()
	
	# Para compatibilidad, también guardar en OptionsManager si existe
	elif has_node("/root/OptionsManager"):
		var options_manager = get_node("/root/OptionsManager")
		if options_manager.has_method("save_option"):
			options_manager.save_option("tween_duration", tween_duration)

# Función para mostrar el panel de opciones
func show_options_panel():
	# Usar nuestra función de mostrar opciones que maneja la pausa correctamente
	show_options_menu()
	
	# El resto del código legacy se mantiene como respaldo
	if has_node("OptionsLayer/OptionsPanel"):
		# Si existe, simplemente mostrarlo
		get_node("OptionsLayer/OptionsPanel").visible = true

func _on_BackButton_pressed() -> void:
	# Volver al menú principal
	GLOBAL.change_scene_with_loading("res://Scenes/PuzzleSelection.tscn")

# Nueva función para actualizar el estado de posición de una pieza
func update_piece_position_state(piece_obj: Piece):
	if is_instance_valid(piece_obj) and is_instance_valid(piece_obj.node):
		var is_correct = piece_obj.current_cell == piece_obj.original_pos
		
		# Si la pieza tiene el método para establecer el estado de posición, usarlo
		if piece_obj.node.has_method("set_correct_position"):
			piece_obj.node.set_correct_position(is_correct)

func play_flip_sound():
	if audio_flip and not audio_flip.playing:
		audio_flip.play()

# Nueva función para encontrar un espacio coherente para un grupo
func find_space_for_group(group, avoid_cells = []):
	# Primero, necesitamos conocer la estructura del grupo
	var leader = get_group_leader(group[0])
	var pieces_layout = []  # Lista de offsets relativos al líder
	
	# Recopilar la estructura relativa de las piezas
	for p in group:
		var offset = p.original_pos - leader.original_pos
		pieces_layout.append(offset)
	
	# Recorrer todo el tablero buscando un espacio donde quepa el grupo
	for row in range(GLOBAL.rows):
		for col in range(GLOBAL.columns):
			var base_cell = Vector2(col, row)
			var can_place = true
			var target_cells = []
			
			# Verificar cada posición relativa
			for offset in pieces_layout:
				var check_cell = base_cell + offset
				
				# Verificar límites
				if check_cell.x < 0 or check_cell.x >= GLOBAL.columns or check_cell.y < 0 or check_cell.y >= GLOBAL.rows:
					can_place = false
					break
				
				# Verificar si la celda está libre y no en la lista de celdas a evitar
				var cell_key_str = cell_key(check_cell)
				if grid.has(cell_key_str) or check_cell in avoid_cells:
					can_place = false
					break
				
				target_cells.append(check_cell)
			
			# Si encontramos un espacio válido, devolver las celdas
			if can_place:
				return target_cells
	
	# Si llegamos aquí, intentamos añadir una fila y volver a buscar
	if add_extra_row():
		return find_space_for_group(group, avoid_cells)
	
	# Si no encontramos un espacio, devolver un array vacío
	return []

# Función auxiliar para verificar si algún grupo contiene una pieza específica
func any_group_contains(groups_map, piece):
	for group_id in groups_map:
		if piece in groups_map[group_id]:
			return true
	return false

# Nueva función para reorganizar las piezas en filas extras a espacios disponibles en el área principal
func reorganize_pieces():
	show_success_message("Reorganizando piezas...")
	
	# 1. Recopilar todos los grupos existentes (tanto dentro como fuera del área original)
	var all_groups = []  # Lista de grupos únicos (líderes)
	var processed_pieces = []  # Piezas que ya hemos procesado
	
	for piece_obj in pieces:
		if piece_obj in processed_pieces:
			continue
			
		var group_leader = get_group_leader(piece_obj)
		if not (group_leader in all_groups):
			all_groups.append(group_leader)
			
		# Marcar todas las piezas de este grupo como procesadas
		for p in group_leader.group:
			if not (p in processed_pieces):
				processed_pieces.append(p)
	
	# 2. Identificar los grupos que están completamente fuera del área original
	var groups_outside_original = []
	
	for group_leader in all_groups:
		var completely_outside = true
		
		for p in group_leader.group:
			if p.current_cell.y < original_rows and p.current_cell.y >= 0 and p.current_cell.x < GLOBAL.columns and p.current_cell.x >= 0:
				completely_outside = false
				break
				
		if completely_outside:
			groups_outside_original.append(group_leader)
	
	# 3. Identificar piezas sueltas fuera del área original (piezas en grupos de tamaño 1)
	var singles_outside_original = []
	
	for piece_obj in pieces:
		if piece_obj.group.size() == 1 and (
		   piece_obj.current_cell.y >= original_rows or piece_obj.current_cell.y < 0 or 
		   piece_obj.current_cell.x >= GLOBAL.columns or piece_obj.current_cell.x < 0):
			singles_outside_original.append(piece_obj)
	
	# Si no hay nada que reorganizar, salir
	if groups_outside_original.size() == 0 and singles_outside_original.size() == 0:
		show_success_message("No hay piezas para reorganizar")
		return
		
	# Mostrar cuántas piezas/grupos se reorganizarán
	print("Reorganizando " + str(groups_outside_original.size()) + " grupos y " + 
		  str(singles_outside_original.size()) + " piezas sueltas")
	
	# 4. Crear un mapa de celdas ocupadas en el área original
	var occupied_cells = {}
	for piece_obj in pieces:
		var cell = piece_obj.current_cell
		if cell.y < original_rows and cell.y >= 0 and cell.x < GLOBAL.columns and cell.x >= 0:
			occupied_cells[cell_key(cell)] = piece_obj
	
	# 5. Identificar celdas libres en el área original
	var free_cells = []
	for r in range(original_rows):
		for c in range(GLOBAL.columns):
			var cell = Vector2(c, r)
			if not occupied_cells.has(cell_key(cell)):
				free_cells.append(cell)
	
	# 6. Intentar mover los grupos completos al área original
	var pieces_moved = 0
	var groups_moved = 0
	
	# Ordenar grupos por tamaño (de mayor a menor) para mover primero los grupos más grandes
	groups_outside_original.sort_custom(func(a, b): return a.group.size() > b.group.size())
	
	for group_leader in groups_outside_original:
		# Buscar un conjunto de celdas adecuado para el grupo completo
		var group_cells = find_space_for_group_in_original_area(group_leader, occupied_cells)
		
		if group_cells.size() >= group_leader.group.size():
			# ¡Encontramos espacio! Mover el grupo completo
			var i = 0
			
			# Registrar las celdas que ocupará este grupo para actualizar el mapa de ocupación
			var cells_to_occupy = []
			for p in group_leader.group:
				if i < group_cells.size():
					cells_to_occupy.append(group_cells[i])
					i += 1
			
			# Ahora mover las piezas del grupo a sus nuevas posiciones
			i = 0
			for p in group_leader.group:
				if i < cells_to_occupy.size():
					# Quitar la pieza de su posición actual
					remove_piece_at(p.current_cell)
					
					# Colocar en la nueva celda
					var target_cell = cells_to_occupy[i]
					set_piece_at(target_cell, p)
					
					# Marcar la celda como ocupada
					occupied_cells[cell_key(target_cell)] = p
					
					# Si esta celda estaba en la lista de free_cells, quitarla
					if target_cell in free_cells:
						free_cells.erase(target_cell)
					
					# Actualizar la posición visual
					var target_position = puzzle_offset + target_cell * cell_size
					if use_tween_effect:
						apply_tween_effect(p.node, target_position)
					else:
						p.node.position = target_position
					
					pieces_moved += 1
					i += 1
			
			groups_moved += 1
	
	# 7. Después, mover piezas individuales a celdas libres restantes
	for piece_obj in singles_outside_original:
		# Asegurarse de que la pieza sigue estando fuera del área original
		# (podría haber sido movida como parte de un grupo)
		if piece_obj.current_cell.y < original_rows and piece_obj.current_cell.y >= 0 and piece_obj.current_cell.x < GLOBAL.columns and piece_obj.current_cell.x >= 0:
			continue
			
		# Si hay celdas libres disponibles, mover la pieza
		if free_cells.size() > 0:
			var target_cell = free_cells[0]
			free_cells.remove_at(0)
			
			remove_piece_at(piece_obj.current_cell)
			set_piece_at(target_cell, piece_obj)
			
			# Marcar la celda como ocupada
			occupied_cells[cell_key(target_cell)] = piece_obj
			
			var target_position = puzzle_offset + target_cell * cell_size
			if use_tween_effect:
				apply_tween_effect(piece_obj.node, target_position)
			else:
				piece_obj.node.position = target_position
				
			pieces_moved += 1
		else:
			# No hay más espacios disponibles
			break
	
	# 8. Si se movieron piezas, reproducir el sonido y mostrar mensaje
	if pieces_moved > 0:
		if groups_moved > 0:
			show_success_message("¡" + str(groups_moved) + " grupos y " + str(pieces_moved - groups_moved) + " piezas reorganizadas!")
		else:
			show_success_message("¡" + str(pieces_moved) + " piezas reorganizadas!")
	else:
		show_error_message("No hay espacio para reorganizar")
	
	# 9. Verificar y actualizar los grupos después de la reorganización
	check_all_groups()
	verify_all_pieces_in_grid()

# Nueva función para encontrar espacio para un grupo dentro del área original
func find_space_for_group_in_original_area(group_leader: Piece, occupied_cells: Dictionary) -> Array:
	# 1. Determinar la estructura relativa del grupo
	var pieces_layout = []  # Lista de offsets relativos al líder
	
	for p in group_leader.group:
		var offset = p.original_pos - group_leader.original_pos
		pieces_layout.append(offset)
	
	# 2. Recorrer el área original buscando espacio disponible
	for row in range(original_rows):
		for col in range(GLOBAL.columns):
			var base_cell = Vector2(col, row)
			var can_place = true
			var target_cells = []
			
			# Verificar si todas las posiciones relativas están disponibles
			for offset in pieces_layout:
				var check_cell = base_cell + offset
				
				# Verificar límites del área original
				if check_cell.x < 0 or check_cell.x >= GLOBAL.columns or check_cell.y < 0 or check_cell.y >= original_rows:
					can_place = false
					break
				
				# Verificar si la celda está libre
				if occupied_cells.has(cell_key(check_cell)):
					can_place = false
					break
				
				target_cells.append(check_cell)
			
			# Si encontramos un espacio válido, devolver las celdas
			if can_place:
				return target_cells
	
	# Si no encontramos espacio, devolver un array vacío
	return []


func _on_button_toggle_hud_pressed() -> void:
	
	var btn_hide: Button = $BackgroundLayer/ButtonHideHUD
	var btn_show: Button = $BackgroundLayer/ButtonShowHUD
	
	if (UILayer.visible):
		UILayer.visible = false
		btn_hide.visible = false
		btn_show.visible = true
	else:
		UILayer.visible = true
		btn_hide.visible = true
		btn_show.visible = false

# Función para iniciar el temporizador de juego
func start_game_timer():
	start_time = Time.get_unix_time_from_system()
	is_timer_active = true
	accumulated_time = 0.0
	
	# Crear y añadir un timer para actualizar el tiempo transcurrido
	var timer = Timer.new()
	timer.name = "GameTimer"
	timer.wait_time = 1.0  # Actualizar cada segundo
	timer.one_shot = false
	timer.autostart = true
	timer.connect("timeout", Callable(self, "update_elapsed_time"))
	add_child(timer)
	
	print("PuzzleGame: Temporizador de juego iniciado")

# Función para actualizar el tiempo transcurrido
func update_elapsed_time():
	if is_timer_active and !is_paused:
		# Calcular el tiempo actual correctamente
		elapsed_time = Time.get_unix_time_from_system() - start_time - accumulated_time
		
		# Actualizar UI si existe
		update_timer_ui()

# Función para detener el temporizador de juego
func stop_game_timer():
	is_timer_active = false
	
	# La última actualización del tiempo transcurrido debe ser correcta
	if is_paused:
		# Si está pausado, usar el tiempo guardado en pause_start_time
		elapsed_time = pause_start_time - start_time - accumulated_time
	else:
		elapsed_time = Time.get_unix_time_from_system() - start_time - accumulated_time
	
	# Detener el timer si existe
	if has_node("GameTimer"):
		var timer = get_node("GameTimer")
		timer.stop()
	
	panelPaused.visible = true
	print("PuzzleGame: Temporizador de juego detenido. Tiempo total: ", elapsed_time, " segundos")

# Función para actualizar la UI del temporizador (si existe)
func update_timer_ui():
	# Si existe un nodo de UI para mostrar el tiempo, actualizarlo
	var timer_label = $UILayer/TimerLabel if has_node("UILayer/TimerLabel") else null
	
	if timer_label:
		var minutes = int(elapsed_time) / 60
		var seconds = int(elapsed_time) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func _notification(what):
	# Control de pausa cuando la ventana pierde el foco
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if !is_paused and is_timer_active and !puzzle_completed:
			pause_game()
			print("PuzzleGame: Juego pausado por pérdida de foco")
	
	# Reanudar el juego cuando la ventana vuelve a tener foco
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if is_paused and !is_options_menu_open and !puzzle_completed:
			resume_game()
			print("PuzzleGame: Juego reanudado por recuperación de foco")

# Función para pausar el juego
func pause_game():
	if is_paused or puzzle_completed:
		return
		
	is_paused = true
	pause_start_time = Time.get_unix_time_from_system()
	panelPaused.visible = true
	
	# Guardar el tiempo transcurrido en el momento de la pausa
	elapsed_time = pause_start_time - start_time - accumulated_time
	
	# Pausar el temporizador manteniendo el estado actual
	if has_node("GameTimer"):
		var timer = get_node("GameTimer")
		timer.paused = true
	
	# Mostrar mensaje de pausa
	show_success_message("Juego en pausa", 0.5)
	
	print("PuzzleGame: Juego pausado en tiempo:", elapsed_time)

# Función para reanudar el juego
func resume_game():
	if !is_paused or puzzle_completed:
		return
		
	# Calcular el tiempo que estuvo en pausa
	var current_time = Time.get_unix_time_from_system()
	var pause_duration = current_time - pause_start_time
	
	# Acumular tiempo de pausa
	accumulated_time += pause_duration
	
	is_paused = false
	
	# Reanudar el temporizador
	if has_node("GameTimer"):
		var timer = get_node("GameTimer")
		timer.paused = false
	
	# Mostrar mensaje de reanudación
	show_success_message("Juego reanudado", 0.5)
	panelPaused.visible = false
	
	print("PuzzleGame: Juego reanudado después de ", pause_duration, " segundos en pausa. Tiempo acumulado en pausa:", accumulated_time)

# Función para manejar el cierre del menú de opciones
func _on_options_closed():
	is_options_menu_open = false
	if is_paused and !puzzle_completed:
		resume_game()



# Función para contar los grupos únicos y actualizar ungrouped_pieces
func count_unique_groups():
	var unique_groups = []
	var group_leaders = []
	
	for piece_obj in pieces:
		var leader = get_group_leader(piece_obj)
		if not (leader in group_leaders):
			group_leaders.append(leader)
			unique_groups.append(leader.group)
	
	# Actualizar el contador de piezas sin agrupar
	ungrouped_pieces = unique_groups.size()
	
	if OS.is_debug_build():
		print("Recuento actualizado: " + str(ungrouped_pieces) + " grupos únicos")
	
	# Verificar si todas las piezas están en un solo grupo grande
	if unique_groups.size() == 1 and unique_groups[0].size() == pieces.size():
		ungrouped_pieces = 1
		print("¡Victoria por agrupación completa de piezas!")
		call_deferred("_on_puzzle_completed")
	
	return unique_groups.size()


func _on_button_exit_pressed() -> void:
	
	show_exit_dialog()
	

# Mostrar el diálogo de confirmación para salir directamente
func show_exit_dialog():
	# Eliminar diálogos anteriores si existen
	for child in get_children():
		if child.is_in_group("exit_dialog"):
			child.queue_free()
	
	# Instanciar nuevo diálogo
	var dialog = confirm_dialog_scene.instantiate()
	dialog.title_text = "¿Salir del Puzzle?"
	# Conectar señales
	dialog.exit_confirmed.connect(
		func(): 
			resume_game()
			get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn"))
	dialog.exit_canceled.connect(func(): dialog.queue_free())
	
	# Añadir a la escena actual
	add_child(dialog)
	
	# Mostrar el diálogo
	dialog.show_dialog()

func _on_button_repeat_pressed() -> void:
	_on_difficulty_changed(GLOBAL.columns, GLOBAL.rows)

# --- Timer de cuenta atrás para modo contrarreloj ---
func _on_timer_countdown():
	if timer_mode:
		time_left -= 1.0
		# Actualizar el label del reloj
		if has_node("UILayer/TimerLabel"):
			var timer_label = $UILayer/TimerLabel
			var minutes = int(time_left) / 60
			var seconds = int(time_left) % 60
			timer_label.text = "%02d:%02d" % [minutes, seconds]
		if time_left <= 0:
			timer_countdown.stop()
			defeat_reason = "Tiempo agotado"
			_show_defeat_message(defeat_reason)

# --- Lógica de movimientos y flips ---
func _increment_move_count():
	total_moves += 1
	if maxMovesLabel.visible:
		maxMovesLabel.text = str(max_moves - total_moves)	
	if (is_flip):
		_increment_flip_move_count()

	if movesLabel:
		movesLabel.text = str(total_moves)
	if challenge_mode and max_moves > 0 and total_moves >= max_moves:
		defeat_reason = "Límite de movimientos alcanzado"
		_show_defeat_message(defeat_reason)

func _increment_flip_count():
	flip_count += 1

func _increment_flip_move_count():
	flip_move_count += 1
	maxMovesFlipLabel.text = str(max_flip_moves - flip_move_count)
	if (timer_mode or challenge_mode) and max_flip_moves > 0 and flip_move_count > max_flip_moves:
		defeat_reason = "Límite de movimientos en flip alcanzado"
		_show_defeat_message(defeat_reason)

# --- Mensaje temporal de derrota (placeholder) ---
func _show_defeat_message(reason: String):
	# Preparar los datos de derrota para enviar a la pantalla de derrota
	var defeat_data = {
		"total_moves": total_moves,
		"elapsed_time": elapsed_time,
		"flip_count": flip_count,
		"flip_move_count": flip_move_count,
		"reason": reason,
		"scene_path": "res://Scenes/PuzzleGame.tscn"
	}
	GLOBAL.defeat_data = defeat_data

	# Cambiar a la pantalla de derrota
	GLOBAL.change_scene_with_loading("res://Scenes/DefeatScreen/DefeatScreen.tscn")

	# Pausar el juego y detener timers (por si acaso)
	is_paused = true
	if timer_countdown:
		timer_countdown.stop()
	stop_game_timer()

# Manejar el gesto de 'volver atrás' (botón de retroceso Android, gestos de sistema)
func handle_back_gesture() -> bool:
	print("PuzzleGame: Manejando gesto de volver atrás")
	if !puzzle_completed and is_timer_active:
		show_exit_dialog()
		return true  # Devolver true para indicar que hemos manejado el gesto
	return false  # Usar comportamiento por defecto
