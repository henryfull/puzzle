extends Node

# Señal para notificar cuando se cambia la dificultad
signal difficulty_changed(columns, rows)
signal show_difficult(is_difficult)
@export var descriptionLabel: Label

# Estructura para almacenar las dificultades disponibles
var difficulties = [
	{"name": "Aprendizaje", "columns": 1, "rows": 1, "color": "ButtonBlue", "description": "El modo APRENDIZ esta enfocado para que los niños aprendan formas, colores, no números de manera visual. Cuando se selecciona un puzzle directamente te muestra la imagen y un texto relacionado con la imagen. "},
	{"name": "Muy Fácil", "columns": 2, "rows": 2, "color": "", "description": "Perfecto para principiantes con sólo 4 piezas. Ideal para niños pequeños que comienzan a desarrollar habilidades de resolución de puzles."},
	{"name": "Fácil", "columns": 3, "rows": 3, "color": "", "description": "Con 9 piezas, este nivel ofrece un desafío suave que ayuda a mejorar la concentración y coordinación visual sin resultar frustrante."},
	{"name": "Normal", "columns": 4, "rows": 4, "color": "ButtonYellow", "description": "El nivel estándar con 16 piezas. Equilibrado para jugadores casuales que buscan un reto moderado sin demasiada complejidad."},
	{"name": "Medio", "columns": 4, "rows": 6, "color": "ButtonYellow", "description": "Aumenta la dificultad con 24 piezas. Requiere más atención al detalle y es adecuado para quienes ya dominan los niveles anteriores."},
	{"name": "Desafiante", "columns": 4, "rows": 8, "color": "ButtonYellow", "description": "Con 32 piezas, este nivel pone a prueba tu paciencia y habilidad para reconocer patrones. Recomendado para jugadores con experiencia."},
	{"name": "Difícil", "columns": 6, "rows": 8, "color": "ButtonRed", "description": "48 piezas que exigen concentración sostenida y estrategia. Un verdadero reto que pondrá a prueba tus habilidades de resolución."},
	{"name": "Muy Difícil", "columns": 8, "rows": 8, "color": "ButtonRed", "description": "64 piezas para expertos. Requiere excelente memoria visual, paciencia y capacidad para trabajar sistemáticamente con muchas piezas similares."},
	{"name": "Experto", "columns": 10, "rows": 10, "color": "ButtonRed", "description": "El máximo desafío con 100 piezas. Solo para maestros del puzle con excepcional atención al detalle y resistencia mental."}
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
		button.text = diff.name + " (" + str(diff.columns) + "x" + str(diff.rows) + ")"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.custom_minimum_size = Vector2(0, 100)
		button.tooltip_text = diff.description
		
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
