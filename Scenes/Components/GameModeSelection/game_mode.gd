extends Control

# Señal para notificar cuando se cambia la dificultad
signal gamemode_changed(gamemode)
signal show_difficult(is_difficult)

@export var descriptionLabel: Label
@export var panelColor = PanelContainer
@export var headerColor = Panel

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
	$GameModeLayer/Panel/MarginContainer/VBoxContainer/PlayButton.text = tr("common_play")
	# Crear los botones de dificultad
	_create_difficulty_buttons()
	
	
	# Actualizar el texto del botón con la dificultad actual
	_update_button_text()
	
	# Conectar a la señal propia
	self.connect("show_difficult", Callable(self, "_on_toggle_difficult"))
	updateColor()

func updateColor():
	GLOBAL.setColorMode(panelColor, headerColor)


func _on_toggle_difficult(is_difficult: bool):
	var difLayer = $GameModeLayer
	difLayer.visible = is_difficult
	
	# Si se está mostrando el panel, actualizar el foco
	if is_difficult:
		_update_button_text()

# Función para crear los botones de dificultad
func _create_difficulty_buttons():
	# Limpiar el array de botones por si acaso
	difficulty_buttons.clear()
	
	# Añadir las opciones de dificultad
	for i in range(GLOBAL.modes.size()):
		var diff = GLOBAL.modes[i]
		var button = Button.new()
		button.text = tr(diff.name)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.custom_minimum_size = Vector2(0, 120)
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
	
	for i in range(GLOBAL.modes.size()):
		var diff = GLOBAL.modes[i]
		if diff.id == GLOBAL.gamemode:
			current_difficulty = diff.name
			descriptionLabel.text = diff.description
			selected_index = i
			break
	
	
# Función llamada cuando se selecciona una dificultad
func _on_difficulty_selected(index):
	var selected = GLOBAL.modes[index]
	
	# Actualizar las variables globales
	GLOBAL.gamemode = selected.id
	if(selected.id == 0): 
		GLOBAL.columns = 1
		GLOBAL.rows = 4
		GLOBAL.is_learner = true
	elif (selected.id == 3): 
		GLOBAL.columns = 4
		GLOBAL.rows = 6
	else:
		GLOBAL.is_learner = false

	
	# Actualizar el texto del botón
	_update_button_text()
	
	# Emitir la señal de cambio de dificultad
	emit_signal("gamemode_changed", selected.id)
	updateColor()
	GLOBAL.save_settings()


# Función para limpiar cuando se sale
func _exit_tree():
	# Si el panel es hijo de la raíz, removerlo para evitar errores
	emit_signal("show_difficult", false)


func _on_play_button_pressed() -> void:
	GLOBAL.change_scene_with_loading("res://Scenes/PackSelection.tscn")


func _on_button_pressed(index) -> void:
	print(index)
