extends Node2D

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")

# Variables para controlar el desplazamiento táctil
var is_scrolling = false
var scroll_start_time = 0

# Referencia a la escena del componente de pack
var pack_component_scene = preload("res://Scenes/Components/PackComponent.tscn")

# Variable para controlar si estamos en un dispositivo táctil
var is_touch_device = false

func _ready():
	# Detectar si estamos en un dispositivo táctil
	is_touch_device = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("ios") or OS.has_feature("android")
	print("PackSelection: Dispositivo táctil: ", is_touch_device)
	
	# Inicialización de la selección de pack.
	print("PackSelection: inicialización de los packs disponibles")
	load_packs()
	
	# Cargar el script de configuración táctil
	var TouchScrollFix = load("res://Scripts/TouchScrollFix.gd")
	if TouchScrollFix:
		# Configurar todos los nodos para mejorar el desplazamiento táctil
		TouchScrollFix.configure_touch_scroll(self)
		
		# Conectar las señales del ScrollContainer después de cargarlo
		var scroll_container = $CanvasLayer/VBoxContainer.get_node_or_null("ScrollContainer")
		if scroll_container:
			TouchScrollFix.connect_scroll_signals(scroll_container, self, "_on_scroll_started", "_on_scroll_ended")
		else:
			print("ERROR: No se pudo encontrar el ScrollContainer para conectar señales")
	else:
		print("ERROR: No se pudo cargar el script TouchScrollFix")
	
	# Ajustar el layout según el tipo de dispositivo
	adjust_layout_for_device()

# Nueva función para ajustar el layout según el tipo de dispositivo
func adjust_layout_for_device():
	var vbox = $CanvasLayer/VBoxContainer
	
	if is_touch_device:
		# En dispositivos táctiles, usar todo el ancho disponible
		vbox.anchors_preset = 15  # Full rect
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		vbox.offset_left = 20.0
		vbox.offset_top = 20.0
		vbox.offset_right = -20.0
		vbox.offset_bottom = -100.0
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		print("PackSelection: Layout ajustado para dispositivo táctil")
	else:
		# En ordenadores, usar un ancho máximo
		vbox.anchors_preset = 8  # Center
		vbox.anchor_left = 0.5
		vbox.anchor_top = 0.5
		vbox.anchor_right = 0.5
		vbox.anchor_bottom = 0.5
		vbox.offset_left = -400.0  # Mitad del ancho máximo
		vbox.offset_top = -500.0
		vbox.offset_right = 400.0  # Mitad del ancho máximo
		vbox.offset_bottom = 500.0
		vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vbox.custom_minimum_size = Vector2(800, 1000)  # Ancho máximo para ordenadores
		print("PackSelection: Layout ajustado para ordenador")

func load_packs():
	# Limpiar cualquier elemento existente en el contenedor
	for child in $CanvasLayer/VBoxContainer.get_children():
		child.queue_free()
	
	# Añadir un título a la pantalla
	var title_label = Label.new()
	title_label.text = "PACKS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(0, 60)
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.4, 0.2, 0.1))
	$CanvasLayer/VBoxContainer.add_child(title_label)
	
	# Añadir un separador
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 20)
	$CanvasLayer/VBoxContainer.add_child(separator)
	
	# Añadir un subtítulo
	var subtitle_label = Label.new()
	subtitle_label.text = "Selecciona un pack"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.custom_minimum_size = Vector2(0, 40)
	subtitle_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	$CanvasLayer/VBoxContainer.add_child(subtitle_label)
	
	# Crear un ScrollContainer personalizado para permitir desplazamiento táctil
	var scroll_container
	
	# Intentar cargar la escena del TouchScrollContainer
	var touch_scroll_scene = load("res://Scenes/Components/TouchScrollContainer.tscn")
	if touch_scroll_scene:
		scroll_container = touch_scroll_scene.instantiate()
		print("Usando TouchScrollContainer personalizado")
	else:
		# Si no se puede cargar, usar un ScrollContainer normal
		scroll_container = ScrollContainer.new()
		print("Usando ScrollContainer estándar")
		
		# Intentar adjuntar el script TouchScrollHandler
		var touch_handler_script = load("res://Scripts/TouchScrollHandler.gd")
		if touch_handler_script:
			scroll_container.set_script(touch_handler_script)
			print("Script TouchScrollHandler adjuntado al ScrollContainer")
	
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(0, 0)  # Eliminar altura mínima fija
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # Desactivar scroll horizontal
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO  # Activar scroll vertical automático
	
	# Conectar señales de desplazamiento
	if scroll_container.has_signal("touch_scroll_started"):
		scroll_container.connect("touch_scroll_started", Callable(self, "_on_scroll_started"))
	if scroll_container.has_signal("touch_scroll_ended"):
		scroll_container.connect("touch_scroll_ended", Callable(self, "_on_scroll_ended"))
	
	$CanvasLayer/VBoxContainer.add_child(scroll_container)
	
	# Crear un VBoxContainer dentro del ScrollContainer para los packs
	var packs_container = VBoxContainer.new()
	packs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	packs_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	packs_container.add_theme_constant_override("separation", 20)  # Separación entre packs
	packs_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Ignorar eventos de ratón para que pasen al ScrollContainer
	scroll_container.add_child(packs_container)
	
	# Obtener los packs con información de progresión
	var packs = progress_manager.get_all_packs_with_progress()
	print("Packs cargados: ", packs.size())
	
	if packs.size() == 0:
		print("ERROR: No se encontraron packs disponibles")
		var error_label = Label.new()
		error_label.text = "Error: No se encontraron packs disponibles"
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		error_label.custom_minimum_size = Vector2(0, 100)
		error_label.add_theme_font_size_override("font_size", 18)
		error_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		packs_container.add_child(error_label)
		return
	
	# Crear componentes de pack para cada pack disponible
	for pack in packs:
		print("Procesando pack: ", pack.name)
		
		# Añadir la ruta de la imagen al pack si existe
		if not pack.has("image_path"):
			# Intentar encontrar una imagen para el pack
			var possible_paths = [
				"res://Assets/Images/packs/" + pack.id + "/icon.png",
				"res://Assets/Images/packs/" + pack.id + "/preview.png",
				"res://Assets/Images/packs/" + pack.name.to_lower() + "/icon.png",
				"res://Assets/Images/packs/" + pack.name.to_lower() + "/preview.png"
			]
			
			for path in possible_paths:
				var file = FileAccess.open(path, FileAccess.READ)
				if file:
					pack.image_path = path
					file.close()
					break
			
			# Si no se encuentra una imagen específica, usar la imagen por defecto
			if not pack.has("image_path") or pack.image_path == "":
				pack.image_path = "res://Assets/Images/default_image_pack.png"
		
		# Instanciar el componente de pack
		var pack_component = pack_component_scene.instantiate()
		pack_component.setup(pack)
		pack_component.connect("pack_selected", Callable(self, "_on_PackSelected"))
		
		# Añadir el componente al contenedor
		packs_container.add_child(pack_component)
		print("Componente añadido para pack: ", pack.name)

func _on_scroll_started():
	is_scrolling = true
	scroll_start_time = Time.get_ticks_msec()

func _on_scroll_ended():
	# Mantener el estado de desplazamiento por un breve período para evitar clics accidentales
	await get_tree().create_timer(0.1).timeout
	is_scrolling = false

func _on_PackSelected(pack):
	# Verificar que el pack tenga la estructura correcta
	if not pack.has("puzzles"):
		print("ERROR: El pack seleccionado no tiene la clave 'puzzles'")
		# Añadir una clave puzzles vacía para evitar errores
		pack["puzzles"] = []
	
	GLOBAL.selected_pack = pack	
	# Función llamada al seleccionar un pack
	print("Pack seleccionado: " + pack.name + " con " + str(pack.puzzles.size()) + " puzzles")
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn")

func _on_BackButton_pressed():
	# Volver al menú principal
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
