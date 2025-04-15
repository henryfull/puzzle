extends Control

# Señal para notificar cuando se cambia la dificultad
signal gamemode_changed(gamemode)
signal show_difficult(is_difficult)
@export var descriptionLabel: Label

# Estructura para almacenar las dificultades disponibles
var modes = [
	{"name": "Relax", "id": 0, "color": "ButtonBlue", "description": "game_mode_relax"},
	{"name": "normal", "id": 1, "color": "", "description": "game_mode_normal"},
	{"name": "common_timetrial", "id": 3, "color": "ButtonYellow", "description": "game_mode_timetrial"},
	{"name": "common_challenge", "id": 4, "color": "ButtonRed", "description": "game_mode_chagenlle"},
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
	$GameModeLayer/Panel/MarginContainer/VBoxContainer/PlayButton.text = tr("common_play")
	# Crear los botones de dificultad
	_create_difficulty_buttons()
	
	# Actualizar el texto del botón con la dificultad actual
	_update_button_text()
	
	# Conectar a la señal propia
	self.connect("show_difficult", Callable(self, "_on_toggle_difficult"))

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
	for i in range(modes.size()):
		var diff = modes[i]
		var button = Button.new()
		button.text = tr(diff.name)
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
	
	for i in range(modes.size()):
		var diff = modes[i]
		if diff.id == GLOBAL.gamemode:
			current_difficulty = diff.name
			descriptionLabel.text = diff.description
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
	var selected = modes[index]
	
	# Actualizar las variables globales
	GLOBAL.gamemode = selected.id

	
	# Actualizar el texto del botón
	_update_button_text()
	
	# Emitir la señal de cambio de dificultad
	emit_signal("gamemode_changed", selected.id)


# Función para limpiar cuando se sale
func _exit_tree():
	# Si el panel es hijo de la raíz, removerlo para evitar errores
	emit_signal("show_difficult", false)


func _on_play_button_pressed() -> void:
	GLOBAL.change_scene_with_loading("res://Scenes/PackSelection.tscn")
