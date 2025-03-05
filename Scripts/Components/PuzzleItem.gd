extends Control

# Señal que se emite cuando se selecciona este puzzle
signal puzzle_selected(puzzle_data)

# Variables para almacenar los nodos
var image_texture: TextureRect
var name_label: Label
var select_button: Button
# Datos del puzzle
var puzzle_data = null
var is_initialized = false

func _ready():
	print("PuzzleItem: _ready()")
	
	# Crear la estructura de nodos si no existe
	if not has_node("Button"):
		print("PuzzleItem: No se encontró el nodo Button, creando estructura de UI")
		_create_ui_structure()
	else:
		print("PuzzleItem: Se encontró el nodo Button existente")
	
	# Obtener referencias a los nodos
	select_button = $Button
	image_texture = $Button/TextureRect
	name_label = $Button/Label
	
	# Verificar que todos los nodos se hayan encontrado correctamente
	if select_button and image_texture and name_label:
		print("PuzzleItem: Todos los nodos encontrados correctamente")
		
		# Asegurarse de que la señal pressed del botón esté conectada
		if not select_button.is_connected("pressed", Callable(self, "_on_select_pressed")):
			print("PuzzleItem: Conectando señal pressed del botón a _on_select_pressed")
			select_button.pressed.connect(Callable(self, "_on_select_pressed"))
		else:
			print("PuzzleItem: La señal pressed ya está conectada")
		
		is_initialized = true
		
		# Si ya tenemos datos del puzzle, configurarlo ahora
		if puzzle_data:
			print("PuzzleItem: Aplicando datos del puzzle que ya estaban disponibles")
			_apply_puzzle_data()
	else:
		print("ERROR: No se pudieron encontrar todos los nodos necesarios para PuzzleItem")
		if not select_button:
			print("ERROR: No se encontró el nodo select_button")
		if not image_texture:
			print("ERROR: No se encontró el nodo image_texture")
		if not name_label:
			print("ERROR: No se encontró el nodo name_label")
		push_error("No se pudieron encontrar todos los nodos necesarios para PuzzleItem")

# Función para crear la estructura de UI
func _create_ui_structure():
	print("PuzzleItem: Creando estructura de UI")
	
	# Configurar este nodo Control
	custom_minimum_size = Vector2(180, 220)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	
	# Crear el botón
	select_button = Button.new()
	select_button.name = "Button"
	select_button.custom_minimum_size = Vector2(160, 230)
	select_button.size_flags_horizontal = SIZE_EXPAND_FILL
	select_button.size_flags_vertical = SIZE_EXPAND_FILL
	
	# Conectar la señal pressed del botón
	select_button.pressed.connect(Callable(self, "_on_select_pressed"))
	print("PuzzleItem: Señal pressed del botón conectada a _on_select_pressed")
	
	# Añadir estilos al botón
	select_button.add_theme_constant_override("h_separation", 10)
	select_button.add_theme_constant_override("icon_max_width", 160)
	select_button.add_theme_stylebox_override("normal", _create_stylebox(Color(0.9, 0.9, 0.9, 1.0), 8))
	select_button.add_theme_stylebox_override("hover", _create_stylebox(Color(1.0, 1.0, 1.0, 1.0), 10))
	select_button.add_theme_stylebox_override("pressed", _create_stylebox(Color(0.8, 0.8, 0.8, 1.0), 6))
	
	# Crear la imagen
	image_texture = TextureRect.new()
	image_texture.name = "TextureRect"
	image_texture.expand = true
	image_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_texture.custom_minimum_size = Vector2(140, 180)
	image_texture.size_flags_horizontal = SIZE_EXPAND_FILL
	image_texture.size_flags_vertical = SIZE_EXPAND_FILL
	image_texture.position = Vector2(10, 10)
	
	# Crear la etiqueta
	name_label = Label.new()
	name_label.name = "Label"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(160, 30)
	name_label.position = Vector2(0, 150)
	name_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	name_label.text = "Puzzle"
	
	# Añadir los nodos a la jerarquía
	add_child(select_button)
	select_button.add_child(image_texture)
	select_button.add_child(name_label)
	
	print("PuzzleItem: Estructura de UI creada correctamente")

# Función para crear un StyleBox con sombra
func _create_stylebox(color: Color, shadow_size: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(2, 2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
	
func setup(puzzle):
	print("PuzzleItem: setup() con puzzle: ", puzzle)
	puzzle_data = puzzle
	
	# Solo aplicar los datos si ya estamos inicializados
	if is_initialized:
		print("PuzzleItem: Componente inicializado, aplicando datos del puzzle")
		_apply_puzzle_data()
	else:
		print("PuzzleItem: Componente no inicializado, los datos se aplicarán en _ready()")

# Función interna para aplicar los datos del puzzle a los nodos
func _apply_puzzle_data():
	print("PuzzleItem: _apply_puzzle_data()")
	if name_label and puzzle_data and puzzle_data.has("name"):
		print("PuzzleItem: Estableciendo nombre: ", puzzle_data["name"])
		name_label.text = puzzle_data["name"]
	else:
		print("ERROR: No se pudo establecer el nombre del puzzle")
		if not name_label:
			print("ERROR: name_label es nulo")
		if not puzzle_data:
			print("ERROR: puzzle_data es nulo")
		elif not puzzle_data.has("name"):
			print("ERROR: puzzle_data no tiene la clave 'name'")
	
	# Cargar la imagen si existe
	if image_texture and puzzle_data:
		if puzzle_data.has("image") and puzzle_data["image"] != "":
			print("PuzzleItem: Cargando imagen: ", puzzle_data["image"])
			var image = load(puzzle_data["image"])
			if image:
				print("PuzzleItem: Imagen cargada correctamente")
				image_texture.texture = image
			else:
				print("ERROR: No se pudo cargar la imagen, usando imagen por defecto")
				_set_default_image()
		else:
			print("PuzzleItem: El puzzle no tiene imagen, usando imagen por defecto")
			_set_default_image()
	else:
		print("ERROR: No se pudo establecer la imagen del puzzle")
		if not image_texture:
			print("ERROR: image_texture es nulo")
		if not puzzle_data:
			print("ERROR: puzzle_data es nulo")

# Función para establecer la imagen por defecto
func _set_default_image():
	print("PuzzleItem: _set_default_image()")
	if image_texture:
		# Intentar usar una imagen existente como alternativa
		var default_paths = [
			"res://Assets/Images/default_puzzle_image.png",
			"res://Assets/Images/arte1.jpg",
			"res://Assets/Images/paisaje1.jpg"
		]
		
		var default_image = null
		for path in default_paths:
			if ResourceLoader.exists(path):
				default_image = load(path)
				if default_image:
					print("PuzzleItem: Imagen alternativa cargada correctamente: ", path)
					image_texture.texture = default_image
					return
		
		print("ERROR: No se pudo cargar ninguna imagen alternativa, creando un placeholder")
		# Crear una imagen de color sólido como placeholder
		var img = Image.create(100, 100, false, Image.FORMAT_RGB8)
		# Rellenar con un color azul claro
		img.fill(Color(0.3, 0.5, 0.8))
		var placeholder = ImageTexture.create_from_image(img)
		image_texture.texture = placeholder

func _on_select_pressed():
	print("PuzzleItem: _on_select_pressed() - BOTÓN PRESIONADO")
	
	# Imprimir información sobre el botón
	print("PuzzleItem: Botón presionado - Nombre: ", select_button.name if select_button else "NULL")
	
	if puzzle_data:
		print("PuzzleItem: Emitiendo señal puzzle_selected con datos: ", puzzle_data)
		print("PuzzleItem: Nombre del puzzle: ", puzzle_data.get("name", "NO NAME"))
		print("PuzzleItem: Datos completos del puzzle: ", JSON.stringify(puzzle_data))
		emit_signal("puzzle_selected", puzzle_data)
	else:
		print("ERROR: No hay datos del puzzle para emitir la señal")
		print("ERROR: puzzle_data es NULL")
