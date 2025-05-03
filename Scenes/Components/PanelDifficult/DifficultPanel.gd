extends Node

# Señal para notificar cuando se cambia la dificultad
signal difficulty_changed(columns, rows)
signal show_difficult(is_difficult)
@export var descriptionLabel: Label
var current_difficulty
# Estructura para almacenar las dificultades disponibles

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
	$DifficultyLayer/Panel/MarginContainer/VBoxContainer/CheckButtonDifficult["button_pressed"] = GLOBAL.progresive_difficulty
	# Conectar a la señal propia
	updateColumRows()
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
	for i in range(GLOBAL.difficulties.size()):
		var diff = GLOBAL.difficulties[i]
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
	current_difficulty = "Personalizado"
	var selected_index = -1
	
	for i in range(GLOBAL.difficulties.size()):
		var diff = GLOBAL.difficulties[i]
		if diff.columns == GLOBAL.columns and diff.rows == GLOBAL.rows:
			current_difficulty = tr(diff.name)
			descriptionLabel.text = tr(diff.description)
			selected_index = i
			break
	

# Función llamada cuando se selecciona una dificultad
func _on_difficulty_selected(index):
	var selected = GLOBAL.difficulties[index]
	GLOBAL.current_difficult = index
	
	# Actualizar las variables globales
	GLOBAL.columns = selected.columns
	GLOBAL.rows = selected.rows
	GLOBAL.is_learner = false
	if(GLOBAL.gamemode == 0):
		# Se establece el modo normal si es learner al cambiar de dificultad
		GLOBAL.gamemode = 2
	
	# Actualizar el texto del botón
	_update_button_text()
	
	# Guardar la configuración
	GLOBAL.save_settings()
	
	# Emitir la señal de cambio de dificultad
	emit_signal("difficulty_changed", selected.columns, selected.rows)
	updateColumRows()


# Función para limpiar cuando se sale
func _exit_tree():
	# Si el panel es hijo de la raíz, removerlo para evitar errores
	emit_signal("show_difficult", false)


func _on_check_button_pressed() -> void:
	if(GLOBAL.progresive_difficulty):
		GLOBAL.progresive_difficulty = false
	else:
		GLOBAL.progresive_difficulty = true
	
	# Guardar la configuración
	GLOBAL.save_settings()

func updateColumRows():
	$DifficultyLayer/HeaderPanelColor/VBoxContainer/SubTitleLabel.text = current_difficulty + " (" +str(GLOBAL.columns) + " x " + str(GLOBAL.rows) + ")"
