extends Node2D

# Variables para almacenar los datos del puzzle
var puzzle_data = null
var pack_data = null
var total_moves = 0
var current_pack_id = ""
var current_puzzle_id = ""
var progress_manager = null

# Referencias a nodos de la interfaz
var image_view = null
var text_view = null
var toggle_button = null
var showing_image = true

func _ready():
	# Obtener referencia al ProgressManager
	progress_manager = get_node("/root/ProgressManager")
	
	# Obtener los datos de victoria desde GLOBAL
	if GLOBAL.has_method("get") and GLOBAL.get("victory_data") != null:
		var victory_data = GLOBAL.victory_data
		
		# Cargar los datos del puzzle
		if victory_data.has("puzzle"):
			puzzle_data = victory_data.puzzle
		
		# Cargar los datos del pack
		if victory_data.has("pack"):
			pack_data = victory_data.pack
		
		# Cargar el número de movimientos
		if victory_data.has("total_moves"):
			total_moves = victory_data.total_moves
		
		# Cargar los IDs para la navegación
		if victory_data.has("pack_id"):
			current_pack_id = victory_data.pack_id
		
		if victory_data.has("puzzle_id"):
			current_puzzle_id = victory_data.puzzle_id
		
		# Limpiar los datos de victoria para evitar problemas si se vuelve a esta escena
		GLOBAL.victory_data = null
	
	# Configurar la interfaz básica
	setup_ui()
	
	# Si tenemos datos del puzzle, mostrarlos
	if puzzle_data != null:
		update_ui_with_puzzle_data()
	else:
		# Si no hay datos, intentar usar GLOBAL.selected_puzzle como respaldo
		if GLOBAL.selected_puzzle != null:
			puzzle_data = GLOBAL.selected_puzzle
			update_ui_with_puzzle_data()

# Función para configurar la interfaz básica
func setup_ui():
	# Obtener referencias a los nodos existentes
	var vbox_container = $CanvasLayer/VBoxContainer
	
	# Asegurarse de que el contenedor principal ocupe toda la pantalla
	$CanvasLayer.layer = 10  # Asegurarse de que esté por encima de todo
	vbox_container.anchor_right = 1.0
	vbox_container.anchor_bottom = 1.0
	vbox_container.offset_left = 0
	vbox_container.offset_top = 0
	vbox_container.offset_right = 0
	vbox_container.offset_bottom = 0
	vbox_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Añadir un título
	var title = Label.new()
	title.text = "PUZZLE COMPLETADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0, 0, 0))
	vbox_container.add_child(title)
	vbox_container.move_child(title, 0)  # Mover al principio
	
	# Añadir información sobre el puzzle completado
	var info = Label.new()
	info.name = "InfoLabel"
	info.text = "Has completado el puzzle"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	vbox_container.add_child(info)
	vbox_container.move_child(info, 1)  # Mover después del título
	
	# Crear un contenedor para el contenido (imagen o texto)
	var content_container = PanelContainer.new()
	content_container.name = "ContentContainer"
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.custom_minimum_size = Vector2(350, 350)
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color(1, 1, 1, 1.0) # Fondo blanco
	content_style.corner_radius_top_left = 5
	content_style.corner_radius_top_right = 5
	content_style.corner_radius_bottom_left = 5
	content_style.corner_radius_bottom_right = 5
	content_container.add_theme_stylebox_override("panel", content_style)
	vbox_container.add_child(content_container)
	vbox_container.move_child(content_container, 2)  # Mover después de la info
	
	# Usar el Sprite2D existente para la vista de imagen
	if has_node("CanvasLayer/VBoxContainer/Sprite2D"):
		var sprite = get_node("CanvasLayer/VBoxContainer/Sprite2D")
		vbox_container.remove_child(sprite)
		content_container.add_child(sprite)
		sprite.position = Vector2(175, 175)  # Centrar en el contenedor
		sprite.scale = Vector2(0.5, 0.5)  # Ajustar escala
		image_view = sprite
	else:
		# Crear una vista de imagen si no existe
		var image_view_container = VBoxContainer.new()
		image_view_container.name = "ImageView"
		image_view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		image_view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_container.add_child(image_view_container)
		
		var image_texture_rect = TextureRect.new()
		image_texture_rect.expand = true
		image_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		image_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		image_view_container.add_child(image_texture_rect)
		
		# Añadir el panel con el nombre de la imagen en la parte inferior
		var name_panel = PanelContainer.new()
		var name_style = StyleBoxFlat.new()
		name_style.bg_color = Color(0.05, 0.15, 0.3, 1.0) # Azul oscuro
		name_panel.add_theme_stylebox_override("panel", name_style)
		name_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		image_view_container.add_child(name_panel)
		
		# Añadir el nombre de la imagen
		var image_name_label = Label.new()
		image_name_label.name = "ImageNameLabel"
		image_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		image_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		image_name_label.add_theme_font_size_override("font_size", 24)
		image_name_label.add_theme_color_override("font_color", Color(1, 1, 1))
		image_name_label.custom_minimum_size = Vector2(0, 50)
		name_panel.add_child(image_name_label)
		
		image_view = image_view_container
	
	# Crear la vista de texto
	var text_view_node = RichTextLabel.new()
	text_view_node.name = "TextView"
	text_view_node.visible = false
	text_view_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_view_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_view_node.bbcode_enabled = true
	text_view_node.scroll_active = true
	text_view_node.add_theme_font_size_override("normal_font_size", 16)
	text_view_node.add_theme_color_override("default_color", Color(0, 0, 0))
	content_container.add_child(text_view_node)
	text_view = text_view_node
	
	# Añadir un contenedor para el botón de alternancia
	var toggle_container = HBoxContainer.new()
	toggle_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_container.alignment = BoxContainer.ALIGNMENT_CENTER
	toggle_container.add_theme_constant_override("separation", 20)
	vbox_container.add_child(toggle_container)
	vbox_container.move_child(toggle_container, 3)  # Mover después del contenido
	
	# Botón para alternar entre imagen y texto
	var toggle_btn = Button.new()
	toggle_btn.text = "Texto"
	toggle_btn.custom_minimum_size = Vector2(150, 40)
	toggle_btn.add_theme_stylebox_override("normal", _create_button_style(Color(0.1, 0.3, 0.5, 1.0)))
	toggle_btn.add_theme_stylebox_override("hover", _create_button_style(Color(0.2, 0.4, 0.6, 1.0)))
	toggle_btn.add_theme_stylebox_override("pressed", _create_button_style(Color(0.05, 0.2, 0.4, 1.0)))
	toggle_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	toggle_btn.connect("pressed", Callable(self, "_on_toggle_view_pressed"))
	toggle_container.add_child(toggle_btn)
	toggle_button = toggle_btn
	
	# Configurar los botones existentes
	var hbox_buttons = $CanvasLayer/VBoxContainer/HBoxContainer
	if hbox_buttons:
		# Asegurarse de que los botones tengan el estilo correcto
		for button in hbox_buttons.get_children():
			if button is Button:
				button.custom_minimum_size = Vector2(150, 50)
				button.add_theme_stylebox_override("normal", _create_button_style(Color(0.1, 0.3, 0.5, 1.0)))
				button.add_theme_stylebox_override("hover", _create_button_style(Color(0.2, 0.4, 0.6, 1.0)))
				button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.05, 0.2, 0.4, 1.0)))
				button.add_theme_color_override("font_color", Color(1, 1, 1))

# Función para actualizar la interfaz con los datos del puzzle
func update_ui_with_puzzle_data():
	# Actualizar la información de movimientos
	var info_label = get_node_or_null("CanvasLayer/VBoxContainer/InfoLabel")
	if info_label:
		info_label.text = "Has completado el puzzle en " + str(total_moves) + " movimientos"
	
	# Actualizar la imagen
	if puzzle_data and puzzle_data.has("image"):
		var image_path = puzzle_data.image
		var image_texture = load(image_path)
		
		if image_view is Sprite2D:
			image_view.texture = image_texture
		elif image_view is VBoxContainer:
			var texture_rect = image_view.get_node_or_null("TextureRect")
			if texture_rect:
				texture_rect.texture = image_texture
			
			# Actualizar el nombre de la imagen
			var name_label = image_view.get_node_or_null("PanelContainer/ImageNameLabel")
			if name_label and puzzle_data.has("name"):
				name_label.text = puzzle_data.name.to_upper()
	
	# Actualizar el texto descriptivo
	if puzzle_data and puzzle_data.has("description") and text_view:
		# Formatear el texto para resaltar el nombre científico si existe
		var description = puzzle_data.description
		var formatted_text = description
		
		# Buscar posibles nombres científicos (en cursiva o entre comillas)
		var regex = RegEx.new()
		regex.compile("([A-Z][a-z]+ [a-z]+)")
		var result = regex.search(description)
		
		if result:
			var scientific_name = result.get_string()
			formatted_text = description.replace(scientific_name, "[color=red]" + scientific_name + "[/color]")
		
		text_view.text = formatted_text
	
	# Verificar si hay un siguiente puzzle disponible
	var next_button = get_node_or_null("CanvasLayer/VBoxContainer/HBoxContainer/Siguiente")
	if next_button and progress_manager:
		var next_puzzle = progress_manager.get_next_unlocked_puzzle(current_pack_id, current_puzzle_id)
		next_button.disabled = (next_puzzle == null)

# Función para alternar entre la vista de imagen y texto
func _on_toggle_view_pressed():
	showing_image = !showing_image
	
	# Alternar la visibilidad
	if image_view:
		image_view.visible = showing_image
	if text_view:
		text_view.visible = !showing_image
	
	# Actualizar el texto del botón
	if toggle_button:
		toggle_button.text = "Imagen" if !showing_image else "Texto"

# Función para crear un estilo de botón
func _create_button_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

# Funciones existentes para los botones
func _on_RepeatButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")

func _on_NextPuzzleButton_pressed():
	# Obtener el siguiente puzzle del pack actual
	var next_puzzle = progress_manager.get_next_unlocked_puzzle(current_pack_id, current_puzzle_id)
	
	if next_puzzle != null:
		# Si hay un siguiente puzzle, lo cargamos directamente
		GLOBAL.selected_puzzle = next_puzzle
		# Reiniciar la escena actual con el nuevo puzzle
		get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")
	else:
		# Si no hay siguiente puzzle, volvemos a la selección
		get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn")

func _on_MainMenuButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn") 
