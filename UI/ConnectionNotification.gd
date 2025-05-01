extends Control

# Nodos de la interfaz
@onready var icon = $Panel/HBoxContainer/Icon
@onready var message_label = $Panel/HBoxContainer/Message
@onready var timer = $Timer
@onready var animation_player = $AnimationPlayer

# Colores para los estados
var success_color = Color(0.2, 0.8, 0.2)
var error_color = Color(0.8, 0.2, 0.2)

# Duración de la notificación en segundos
var display_duration = 3.0

func _ready():
	# Configurar temporizador
	timer.wait_time = display_duration
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	
	# Posicionar la notificación en la parte superior de la pantalla
	reset_position()
	
	# Ocultar al inicio
	visible = false

# Mostrar notificación de éxito
func show_success(service_name):
	message_label.text = "Conectado a " + service_name
	icon.modulate = success_color
	
	_show_notification()

# Mostrar notificación de error
func show_error(service_name, error_message):
	message_label.text = "Error al conectar a " + service_name + ": " + error_message
	icon.modulate = error_color
	
	_show_notification()

# Método interno para mostrar la notificación
func _show_notification():
	reset_position()
	visible = true
	
	# Iniciar animación de entrada
	animation_player.play("fade_in")
	
	# Iniciar temporizador
	timer.start()

# Cuando el temporizador termina, ocultar la notificación
func _on_timer_timeout():
	animation_player.play("fade_out")
	animation_player.animation_finished.connect(_on_fade_out_finished)

# Cuando la animación de salida termina
func _on_fade_out_finished(anim_name):
	if anim_name == "fade_out":
		visible = false
		# Desconectar la señal para evitar múltiples conexiones
		animation_player.animation_finished.disconnect(_on_fade_out_finished)

# Ajustar posición al tamaño de la pantalla
func reset_position():
	var viewport_size = get_viewport_rect().size
	position = Vector2((viewport_size.x - size.x) / 2, 20) 
