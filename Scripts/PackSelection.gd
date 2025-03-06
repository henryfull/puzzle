extends Node2D

# Acceso al singleton ProgressManager
@onready var progress_manager = get_node("/root/ProgressManager")

func _ready():
	# Inicialización de la selección de pack.
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
	
	for pack in packs:
		print("Procesando pack: ", pack.name)
		
		# Crear un panel para el pack con estilo
		var pack_panel = Panel.new()
		pack_panel.custom_minimum_size = Vector2(300, 80)
		pack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Añadir estilo al panel
		var style = StyleBoxFlat.new()
		
		# Cambiar el color del panel según el estado del pack
		if pack.unlocked and pack.purchased:
			# Pack disponible
			style.bg_color = Color(0.9, 0.9, 0.9, 1.0)
		elif pack.unlocked and not pack.purchased:
			# Pack desbloqueado pero requiere compra
			style.bg_color = Color(0.9, 0.8, 0.3, 1.0)
		else:
			# Pack bloqueado
			style.bg_color = Color(0.7, 0.7, 0.7, 0.8)
		
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.shadow_color = Color(0, 0, 0, 0.2)
		style.shadow_size = 5
		style.shadow_offset = Vector2(2, 2)
		pack_panel.add_theme_stylebox_override("panel", style)
		
		# Crear un contenedor para organizar el contenido del panel
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hbox.custom_minimum_size = Vector2(280, 60)
		hbox.position = Vector2(10, 10)
		pack_panel.add_child(hbox)
		
		# Crear un botón para el pack
		var button = Button.new()
		button.text = pack.name
		button.custom_minimum_size = Vector2(200, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Desactivar el botón si el pack está bloqueado
		button.disabled = not (pack.unlocked and pack.purchased)
		
		button.pressed.connect(Callable(self, "_on_PackSelected").bind(pack))
		hbox.add_child(button)
		
		# Si el pack está desbloqueado pero requiere compra, añadir un botón de compra
		if pack.unlocked and not pack.purchased:
			var buy_button = Button.new()
			buy_button.text = "Comprar"
			buy_button.custom_minimum_size = Vector2(80, 60)
			buy_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
			buy_button.pressed.connect(Callable(self, "_on_BuyPackSelected").bind(pack))
			hbox.add_child(buy_button)
		
		# Si el pack está bloqueado, mostrar un icono de candado
		if not pack.unlocked:
			var lock_label = Label.new()
			lock_label.text = "🔒"
			lock_label.custom_minimum_size = Vector2(40, 60)
			lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_label.add_theme_font_size_override("font_size", 24)
			hbox.add_child(lock_label)
		
		# Añadir el panel al contenedor de packs
		packs_container.add_child(pack_panel)
		print("Panel añadido para pack: ", pack.name)

func _on_PackSelected(pack):
	print("Pack seleccionado: ", pack)
	
	# Verificar que el pack tenga la estructura correcta
	if not pack.has("puzzles"):
		print("ERROR: El pack seleccionado no tiene la clave 'puzzles'")
		# Añadir una clave puzzles vacía para evitar errores
		pack["puzzles"] = []
	
	GLOBAL.selected_pack = pack	
	# Función llamada al seleccionar un pack
	print("Pack seleccionado: " + pack.name + " con " + str(pack.puzzles.size()) + " puzzles")
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn") 

func _on_BuyPackSelected(pack):
	print("Comprar pack seleccionado: ", pack.name)
	
	# Aquí iría la lógica de compra real (integración con tienda, etc.)
	# Por ahora, simplemente simularemos la compra
	
	# Mostrar un diálogo de confirmación
	var dialog = ConfirmationDialog.new()
	dialog.title = "Comprar Pack"
	dialog.dialog_text = "¿Quieres comprar el pack '" + pack.name + "'?"
	dialog.confirmed.connect(Callable(self, "_on_BuyConfirmed").bind(pack))
	add_child(dialog)
	dialog.popup_centered()

func _on_BuyConfirmed(pack):
	print("Compra confirmada para el pack: ", pack.name)
	
	# Marcar el pack como comprado en el ProgressManager
	progress_manager.purchase_pack(pack.id)
	
	# Recargar la lista de packs para reflejar los cambios
	load_packs()

func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
