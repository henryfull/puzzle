extends Control

# Señal que se emite cuando se selecciona este puzzle
signal puzzle_selected(puzzle_data)

# Variables para almacenar los nodos
var image_texture: TextureRect
var name_label: Label
var select_button: Button
var lock_icon: TextureRect  # Icono de candado para puzzles bloqueados
var completed_icon: TextureRect  # Nuevo: icono de completado para puzzles terminados

# Datos del puzzle
var puzzle_data = null
var is_initialized = false
var is_locked = false  # Indica si el puzzle está bloqueado
var is_completed = false  # Nuevo: indica si el puzzle está completado

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
	
	# Buscar o crear el icono de candado
	if $Button.has_node("LockIcon"):
		lock_icon = $Button/LockIcon
	else:
		_create_lock_icon()
	
	# Buscar o crear el icono de completado
	if $Button.has_node("CompletedIcon"):
		completed_icon = $Button/CompletedIcon
	else:
		_create_completed_icon()
	
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
	select_button.add_theme_stylebox_override("disabled", _create_stylebox(Color(0.7, 0.7, 0.7, 0.8), 8))
	
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
	
	# Crear los iconos de estado
	_create_lock_icon()
	_create_completed_icon()
	
	print("PuzzleItem: Estructura de UI creada correctamente")

# Función para crear el icono de candado
func _create_lock_icon():
	# Crear el icono de candado (inicialmente oculto)
	lock_icon = TextureRect.new()
	lock_icon.name = "LockIcon"
	lock_icon.expand = true
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_icon.custom_minimum_size = Vector2(60, 60)
	lock_icon.size_flags_horizontal = SIZE_SHRINK_CENTER
	lock_icon.size_flags_vertical = SIZE_SHRINK_CENTER
	lock_icon.position = Vector2(50, 50)  # Centrado en la imagen
	lock_icon.visible = false
	
	# Intentar cargar una imagen de candado
	var lock_texture = null
	var lock_paths = [
		"res://Assets/Images/lock_icon.png",
		"res://Assets/UI/lock.png"
	]
	
	for path in lock_paths:
		if ResourceLoader.exists(path):
			lock_texture = load(path)
			if lock_texture:
				lock_icon.texture = lock_texture
				break
	
	# Si no se pudo cargar una imagen, crear un texto de candado
	if not lock_texture:
		var lock_label = Label.new()
		lock_label.text = "🔒"  # Emoji de candado
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_label.add_theme_font_size_override("font_size", 32)
		lock_icon.add_child(lock_label)
	
	select_button.add_child(lock_icon)

# Función para crear el icono de completado
func _create_completed_icon():
	# Crear el icono de completado (inicialmente oculto)
	completed_icon = TextureRect.new()
	completed_icon.name = "CompletedIcon"
	completed_icon.expand = true
	completed_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	completed_icon.custom_minimum_size = Vector2(60, 60)
	completed_icon.size_flags_horizontal = SIZE_SHRINK_CENTER
	completed_icon.size_flags_vertical = SIZE_SHRINK_CENTER
	completed_icon.position = Vector2(120, 20)  # Esquina superior derecha
	completed_icon.visible = false
	
	# Intentar cargar una imagen de marca de verificación
	var check_texture = null
	var check_paths = [
		"res://Assets/Images/check_icon.png",
		"res://Assets/UI/check.png"
	]
	
	for path in check_paths:
		if ResourceLoader.exists(path):
			check_texture = load(path)
			if check_texture:
				completed_icon.texture = check_texture
				break
	
	# Si no se pudo cargar una imagen, crear un texto de marca de verificación
	if not check_texture:
		var check_label = Label.new()
		check_label.text = "✓"  # Marca de verificación
		check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		check_label.add_theme_font_size_override("font_size", 32)
		check_label.add_theme_color_override("font_color", Color(0, 0.8, 0, 1))  # Verde
		completed_icon.add_child(check_label)
	
	select_button.add_child(completed_icon)

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
	
	# Verificar si el puzzle está desbloqueado
	if puzzle_data and puzzle_data.has("unlocked"):
		is_locked = not puzzle_data.unlocked
	
	# Verificar si el puzzle está completado
	if puzzle_data and puzzle_data.has("completed"):
		is_completed = puzzle_data.completed
		print("PuzzleItem: Puzzle completado: ", is_completed)
	
	# Solo aplicar los datos si ya estamos inicializados
	if is_initialized:
		print("PuzzleItem: Componente inicializado, aplicando datos del puzzle")
		_apply_puzzle_data()
	else:
		print("PuzzleItem: Componente no inicializado, los datos se aplicarán en _ready()")

# Función para establecer el estado de bloqueo
func set_locked(locked: bool):
	is_locked = locked
	
	if is_initialized:
		_update_lock_state()

# Función para establecer el estado de completado
func set_completed(completed: bool):
	is_completed = completed
	
	if is_initialized:
		_update_completed_state()

# Función para actualizar el estado visual de bloqueo
func _update_lock_state():
	if not is_initialized:
		return
	
	# Actualizar el botón
	select_button.disabled = is_locked
	
	# Actualizar el icono de candado
	if lock_icon:
		lock_icon.visible = is_locked
	
	# Aplicar un efecto de desaturación a la imagen si está bloqueada
	if image_texture:
		if is_locked:
			# Aplicar un shader de desaturación o simplemente reducir la opacidad
			image_texture.modulate = Color(0.7, 0.7, 0.7, 0.7)
		else:
			image_texture.modulate = Color(1, 1, 1, 1)

# Función para actualizar el estado visual de completado
func _update_completed_state():
	if not is_initialized:
		return
	
	# Actualizar el icono de completado
	if completed_icon:
		completed_icon.visible = is_completed
	
	# Cambiar el estilo del botón si está completado
	if select_button and is_completed:
		# Crear un estilo especial para puzzles completados
		var completed_style = _create_stylebox(Color(0.8, 1.0, 0.8, 1.0), 8)  # Verde claro
		select_button.add_theme_stylebox_override("normal", completed_style)
		
		# También actualizar el estilo hover
		var completed_hover_style = _create_stylebox(Color(0.9, 1.0, 0.9, 1.0), 10)
		select_button.add_theme_stylebox_override("hover", completed_hover_style)
	elif select_button and not is_completed:
		# Restaurar el estilo normal
		select_button.add_theme_stylebox_override("normal", _create_stylebox(Color(0.9, 0.9, 0.9, 1.0), 8))
		select_button.add_theme_stylebox_override("hover", _create_stylebox(Color(1.0, 1.0, 1.0, 1.0), 10))

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
	
	# Actualizar el estado de bloqueo
	_update_lock_state()
	
	# Actualizar el estado de completado
	_update_completed_state()

# Función para establecer la imagen por defecto
func _set_default_image():
	print("PuzzleItem: _set_default_image()")
	if image_texture:
		# Intentar cargar una imagen por defecto
		var default_paths = [
			"res://Assets/Images/default_puzzle.png",
			"res://Assets/UI/default_puzzle.png"
		]
		
		for path in default_paths:
			if ResourceLoader.exists(path):
				var default_texture = load(path)
				if default_texture:
					image_texture.texture = default_texture
					return
		
		# Si no se pudo cargar ninguna imagen, crear un color de fondo
		var placeholder = ColorRect.new()
		placeholder.color = Color(0.8, 0.8, 0.8)
		placeholder.custom_minimum_size = Vector2(140, 180)
		placeholder.size_flags_horizontal = SIZE_EXPAND_FILL
		placeholder.size_flags_vertical = SIZE_EXPAND_FILL
		
		# Añadir un texto al placeholder
		var placeholder_label = Label.new()
		placeholder_label.text = "Sin imagen"
		placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder_label.add_theme_font_size_override("font_size", 16)
		placeholder_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		placeholder.add_child(placeholder_label)
		
		# Limpiar cualquier hijo existente en image_texture
		for child in image_texture.get_children():
			child.queue_free()
		
		image_texture.add_child(placeholder)

# Función llamada cuando se presiona el botón
func _on_select_pressed():
	print("PuzzleItem: _on_select_pressed()")
	if puzzle_data:
		print("PuzzleItem: Emitiendo señal puzzle_selected con datos: ", puzzle_data)
		emit_signal("puzzle_selected", puzzle_data)
	else:
		print("ERROR: No hay datos del puzzle para emitir")
