extends Control

# Señal que se emite cuando se selecciona este puzzle
signal puzzle_selected(puzzle_data)

# Variables para almacenar los nodos
var background_rect: ColorRect
var frame_rect: Panel
var image_texture: TextureRect
var name_label: Label
var select_button: Button
var lock_icon: TextureRect
var completed_icon: TextureRect
var background_looked: ColorRect

# Datos del puzzle
var puzzle_data = null
var is_initialized = false
var is_locked = false
var is_completed = false

func _ready():
	print("PuzzleItem: _ready()")
	
	# Obtener referencias a los nodos
	background_rect = $BackgroundRect
	frame_rect = $BackgroundRect/FrameRect
	select_button = $BackgroundRect/FrameRect/Button
	image_texture = $BackgroundRect/FrameRect/Button/TextureRect
	name_label = $BackgroundRect/NameLabel
	lock_icon = $BackgroundRect/FrameRect/LockIcon
	completed_icon = $BackgroundRect/FrameRect/CompletedIcon
	background_looked = $BackgroundRectLook
	# Verificar que todos los nodos se hayan encontrado correctamente
	if select_button and image_texture and name_label:
		print("PuzzleItem: Todos los nodos encontrados correctamente")
		
		# Asegurarse de que la señal pressed del botón esté conectada
		if not select_button.is_connected("pressed", Callable(self, "_on_select_pressed")):
			print("PuzzleItem: Conectando señal pressed del botón a _on_select_pressed")
			select_button.pressed.connect(Callable(self, "_on_select_pressed"))
		
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
	if is_locked and background_looked:
		background_looked.visible = true
		background_rect.visible = false
		if select_button:
			select_button.disabled = true
	else:
		if background_looked:
			background_looked.visible = false
			background_rect.visible = true
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
		"res://Assets/Images/default_image_pack.png",
		"res://Assets/Images/paisaje1.jpg",
		"res://Assets/Images/paisaje2.jpg",
		"res://Assets/Images/arte1.jpg",
		"res://Assets/Images/arte2.jpg"
	]
	
	for path in default_paths:
		if ResourceLoader.exists(path):
			var texture = load(path)
			if texture:
				image_texture.texture = texture
				print("PuzzleItem: Imagen por defecto cargada: ", path)
				return
	
	# Si no se pudo cargar ninguna imagen, mostrar un color de fondo con texto
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
		return
	
	# Emitir la señal con los datos del puzzle
	print("PuzzleItem: Emitiendo señal puzzle_selected con datos: ", puzzle_data)
	puzzle_selected.emit(puzzle_data)
