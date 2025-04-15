extends Node

# Señal para notificar cuando se cambia la dificultad
signal difficulty_changed(columns, rows)
signal show_difficult(is_difficult)
@export var descriptionLabel: Label

# Estructura para almacenar las dificultades disponibles
var difficulties = [
	{"name": "difficulty_learner", "columns": 1, "rows": 1, "color": "ButtonBlue", "description": "difficulty_learner_description"},
	{"name": "difficulty_very_easy", "columns": 1, "rows": 8, "color": "", "description": "difficulty_very_easy_description"},
	{"name": "difficulty_easy", "columns": 2, "rows": 8, "color": "", "description": "difficulty_easy_description"},
	{"name": "difficulty_normal", "columns": 3, "rows": 8, "color": "ButtonYellow", "description": "difficulty_normal_description"},
	{"name": "difficulty_medium", "columns": 4, "rows": 6, "color": "ButtonYellow", "description": "difficulty_medium_description"},
	{"name": "difficulty_challenge", "columns": 4, "rows": 8, "color": "ButtonYellow", "description": "difficulty_challenge_description"},
	{"name": "difficulty_hard", "columns": 6, "rows": 8, "color": "ButtonRed", "description": "difficulty_hard_description"},
	{"name": "difficulty_very_hard", "columns": 8, "rows": 8, "color": "ButtonRed", "description": "difficulty_very_hard_description"},
	{"name": "difficulty_expert", "columns": 10, "rows": 10, "color": "ButtonRed", "description": "difficulty_expert_description"}
]
@export var difficulty_container: BoxContainer

# Referencias a nodos
var button_change
var difficulty_panel
var is_mobile = false
var emisor
var difficulty_buttons = [] # Array para guardar referencias a los botones de dificultad

func _ready():
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Obtener referencias a los nodos
	difficulty_panel = $"."
	
	# Crear los botones de dificultad
	_create_difficulty_buttons()
	
	# Actualizar el texto del botón con la dificultad actual
	_update_button_text()
	
	# Conectar a la señal propia
	self.connect("show_difficult", Callable(self, "_on_toggle_difficult"))

func _on_toggle_difficult(is_difficult: bool):
	var difLayer = $DifficultyLayer
	difLayer.visible = is_difficult
	
	# Si se está mostrando el panel, actualizar el foco
	if is_difficult:
		_update_button_text()

# Función para crear los botones de dificultad
func _create_difficulty_buttons():
	# Limpiar el array de botones por si acaso
	difficulty_buttons.clear()
	
	# Añadir las opciones de dificultad
	for i in range(difficulties.size()):
		var diff = difficulties[i]
		var button = Button.new()
		button.text = tr(diff.name) + " (" + str(diff.columns) + "x" + str(diff.rows) + ")"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.custom_minimum_size = Vector2(0, 100)
		button.tooltip_text = tr(diff.description)
		
		# Aplicar el tema de color si está definido
		if diff.color != "":
			button.theme_type_variation = diff.color
	
		# Conectar la señal del botón
		button.connect("pressed", Callable(self, "_on_difficulty_selected").bind(i))
		
		difficulty_container.add_child(button)
		difficulty_buttons.append(button) # Guardar referencia al botón

# Función para actualizar el texto del botón con la dificultad actual
func _update_button_text():
	# Buscar la dificultad actual
	var current_difficulty = "Personalizado"
	var selected_index = -1
	
	for i in range(difficulties.size()):
		var diff = difficulties[i]
		if diff.columns == GLOBAL.columns and diff.rows == GLOBAL.rows:
			current_difficulty = tr(diff.name)
			descriptionLabel.text = tr(diff.description)
			selected_index = i
			break
	
	# Si encontramos el índice de la dificultad seleccionada
	if selected_index != -1 and selected_index < difficulty_buttons.size():
		# Dar foco al botón seleccionado
		difficulty_buttons[selected_index].grab_focus()
		
		# Asegurar que el botón está visible en el scroll (si el contenedor es ScrollContainer)
		var parent = difficulty_container.get_parent()
		if parent is ScrollContainer:
			# Calcular la posición del botón dentro del ScrollContainer
			var button_position = difficulty_buttons[selected_index].position.y
			
			# Ajustar el scroll para mostrar el botón
			parent.scroll_vertical = button_position
	
# Función llamada cuando se selecciona una dificultad
func _on_difficulty_selected(index):
	var selected = difficulties[index]
	
	# Actualizar las variables globales
	GLOBAL.columns = selected.columns
	GLOBAL.rows = selected.rows
	
	# Actualizar el texto del botón
	_update_button_text()
	
	# Emitir la señal de cambio de dificultad
	emit_signal("difficulty_changed", selected.columns, selected.rows)


# Función para limpiar cuando se sale
func _exit_tree():
	# Si el panel es hijo de la raíz, removerlo para evitar errores
	emit_signal("show_difficult", false)
