extends Control

# Señal para notificar cuando se cambia la dificultad
signal difficulty_changed(columns, rows)

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
var difficulty_layer
var difficulty_panel
var difficulty_container
var is_mobile = false

func _ready():
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Obtener referencias a los nodos
	button_change = $ButtonChange
	difficulty_layer = $DifficultyLayer
	difficulty_panel = $DifficultyLayer/DifficultyPanel
	difficulty_container = $DifficultyLayer/DifficultyPanel/VBoxContainer/ScrollContainer/DifficultyContainer
	
	# Configurar el botón
	button_change.text = "Dificultad"
	button_change.custom_minimum_size = Vector2(160, 60)
	

	
	# Conectar la señal del botón
	if not button_change.is_connected("pressed", Callable(self, "_on_button_change_pressed")):
		button_change.connect("pressed", Callable(self, "_on_button_change_pressed"))
		
	# Conectar el botón de cerrar
	$DifficultyLayer/DifficultyPanel/VBoxContainer/CloseButton.connect("pressed", Callable(self, "_on_close_button_pressed"))
	
	# Crear los botones de dificultad
	_create_difficulty_buttons()
	
	# Actualizar el texto del botón con la dificultad actual
	_update_button_text()
	
	# Ocultar el panel al inicio
	difficulty_layer.visible = false

# Función para crear los botones de dificultad
func _create_difficulty_buttons():
	# Añadir las opciones de dificultad
	for i in range(difficulties.size()):
		var diff = difficulties[i]
		var button = Button.new()
		button.text = diff.name + " (" + str(diff.columns) + "x" + str(diff.rows) + ")"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Ajustar tamaño para móviles
		if is_mobile:
			button.custom_minimum_size = Vector2(0, 60)
			button.add_theme_font_size_override("font_size", 24)
		else:
			button.custom_minimum_size = Vector2(0, 40)
		
		# Conectar la señal del botón
		button.connect("pressed", Callable(self, "_on_difficulty_selected").bind(i))
		
		difficulty_container.add_child(button)

# Función para actualizar el texto del botón con la dificultad actual
func _update_button_text():
	# Buscar la dificultad actual
	var current_difficulty = "Personalizado"
	for diff in difficulties:
		if diff.columns == GLOBAL.columns and diff.rows == GLOBAL.rows:
			current_difficulty = diff.name
			break
	
	button_change.text = "Dificultad: " + current_difficulty

# Función llamada cuando se presiona el botón de cambio
func _on_button_change_pressed():
	# Mostrar el CanvasLayer que contiene el panel
	difficulty_layer.visible = true

# Función llamada cuando se selecciona una dificultad
func _on_difficulty_selected(index):
	var selected = difficulties[index]
	
	# Actualizar las variables globales
	GLOBAL.columns = selected.columns
	GLOBAL.rows = selected.rows
	
	# Actualizar el texto del botón
	_update_button_text()
	
	# Ocultar el panel
	difficulty_layer.visible = false
	
	# Emitir la señal de cambio de dificultad
	emit_signal("difficulty_changed", selected.columns, selected.rows)

# Función llamada cuando se presiona el botón de cerrar
func _on_close_button_pressed():
	difficulty_layer.visible = false

# Función para limpiar cuando se sale
func _exit_tree():
	# Si el panel es hijo de la raíz, removerlo para evitar errores
	if difficulty_panel and is_instance_valid(difficulty_panel) and difficulty_panel.get_parent() != self:
		difficulty_panel.queue_free()
