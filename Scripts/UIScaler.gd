extends Node

# Factor de escala base para dispositivos móviles
const MOBILE_SCALE_FACTOR = 1.5

# Obtener el factor de escala adecuado según el dispositivo
static func get_scale_factor():
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		# Obtener el tamaño de la pantalla
		var screen_size = DisplayServer.window_get_size()
		var min_dimension = min(screen_size.x, screen_size.y)
		
		# Ajustar el factor según el tamaño de la pantalla
		if min_dimension < 600:
			return MOBILE_SCALE_FACTOR * 1.2  # Pantallas muy pequeñas
		elif min_dimension < 900:
			return MOBILE_SCALE_FACTOR
		else:
			return MOBILE_SCALE_FACTOR * 0.9  # Tablets grandes
	else:
		return 1.0  # Sin escala adicional para PC

# Escalar un botón para adaptarlo al dispositivo
static func scale_button(button):
	var scale = get_scale_factor()
	
	# Ajustar tamaño mínimo
	button.custom_minimum_size = Vector2(
		max(150, button.custom_minimum_size.x) * scale,
		max(50, button.custom_minimum_size.y) * scale
	)
	
	# Ajustar tamaño de fuente
	var current_size = button.get_theme_font_size("font_size") if button.has_theme_font_size_override("font_size") else 16
	button.add_theme_font_size_override("font_size", int(current_size * scale))
	
	# Ajustar padding
	var padding = 10 * scale
	button.add_theme_constant_override("h_separation", int(padding))
	button.add_theme_constant_override("content_margin_left", int(padding))
	button.add_theme_constant_override("content_margin_right", int(padding))
	button.add_theme_constant_override("content_margin_top", int(padding))
	button.add_theme_constant_override("content_margin_bottom", int(padding))

# Escalar todos los botones en un contenedor
static func scale_buttons_in_container(container):
	for child in container.get_children():
		if child is Button:
			scale_button(child)
		elif child is Container:
			scale_buttons_in_container(child)
			
# Escalar una etiqueta para adaptarla al dispositivo
static func scale_label(label):
	var scale = get_scale_factor()
	
	# Ajustar tamaño de fuente
	var current_size = label.get_theme_font_size("font_size") if label.has_theme_font_size_override("font_size") else 16
	label.add_theme_font_size_override("font_size", int(current_size * scale))
	
	# Ajustar márgenes si es necesario
	if scale > 1.0:
		label.add_theme_constant_override("margin_top", int(5 * scale))
		label.add_theme_constant_override("margin_bottom", int(5 * scale))

# Escalar todas las etiquetas en un contenedor
static func scale_labels_in_container(container):
	for child in container.get_children():
		if child is Label:
			scale_label(child)
		elif child is Container:
			scale_labels_in_container(child)
			
# Escalar un panel para adaptarlo al dispositivo
static func scale_panel(panel):
	var scale = get_scale_factor()
	
	# Ajustar márgenes
	panel.add_theme_constant_override("margin_left", int(10 * scale))
	panel.add_theme_constant_override("margin_right", int(10 * scale))
	panel.add_theme_constant_override("margin_top", int(10 * scale))
	panel.add_theme_constant_override("margin_bottom", int(10 * scale))

# Función para escalar toda la UI de una escena
static func scale_ui(node):
	if node is Button:
		scale_button(node)
	elif node is Label:
		scale_label(node)
	elif node is PanelContainer:
		scale_panel(node)
		
	# Escalar hijos recursivamente
	for child in node.get_children():
		scale_ui(child) 