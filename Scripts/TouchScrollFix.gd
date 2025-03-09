# Script para configurar correctamente los filtros de ratón en todos los nodos
# para mejorar el desplazamiento táctil

extends Node

# Llamar a esta función desde _ready() en la escena principal
static func configure_touch_scroll(root_node: Node) -> void:
	print("Configurando filtros de ratón para mejorar el desplazamiento táctil...")
	
	# Configurar recursivamente todos los nodos
	_configure_node_recursive(root_node)
	
	print("Configuración de desplazamiento táctil completada.")

# Función recursiva para configurar cada nodo
static func _configure_node_recursive(node: Node) -> void:
	# Configurar el nodo actual si es un Control
	if node is Control:
		_configure_control_node(node)
	
	# Configurar recursivamente todos los hijos
	for child in node.get_children():
		_configure_node_recursive(child)

# Configurar un nodo de Control específico
static func _configure_control_node(control: Control) -> void:
	# ScrollContainer debe tener MOUSE_FILTER_STOP para capturar los eventos táctiles
	if control is ScrollContainer:
		# Verificar si ya tiene un script de manejo táctil
		if control.has_method("_handle_touch_event"):
			print("ScrollContainer ya tiene script de manejo táctil: ", control.name)
		else:
			# Intentar adjuntar el script TouchScrollHandler
			var touch_handler_script = load("res://Scripts/TouchScrollHandler.gd")
			if touch_handler_script:
				control.set_script(touch_handler_script)
				print("Script TouchScrollHandler adjuntado al ScrollContainer: ", control.name)
			else:
				# Si no se puede cargar el script, configurar manualmente
				control.mouse_filter = Control.MOUSE_FILTER_STOP
				control.scroll_deadzone = 10
				print("Configurado ScrollContainer manualmente: ", control.name)
	
	# Los contenedores dentro de ScrollContainer deben tener MOUSE_FILTER_IGNORE
	# para que no interfieran con el desplazamiento
	elif control.get_parent() is ScrollContainer:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		print("Configurado contenedor hijo directo de ScrollContainer: ", control.name)
	
	# Los botones y otros controles interactivos dentro de ScrollContainer
	# deben tener MOUSE_FILTER_STOP para capturar sus propios eventos
	elif _is_inside_scroll_container(control):
		if control is Button or control is TextureButton or control is LinkButton:
			control.mouse_filter = Control.MOUSE_FILTER_STOP
			print("Configurado botón dentro de ScrollContainer: ", control.name)
		else:
			# Otros controles dentro del ScrollContainer que no necesitan interacción
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			print("Configurado control dentro de ScrollContainer: ", control.name)

# Verificar si un nodo está dentro de un ScrollContainer
static func _is_inside_scroll_container(node: Node) -> bool:
	var parent = node.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false

# Función para conectar señales de ScrollContainer
static func connect_scroll_signals(scroll_container: ScrollContainer, target: Object, start_method: String, end_method: String) -> void:
	if scroll_container:
		# Verificar si el ScrollContainer tiene las señales personalizadas
		if scroll_container.has_signal("touch_scroll_started") and scroll_container.has_signal("touch_scroll_ended"):
			# Desconectar señales existentes para evitar duplicados
			if scroll_container.is_connected("touch_scroll_started", Callable(target, start_method)):
				scroll_container.disconnect("touch_scroll_started", Callable(target, start_method))
			
			if scroll_container.is_connected("touch_scroll_ended", Callable(target, end_method)):
				scroll_container.disconnect("touch_scroll_ended", Callable(target, end_method))
			
			# Conectar las señales personalizadas
			scroll_container.connect("touch_scroll_started", Callable(target, start_method))
			scroll_container.connect("touch_scroll_ended", Callable(target, end_method))
			
			print("Señales personalizadas de ScrollContainer conectadas correctamente")
		else:
			# Usar las señales estándar si no tiene las personalizadas
			if scroll_container.is_connected("scroll_started", Callable(target, start_method)):
				scroll_container.disconnect("scroll_started", Callable(target, start_method))
			
			if scroll_container.is_connected("scroll_ended", Callable(target, end_method)):
				scroll_container.disconnect("scroll_ended", Callable(target, end_method))
			
			# Conectar las señales estándar
			scroll_container.connect("scroll_started", Callable(target, start_method))
			scroll_container.connect("scroll_ended", Callable(target, end_method))
			
			print("Señales estándar de ScrollContainer conectadas correctamente") 