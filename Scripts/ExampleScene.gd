extends Node2D

# Variables de ejemplo para la demostración
var back_pressed_count = 0
var max_back_presses = 2

func _ready():
	print("Escena de ejemplo inicializada")

# Esta función será llamada por BackGestureHandler cuando se detecte un gesto de retroceso
# Debe devolver true si maneja el gesto, o false para usar el comportamiento predeterminado
func handle_back_gesture():
	print("Manejando gesto de retroceso personalizado")
	
	# Ejemplo: Requerir múltiples deslizamientos antes de volver
	back_pressed_count += 1
	
	if back_pressed_count < max_back_presses:
		# Mostrar mensaje de cuántos deslizamientos faltan
		var remaining = max_back_presses - back_pressed_count
		show_toast("Desliza hacia atrás " + str(remaining) + " veces más para salir")
		
		# Devolver true para indicar que hemos manejado el gesto
		return true
	else:
		# Cuando alcanzamos el número deseado de deslizamientos, 
		# devolvemos false para usar el comportamiento predeterminado
		back_pressed_count = 0
		show_toast("Volviendo...")
		return false

# Función de ejemplo para mostrar un mensaje toast
func show_toast(message):
	print("TOAST: " + message)
	
	# Aquí puedes implementar la lógica para mostrar un mensaje en pantalla
	# Ejemplo básico usando un Label:
	var toast = Label.new()
	toast.text = message
	toast.name = "Toast"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Estilo del toast
	toast.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	toast.add_theme_font_size_override("font_size", 24)
	
	# Fondo semi-transparente
	var panel = Panel.new()
	panel.name = "ToastBackground"
	panel.add_child(toast)
	
	# Posicionar en la parte inferior de la pantalla
	panel.size = Vector2(500, 100)
	panel.position = Vector2(
		(get_viewport_rect().size.x - panel.size.x) / 2,
		get_viewport_rect().size.y - panel.size.y - 50
	)
	
	add_child(panel)
	
	# Animación de desvanecimiento
	panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): panel.queue_free()) 