extends Control

@onready var purchase_manager = get_node("/root/PackPurchaseManager")

# Señal que se emite cuando se selecciona un pack
signal pack_selected(pack_data)
# Señal que se emite cuando se quiere comprar un pack
signal pack_purchase_requested(pack_data)


# Variables para almacenar los datos del pack
var pack_data = null
var is_locked = false
var requires_purchase = false

# Añadir referencia al nodo parent para comprobar si está haciendo scroll
var parent_node

# Función para configurar el componente con los datos del pack
func setup(data):
	pack_data = data
	# Configurar el título
	$MarginContainer/VBoxContainer/TitleBackground/TitleLabel.text = data.name.to_upper()
	
	# Cargar la imagen del pack si está disponible
	_load_pack_image()
	
	# Configurar el estado de bloqueo y compra
	_update_pack_state()

# Función para cargar la imagen del pack
func _load_pack_image():
	if pack_data.has("image_path") and pack_data.image_path != "":
		var image = load(pack_data.image_path)
		if image:
			$MarginContainer/VBoxContainer/ImageContainer/PackImage.texture = image
	else:
		# Intentar encontrar una imagen basada en el ID o nombre
		_find_and_set_pack_image()

# Busca una imagen apropiada para el pack y la establece
func _find_and_set_pack_image():
	if not pack_data.has("id"):
		return
		
	var possible_paths = [
		"res://Assets/Images/packs/" + pack_data.id + "/icon.png",
		"res://Assets/Images/packs/" + pack_data.id + "/preview.png"
	]
	
	if pack_data.has("name"):
		possible_paths.append("res://Assets/Images/packs/" + pack_data.name.to_lower() + "/icon.png")
		possible_paths.append("res://Assets/Images/packs/" + pack_data.name.to_lower() + "/preview.png")
	
	for path in possible_paths:
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var image = load(path)
			if image:
				$MarginContainer/VBoxContainer/ImageContainer/PackImage.texture = image
				pack_data.image_path = path
			file.close()
			break

# Actualiza el estado del pack (bloqueado/desbloqueado, comprado/no comprado)
func _update_pack_state():
	# Configurar el estado de bloqueo
	if pack_data.has("unlocked") and not pack_data.unlocked:
		is_locked = true
		$LockOverlay.visible = true
		# Cargar icono de candado si existe
		var lock_icon = load("res://Assets/Images/lock_icon.png")
		if lock_icon:
			$LockOverlay/LockIcon.texture = lock_icon
	else:
		is_locked = false
		$LockOverlay.visible = false
	
	# Configurar estado de compra
	if pack_data.has("purchased") and not pack_data.purchased and pack_data.has("unlocked") and pack_data.unlocked:
		requires_purchase = true
		# Aquí podrías añadir un indicador visual de que requiere compra
		# Por ejemplo, añadir un icono o cambiar el color
		_show_purchase_indicator()
	else:
		requires_purchase = false
		_hide_purchase_indicator()

# Muestra un indicador visual de que el pack requiere compra
func _show_purchase_indicator():
	# Implementar visualización de indicador de compra
	# Por ejemplo, podríamos cambiar el color del borde o añadir un icono
	$Panel.add_theme_color_override("border_color", Color(0.9, 0.6, 0.1, 1)) # Color naranja para indicar compra

# Oculta el indicador de compra
func _hide_purchase_indicator():
	# Restaurar visualización por defecto
	$Panel.add_theme_color_override("border_color", Color(0, 0.827451, 0.243137, 1)) # Verde por defecto

# Función llamada cuando se presiona el botón
func _on_button_pressed():

	if is_locked:
		# Si está bloqueado, mostrar mensaje o animación
		print("PackComponent: Pack bloqueado: ", pack_data.name)
		_show_locked_feedback()
		return
	
	if requires_purchase:
		# Si requiere compra, emitir señal para mostrar diálogo de compra
		print("PackComponent: Pack requiere compra: ", pack_data.name)
		emit_signal("pack_purchase_requested", pack_data)
		return
	
	# Si el pack está disponible, emitir señal de selección
	print("PackComponent: Pack seleccionado: ", pack_data.name)
	GLOBAL.selected_pack = pack_data	
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn")

# Muestra algún tipo de feedback cuando se intenta acceder a un pack bloqueado
func _show_locked_feedback():
	# Animación o efecto visual para indicar que está bloqueado
	# Por ejemplo, hacer que el candado parpadee o vibre
	var tween = create_tween()
	tween.tween_property($LockOverlay, "modulate", Color(1, 0.5, 0.5, 1), 0.2)
	tween.tween_property($LockOverlay, "modulate", Color(1, 1, 1, 1), 0.2)

# Método para obtener los datos del pack
func get_pack_data():
	return pack_data

# Actualiza el estado del pack (útil cuando cambia su estado)
func update_pack_state(new_data = null):
	if new_data:
		pack_data = new_data
	_update_pack_state() 
