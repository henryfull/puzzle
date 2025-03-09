# Script para mejorar el manejo de entrada táctil en ScrollContainer
# Adjuntar este script a un ScrollContainer para mejorar su comportamiento táctil

extends ScrollContainer

# Señales para notificar cuando comienza y termina el desplazamiento
signal touch_scroll_started
signal touch_scroll_ended

# Variables para el manejo de entrada táctil
var touch_start_position = Vector2.ZERO
var is_touch_scrolling = false
var touch_scroll_speed = 1.0  # Factor de velocidad de desplazamiento
var touch_scroll_inertia = 0.9  # Factor de inercia (0-1)
var touch_scroll_deadzone = 10  # Zona muerta en píxeles
var touch_hold_delay = 0.2  # Tiempo en segundos para considerar un toque como "mantenido"
var last_touch_velocity = Vector2.ZERO
var touch_time = 0.0
var touch_id = -1  # ID del toque actual para seguimiento
var touch_hold_timer = null  # Temporizador para detectar toques mantenidos
var potential_click = true  # Indica si el toque actual podría ser un clic

# Referencia al temporizador de inercia
var inertia_timer = null

func _ready():
	# Configurar el ScrollContainer para capturar eventos táctiles
	mouse_filter = Control.MOUSE_FILTER_STOP
	scroll_deadzone = touch_scroll_deadzone
	
	# Crear un temporizador para la inercia
	inertia_timer = Timer.new()
	inertia_timer.wait_time = 0.016  # ~60 FPS
	inertia_timer.one_shot = false
	inertia_timer.autostart = false
	inertia_timer.timeout.connect(Callable(self, "_on_inertia_timer_timeout"))
	add_child(inertia_timer)
	
	# Crear un temporizador para detectar toques mantenidos
	touch_hold_timer = Timer.new()
	touch_hold_timer.wait_time = touch_hold_delay
	touch_hold_timer.one_shot = true
	touch_hold_timer.autostart = false
	touch_hold_timer.timeout.connect(Callable(self, "_on_touch_hold_timeout"))
	add_child(touch_hold_timer)
	
	print("TouchScrollHandler inicializado en: ", name)

func _input(event):
	# Manejar eventos táctiles globalmente para capturar todos los eventos
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
	elif event is InputEventScreenDrag:
		_handle_drag_event(event)

func _handle_touch_event(event: InputEventScreenTouch):
	# Solo procesar si es el mismo toque que estamos siguiendo o si es un nuevo toque
	if touch_id != -1 and event.index != touch_id:
		return
		
	if event.pressed:
		# Inicio del toque
		touch_id = event.index
		touch_start_position = event.position
		touch_time = Time.get_ticks_msec() / 1000.0
		last_touch_velocity = Vector2.ZERO
		potential_click = true
		
		# Iniciar temporizador para detectar toques mantenidos
		touch_hold_timer.start()
	else:
		# Fin del toque
		if event.index == touch_id:
			touch_hold_timer.stop()
			
			if is_touch_scrolling:
				# Estábamos desplazando, finalizar desplazamiento
				is_touch_scrolling = false
				emit_signal("touch_scroll_ended")
				
				# Calcular velocidad final para inercia
				var current_time = Time.get_ticks_msec() / 1000.0
				var time_diff = current_time - touch_time
				if time_diff > 0 and time_diff < 0.3:  # Solo aplicar inercia para gestos rápidos
					# Iniciar inercia
					inertia_timer.start()
				else:
					last_touch_velocity = Vector2.ZERO
			elif potential_click:
				# No estábamos desplazando y es un toque corto, propagar el evento como clic
				_propagate_click_to_children(event.position)
			
			# Resetear el seguimiento del toque
			touch_id = -1
			potential_click = true

func _handle_drag_event(event: InputEventScreenDrag):
	# Solo procesar si es el mismo toque que estamos siguiendo
	if touch_id != -1 and event.index != touch_id:
		return
		
	# Detener el temporizador de toque mantenido
	touch_hold_timer.stop()
	
	# Verificar si el evento está dentro del área del ScrollContainer
	var local_position = get_local_mouse_position()
	if local_position.x < 0 or local_position.x > size.x or local_position.y < 0 or local_position.y > size.y:
		return
	
	# Calcular la distancia desde el inicio del toque
	var distance = event.position.distance_to(touch_start_position)
	
	if distance > touch_scroll_deadzone:
		# Ya no es un potencial clic si se ha movido más allá de la zona muerta
		potential_click = false
		
		if not is_touch_scrolling:
			is_touch_scrolling = true
			emit_signal("touch_scroll_started")
		
		# Calcular velocidad para inercia
		var current_time = Time.get_ticks_msec() / 1000.0
		var time_diff = current_time - touch_time
		if time_diff > 0:
			last_touch_velocity = event.velocity * touch_scroll_speed
		touch_time = current_time
		
		# Aplicar desplazamiento
		var scroll_delta = event.relative * touch_scroll_speed
		
		# Aplicar desplazamiento vertical u horizontal según la configuración
		if vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			scroll_vertical -= scroll_delta.y
		
		if horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			scroll_horizontal -= scroll_delta.x
		
		# Aceptar el evento para evitar que se propague
		get_viewport().set_input_as_handled()

func _on_inertia_timer_timeout():
	# Aplicar inercia al desplazamiento
	if last_touch_velocity.length() < 1.0:
		inertia_timer.stop()
		return
	
	# Aplicar desplazamiento con inercia
	if vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll_vertical -= last_touch_velocity.y * 0.016  # 0.016 segundos (60 FPS)
	
	if horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll_horizontal -= last_touch_velocity.x * 0.016
	
	# Reducir la velocidad gradualmente
	last_touch_velocity *= touch_scroll_inertia

func _on_touch_hold_timeout():
	# Si el temporizador se activa, ya no es un potencial clic sino un toque mantenido
	potential_click = false

func _propagate_click_to_children(position: Vector2):
	# Crear un evento de clic para propagar a los hijos
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = position
	click_event.global_position = position
	
	# Encontrar el control bajo el punto de clic
	var control_under_point = _find_control_at_position(position)
	if control_under_point:
		# Propagar el evento al control
		control_under_point.emit_signal("gui_input", click_event)
		
		# Simular también el evento de liberación
		click_event.pressed = false
		control_under_point.emit_signal("gui_input", click_event)

func _find_control_at_position(position: Vector2) -> Control:
	# Convertir la posición global a local
	var local_pos = get_local_mouse_position()
	
	# Buscar recursivamente el control bajo el punto
	return _find_control_recursive(self, local_pos)

func _find_control_recursive(parent: Control, position: Vector2) -> Control:
	# Verificar si la posición está dentro del control padre
	if not parent.get_global_rect().has_point(position):
		return null
	
	# Verificar los hijos en orden inverso (de arriba a abajo en la jerarquía visual)
	for i in range(parent.get_child_count() - 1, -1, -1):
		var child = parent.get_child(i)
		if child is Control and child.visible:
			# Convertir la posición al espacio local del hijo
			var child_pos = position - child.position
			
			# Verificar recursivamente
			var result = _find_control_recursive(child, child_pos)
			if result:
				return result
	
	# Si no se encontró en los hijos, devolver el padre si es interactivo
	if parent.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return parent
	
	return null 