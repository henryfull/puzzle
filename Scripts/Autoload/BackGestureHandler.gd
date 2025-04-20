extends Node

# Variables para configurar el gesto de deslizar desde el borde
@export var edge_width: int = 50  # Ancho en píxeles del borde sensible al gesto
@export var swipe_threshold: float = 100.0  # Distancia mínima para considerar un deslizamiento válido
@export var swipe_time_threshold: float = 0.5  # Tiempo máximo para completar el gesto (en segundos)

# Variable para el diálogo de confirmación
var confirm_dialog_scene := preload("res://Scenes/ConfirmExitDialog.tscn")

# Variables para seguimiento del gesto
var touch_start_position = Vector2.ZERO
var touch_start_time = 0.0
var is_touching_edge = false
var current_touch_id = -1  # Para seguimiento del ID del toque
var quit_requested = false

# Variables de control para escenas
var is_in_main_menu = false
var active_dialog = null

func _ready():
	# Desactivar la aceptación automática de salida
	get_tree().set_auto_accept_quit(false)
	
	# Conectar el cambio de escena para detectar cuándo estamos en el menú principal
	get_tree().root.connect("ready", _on_scene_changed)

func _on_scene_changed():
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_path = current_scene.scene_file_path
		if scene_path != null:
			var scene_name = scene_path.get_file()
			is_in_main_menu = (scene_name == "MainMenu.tscn")
			print("Escena cambiada a: ", scene_name, ", es menú principal: ", is_in_main_menu)

# Esta función se llama cuando el sistema operativo intenta cerrar la app
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Solicitud de cierre de ventana detectada")
		_on_close_requested()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Solo en Android, cuando se pulsa el botón atrás físico
		print("Solicitud de botón atrás detectada")
		_handle_back_gesture()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		print("Aplicación perdió el foco")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		print("Aplicación recuperó el foco")

# Esta función intercepta el cierre por teclado o UI
func _process(_delta):
	if quit_requested:
		print("Petición de salida en proceso...")

# Cuando se recibe una solicitud de cierre de la aplicación
func _on_close_requested():
	print("Interceptada solicitud de cierre")
	show_exit_dialog()
	# Bloquear el cierre automático
	get_viewport().set_input_as_handled()

func _input(event):
	# Eventos de toque en pantalla solo en dispositivos móviles
	if not (OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android")):
		return
	
	# Eventos de toque en pantalla
	if event is InputEventScreenTouch:
		if event.pressed:
			# Iniciar seguimiento del toque
			var screen_size = get_viewport().get_visible_rect().size
			
			# Verificar si el toque está en el borde derecho
			if event.position.x >= screen_size.x - edge_width:
				touch_start_position = event.position
				touch_start_time = Time.get_ticks_msec() / 1000.0
				is_touching_edge = true
				current_touch_id = event.index
			else:
				is_touching_edge = false
		else:
			# Finalizar seguimiento solo si es el mismo toque que iniciamos
			if event.index == current_touch_id:
				is_touching_edge = false
				current_touch_id = -1
	
	# Eventos de arrastre en pantalla
	elif event is InputEventScreenDrag and is_touching_edge and event.index == current_touch_id:
		# Verificar si es un deslizamiento desde el borde derecho hacia la izquierda
		var current_time = Time.get_ticks_msec() / 1000.0
		var time_elapsed = current_time - touch_start_time
		var distance = touch_start_position.x - event.position.x
		
		# Si el gesto cumple los requisitos (distancia y tiempo)
		if distance > swipe_threshold and time_elapsed < swipe_time_threshold:
			# Detectamos un gesto de "volver atrás"
			_handle_back_gesture()
			
			# Reiniciar el seguimiento del gesto
			is_touching_edge = false
			current_touch_id = -1
			
			# Marcar el evento como manejado para evitar que se propague
			get_viewport().set_input_as_handled()

# Manejar el gesto de "volver atrás"
func _handle_back_gesture():
	# Obtener la escena actual
	var current_scene = get_tree().current_scene
	if current_scene == null:
		print("No hay escena activa para manejar el gesto")
		return
		
	print("Gesto de volver atrás detectado")
	
	# Verificar si la escena tiene su propio método para manejar el gesto
	if current_scene.has_method("handle_back_gesture"):
		print("La escena tiene un manejador personalizado para el gesto")
		# Delegar el manejo del gesto a la escena actual
		var result = current_scene.handle_back_gesture()
		
		# Si la escena devuelve true, significa que manejó el gesto
		if result == true:
			print("Gesto manejado por la escena")
			return
	
	# Si la escena no tiene manejador o devolvió false, usar comportamiento predeterminado
	_default_back_behavior()

# Comportamiento predeterminado para el gesto de volver atrás
func _default_back_behavior():
	# Verificar en qué escena estamos
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return
		
	var scene_path = current_scene.scene_file_path
	if scene_path == null:
		print("Escena sin ruta, no se puede determinar comportamiento")
		return
		
	var scene_name = scene_path.get_file()
	print("Usando comportamiento predeterminado para escena: ", scene_name)
	
	# Implementar lógica de navegación "atrás" según la escena actual
	if scene_name == "MainMenu.tscn":
		# En el menú principal, mostrar diálogo de confirmación para salir
		show_exit_dialog()
	elif scene_name == "PuzzleGame.tscn":
		# En el juego, volver al menú de selección
		get_node("/root/GLOBAL").change_scene_with_loading("res://Scenes/PuzzleSelection.tscn")
	elif scene_name == "PuzzleSelection.tscn":
		# En selección de puzzles, volver a selección de packs
		get_node("/root/GLOBAL").change_scene_with_loading("res://Scenes/PackSelection.tscn")
	elif scene_name == "PackSelection.tscn" or scene_name == "Options.tscn" or scene_name == "Achievements.tscn":
		# En estas escenas, volver al menú principal
		get_node("/root/GLOBAL").change_scene_with_loading("res://Scenes/MainMenu.tscn")
	else:
		# Para escenas desconocidas, intentar volver al menú principal
		print("Escena desconocida, volviendo al menú principal")
		get_node("/root/GLOBAL").change_scene_with_loading("res://Scenes/MainMenu.tscn")

# Mostrar el diálogo de confirmación para salir
func show_exit_dialog():
	# Si ya hay un diálogo activo, no crear otro
	if active_dialog != null and is_instance_valid(active_dialog):
		print("Ya hay un diálogo activo")
		return
		
	# Eliminar diálogos existentes para evitar duplicados
	_remove_existing_dialogs()
	
	print("Instanciando diálogo en la escena actual")
	
	# Obtener la escena actual
	var current_scene = get_tree().current_scene
	if not current_scene:
		print("ERROR: No se puede encontrar la escena actual")
		return
	
	# Instanciar un nuevo diálogo (que ya incluye su propio CanvasLayer)
	var dialog = confirm_dialog_scene.instantiate()
	
	# Conectar las señales
	dialog.exit_confirmed.connect(_on_exit_confirmed)
	dialog.exit_canceled.connect(_on_exit_canceled)
	
	# Guardar referencia al diálogo activo
	active_dialog = dialog
	
	# Añadir el diálogo directamente a la escena actual
	current_scene.add_child(dialog)
	
	# Mostrar el diálogo
	dialog.show_dialog()
	
	print("Diálogo instanciado y mostrado")

# Eliminar diálogos existentes para evitar duplicados
func _remove_existing_dialogs():
	# Limpiar diálogos en la escena actual
	var current_scene = get_tree().current_scene
	if current_scene:
		for child in current_scene.get_children():
			if child.is_in_group("exit_dialog"):
				print("Eliminando diálogo existente de la escena")
				child.queue_free()
	
	# Limpiar referencia al diálogo activo
	active_dialog = null

# Callback cuando se confirma salir
func _on_exit_confirmed():
	print("Confirmado: Saliendo del juego")
	# Indicar que la salida está autorizada
	quit_requested = false
	# Salir del juego
	get_tree().quit()

# Callback cuando se cancela salir
func _on_exit_canceled():
	print("Cancelado: Permaneciendo en el juego")
	# Reiniciar la bandera
	quit_requested = false
	
	# Eliminar el diálogo después de cancelar
	_remove_existing_dialogs()
	
