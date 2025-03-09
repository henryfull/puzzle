extends Node

# Este script se debe añadir como autoload en el proyecto
# para asegurar que la UI se adapte correctamente en todas las escenas

# Señal que se emite cuando cambia la escala de la UI
signal ui_scale_changed(scale_factor)

# Variable para almacenar el factor de escala actual
var current_scale_factor = 1.0

func _ready():
	# Detectar si estamos en un dispositivo móvil
	var is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Configurar la escala de la UI según el dispositivo
	if is_mobile:
		# Usar UIScaler si está disponible
		if ResourceLoader.exists("res://Scripts/UIScaler.gd"):
			var UIScaler = load("res://Scripts/UIScaler.gd")
			current_scale_factor = UIScaler.get_scale_factor()
		else:
			# Si no existe el script UIScaler, usar un valor predeterminado
			current_scale_factor = 1.5
	
	# Conectar señal para adaptar la UI cuando cambia la escena
	get_tree().root.connect("size_changed", Callable(self, "_on_window_size_changed"))
	
	# Esperar un frame para asegurarnos de que GLOBAL esté inicializado
	await get_tree().process_frame
	
	# Actualizar la escala en GLOBAL si existe
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		if global.has_method("get") and global.get("settings") != null:
			global.settings.ui_scale = current_scale_factor
			if global.has_method("save_settings"):
				global.save_settings()
	
	# Emitir señal para que las escenas actuales se adapten
	ui_scale_changed.emit(current_scale_factor)

# Función para adaptar la UI de una escena
func adapt_scene_ui(scene_root):
	# Usar UIScaler si está disponible
	if ResourceLoader.exists("res://Scripts/UIScaler.gd"):
		var UIScaler = load("res://Scripts/UIScaler.gd")
		UIScaler.scale_ui(scene_root)
	else:
		# Si no existe UIScaler, aplicar escalado básico
		apply_basic_scaling(scene_root)

# Función para aplicar un escalado básico a los controles
func apply_basic_scaling(node):
	# Escalar según el tipo de nodo
	if node is Button:
		scale_button(node)
	elif node is Label:
		scale_label(node)
	elif node is LineEdit or node is TextEdit or node is RichTextLabel:
		scale_text_control(node)
	elif node is OptionButton or node is MenuButton:
		scale_button(node)
	elif node is HSlider or node is VSlider:
		scale_slider(node)
	
	# Escalar hijos recursivamente
	for child in node.get_children():
		apply_basic_scaling(child)

# Función para escalar un botón
func scale_button(button):
	button.custom_minimum_size = Vector2(
		max(150, button.custom_minimum_size.x) * current_scale_factor,
		max(50, button.custom_minimum_size.y) * current_scale_factor
	)
	
	var font_size = button.get_theme_font_size("font_size") if button.has_theme_font_size_override("font_size") else 16
	button.add_theme_font_size_override("font_size", int(font_size * current_scale_factor))

# Función para escalar una etiqueta
func scale_label(label):
	var font_size = label.get_theme_font_size("font_size") if label.has_theme_font_size_override("font_size") else 16
	label.add_theme_font_size_override("font_size", int(font_size * current_scale_factor))

# Función para escalar un control de texto
func scale_text_control(control):
	var font_size = control.get_theme_font_size("font_size") if control.has_theme_font_size_override("font_size") else 16
	control.add_theme_font_size_override("font_size", int(font_size * current_scale_factor))

# Función para escalar un slider
func scale_slider(slider):
	if slider is HSlider:
		slider.custom_minimum_size = Vector2(100 * current_scale_factor, slider.custom_minimum_size.y)
	elif slider is VSlider:
		slider.custom_minimum_size = Vector2(slider.custom_minimum_size.x, 100 * current_scale_factor)

# Función llamada cuando cambia el tamaño de la ventana
func _on_window_size_changed():
	# Recalcular la escala si es necesario
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		# Usar UIScaler si está disponible
		if ResourceLoader.exists("res://Scripts/UIScaler.gd"):
			var UIScaler = load("res://Scripts/UIScaler.gd")
			var new_scale = UIScaler.get_scale_factor()
			
			# Si la escala ha cambiado, actualizar y emitir señal
			if abs(new_scale - current_scale_factor) > 0.1:
				current_scale_factor = new_scale
				ui_scale_changed.emit(current_scale_factor)
				
				# Actualizar la escala en GLOBAL si existe
				if has_node("/root/GLOBAL"):
					var global = get_node("/root/GLOBAL")
					if global.has_method("get") and global.get("settings") != null:
						global.settings.ui_scale = current_scale_factor
						if global.has_method("save_settings"):
							global.save_settings() 