extends Control

# Señal que se emite cuando se selecciona este puzzle
signal puzzle_selected(puzzle_data)

# Variables para almacenar los nodos
var background_rect: ColorRect
var frame_rect: Panel
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
	if not has_node("BackgroundRect"):
		print("PuzzleItem: No se encontró la estructura UI completa, creando...")
		_create_ui_structure()
	else:
		print("PuzzleItem: Se encontró la estructura UI existente")
	
	# Obtener referencias a los nodos
	background_rect = $BackgroundRect
	frame_rect = $BackgroundRect/FrameRect
	select_button = $BackgroundRect/FrameRect/Button
	image_texture = $BackgroundRect/FrameRect/Button/TextureRect
	name_label = $NameLabel
	
	# Buscar o crear el icono de candado
	if $BackgroundRect/FrameRect.has_node("LockIcon"):
		lock_icon = $BackgroundRect/FrameRect/LockIcon
	else:
		_create_lock_icon()
	
	# Buscar o crear el icono de completado
	if $BackgroundRect/FrameRect.has_node("CompletedIcon"):
		completed_icon = $BackgroundRect/FrameRect/CompletedIcon
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
	print("PuzzleItem: Creando estructura de UI estilizada")
	
	# Configurar este nodo Control
	custom_minimum_size = Vector2(220, 350)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	
	# Crear el fondo verde redondeado
	background_rect = ColorRect.new()
	background_rect.name = "BackgroundRect"
	background_rect.custom_minimum_size = Vector2(220, 350)
	background_rect.size_flags_horizontal = SIZE_EXPAND_FILL
	background_rect.size_flags_vertical = SIZE_EXPAND_FILL
	background_rect.color = Color("3db54a") # Color verde como en la imagen
	
	# Crear el marco con bordes redondeados
	frame_rect = Panel.new()
	frame_rect.name = "FrameRect"
	frame_rect.custom_minimum_size = Vector2(200, 300)
	frame_rect.size_flags_horizontal = SIZE_SHRINK_CENTER
	frame_rect.size_flags_vertical = SIZE_SHRINK_CENTER
	frame_rect.add_theme_stylebox_override("panel", _create_panel_stylebox())
	
	# Crear el botón para la imagen
	select_button = Button.new()
	select_button.name = "Button"
	select_button.custom_minimum_size = Vector2(180, 180)
	select_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	select_button.size_flags_vertical = SIZE_SHRINK_CENTER
	select_button.flat = true # Para que solo sea clicable sin estilo visual
	
	# Conectar la señal pressed del botón
	select_button.pressed.connect(Callable(self, "_on_select_pressed"))
	print("PuzzleItem: Señal pressed del botón conectada a _on_select_pressed")
	
	# Crear la imagen
	image_texture = TextureRect.new()
	image_texture.name = "TextureRect"
	image_texture.expand = true
	image_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_texture.custom_minimum_size = Vector2(180, 180)
	image_texture.size_flags_horizontal = SIZE_EXPAND_FILL
	image_texture.size_flags_vertical = SIZE_EXPAND_FILL
	
	# Crear la etiqueta de nombre
	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(200, 40)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1)) # Texto blanco
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.text = "PUZZLE"
	name_label.uppercase = true
	
	# Añadir los nodos a la jerarquía
	add_child(background_rect)
	background_rect.add_child(frame_rect)
	frame_rect.add_child(select_button)
	select_button.add_child(image_texture)
	frame_rect.add_child(name_label)
	
	# Posicionar los elementos
	name_label.position.y = 240 # Posicionar la etiqueta en la parte inferior
	
	# Crear los iconos de estado
	_create_lock_icon()
	_create_completed_icon()
	
	print("PuzzleItem: Estructura de UI creada correctamente")

# Función para crear el StyleBox del panel (marco blanco con bordes redondeados)
func _create_panel_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1) # Blanco
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

# Función para crear el icono de candado
func _create_lock_icon():
	# Crear el icono de candado (inicialmente oculto)
	lock_icon = TextureRect.new()
	lock_icon.name = "LockIcon"
	lock_icon.expand = true
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_icon.custom_minimum_size = Vector2(80, 80)
	lock_icon.size_flags_horizontal = SIZE_SHRINK_CENTER
	lock_icon.size_flags_vertical = SIZE_SHRINK_CENTER
	lock_icon.visible = false
	
	# Intentar cargar una imagen de candado
	var lock_texture = null
	var lock_paths = [
		"res://Assets/Images/GUID/icon_lock.svg",
		"res://Assets/Images/GUID/icon_looked.png",
		"res://Assets/Images/lock_icon.png"
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
		lock_label.add_theme_font_size_override("font_size", 40)
		lock_icon.add_child(lock_label)
	
	frame_rect.add_child(lock_icon)
	# Centrar el icono de candado
	lock_icon.position = Vector2(60, 80)

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
	completed_icon.visible = false
	
	# Intentar cargar una imagen de marca de verificación
	var check_texture = null
	var check_paths = [
		"res://Assets/Images/GUID/icon_check.svg",
		"res://Assets/Images/check_icon.png"
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
		check_label.add_theme_font_size_override("font_size", 40)
		check_label.add_theme_color_override("font_color", Color(0, 0.8, 0, 1))  # Verde
		completed_icon.add_child(check_label)
	
	frame_rect.add_child(completed_icon)
	# Colocar en la esquina superior derecha
	completed_icon.position = Vector2(150, 20)

# Aplicar los datos del puzzle a los componentes de UI
func _apply_puzzle_data():
	if not puzzle_data:
		print("ERROR: No hay datos de puzzle para aplicar")
		return
		
	if not is_initialized:
		print("ERROR: El componente no está inicializado")
		return
	
	print("PuzzleItem: Aplicando datos del puzzle: ", puzzle_data)
	
	# Actualizar el texto del nombre
	if puzzle_data.has("name") and name_label:
		name_label.text = puzzle_data.name.to_upper()
	
	# Intentar cargar la imagen con diferentes claves que podrían estar en el puzzle_data
	var image_loaded = false
	
	# Lista de posibles claves para la imagen
	var image_keys = ["image_path", "image", "imagen", "thumbnail", "icon"]
	
	for key in image_keys:
		if puzzle_data.has(key) and not image_loaded:
			var img_path = puzzle_data[key]
			if typeof(img_path) == TYPE_STRING and img_path != "":
				if ResourceLoader.exists(img_path):
					var texture = load(img_path)
					if texture and image_texture:
						image_texture.texture = texture
						print("PuzzleItem: Imagen cargada desde clave '" + key + "': ", img_path)
						image_loaded = true
	
	# Si no se cargó ninguna imagen, intentar con la opción "id" como nombre de imagen
	if not image_loaded and puzzle_data.has("id"):
		var possible_paths = [
			"res://Assets/Images/puzzles/" + puzzle_data.id + ".png",
			"res://Assets/Images/puzzles/" + puzzle_data.id + ".jpg",
			"res://Assets/Images/" + puzzle_data.id + ".png",
			"res://Assets/Images/" + puzzle_data.id + ".jpg"
		]
		
		for path in possible_paths:
			if ResourceLoader.exists(path):
				var texture = load(path)
				if texture and image_texture:
					image_texture.texture = texture
					print("PuzzleItem: Imagen cargada usando ID: ", path)
					image_loaded = true
					break
	
	# Si todavía no se ha cargado ninguna imagen, cargar una por defecto
	if not image_loaded:
		print("PuzzleItem: No se pudo cargar la imagen, usando imagen por defecto")
		_load_default_image()
	
	# Actualizar el estado de bloqueo
	if is_locked and lock_icon:
		lock_icon.visible = true
		if select_button:
			select_button.disabled = true
	else:
		if lock_icon:
			lock_icon.visible = false
		if select_button:
			select_button.disabled = false
	
	# Actualizar el estado de completado
	if is_completed and completed_icon:
		completed_icon.visible = true
	else:
		if completed_icon:
			completed_icon.visible = false

# Función para cargar una imagen por defecto
func _load_default_image():
	print("PuzzleItem: Intentando cargar imagen por defecto")
	
	var default_paths = [
		# Imágenes específicas
		"res://Assets/Images/default_image_pack.png",
		"res://Assets/Images/paisaje1.jpg",
		"res://Assets/Images/paisaje2.jpg",
		"res://Assets/Images/arte1.jpg",
		"res://Assets/Images/arte2.jpg",
		"res://Assets/Images/GUID/001.png",
		# Imágenes en subcarpetas
		"res://Assets/Images/packs/default.png",
		"res://Assets/Images/puzzles/default.png"
	]
	
	var loaded = false
	
	for path in default_paths:
		if ResourceLoader.exists(path):
			var texture = load(path)
			if texture:
				image_texture.texture = texture
				print("PuzzleItem: Imagen por defecto cargada: ", path)
				loaded = true
				break
	
	# Si no se pudo cargar ninguna imagen, intentar con la primera imagen que encontremos
	if not loaded:
		# Intentar cargar alguna imagen de arte
		var arte_paths = ["res://Assets/Images/arte1.jpg", "res://Assets/Images/arte2.jpg"]
		for path in arte_paths:
			if ResourceLoader.exists(path):
				var texture = load(path)
				if texture:
					image_texture.texture = texture
					print("PuzzleItem: Imagen de arte cargada como respaldo: ", path)
					loaded = true
					break
	
	# Si aún no se ha cargado nada, mostrar un color de fondo con texto de respaldo
	if not loaded:
		print("ERROR: No se pudo cargar ninguna imagen por defecto, usando respaldo")
		
		# Crear un color de fondo con texto
		var placeholder = ColorRect.new()
		placeholder.color = Color(0.8, 0.8, 0.8, 1.0)
		placeholder.custom_minimum_size = Vector2(180, 180)
		placeholder.size_flags_horizontal = SIZE_EXPAND_FILL
		placeholder.size_flags_vertical = SIZE_EXPAND_FILL
		
		# Añadir un texto al placeholder
		var placeholder_label = Label.new()
		placeholder_label.text = "Sin imagen"
		placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder_label.add_theme_font_size_override("font_size", 20)
		placeholder.add_child(placeholder_label)
		
		# Limpiar cualquier hijo existente en image_texture
		for child in image_texture.get_children():
			child.queue_free()
		
		image_texture.add_child(placeholder)

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
		if lock_icon:
			lock_icon.visible = locked
		if select_button:
			select_button.disabled = locked

# Función para establecer el estado de completado
func set_completed(completed: bool):
	is_completed = completed
	
	if is_initialized and completed_icon:
		completed_icon.visible = completed

# Función llamada cuando se presiona el botón de selección
func _on_select_pressed():
	print("PuzzleItem: _on_select_pressed() - Botón presionado")
	
	# Verificar si el botón está bloqueado
	if is_locked:
		print("PuzzleItem: No se puede seleccionar porque está bloqueado")
		return
		
	# Verificar los datos del puzzle
	if puzzle_data == null:
		print("ERROR: No hay datos del puzzle para emitir")
		
		# Crear unos datos mínimos para permitir avanzar en caso de error
		puzzle_data = {
			"id": "default_puzzle",
			"name": name_label.text if name_label else "Puzzle Desconocido",
			"image": "res://Assets/Images/default_image_pack.png"
		}
		print("PuzzleItem: Creados datos básicos de puzzle para continuar: ", puzzle_data)
	
	# Emitir la señal con los datos del puzzle
	print("PuzzleItem: Emitiendo señal puzzle_selected con datos: ", puzzle_data)
	
	# Intenta emitir la señal de dos formas diferentes para mayor compatibilidad
	if has_signal("puzzle_selected"):
		emit_signal("puzzle_selected", puzzle_data)
	else:
		# Forma alternativa de emitir señales en Godot 4
		print("PuzzleItem: Intentando emitir la señal de manera alternativa")
		puzzle_selected.emit(puzzle_data)
