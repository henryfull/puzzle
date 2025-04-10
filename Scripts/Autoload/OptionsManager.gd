extends Node

# Referencia a la escena de opciones
var options_scene = null
var options_instance = null
var options_container = null
var is_options_visible = false
var parent_node = null

# Señal que se emite cuando el menú de opciones se cierra
signal options_closed()

func _ready():
	print("OptionsManager: Inicializado")
	# Cargar la escena de opciones
	options_scene = load("res://Scenes/Options.tscn")
	if options_scene:
		print("OptionsManager: Escena de opciones cargada correctamente")
	else:
		print("OptionsManager: ERROR - No se pudo cargar la escena de opciones")

# Función para mostrar el menú de opciones
func show_options(node = null):
	if is_options_visible:
		print("OptionsManager: Las opciones ya están visibles")
		return
	
	print("OptionsManager: Mostrando opciones")
	
	# Si no se proporciona un nodo, usar el nodo actual o el viewport actual
	if node == null:
		# Intentar obtener el viewport actual
		var viewport = get_viewport()
		if viewport and viewport.get_parent():
			node = viewport.get_parent()
		else:
			# Si no hay viewport, usar el nodo actual
			node = get_tree().get_current_scene()
	
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
	
	# Almacenar referencia al contenedor de opciones
	options_container = options_instance.get_node("CanvasLayer/PanelContainer")
	
	# Conectar la señal de cierre de opciones si existe
	if options_instance.has_signal("options_closed"):
		options_instance.connect("options_closed", Callable(self, "_on_options_closed"))
	
	# Conectar la señal del botón de volver si existe
	var button = options_instance.get_node_or_null("CanvasLayer/BoxContainer/VBoxContainer3/Button")
	if button:
		button.connect("pressed", Callable(self, "_on_options_back_pressed"))
	
	# Añadir botón de restaurar compras si estamos en plataforma móvil
	if OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android"):
		_add_restore_purchases_button()
	
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
			options_container = null
			
			# Marcar como no visible
			is_options_visible = false
			
			# Emitir señal de que el menú se ha cerrado
			emit_signal("options_closed")
		else:
			# Si no se encuentra el CanvasLayer, eliminar la instancia directamente
			options_instance.queue_free()
			options_instance = null
			options_container = null
			is_options_visible = false
			emit_signal("options_closed")
	else:
		print("OptionsManager: No hay opciones para ocultar")

# Función para manejar el botón de volver del menú de opciones
func _on_options_back_pressed():
	print("OptionsManager: Botón de volver presionado")
	hide_options()

# Función para manejar la señal de cierre del menú de opciones
func _on_options_closed():
	is_options_visible = false
	
	# Emitir señal que el menú de opciones se ha cerrado
	emit_signal("options_closed")
	
	# Llamar al callback del nodo llamador si existe
	if parent_node and is_instance_valid(parent_node) and parent_node.has_method("_on_options_closed"):
		parent_node._on_options_closed()

# Función para actualizar los textos del menú de opciones si está visible
func update_texts_if_visible():
	if is_options_visible and options_instance != null:
		if options_instance.has_method("update_ui_texts"):
			options_instance.update_ui_texts()
		elif options_instance.has_method("update_texts"):
			options_instance.update_texts()
		else:
			print("OptionsManager: ERROR - La instancia no tiene el método para actualizar textos")

# Función para guardar una opción en GLOBAL
func save_option(option_name: String, value):
	print("OptionsManager: Guardando opción ", option_name, " con valor ", value)
	
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		
		# Asegurar que exista la sección puzzle en settings si es necesario
		if option_name.begins_with("pan_") or option_name.begins_with("tween_"):
			if not "puzzle" in global.settings:
				global.settings.puzzle = {}
			
			# Guardar la opción en la sección puzzle
			match option_name:
				"pan_sensitivity":
					global.settings.puzzle.pan_sensitivity = value
				"use_tween_effect":
					global.settings.puzzle.use_tween_effect = value
				"tween_duration":
					global.settings.puzzle.tween_duration = value
		
		# Guardar las configuraciones
		if global.has_method("save_settings"):
			global.save_settings()
		return true
	
	print("OptionsManager: ERROR - No se pudo guardar la opción (GLOBAL no encontrado)")
	return false

# Función para obtener una opción desde GLOBAL
func get_option(option_name: String, default_value = null):
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		
		# Obtener la opción desde la sección puzzle si es necesario
		if option_name.begins_with("pan_") or option_name.begins_with("tween_"):
			if "puzzle" in global.settings:
				match option_name:
					"pan_sensitivity":
						if "pan_sensitivity" in global.settings.puzzle:
							return global.settings.puzzle.pan_sensitivity
					"use_tween_effect":
						if "use_tween_effect" in global.settings.puzzle:
							return global.settings.puzzle.use_tween_effect
					"tween_duration":
						if "tween_duration" in global.settings.puzzle:
							return global.settings.puzzle.tween_duration
	
	# Si no se encuentra la opción, devolver el valor por defecto
	return default_value

# Función para añadir el botón de restaurar compras
func _add_restore_purchases_button():
	if options_container and not options_container.has_node("RestorePurchasesButton"):
		# Obtener referencia al contenedor de botones
		if options_container.has_node("VBoxContainer"):
			var vbox = options_container.get_node("VBoxContainer")
			
			# Añadir un separador antes del botón de restaurar compras
			var separator = HSeparator.new()
			separator.custom_minimum_size.y = 20
			vbox.add_child(separator)
			
			# Crear el botón de restaurar compras
			var restore_button = Button.new()
			restore_button.name = "RestorePurchasesButton"
			restore_button.text = tr("common_purchase_restore")
			restore_button.custom_minimum_size.y = 60
			
			# Conectar la señal de pulsación
			restore_button.connect("pressed", Callable(self, "restore_purchases"))
			
			# Añadir el botón al contenedor
			vbox.add_child(restore_button)
			
			print("OptionsManager: Botón de restaurar compras añadido")
		else:
			print("OptionsManager: No se encontró el contenedor VBoxContainer")

# Función para restaurar compras
func restore_purchases():
	if has_node("/root/PurchaseManager"):
		var purchase_manager = get_node("/root/PurchaseManager")
		purchase_manager.restore_purchases()
		
		# Mostrar un mensaje temporal de que las compras se están restaurando
		if options_container and options_container.has_node("VBoxContainer/RestorePurchasesButton"):
			var restore_button = options_container.get_node("VBoxContainer/RestorePurchasesButton")
			var original_text = restore_button.text
			restore_button.text = tr("purchase_pending")
			restore_button.disabled = true
			
			# Esperar un poco y restaurar el texto original
			await get_tree().create_timer(2.0).timeout
			
			restore_button.text = original_text
			restore_button.disabled = false
	else:
		print("OptionsManager: No se pudo encontrar el PurchaseManager para restaurar compras")
			
