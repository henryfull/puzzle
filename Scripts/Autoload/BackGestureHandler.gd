extends Node

# Variables para configurar el gesto de deslizar desde el borde
@export var edge_width: int = 50  # Ancho en píxeles del borde sensible al gesto
@export var swipe_threshold: float = 100.0  # Distancia mínima para considerar un deslizamiento válido
@export var swipe_time_threshold: float = 0.5  # Tiempo máximo para completar el gesto (en segundos)

# Variable para el diálogo de confirmación
var confirm_dialog_scene := preload("res://Scenes/Components/ConfirmExitDialog/ConfirmExitDialog.tscn")

# Variables para seguimiento del gesto
var touch_start_position = Vector2.ZERO
var touch_start_time = 0.0
var is_touching_edge = false
var current_touch_id = -1  # Para seguimiento del ID del toque
var quit_requested = false

# Variables de control para escenas
var is_in_main_menu = false
var is_in_puzzle_game = false  # Nueva variable para detectar si estamos en el puzzle
var active_dialog = null

# Variable para controlar si los gestos del borde están habilitados
var edge_gestures_enabled = true

func _ready():
	# Desactivar la aceptación automática de salida
	get_tree().set_auto_accept_quit(false)
	
	# Conectar el cambio de escena para detectar cuándo estamos en el menú principal o en el puzzle
	get_tree().root.connect("ready", _on_scene_changed)

func _on_scene_changed():
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_path = current_scene.scene_file_path
		if scene_path != null:
			var scene_name = scene_path.get_file()
			is_in_main_menu = (scene_name == "MainMenu.tscn")
			is_in_puzzle_game = (scene_name == "PuzzleGame.tscn")
			
			# CRÍTICO: Deshabilitar gestos del borde cuando estamos en el puzzle
			if is_in_puzzle_game:
				edge_gestures_enabled = false
				print("BackGestureHandler: Gestos del borde DESHABILITADOS para el puzzle")
			else:
				edge_gestures_enabled = true
				print("BackGestureHandler: Gestos del borde habilitados para escena: ", scene_name)
			
			print("BackGestureHandler: Escena cambiada a: ", scene_name, 
				  ", es menú principal: ", is_in_main_menu, 
				  ", es puzzle: ", is_in_puzzle_game)

# Esta función se llama cuando el sistema operativo intenta cerrar la app
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Solicitud de cierre de ventana detectada")
		_on_close_requested()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Solo en Android, cuando se pulsa el botón atrás físico
		print("Solicitud de botón atrás detectada")
		# Si estamos en el puzzle, IGNORAR el gesto del botón atrás físico
		if is_in_puzzle_game:
			print("BackGestureHandler: En puzzle - Ignorando botón atrás físico")
			get_viewport().set_input_as_handled()
			return
		_handle_back_gesture()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		print("Aplicación perdió el foco")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		print("Aplicación recuperó el foco")

# Esta función intercepta el cierre por teclado o UI
func _process(_delta):
	if quit_requested:
		print("Petición de salida en proceso...")
	
	# 🚫 CRÍTICO: Durante el puzzle, eliminar CUALQUIER diálogo que aparezca cada frame
	if is_in_puzzle_game:
		_force_remove_all_dialogs_during_puzzle()

# Cuando se recibe una solicitud de cierre de la aplicación
func _on_close_requested():
	print("Interceptada solicitud de cierre")
	
	# Si estamos en el puzzle, mostrar un diálogo especial de confirmación
	if is_in_puzzle_game:
		print("BackGestureHandler: En puzzle - Mostrando diálogo de confirmación de cierre")
		_show_puzzle_exit_confirmation()
	else:
		# En otras escenas, usar el diálogo normal
		show_exit_dialog()
	
	# Bloquear el cierre automático para permitir la confirmación
	get_viewport().set_input_as_handled()

func _input(event):
	# 🚫 CRÍTICO: Si estamos en el puzzle, NO procesar NINGÚN gesto del borde
	if is_in_puzzle_game:
		# Durante el puzzle, ignorar completamente todos los gestos del borde
		# No mostrar mensajes, no hacer nada, simplemente continuar con el juego
		return
	
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

# Manejar el gesto de "volver atrás" específico para el puzzle
func _handle_back_gesture_puzzle():
	print("BackGestureHandler: Botón atrás físico detectado en puzzle")
	
	# En el puzzle, abrir el menú de pausa en lugar de salir directamente
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("_on_button_options_pressed"):
		print("BackGestureHandler: Abriendo menú de pausa en puzzle")
		current_scene._on_button_options_pressed()
	else:
		print("BackGestureHandler: Escena de puzzle no tiene menú de pausa, mostrando diálogo de salida")
		show_exit_dialog()

# Manejar el gesto de "volver atrás"
func _handle_back_gesture():
	print("BackGestureHandler: Gesto de volver atrás detectado")
	
	# 🚫 CRÍTICO: Si estamos en el puzzle, IGNORAR completamente el gesto
	if is_in_puzzle_game:
		print("BackGestureHandler: En puzzle - Ignorando gesto de volver atrás")
		get_viewport().set_input_as_handled()
		return
	
	# Si ya hay un diálogo activo, no hacer nada
	if active_dialog != null:
		print("BackGestureHandler: Ya hay un diálogo activo, ignorando gesto")
		return
	
	# Si estamos en el menú principal, mostrar diálogo de salida
	if is_in_main_menu:
		print("BackGestureHandler: En menú principal, mostrando diálogo de salida")
		show_exit_dialog()
		return
	
	# Si estamos en otra escena, intentar volver al menú principal
	print("BackGestureHandler: En otra escena, volviendo al menú principal")
	go_to_main_menu()

# Mostrar el diálogo de confirmación para salir
func show_exit_dialog():
	# 🚫 CRÍTICO: Si estamos en el puzzle, NO mostrar NINGÚN diálogo
	if is_in_puzzle_game:
		print("BackGestureHandler: En puzzle - NO mostrar diálogo de salida, ignorando completamente")
		return
	
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
	
	# 🚫 NUEVO: Usar el interceptor para crear el diálogo
	var dialog = _create_exit_dialog()
	
	# Si el interceptor devolvió null (estamos en puzzle), salir inmediatamente
	if dialog == null:
		print("BackGestureHandler: Creación de diálogo bloqueada por interceptor")
		return
	
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
	# Si estamos en el puzzle, solo eliminar diálogos que NO sean nuestro diálogo especial
	if is_in_puzzle_game:
		print("BackGestureHandler: En puzzle - Eliminando diálogos excepto el de confirmación de cierre")
		var current_scene = get_tree().current_scene
		if current_scene:
			for child in current_scene.get_children():
				# NO eliminar nuestro diálogo especial de confirmación de cierre
				if child == active_dialog and child is AcceptDialog:
					continue
				
				if child.is_in_group("exit_dialog") or child.name.contains("Dialog") or child.name.contains("Confirm"):
					print("BackGestureHandler: Eliminando diálogo forzosamente: ", child.name)
					child.queue_free()
		
		# Solo limpiar active_dialog si NO es nuestro diálogo especial
		if active_dialog != null and is_instance_valid(active_dialog):
			if not (active_dialog is AcceptDialog):
				active_dialog = null
		return
	
	# Limpiar diálogos en la escena actual (fuera del puzzle)
	var current_scene = get_tree().current_scene
	if current_scene:
		for child in current_scene.get_children():
			if child.is_in_group("exit_dialog"):
				print("Eliminando diálogo existente de la escena")
				child.queue_free()
	
	# Limpiar referencia al diálogo activo
	active_dialog = null

# Función para volver al menú principal de manera segura
func go_to_main_menu():
	print("BackGestureHandler: Navegando al menú principal")
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		if global.has_method("change_scene_with_loading"):
			global.change_scene_with_loading("res://Scenes/MainMenu.tscn")
		else:
			# Fallback si no existe change_scene_with_loading
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	else:
		# Fallback directo
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

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
	
# 🚫 FUNCIÓN CRÍTICA: Eliminar cualquier diálogo que aparezca durante el puzzle
# EXCEPTO el diálogo especial de confirmación de cierre
func _force_remove_all_dialogs_during_puzzle():
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	# Lista de nombres comunes de diálogos a eliminar
	var dialog_keywords = ["Dialog", "Confirm", "Exit", "Quit", "Alert", "Warning", "Popup", "Modal"]
	
	# Buscar y eliminar cualquier nodo que pueda ser un diálogo
	for child in current_scene.get_children():
		# NO eliminar nuestro diálogo especial de confirmación de cierre
		if child == active_dialog and child is AcceptDialog:
			continue
		
		# Verificar si es un diálogo por nombre
		var is_dialog = false
		for keyword in dialog_keywords:
			if child.name.contains(keyword):
				is_dialog = true
				break
		
		# Verificar si está en grupo de diálogos
		if child.is_in_group("exit_dialog") or child.is_in_group("dialog") or child.is_in_group("popup"):
			is_dialog = true
		
		# Verificar si es un CanvasLayer con diálogos dentro
		if child is CanvasLayer:
			for grandchild in child.get_children():
				for keyword in dialog_keywords:
					if grandchild.name.contains(keyword):
						print("BackGestureHandler: Eliminando diálogo en CanvasLayer: ", grandchild.name)
						grandchild.queue_free()
		
		# Si encontramos un diálogo, eliminarlo inmediatamente
		if is_dialog:
			print("BackGestureHandler: Eliminando diálogo durante puzzle: ", child.name)
			child.queue_free()
	
	# NO limpiar la referencia al diálogo activo si es nuestro diálogo especial
	if active_dialog != null and is_instance_valid(active_dialog):
		if not (active_dialog is AcceptDialog):
			active_dialog.queue_free()
			active_dialog = null

# 🚫 NUEVO: Función para crear diálogo con interceptor
func _create_exit_dialog():
	# 🚫 INTERCEPTOR CRÍTICO: Si estamos en puzzle, NO crear NUNCA el diálogo
	if is_in_puzzle_game:
		print("BackGestureHandler: _create_exit_dialog() bloqueado - Estamos en puzzle")
		return null
	
	# Solo crear si no estamos en puzzle
	return confirm_dialog_scene.instantiate()

# Función especial para mostrar confirmación de cierre durante el puzzle
func _show_puzzle_exit_confirmation():
	print("BackGestureHandler: Mostrando diálogo de confirmación especial para puzzle")
	
	# Crear un diálogo simple usando el sistema de alertas de Godot
	var dialog_text = "¿Quieres cerrar el juego?\n\nTu progreso en el puzzle actual se perderá."
	
	# Crear un diálogo personalizado que NO será eliminado por el sistema anti-diálogos
	var puzzle_exit_dialog = AcceptDialog.new()
	puzzle_exit_dialog.set_title("Cerrar juego")
	puzzle_exit_dialog.set_text(dialog_text)
	puzzle_exit_dialog.add_button("Salir", true, "exit")
	puzzle_exit_dialog.add_button("Cancelar", false, "cancel")
	
	# Configurar el diálogo para que esté por encima de todo
	puzzle_exit_dialog.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	puzzle_exit_dialog.set_flag(Window.FLAG_ALWAYS_ON_TOP, true)
	
	# Conectar las señales
	puzzle_exit_dialog.confirmed.connect(_on_puzzle_exit_confirmed)
	puzzle_exit_dialog.canceled.connect(_on_puzzle_exit_canceled)
	puzzle_exit_dialog.custom_action.connect(_on_puzzle_exit_custom_action)
	
	# Añadir el diálogo a la escena del puzzle
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(puzzle_exit_dialog)
		puzzle_exit_dialog.popup_centered()
		
		# Guardar referencia para poder limpiarlo después
		active_dialog = puzzle_exit_dialog
		
		print("BackGestureHandler: Diálogo de confirmación de puzzle mostrado")

# Callback cuando se confirma salir del puzzle
func _on_puzzle_exit_confirmed():
	print("BackGestureHandler: Confirmado cierre del juego desde puzzle")
	_cleanup_puzzle_dialog()
	get_tree().quit()

# Callback cuando se cancela salir del puzzle
func _on_puzzle_exit_canceled():
	print("BackGestureHandler: Cancelado cierre del juego desde puzzle")
	_cleanup_puzzle_dialog()

# Callback para acciones personalizadas del diálogo
func _on_puzzle_exit_custom_action(action):
	print("BackGestureHandler: Acción personalizada en diálogo de puzzle: ", action)
	if action == "exit":
		_on_puzzle_exit_confirmed()
	elif action == "cancel":
		_on_puzzle_exit_canceled()

# Limpiar el diálogo del puzzle
func _cleanup_puzzle_dialog():
	if active_dialog != null and is_instance_valid(active_dialog):
		active_dialog.queue_free()
		active_dialog = null
