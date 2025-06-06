extends Control

# Señal que se emite cuando el usuario confirma salir
signal exit_confirmed
# Señal que se emite cuando el usuario cancela
signal exit_canceled

# Variables para personalización desde el Inspector
@export var title_text: String = "¿Salir del juego?"
@export var message_text: String = "¿Estás seguro que quieres salir?"
@export var confirm_button_text: String = "Salir"
@export var cancel_button_text: String = "Cancelar"

# Referencias a los nodos
@onready var title_label = $CanvasLayer/CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var message_label = $CanvasLayer/CenterContainer/Panel/MarginContainer/VBoxContainer/MessageLabel
@onready var confirm_button = $CanvasLayer/CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonsContainer/ConfirmButton
@onready var cancel_button = $CanvasLayer/CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonsContainer/CancelButton

func _ready():
	# 🚫 INTERCEPTOR CRÍTICO: Si estamos en puzzle, hacerse invisible INMEDIATAMENTE
	if _is_in_puzzle_game():
		print("ConfirmExitDialog: En puzzle - Haciéndose invisible inmediatamente")
		_make_completely_invisible()
		_self_destruct_immediately()
		return
	
	# Añadir el nodo a un grupo para facilitar su identificación
	add_to_group("exit_dialog")
	
	# Aplicar textos configurados
	title_label.text = title_text
	message_label.text = message_text
	confirm_button.text = confirm_button_text
	cancel_button.text = cancel_button_text
	
	# Asegurar que las señales están conectadas correctamente
	if not confirm_button.pressed.is_connected(_on_confirm_button_pressed):
		confirm_button.pressed.connect(_on_confirm_button_pressed)
		
	if not cancel_button.pressed.is_connected(_on_cancel_button_pressed):
		cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	# Configurar para que siempre esté por encima de todo
	$CanvasLayer.layer = 128  # Un valor alto para estar por encima
	
	# Asegurarse que el diálogo está visible inicialmente (será llamado show_dialog después)
	visible = true
	print("ConfirmExitDialog listo")

# 🚫 FUNCIÓN CRÍTICA: Detectar si estamos en el puzzle
func _is_in_puzzle_game() -> bool:
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_path = current_scene.scene_file_path
		if scene_path != null:
			var scene_name = scene_path.get_file()
			return scene_name == "PuzzleGame.tscn"
	return false

# 🚫 FUNCIÓN CRÍTICA: Hacerse completamente invisible sin parpadeo
func _make_completely_invisible():
	# Hacerse invisible inmediatamente
	visible = false
	modulate.a = 0
	
	# Hacer invisible el CanvasLayer también
	if has_node("CanvasLayer"):
		$CanvasLayer.visible = false
		# Los CanvasLayer no tienen modulate, solo se puede hacer invisible
		
		# Hacer invisibles todos los hijos también
		for child in $CanvasLayer.get_children():
			if child != null:
				child.visible = false
				if child.has_method("set_modulate"):
					child.modulate.a = 0

# 🚫 FUNCIÓN CRÍTICA: Auto-destruirse inmediatamente
func _self_destruct_immediately():
	# Programar eliminación inmediata (siguiente frame)
	call_deferred("queue_free")
	
	# También programar una eliminación de emergencia por si la primera falla
	get_tree().create_timer(0.01).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)

# Mostrar el diálogo
func show_dialog():
	# 🚫 INTERCEPTOR CRÍTICO: Si estamos en puzzle, NO mostrar NUNCA
	if _is_in_puzzle_game():
		print("ConfirmExitDialog: show_dialog() llamado en puzzle - BLOQUEANDO")
		_make_completely_invisible()
		_self_destruct_immediately()
		return
	
	print("Mostrando diálogo, botones: ", confirm_button != null, ", ", cancel_button != null)
	
	# Asegurar que el diálogo se muestre por encima de todo
	$CanvasLayer.layer = 128
	
	# Limpiar estado antes de mostrar
	visible = true
	$CanvasLayer/ColorRect.modulate.a = 0
	$CanvasLayer/CenterContainer.modulate.a = 0
	
	# Animación simple de aparecer
	var tween = create_tween()
	tween.parallel().tween_property($CanvasLayer/ColorRect, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property($CanvasLayer/CenterContainer, "modulate:a", 1.0, 0.2)
	
	# Dar foco al botón de cancelar por defecto
	cancel_button.grab_focus()
		
	print("Diálogo mostrado, visible=", visible)

# Ocultar el diálogo
func hide_dialog():
	print("Ocultando diálogo")
	
	var tween = create_tween()
	tween.parallel().tween_property($CanvasLayer/ColorRect, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property($CanvasLayer/CenterContainer, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): 
		visible = false
		# Liberar el diálogo después de ocultarlo
		queue_free()
	)

# Configurar los textos desde código
func configure(new_title: String = "", new_message: String = "", new_confirm_text: String = "", new_cancel_text: String = ""):
	if new_title != "":
		title_text = new_title
		if title_label:
			title_label.text = new_title
	
	if new_message != "":
		message_text = new_message
		if message_label:
			message_label.text = new_message
	
	if new_confirm_text != "":
		confirm_button_text = new_confirm_text
		if confirm_button:
			confirm_button.text = new_confirm_text
	
	if new_cancel_text != "":
		cancel_button_text = new_cancel_text
		if cancel_button:
			cancel_button.text = new_cancel_text

# Conexión con botón Cancelar
func _on_cancel_button_pressed():
	print("Botón cancelar presionado")
	hide_dialog()
	emit_signal("exit_canceled")

# Conexión con botón Confirmar
func _on_confirm_button_pressed():
	print("Botón confirmar presionado")
	hide_dialog()
	emit_signal("exit_confirmed")

# Capturar pulsación de tecla Escape para cancelar
func _unhandled_input(event):
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("Tecla Escape presionada")
			_on_cancel_button_pressed()
			get_viewport().set_input_as_handled() 
