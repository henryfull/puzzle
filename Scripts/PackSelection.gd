extends Node2D

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")
# Referencia al administrador de compras (singleton)

# Variables para controlar el desplazamiento táctil
var is_scrolling = false
var scroll_start_position = Vector2.ZERO
var scroll_start_time = 0
var scroll_container
var packs_container
var drag_threshold = 10  # Umbral en píxeles para considerar un desplazamiento
# Referencia a la escena del componente de pack
var pack_component_scene = preload("res://Scenes/Components/PackComponent/PackComponent.tscn")

# Variable para controlar si estamos en un dispositivo táctil

func _ready():
	print("PackSelection: inicialización de los packs disponibles")
	
	scroll_container = $CanvasLayer/PanelContainer/ContainerPacks/ScrollContainer
	packs_container = $CanvasLayer/PanelContainer/ContainerPacks/ScrollContainer/PacksContainer

	# Ajustar el layout según el tipo de dispositivo
	# adjust_layout_for_device()
	
	# Cargar los packs
	load_packs()

# Función para ajustar el layout según el tipo de dispositivo
func adjust_layout_for_device():
	
	# Asegurar que el título y subtítulo queden en la parte superior
	var title_label = $CanvasLayer/PanelContainer/ContainerPacks/TitleLabel
	title_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	var subtitle_label = $CanvasLayer/PanelContainer/ContainerPacks/SubtitleLabel
	subtitle_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	print("PackSelection: Layout ajustado")

func load_packs():
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
		
		# Instanciar el componente de pack
		var pack_component = pack_component_scene.instantiate()
		pack_component.parent_node = self  # Pasar referencia a este nodo para control de scroll
		pack_component.setup(pack)
		pack_component.connect("pack_selected", Callable(self, "_on_PackSelected"))
		pack_component.connect("pack_purchase_requested", Callable(self, "_on_buy_button_pressed"))
		
		# Añadir el componente al contenedor
		packs_container.add_child(pack_component)
		print("Componente añadido para pack: ", pack.name)
	if (GLOBAL.dlc_packs.size() == 0):
		addNoPack()
	# Desplazar automáticamente al último pack disponible por desbloquear
	await get_tree().process_frame
	scroll_to_last_available_pack()

func addNoPack():
	var packs = []
	# Intentar cargar directamente del archivo JSON
	var file = FileAccess.open("res://PacksData/sample_packs.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json_result = JSON.parse_string(json_text)
		if json_result and json_result.has("dlc_packs"):
			packs = json_result.dlc_packs
			print("PackSelection: Cargados ", packs.size(), " packs directamente del archivo JSON")
		else:
			print("PackSelection: ERROR - No se pudo analizar el JSON de packs")
	else:
		print("PackSelection: ERROR - No se pudo abrir el archivo JSON de packs")
		
	# Crear componentes de pack para cada pack disponible	
	for pack in packs:
		print("PackSelection: Procesando pack: ", pack.name)
		
		# Instanciar el componente de pack
		var pack_component = pack_component_scene.instantiate()
		pack_component.parent_node = self  # Pasar referencia a este nodo para control de scroll
		pack_component.setup(pack)
		pack_component.connect("pack_selected", Callable(self, "_on_buy_button_pressed"))
		pack_component.connect("pack_purchase_requested", Callable(self, "_on_buy_button_pressed"))

		# Añadir el componente al contenedor
		packs_container.add_child(pack_component)
		print("Preview DLC añadido para pack: ", pack.name)

# Función para desplazar automáticamente al último pack disponible por desbloquear
func scroll_to_last_available_pack():
	print("PackSelection: Buscando último pack disponible por desbloquear")
	
	var found_unlockable_pack = false
	var pack_to_scroll_to = null
	var last_index = -1
	
	# Recorrer los packs en orden inverso para encontrar el último disponible
	for i in range(packs_container.get_child_count() - 1, -1, -1):
		var pack_component = packs_container.get_child(i)
		if pack_component.has_method("get_pack_data"):
			var pack_data = pack_component.get_pack_data()
			
			# Si encontramos un pack desbloqueado pero no comprado, ese es el que buscamos
			if pack_data.unlocked and not pack_data.purchased:
				pack_to_scroll_to = pack_component
				found_unlockable_pack = true
				print("PackSelection: Encontrado pack por desbloquear: ", pack_data.name)
				break
			
			# Si no encontramos ninguno por desbloquear, usamos el último desbloqueado y comprado
			if pack_data.unlocked and pack_data.purchased and not found_unlockable_pack:
				if last_index < i:
					last_index = i
					pack_to_scroll_to = pack_component
	
	# Si encontramos un pack, desplazar hasta él
	if pack_to_scroll_to:
		print("PackSelection: Desplazando al pack encontrado")
		# Calculamos la posición a la que desplazar
		var scroll_position = pack_to_scroll_to.position.y
		# Ajustamos el desplazamiento teniendo en cuenta el desplazamiento del contenedor
		scroll_container.scroll_vertical = scroll_position
	else:
		print("PackSelection: No se encontró ningún pack disponible por desbloquear")


# Función llamada cuando se confirma una compra
func _on_purchase_confirmed(pack):
	print("Compra confirmada para pack: " + pack.name + ". Actualizando interfaz...")
	# Esperar un momento antes de recargar los packs para que se vean las animaciones
	await get_tree().create_timer(1.5).timeout
	# Recargar los packs para actualizar la interfaz
	load_packs()

# Función llamada cuando se cancela una compra
func _on_purchase_canceled():
	print("Compra cancelada por el usuario")

func _on_buy_button_pressed() -> void:
	print("PackSelection: Iniciando proceso de compra de packs DLC")
	# Crear una nueva instancia de DialogBuy
	var dialogBuy = load("res://Scripts/Components/DialogBuy/DialogBuy.tscn")
	var dialogBuy_instance = dialogBuy.instantiate()
	# Agregar la instancia a la escena
	add_child(dialogBuy_instance)
	# Conectar la señal de compra completada
	dialogBuy_instance.connect("purchase_completed", Callable(self, "_on_purchase_completed"))

# Función que se ejecuta cuando se completa una compra
func _on_purchase_completed() -> void:
	print("PackSelection: Compra de DLC completada, recargando packs...")
	# Recargar los packs para mostrar los nuevos
	load_packs()
	
