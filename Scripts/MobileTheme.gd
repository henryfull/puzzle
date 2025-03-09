extends Resource
class_name MobileTheme

# Función estática para crear un tema adaptado a dispositivos móviles
static func create_mobile_theme() -> Theme:
	var theme = Theme.new()
	
	# Detectar si estamos en un dispositivo móvil
	var is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Obtener el factor de escala
	var scale_factor = 1.0
	if is_mobile:
		if ResourceLoader.exists("res://Scripts/UIScaler.gd"):
			var UIScaler = load("res://Scripts/UIScaler.gd")
			scale_factor = UIScaler.get_scale_factor()
		else:
			scale_factor = 1.5
	
	# Configurar tamaños de fuente para diferentes controles
	var base_font_size = 16
	theme.set_font_size("font_size", "Button", int(base_font_size * scale_factor))
	theme.set_font_size("font_size", "Label", int(base_font_size * scale_factor))
	theme.set_font_size("font_size", "LineEdit", int(base_font_size * scale_factor))
	theme.set_font_size("font_size", "RichTextLabel", int(base_font_size * scale_factor))
	theme.set_font_size("font_size", "OptionButton", int(base_font_size * scale_factor))
	
	# Configurar estilos para botones
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.4, 0.6, 1.0)
	button_style.border_width_left = int(2 * scale_factor)
	button_style.border_width_right = int(2 * scale_factor)
	button_style.border_width_top = int(2 * scale_factor)
	button_style.border_width_bottom = int(2 * scale_factor)
	button_style.border_color = Color(0.3, 0.5, 0.7, 1.0)
	button_style.corner_radius_top_left = int(5 * scale_factor)
	button_style.corner_radius_top_right = int(5 * scale_factor)
	button_style.corner_radius_bottom_left = int(5 * scale_factor)
	button_style.corner_radius_bottom_right = int(5 * scale_factor)
	
	# Añadir padding para mejor experiencia táctil
	button_style.content_margin_left = int(15 * scale_factor)
	button_style.content_margin_right = int(15 * scale_factor)
	button_style.content_margin_top = int(10 * scale_factor)
	button_style.content_margin_bottom = int(10 * scale_factor)
	
	theme.set_stylebox("normal", "Button", button_style)
	
	# Estilo para botón presionado
	var button_pressed_style = button_style.duplicate()
	button_pressed_style.bg_color = Color(0.15, 0.3, 0.5, 1.0)
	theme.set_stylebox("pressed", "Button", button_pressed_style)
	
	# Estilo para botón hover
	var button_hover_style = button_style.duplicate()
	button_hover_style.bg_color = Color(0.25, 0.45, 0.65, 1.0)
	theme.set_stylebox("hover", "Button", button_hover_style)
	
	# Estilo para botón deshabilitado
	var button_disabled_style = button_style.duplicate()
	button_disabled_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	theme.set_stylebox("disabled", "Button", button_disabled_style)
	
	# Configurar colores para botones
	theme.set_color("font_color", "Button", Color(1, 1, 1, 1))
	theme.set_color("font_hover_color", "Button", Color(1, 1, 0.8, 1))
	theme.set_color("font_pressed_color", "Button", Color(0.9, 0.9, 0.9, 1))
	theme.set_color("font_disabled_color", "Button", Color(0.7, 0.7, 0.7, 0.5))
	
	# Configurar estilos para paneles
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	panel_style.corner_radius_top_left = int(5 * scale_factor)
	panel_style.corner_radius_top_right = int(5 * scale_factor)
	panel_style.corner_radius_bottom_left = int(5 * scale_factor)
	panel_style.corner_radius_bottom_right = int(5 * scale_factor)
	panel_style.content_margin_left = int(10 * scale_factor)
	panel_style.content_margin_right = int(10 * scale_factor)
	panel_style.content_margin_top = int(10 * scale_factor)
	panel_style.content_margin_bottom = int(10 * scale_factor)
	
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	
	# Configurar constantes para contenedores
	theme.set_constant("separation", "VBoxContainer", int(10 * scale_factor))
	theme.set_constant("separation", "HBoxContainer", int(10 * scale_factor))
	
	return theme

# Función para aplicar el tema a un nodo y todos sus hijos
static func apply_theme_to_node(node: Node) -> void:
	var theme = create_mobile_theme()
	
	# Aplicar el tema al nodo actual si es un Control
	if node is Control:
		node.theme = theme
	
	# Aplicar el tema a todos los hijos recursivamente
	for child in node.get_children():
		apply_theme_to_node(child) 