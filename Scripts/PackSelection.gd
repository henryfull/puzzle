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
	
	# Configurar el ScrollContainer
	var scroll_container = $CanvasLayer/ContainerPacks/ScrollContainer
	
	# Cargar el script de configuración táctil
	var TouchScrollFix = load("res://Scripts/TouchScrollFix.gd")
	if TouchScrollFix:
		# Configurar todos los nodos para mejorar el desplazamiento táctil
		TouchScrollFix.configure_touch_scroll(self)
		
		# Conectar las señales del ScrollContainer
		if scroll_container:
			TouchScrollFix.connect_scroll_signals(scroll_container, self, "_on_scroll_started", "_on_scroll_ended")
		else:
			print("ERROR: No se pudo encontrar el ScrollContainer para conectar señales")
	else:
		print("ERROR: No se pudo cargar el script TouchScrollFix")
	
	# Ajustar el layout según el tipo de dispositivo
	adjust_layout_for_device()
	
	# Cargar los packs
	load_packs()

# Función para ajustar el layout según el tipo de dispositivo
func adjust_layout_for_device():
	var vbox = $CanvasLayer/ContainerPacks
	
	# Siempre usar pantalla completa con márgenes
	vbox.anchors_preset = 15  # Full rect
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 20.0
	vbox.offset_top = 20.0
	vbox.offset_right = -20.0
	vbox.offset_bottom = -100.0
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Asegurar que el título y subtítulo queden en la parte superior
	var title_label = $CanvasLayer/ContainerPacks/TitleLabel
	title_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	var subtitle_label = $CanvasLayer/ContainerPacks/SubtitleLabel
	subtitle_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	# Asegurar que el ScrollContainer ocupe todo el espacio restante
	var scroll_container = $CanvasLayer/ContainerPacks/ScrollContainer
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	print("PackSelection: Layout ajustado")

func load_packs():
	# Referencia al contenedor de packs
	var packs_container = $CanvasLayer/ContainerPacks/ScrollContainer/PacksContainer
	
	# Limpiar cualquier elemento de pack existente en el contenedor
	for child in packs_container.get_children():
		child.queue_free()
	
	print("PackSelection: Llamando a get_all_packs_with_progress desde ProgressManager")
	# Obtener los packs con información de progresión
	var packs = progress_manager.get_all_packs_with_progress()
	print("PackSelection: Packs cargados: ", packs.size())
	
	# Imprimir detalles de cada pack para diagnóstico
	for i in range(packs.size()):
		var pack = packs[i]
		print("PackSelection: Pack ", i, " - ID: ", pack.id, ", Name: ", pack.name, 
			", Unlocked: ", pack.get("unlocked", "N/A"), 
			", Purchased: ", pack.get("purchased", "N/A"),
			", Puzzles: ", pack.puzzles.size() if pack.has("puzzles") else "No puzzles")
	
	if packs.size() == 0:
		print("PackSelection: ERROR - No se encontraron packs disponibles")
		print("PackSelection: Intentando leer directamente del archivo JSON")
		
		# Intentar cargar directamente del archivo JSON
		var file = FileAccess.open("res://PacksData/sample_packs.json", FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var json_result = JSON.parse_string(json_text)
			if json_result and json_result.has("packs"):
				packs = json_result.packs
				print("PackSelection: Cargados ", packs.size(), " packs directamente del archivo JSON")
			else:
				print("PackSelection: ERROR - No se pudo analizar el JSON de packs")
		else:
			print("PackSelection: ERROR - No se pudo abrir el archivo JSON de packs")
			
		# Si todavía no hay packs después del intento directo
		if packs.size() == 0:
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
		print("PackSelection: Procesando pack: ", pack.name)
		
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
		pack_component.connect("pack_purchase_requested", Callable(self, "_on_PackPurchaseRequested"))
		
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

func _on_PackPurchaseRequested(pack):
	print("Se solicitó la compra del pack: " + pack.name)
	
	# Mostrar un diálogo de confirmación
	var dialog = AcceptDialog.new()
	dialog.title = "Comprar Pack"
	dialog.dialog_text = "¿Quieres comprar el pack '" + pack.name + "'?"
	dialog.add_button("Cancelar", true, "cancel")
	dialog.add_button("Comprar", false, "purchase")
	dialog.connect("confirmed", Callable(self, "_on_Purchase_Confirmed").bind(pack))
	dialog.connect("canceled", Callable(self, "_on_Purchase_Canceled"))
	add_child(dialog)
	dialog.popup_centered()

func _on_Purchase_Confirmed(pack):
	print("Compra confirmada para el pack: " + pack.name)
	
	# Marcar el pack como comprado usando ProgressManager
	if progress_manager.has_method("purchase_pack"):
		progress_manager.purchase_pack(pack.id)
		print("Pack comprado con éxito: " + pack.name)
		
		# Mostrar mensaje de éxito
		var success_dialog = AcceptDialog.new()
		success_dialog.title = "Compra Exitosa"
		success_dialog.dialog_text = "¡Has comprado el pack '" + pack.name + "'! Ya puedes acceder a sus puzzles."
		add_child(success_dialog)
		success_dialog.popup_centered()
		
		# Recargar los packs para actualizar la interfaz
		await get_tree().create_timer(1.5).timeout
		load_packs()
	else:
		print("ERROR: No se pudo comprar el pack - Método purchase_pack no encontrado")
		
		# Mostrar mensaje de error
		var error_dialog = AcceptDialog.new()
		error_dialog.title = "Error de Compra"
		error_dialog.dialog_text = "No se pudo completar la compra. Por favor, inténtalo de nuevo más tarde."
		add_child(error_dialog)
		error_dialog.popup_centered()

func _on_Purchase_Canceled():
	print("Compra cancelada")

func _on_BackButton_pressed():
	# Volver al menú principal
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
