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
var popup_panel
var difficulty_container
var is_mobile = false

func _ready():
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Obtener referencia al botón
	button_change = $ButtonChange
	
	# Configurar el botón
	button_change.text = "Dificultad"
	button_change.custom_minimum_size = Vector2(160, 60)
	
	# Ajustar tamaño para móviles
	if is_mobile:
		button_change.custom_minimum_size = Vector2(180, 70)
		button_change.add_theme_font_size_override("font_size", 24)
	
	# Conectar la señal del botón
	if not button_change.is_connected("pressed", Callable(self, "_on_button_change_pressed")):
		button_change.connect("pressed", Callable(self, "_on_button_change_pressed"))
	
	# Crear el panel emergente
	_create_popup_panel()
	
	# Actualizar el texto del botón con la dificultad actual
	_update_button_text()

# Función para crear el panel emergente con las opciones de dificultad
func _create_popup_panel():
	# Crear el panel emergente
	popup_panel = PopupPanel.new()
	popup_panel.size = Vector2(300, 400)
	
	# Ajustar tamaño para móviles
	if is_mobile:
		popup_panel.size = Vector2(400, 600)
	
	# Crear un contenedor para las opciones
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(280, 380)
	
	# Ajustar tamaño para móviles
	if is_mobile:
		vbox.custom_minimum_size = Vector2(380, 580)
	
	# Añadir un título
	var title = Label.new()
	title.text = "Selecciona la Dificultad"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Ajustar tamaño de fuente para móviles
	if is_mobile:
		title.add_theme_font_size_override("font_size", 28)
	else:
		title.add_theme_font_size_override("font_size", 18)
	
	vbox.add_child(title)
	
	# Añadir un separador
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Crear un ScrollContainer para las opciones
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Crear un contenedor para las opciones de dificultad
	difficulty_container = VBoxContainer.new()
	difficulty_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
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
	
	scroll.add_child(difficulty_container)
	vbox.add_child(scroll)
	
	# Añadir un botón para cerrar
	var close_button = Button.new()
	close_button.text = "Cancelar"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Ajustar tamaño para móviles
	if is_mobile:
		close_button.custom_minimum_size = Vector2(0, 60)
		close_button.add_theme_font_size_override("font_size", 24)
	else:
		close_button.custom_minimum_size = Vector2(0, 40)
	
	close_button.connect("pressed", Callable(self, "_on_close_button_pressed"))
	vbox.add_child(close_button)
	
	# Añadir el contenedor al panel emergente
	popup_panel.add_child(vbox)
	
	# Añadir el panel emergente a la escena
	add_child(popup_panel)

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
	# Centrar el popup en la pantalla
	var viewport_size = get_viewport_rect().size
	# Convertir el tamaño del popup a Vector2 para evitar el error de tipos
	var popup_size = Vector2(popup_panel.size.x, popup_panel.size.y)
	popup_panel.position = (viewport_size - popup_size) / 2
	
	# Mostrar el panel emergente
	popup_panel.popup()

# Función llamada cuando se selecciona una dificultad
func _on_difficulty_selected(index):
	var selected = difficulties[index]
	
	# Actualizar las variables globales
	GLOBAL.columns = selected.columns
	GLOBAL.rows = selected.rows
	
	# Actualizar el texto del botón
	_update_button_text()
	
	# Cerrar el panel emergente
	popup_panel.hide()
	
	# Emitir la señal de cambio de dificultad
	emit_signal("difficulty_changed", selected.columns, selected.rows)

# Función llamada cuando se presiona el botón de cerrar
func _on_close_button_pressed():
	popup_panel.hide()
