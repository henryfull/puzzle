extends Control

# Señal que se emite cuando se selecciona un pack
signal pack_selected(pack_data)
# Señal que se emite cuando se quiere comprar un pack
signal pack_purchase_requested(pack_data)

# Variables para almacenar los datos del pack
var pack_data = null
var is_locked = false
var requires_purchase = false

# Función para configurar el componente con los datos del pack
func setup(data):
	pack_data = data
	
	# Configurar el título
	$MarginContainer/VBoxContainer/TitleBackground/TitleLabel.text = data.name.to_upper()
	
	# Cargar la imagen del pack si está disponible
	if data.has("image_path") and data.image_path != "":
		var image = load(data.image_path)
		if image:
			$MarginContainer/VBoxContainer/ImageContainer/PackImage.texture = image
	
	# Configurar el estado de bloqueo
	if data.has("unlocked") and not data.unlocked:
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
	if data.has("purchased") and not data.purchased and data.has("unlocked") and data.unlocked:
		requires_purchase = true
		# Aquí podrías añadir un indicador visual de que requiere compra
		# Por ejemplo, cambiar el color del fondo o añadir un icono de compra
	else:
		requires_purchase = false

# Función llamada cuando se presiona el botón
func _on_button_pressed():
	if is_locked:
		# Si está bloqueado, mostrar mensaje o animación
		print("Pack bloqueado: ", pack_data.name)
		return
	
	if requires_purchase:
		# Si requiere compra, emitir señal para mostrar diálogo de compra
		print("Pack requiere compra: ", pack_data.name)
		emit_signal("pack_purchase_requested", pack_data)
		return
	
	# Si el pack está disponible, emitir señal de selección
	print("Pack seleccionado: ", pack_data.name)
	emit_signal("pack_selected", pack_data) 
