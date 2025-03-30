extends Control

# Variables privadas
var _title: String = ""
var _description: String = ""
var _icon_path: String = ""
var _duration: float = 3.0

# Configurar la notificación con los datos del logro
func setup(title: String, description: String, icon_path: String, duration: float = 3.0) -> void:
	_title = title
	_description = description
	_icon_path = icon_path
	_duration = duration
	
	# Configurar para que no bloquee la interacción con el juego
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Actualizar la UI
	update_ui()
	
# Actualizar la UI con los datos
func update_ui() -> void:
	# Establecer el título
	var title_label = $Panel/HBoxContainer/VBoxContainer/TitleLabel
	title_label.text = _title
	
	# Establecer la descripción
	var description_label = $Panel/HBoxContainer/VBoxContainer/DescriptionLabel
	description_label.text = _description
	
	# Cargar y establecer el icono
	var icon_texture = $Panel/HBoxContainer/IconTexture
	if ResourceLoader.exists(_icon_path):
		icon_texture.texture = load(_icon_path)
	else:
		# Usar un icono por defecto si no existe el indicado
		print("AchievementNotification: Icono no encontrado: ", _icon_path)
		# icon_texture.texture = load("res://Assets/Icons/achievement_default.png")

# Mostrar la notificación
func show_notification() -> void:
	# Inicialmente establecer la opacidad a 0
	modulate.a = 0
	
	# Asegurar que también el panel no capture eventos del mouse
	$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Reproducir la animación de entrada
	var animation_player = $AnimationPlayer
	animation_player.play("slide_in")
	
	# Configurar el timer para que desaparezca después de la duración
	var timer = $Timer
	timer.wait_time = _duration
	timer.start()

# Cuando el timer finaliza, reproducir la animación de salida
func _on_timer_timeout() -> void:
	var animation_player = $AnimationPlayer
	animation_player.play("slide_out")
	
# Método para permitir cerrar la notificación al hacer clic
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		$AnimationPlayer.play("slide_out")
		
# Método para asegurar que la notificación se libera correctamente
func _exit_tree() -> void:
	# Asegurarse de que se detiene el timer
	$Timer.stop() 