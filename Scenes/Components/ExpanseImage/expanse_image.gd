extends Panel

# Variables para controlar el arrastre y zoom
var dragging = false
var drag_start_pos = Vector2()
var last_mouse_pos = Vector2()
var min_zoom = 0.5
var max_zoom = 3.0
var zoom_speed = 0.1
var current_zoom = 1.0
var initial_zoom = 1.0
var centered_position = Vector2()
var imagen = Texture

# Variables para control táctil
var touch_points = {}
var pinching = false
var last_pinch_distance = 0.0
var pinch_center = Vector2()

func _ready():
	# Referencias a los nodos que vamos a animar
	imagen = $PanelContainer/ImageExpanse
	var boton_cerrar = $ButtonClose
	
	# Configuración inicial para la animación
	imagen.scale = Vector2(0.2, 0.2) # Imagen pequeña inicialmente
	
	boton_cerrar.position.y = -100 # Botón inicialmente fuera de la pantalla
	
	# Calcular escala adecuada para que la imagen quepa dentro del panel
	# con un pequeño margen de seguridad (90% del espacio disponible)

	
	# Crear tween para la animación
	var tween = create_tween().set_parallel(true)
	
	# Configuración inicial exacta
	imagen.position = centered_position
	
	# Segundo se realiza una animación donde se muestra la imagen de pequeña al tamaño calculado
	tween.tween_property(imagen, "scale", Vector2(initial_zoom, initial_zoom), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Animación para asegurar que se mantiene en el centro
	tween.tween_property(imagen, "position", centered_position, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Se desplaza de la parte superior el ButtonClose hacia su posición
	var pos_final_boton = boton_cerrar.position
	pos_final_boton.y = 101 # La posición Y final del botón
	tween.tween_property(boton_cerrar, "position", pos_final_boton, 1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Establecer la escala inicial de zoom
	current_zoom = initial_zoom
	
func _on_button_close_pressed() -> void:
	var tween = create_tween().set_parallel(true)
	
	# Ocultar el panel al finalizar la animación
	tween.tween_callback(func(): $".".visible = false)
	_on_button_reset_pressed()

# Procesar eventos de entrada
func _input(event):
	# Control con ratón
	if event is InputEventMouseButton:
		# Zoom con rueda del ratón
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_image(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_image(-1)
		# Arrastrar con clic
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start_pos = event.position
				last_mouse_pos = event.position
			else:
				dragging = false
	
	# Mover la imagen con ratón
	elif event is InputEventMouseMotion and dragging:
		var delta = event.position - last_mouse_pos
		imagen.position += delta
		last_mouse_pos = event.position
	
	# Eventos táctiles para control con dedos
	elif event is InputEventScreenTouch:
		# Gestionar eventos de toque (para pellizco y arrastre)
		_handle_touch_event(event)
	
	# Eventos de arrastre táctil para mover la imagen con un dedo
	elif event is InputEventScreenDrag:
		# Si estamos haciendo pellizco, no mover la imagen
		if pinching:
			_update_pinch(event)
		# Si es un solo dedo, mover la imagen
		elif touch_points.size() == 1 and touch_points.has(event.index):
			imagen.position += event.relative
	
	# Manejo directo de gestos de zoom si el dispositivo los reporta
	elif event is InputEventMagnifyGesture:
		_zoom_image(event.factor - 1.0)
	elif event is InputEventPanGesture:
		_zoom_image(-event.delta.y * 0.1)

# Manejar eventos de toque para implementar zoom con dos dedos
func _handle_touch_event(event: InputEventScreenTouch):
	# Registrar toque
	if event.pressed:
		touch_points[event.index] = event.position
		# Si tenemos exactamente dos dedos, comienza el pellizco
		if touch_points.size() == 2:
			var points = touch_points.values()
			last_pinch_distance = points[0].distance_to(points[1])
			pinch_center = (points[0] + points[1]) / 2
			pinching = true
	# Eliminar toque al levantar el dedo
	else:
		if touch_points.has(event.index):
			touch_points.erase(event.index)
		
		# Si quedamos con menos de 2 dedos, dejar de pellizcar
		if touch_points.size() < 2:
			pinching = false

# Actualizar el gesto de pellizco cuando se mueven los dedos
func _update_pinch(event: InputEventScreenDrag):
	# Actualizar la posición del dedo
	if touch_points.has(event.index):
		touch_points[event.index] = event.position
	
	# Si tenemos 2 dedos, calcular el cambio en la distancia para aplicar zoom
	if touch_points.size() == 2:
		var points = touch_points.values()
		var current_distance = points[0].distance_to(points[1])
		
		# Calcular el centro actual del pellizco
		var current_center = (points[0] + points[1]) / 2
		
		# Calcular el factor de zoom basado en el cambio en la distancia entre dedos
		if last_pinch_distance > 0:
			var zoom_factor = (current_distance - last_pinch_distance) / 100
			
			# Aplicar zoom centrado en el punto medio entre los dedos
			_zoom_at_position(zoom_factor, current_center)
		
		# Actualizar valores para el próximo frame
		last_pinch_distance = current_distance
		pinch_center = current_center

# Aplicar zoom centrado en una posición específica
func _zoom_at_position(zoom_factor, center_position):
	var new_zoom = current_zoom + zoom_factor
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	
	if new_zoom != current_zoom:
		# Calcular la nueva posición manteniendo el punto bajo los dedos
		var offset = center_position - imagen.position
		var new_offset = offset * (new_zoom / current_zoom)
		var position_delta = offset - new_offset
		
		imagen.scale = Vector2(new_zoom, new_zoom)
		imagen.position += position_delta
		
		current_zoom = new_zoom

# Función para aplicar zoom a la imagen (usado por rueda del ratón y otros gestos)
func _zoom_image(zoom_factor):
	var new_zoom = current_zoom + zoom_factor * zoom_speed
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	
	if new_zoom != current_zoom:
		var zoom_center = get_global_mouse_position()
		var img_pos = imagen.position
		
		# Calcular la nueva posición manteniendo el punto bajo el cursor
		var offset = zoom_center - img_pos
		var new_offset = offset * (new_zoom / current_zoom)
		var position_delta = offset - new_offset
		
		imagen.scale = Vector2(new_zoom, new_zoom)
		imagen.position += position_delta
		
		current_zoom = new_zoom
		
func _on_button_reset_pressed() -> void:
	
	# Crear animación de restablecimiento
	var tween = create_tween()
	
	# Animar el movimiento hacia el centro exacto del panel
	tween.tween_property(imagen, "position", centered_position, 0.3).set_ease(Tween.EASE_OUT)
	
	# Restablecer zoom al tamaño inicial calculado
	tween.tween_property(imagen, "scale", Vector2(initial_zoom, initial_zoom), 0.3).set_ease(Tween.EASE_OUT)
	
	# Actualizar el valor de zoom actual
	current_zoom = initial_zoom
