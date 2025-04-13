extends Control

# Señal para notificar cuando se cambia la dificultad
signal difficulty_changed(columns, rows)
signal show_difficult(is_difficult)

# Estructura para almacenar las dificultades disponibles
var difficulties = [
	{"name": "Aprendizaje", "columns": 1, "rows": 1},
	{"name": "Muy Fácil", "columns": 2, "rows": 2},
	{"name": "Fácil", "columns": 3, "rows": 3},
	{"name": "Normal", "columns": 4, "rows": 4},
	{"name": "Medio", "columns": 4, "rows": 6},
	{"name": "Desafiante", "columns": 4, "rows": 8},
	{"name": "Difícil", "columns": 6, "rows": 8},
	{"name": "Muy Difícil", "columns": 8, "rows": 8},
	{"name": "Experto", "columns": 10, "rows": 10}
]

# Referencias a nodos
var button_change
var difficulty_panel
var is_mobile = false

func _ready():
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
 
	difficulty_panel = $DifficultyPanel
	
	# Configurar el botón
	button_change = $ButtonChange
	button_change.text = "Dificultad"
	# Conectar el botón de cerrar

	
	# Actualizar el texto del botón con la dificultad actual
	_update_button_text()
	
	# Ocultar el panel al inicio


# Función para actualizar el texto del botón con la dificultad actual
func _update_button_text():
	# Buscar la dificultad actual
	var current_difficulty = "Personalizado"
	for diff in difficulties:
		if diff.columns == GLOBAL.columns and diff.rows == GLOBAL.rows:
			current_difficulty = diff.name
			break
	
	button_change.text = "Dificultad: " + current_difficulty


# Función llamada cuando se presiona el botón de cerrar
func _on_close_button_pressed():
	emit_signal("show_difficult", true)
