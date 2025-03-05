extends Node2D

func _ready():
	# Inicialización de la selección de pack.
	# Aquí se pueden cargar los datos de PacksData, por ejemplo, leyendo archivos JSON o YAML.
	print("PackSelection: inicialización de los packs disponibles")
	load_packs()

func load_packs():
	# Limpiar cualquier elemento existente en el contenedor
	for child in $CanvasLayer/VBoxContainer.get_children():
		child.queue_free()
	
	# Añadir un título a la pantalla
	var title_label = Label.new()
	title_label.text = "Selecciona un Pack"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(0, 60)
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	$CanvasLayer/VBoxContainer.add_child(title_label)
	
	# Añadir un separador
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 20)
	$CanvasLayer/VBoxContainer.add_child(separator)
	
	# Crear un ScrollContainer para permitir desplazamiento
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(0, 400)  # Altura mínima para el scroll
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # Desactivar scroll horizontal
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO  # Activar scroll vertical automático
	$CanvasLayer/VBoxContainer.add_child(scroll_container)
	
	# Crear un VBoxContainer dentro del ScrollContainer para los packs
	var packs_container = VBoxContainer.new()
	packs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	packs_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	packs_container.add_theme_constant_override("separation", 10)  # Separación entre packs
	scroll_container.add_child(packs_container)
	
	var packs = load_json("res://PacksData/sample_packs.json") # Cargar el JSON
	print("Packs cargados: ", packs.size())
	
	if packs.size() == 0:
		print("ERROR: No se encontraron packs en el archivo JSON")
		var error_label = Label.new()
		error_label.text = "Error: No se encontraron packs disponibles"
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		error_label.custom_minimum_size = Vector2(0, 100)
		error_label.add_theme_font_size_override("font_size", 18)
		error_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		packs_container.add_child(error_label)
		return
	
	for pack in packs:
		print("Procesando pack: ", pack["name"])
		
		# Crear un panel para el pack con estilo
		var pack_panel = Panel.new()
		pack_panel.custom_minimum_size = Vector2(300, 80)
		pack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Añadir estilo al panel
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.9, 0.9, 0.9, 1.0)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.shadow_color = Color(0, 0, 0, 0.2)
		style.shadow_size = 5
		style.shadow_offset = Vector2(2, 2)
		pack_panel.add_theme_stylebox_override("panel", style)
		
		# Crear un botón para el pack
		var button = Button.new()
		button.text = pack["name"]
		button.custom_minimum_size = Vector2(280, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(Callable(self, "_on_PackSelected").bind(pack))
		
		# Añadir el botón al panel
		pack_panel.add_child(button)
		
		# Centrar el botón en el panel
		button.position = Vector2(10, 10)
		
		# Añadir el panel al contenedor de packs
		packs_container.add_child(pack_panel)
		print("Botón añadido para pack: ", pack["name"])

func load_json(path: String) -> Array:
	print("Cargando archivo JSON: ", path)
	var data = AchievementsManager.loadFile(path)
	
	if data.is_empty():
		print("ERROR: No se pudo cargar el archivo JSON o está vacío")
		return []
	
	var parsed_data = JSON.parse_string(data)
	if parsed_data == null:
		print("ERROR: Error al analizar el JSON")
		return []
	
	if not parsed_data.has("packs"):
		print("ERROR: El JSON no tiene la clave 'packs'")
		return []
	
	var packs = parsed_data.packs
	if packs == null or not (packs is Array):
		print("ERROR: La clave 'packs' no es un array válido")
		return []
	
	print("Packs encontrados en el JSON: ", packs.size())
	return packs

func _on_PackSelected(pack):
	print("Pack seleccionado: ", pack)
	
	# Verificar que el pack tenga la estructura correcta
	if not pack.has("puzzles"):
		print("ERROR: El pack seleccionado no tiene la clave 'puzzles'")
		# Añadir una clave puzzles vacía para evitar errores
		pack["puzzles"] = []
	
	GLOBAL.selected_pack = pack	
	# Función llamada al seleccionar un pack
	print("Pack seleccionado: " + pack["name"] + " con " + str(pack["puzzles"].size()) + " puzzles")
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn") 

func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
