extends Control

# Variables privadas
var _achievement_id: String = ""
var _achievement_data: Dictionary = {}
# var _default_lock_icon = preload("res://Assets/UI/lock_icon.png")

# Función para configurar el elemento con los datos del logro
func setup(achievement_id: String, achievement_data: Dictionary) -> void:
	_achievement_id = achievement_id
	_achievement_data = achievement_data
	update_ui()

# Actualiza la interfaz con los datos del logro
func update_ui() -> void:
	# Referencias a nodos de la interfaz
	var title_label = $Panel/MarginContainer/HBoxContainer/InfoContainer/TitleContainer/TitleLabel
	var secret_label = $Panel/MarginContainer/HBoxContainer/InfoContainer/TitleContainer/SecretLabel
	var description_label = $Panel/MarginContainer/HBoxContainer/InfoContainer/DescriptionLabel
	var icon_texture = $Panel/MarginContainer/HBoxContainer/IconContainer/IconTexture
	var locked_overlay = $Panel/MarginContainer/HBoxContainer/IconContainer/LockedOverlay
	var lock_icon = $Panel/MarginContainer/HBoxContainer/IconContainer/LockedOverlay/LockIcon
	var secret_overlay = $Panel/MarginContainer/HBoxContainer/IconContainer/SecretOverlay
	var progress_container = $Panel/MarginContainer/HBoxContainer/InfoContainer/ProgressContainer
	var progress_value_label = $Panel/MarginContainer/HBoxContainer/InfoContainer/ProgressContainer/ProgressValueLabel
	var progress_bar = $Panel/MarginContainer/HBoxContainer/InfoContainer/ProgressContainer/ProgressBar
	var unlocked_date = $Panel/MarginContainer/HBoxContainer/InfoContainer/UnlockedDate
	
	# Establecer título
	if _achievement_data.has("name"):
		title_label.text = _achievement_data.name
	
	# Manejar logros secretos
	if _achievement_data.has("secret") and _achievement_data.secret:
		secret_label.visible = true
		
		# Si no está desbloqueado, ocultar información
		if not _achievement_data.unlocked:
			description_label.text = "???"
			secret_overlay.visible = true
			locked_overlay.visible = false
		else:
			description_label.text = _achievement_data.desc
			secret_overlay.visible = false
	else:
		secret_label.visible = false
		secret_overlay.visible = false
		description_label.text = _achievement_data.desc if _achievement_data.has("desc") else ""
	
	# Cargar y establecer el icono
	if _achievement_data.has("icon") and ResourceLoader.exists(_achievement_data.icon):
		icon_texture.texture = load(_achievement_data.icon)
	
	# Manejar estado de bloqueado/desbloqueado
	if _achievement_data.has("unlocked") and _achievement_data.unlocked:
		locked_overlay.visible = false
		unlocked_date.visible = true
		
		# Fecha de desbloqueo (simulada por ahora)
		unlocked_date.text = "Desbloqueado el: " + Time.get_datetime_string_from_system()
	else:
		locked_overlay.visible = true
		unlocked_date.visible = false
		# Usamos el ícono por defecto si existe, si no dejamos el que está configurado en la escena
		# lock_icon.texture = _default_lock_icon
	
	# Manejar progreso
	if _achievement_data.has("progress") and _achievement_data.has("max_progress"):
		var progress = _achievement_data.progress
		var max_progress = _achievement_data.max_progress
		
		# Solo mostrar progreso si no está desbloqueado y tiene progreso máximo > 1
		if not _achievement_data.unlocked and max_progress > 1:
			progress_container.visible = true
			progress_value_label.text = "Progreso: " + str(progress) + "/" + str(max_progress)
			progress_bar.max_value = max_progress
			progress_bar.value = progress
		else:
			progress_container.visible = false
	else:
		progress_container.visible = false 