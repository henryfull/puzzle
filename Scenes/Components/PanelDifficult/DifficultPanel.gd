extends Node

# Señal para notificar cuando se cambia la dificultad
signal difficulty_changed(columns, rows)
signal show_difficult(is_difficult)

@export var difficulty_container: GridContainer
@export var _numPieces : Label
@export var descriptionLabel: Label
@export var progressiveDifficultButton: Button
@export var _control: Control

var current_difficulty
var isProgressive = false
var num_pieces = 8
# Estructura para almacenar las dificultades disponibles


# Referencias a nodos
var button_change
var difficulty_panel
var is_mobile = false
var emisor
var difficulty_buttons = [] # Array para guardar referencias a los botones de dificultad
var difficulty_button_group := ButtonGroup.new()

func _ready():
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	isProgressive = GLOBAL.progresive_difficulty
	difficulty_button_group.allow_unpress = false
	
	# Obtener referencias a los nodos
	difficulty_panel = $"."
	
	# Actualiza el boton progresivo
	_updateProgressiveButton()
	
	# Crear los botones de dificultad
	_create_difficulty_buttons()
	
	# Actualizar el texto del botón con la dificultad actual
	_update_button_text()
	# Conectar a la señal propia
	updateColumRows()
	self.connect("show_difficult", Callable(self, "_on_toggle_difficult"))
	
func _updateProgressiveButton():
	if isProgressive:
		progressiveDifficultButton.text = "ON"
		_control.visible = true
	else :
		progressiveDifficultButton.text = "OFF"
		_control.visible = false


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
		button.toggle_mode = true
		button.button_group = difficulty_button_group
		
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
	num_pieces = GLOBAL.rows * GLOBAL.columns
	_numPieces.text = str(num_pieces)
	
	for i in range(GLOBAL.difficulties.size()):
		var diff = GLOBAL.difficulties[i]
		if diff.columns == GLOBAL.columns and diff.rows == GLOBAL.rows:
			current_difficulty = tr(diff.name)
			descriptionLabel.text = tr(diff.description)
			selected_index = i
			break

	_update_selected_difficulty_button(selected_index)

func _update_selected_difficulty_button(selected_index: int) -> void:
	for i in range(difficulty_buttons.size()):
		var button: Button = difficulty_buttons[i]
		if is_instance_valid(button):
			button.button_pressed = i == selected_index

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


func updateColumRows():
	$DifficultyLayer/HeaderPanelColor/VBoxContainer/SubTitleLabel.text = current_difficulty + " (" +str(GLOBAL.columns) + " x " + str(GLOBAL.rows) + ")"


func _on_button_profresive_difficult_toggled(toggled_on: bool) -> void:
	print(toggled_on)
	GLOBAL.progresive_difficulty = toggled_on
	isProgressive = toggled_on
	
	# Guardar la configuración
	GLOBAL.save_settings()
	_updateProgressiveButton()
