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


# Función para obtener el tema actual
func get_current_theme() -> Theme:
	return current_theme 
