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
	
	# Obtener referencias a los elementos de la interfaz
	var title = $CanvasLayer/VBoxContainer/LabelTitle
	title.text = "PUZZLE COMPLETADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0, 0, 0))
	
	var info = $CanvasLayer/VBoxContainer/LabelInfo
	info.text = "Has completado el puzzle"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	
	var content_container = $CanvasLayer/VBoxContainer/PanelContainer
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color(1, 1, 1, 1.0) # Fondo blanco
	content_style.corner_radius_top_left = 5
	content_style.corner_radius_top_right = 5
	content_style.corner_radius_bottom_left = 5
	content_style.corner_radius_bottom_right = 5
	content_container.add_theme_stylebox_override("panel", content_style)
	
	# Configurar la vista de imagen
	var image_view_container = $CanvasLayer/VBoxContainer/PanelContainer/ImageView
	if image_view_container:
		var texture_rect = image_view_container.get_node_or_null("TextureRect")
		if texture_rect:
			texture_rect.expand = true
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var name_panel = image_view_container.get_node_or_null("PanelContainer")
		if name_panel:
			var name_style = StyleBoxFlat.new()
			name_style.bg_color = Color(0.05, 0.15, 0.3, 1.0) # Azul oscuro
			name_panel.add_theme_stylebox_override("panel", name_style)
			name_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var image_name_label = image_view_container.get_node_or_null("PanelContainer/LabelNamePuzzle")
		if image_name_label:
			image_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			image_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			image_name_label.add_theme_font_size_override("font_size", 24)
			image_name_label.add_theme_color_override("font_color", Color(1, 1, 1))
			image_name_label.custom_minimum_size = Vector2(0, 50)
		
		image_view = image_view_container
	
	# Configurar el Sprite2D si existe
	var sprite = $CanvasLayer/VBoxContainer/PanelContainer/ImageView/PuzzleImage2D
	if sprite:
		sprite.position = Vector2(175, 175)  # Centrar en el contenedor
		sprite.scale = Vector2(0.5, 0.5)  # Ajustar escala
		image_view = sprite
	
	# Configurar la vista de texto
	text_view = $CanvasLayer/VBoxContainer/PanelContainer/TextView
	if text_view:
		text_view.visible = false
		text_view.bbcode_enabled = true
		text_view.scroll_active = true
		text_view.add_theme_font_size_override("normal_font_size", 16)
		text_view.add_theme_color_override("default_color", Color(0, 0, 0))
	
	# Configurar el botón de alternancia
	toggle_button = $CanvasLayer/VBoxContainer/BlockButtonChange/Button
	if toggle_button:
		toggle_button.text = "Texto"
		toggle_button.custom_minimum_size = Vector2(150, 40)
		toggle_button.add_theme_stylebox_override("normal", _create_button_style(Color(0.1, 0.3, 0.5, 1.0)))
		toggle_button.add_theme_stylebox_override("hover", _create_button_style(Color(0.2, 0.4, 0.6, 1.0)))
		toggle_button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.05, 0.2, 0.4, 1.0)))
		toggle_button.add_theme_color_override("font_color", Color(1, 1, 1))
		toggle_button.connect("pressed", Callable(self, "_on_toggle_view_pressed"))
	
	# Configurar los botones existentes
	var hbox_buttons = $CanvasLayer/BlockButtonChange
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
	var info_label = $CanvasLayer/VBoxContainer/LabelInfo
	if info_label:
		info_label.text = "Has completado el puzzle en " + str(total_moves) + " movimientos"
	
	# Actualizar la imagen
	if puzzle_data and puzzle_data.has("image"):
		var image_path = puzzle_data.image
		var image_texture = load(image_path)
		
		if image_view is Sprite2D:
			image_view.texture = image_texture
		elif image_view is Control:
			var texture_rect = image_view.get_node_or_null("TextureRect")
			if texture_rect:
				texture_rect.texture = image_texture
			
			# Actualizar el nombre de la imagen
			var name_label = image_view.get_node_or_null("PanelContainer/LabelNamePuzzle")
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
	var next_button = $CanvasLayer/VBoxContainer/HBoxContainer/Siguiente
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
