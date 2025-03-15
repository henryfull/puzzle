extends Node

# Referencia a la escena de opciones
var options_scene = null
var options_instance = null
var is_options_visible = false
var parent_node = null

# Señal que se emite cuando el menú de opciones se cierra
signal options_closed

func _ready():
	print("OptionsManager: Inicializado")
	# Cargar la escena de opciones
	options_scene = load("res://Scenes/Options.tscn")
	if options_scene:
		print("OptionsManager: Escena de opciones cargada correctamente")
	else:
		print("OptionsManager: ERROR - No se pudo cargar la escena de opciones")

# Función para mostrar el menú de opciones
func show_options(node):
	print("OptionsManager: Mostrando opciones")
	
	# Guardar referencia al nodo padre
	parent_node = node
	
	# Verificar que la escena de opciones esté cargada
	if options_scene == null:
		print("OptionsManager: Cargando escena de opciones")
		options_scene = load("res://Scenes/Options.tscn")
		if options_scene == null:
			print("OptionsManager: ERROR - No se pudo cargar la escena de opciones")
			return
	
	# Crear una nueva instancia de opciones
	print("OptionsManager: Creando nueva instancia de opciones")
	options_instance = options_scene.instantiate()
	
	# Añadir el menú de opciones como hijo del nodo actual
	parent_node.add_child(options_instance)
	
	# Conectar la señal del botón de volver
	var button = options_instance.get_node("CanvasLayer/BoxContainer/VBoxContainer3/Button")
	if button:
		button.connect("pressed", Callable(self, "_on_options_back_pressed"))
	
	# Configurar la animación de entrada
	var canvas_layer = options_instance.get_node("CanvasLayer")
	if canvas_layer:
		# Obtener el tamaño de la pantalla
		var viewport_size = parent_node.get_viewport_rect().size
		
		# Configurar la posición inicial fuera de la pantalla (arriba)
		canvas_layer.offset = Vector2(0, -viewport_size.y)
		
		# Animar la entrada del menú usando Tween
		var tween = parent_node.create_tween()
		tween.tween_property(canvas_layer, "offset", Vector2.ZERO, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Marcar como visible
	is_options_visible = true

# Función para ocultar el menú de opciones
func hide_options():
	print("OptionsManager: Ocultando opciones")
	
	# Verificar que la instancia de opciones exista
	if options_instance != null and parent_node != null:
		var canvas_layer = options_instance.get_node("CanvasLayer")
		if canvas_layer:
			# Obtener el tamaño de la pantalla
			var viewport_size = parent_node.get_viewport_rect().size
			
			# Animar la salida del menú usando Tween
			var tween = parent_node.create_tween()
			tween.tween_property(canvas_layer, "offset", Vector2(0, -viewport_size.y), 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			
			# Esperar a que termine la animación antes de liberar el nodo
			await tween.finished
			
			# Eliminar la instancia de opciones
			options_instance.queue_free()
			options_instance = null
			
			# Marcar como no visible
			is_options_visible = false
			
			# Emitir señal de que el menú se ha cerrado
			emit_signal("options_closed")
		else:
			# Si no se encuentra el CanvasLayer, eliminar la instancia directamente
			options_instance.queue_free()
			options_instance = null
			is_options_visible = false
			emit_signal("options_closed")
	else:
		print("OptionsManager: No hay opciones para ocultar")

# Función para manejar el botón de volver del menú de opciones
func _on_options_back_pressed():
	print("OptionsManager: Botón de volver presionado")
	hide_options()

# Función para verificar si el menú de opciones está visible
func is_visible():
	return is_options_visible

# Función para actualizar los textos del menú de opciones si está visible
func update_texts_if_visible():
	if is_options_visible and options_instance != null:
		if options_instance.has_method("update_ui_texts"):
			options_instance.update_ui_texts()
		else:
			print("OptionsManager: ERROR - La instancia no tiene el método update_ui_texts") 
			
