extends Node

# Señal que se emite cuando cambia el tema
signal theme_changed

# Variable para almacenar el tema actual
var current_theme: Theme = null

# Variable para detectar si estamos en un dispositivo móvil
var is_mobile = false

func _ready():
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Crear y aplicar el tema según el dispositivo
	if is_mobile:
		apply_mobile_theme()
	else:
		apply_desktop_theme()
	
	# Conectar señal para adaptar el tema cuando cambia la escena
	get_tree().root.connect("ready", Callable(self, "_on_scene_ready"))

# Función para aplicar el tema móvil
func apply_mobile_theme():
	# Verificar si existe el script MobileTheme
	if ResourceLoader.exists("res://Scripts/MobileTheme.gd"):
		var MobileTheme = load("res://Scripts/MobileTheme.gd")
		current_theme = MobileTheme.create_mobile_theme()
		
		# Aplicar el tema a la escena actual
		apply_theme_to_current_scene()
		
		# Emitir señal de cambio de tema
		theme_changed.emit()
		
		print("ThemeManager: Tema móvil aplicado")
	else:
		push_warning("ThemeManager: No se encontró el script MobileTheme.gd")

# Función para aplicar el tema de escritorio
func apply_desktop_theme():
	# Aquí podrías cargar un tema predefinido para escritorio
	# Por ahora, simplemente usamos el tema predeterminado
	current_theme = null
	
	# Emitir señal de cambio de tema
	theme_changed.emit()
	
	print("ThemeManager: Tema de escritorio aplicado")

# Función para aplicar el tema a la escena actual
func apply_theme_to_current_scene():
	if current_theme == null:
		return
	
	var root = get_tree().root
	var current_scene = root.get_child(root.get_child_count() - 1)
	
	# Aplicar el tema recursivamente a todos los nodos de la escena
	apply_theme_to_node(current_scene)

# Función para aplicar el tema a un nodo y todos sus hijos
func apply_theme_to_node(node: Node):
	if current_theme == null:
		return
	
	# Aplicar el tema al nodo actual si es un Control
	if node is Control:
		node.theme = current_theme
	
	# Aplicar el tema a todos los hijos recursivamente
	for child in node.get_children():
		apply_theme_to_node(child)

# Función llamada cuando una nueva escena está lista
func _on_scene_ready():
	# Aplicar el tema a la nueva escena
	apply_theme_to_current_scene()

# Función para obtener el tema actual
func get_current_theme() -> Theme:
	return current_theme 