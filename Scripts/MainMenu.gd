extends Node2D

func _ready():
	# Esperar un frame para asegurarnos de que GLOBAL y TranslationLoader estén inicializados
	await get_tree().process_frame
	
	# Actualizar los textos según el idioma actual
	update_ui_texts()
	
	# Adaptar la UI para dispositivos móviles
	adapt_ui_for_device()
	
	# Conectar señal de cambio de idioma
	if has_node("/root/TranslationLoader"):
		get_node("/root/TranslationLoader").connect("language_changed", Callable(self, "_on_language_changed"))

# Función para actualizar los textos de la UI
func update_ui_texts():
	$CanvasLayer/VBoxContainer/BTN_options.text = tr("common_options")
	$CanvasLayer/VBoxContainer/BTN_play.text = tr("common_play")
	print("MainMenu: Textos actualizados con idioma: ", TranslationServer.get_locale())

# Función para adaptar la UI según el dispositivo
func adapt_ui_for_device():
	# Verificar si estamos en un dispositivo móvil
	var is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Obtener el contenedor principal
	var main_container = $CanvasLayer/VBoxContainer
	
	# Ajustar el espaciado del contenedor
	if is_mobile:
		main_container.add_theme_constant_override("separation", 30)
	
	# Ajustar los botones
	var buttons = [
		$CanvasLayer/VBoxContainer/BTN_play,
		$CanvasLayer/VBoxContainer/BTN_options
	]
	
	for button in buttons:
		if is_mobile:
			# Tamaño más grande para móviles
			button.custom_minimum_size = Vector2(250, 80)
			button.add_theme_font_size_override("font_size", 32)
			
			# Añadir padding para área táctil más grande
			button.add_theme_constant_override("h_separation", 20)
			button.add_theme_constant_override("content_margin_left", 20)
			button.add_theme_constant_override("content_margin_right", 20)
			button.add_theme_constant_override("content_margin_top", 15)
			button.add_theme_constant_override("content_margin_bottom", 15)
		else:
			# Tamaño normal para PC
			button.custom_minimum_size = Vector2(150, 50)
			button.add_theme_font_size_override("font_size", 18)
	
	# Usar UIScaler si está disponible
	if ResourceLoader.exists("res://Scripts/UIScaler.gd"):
		var UIScaler = load("res://Scripts/UIScaler.gd")
		for button in buttons:
			UIScaler.scale_button(button)

# Función para manejar cambios de idioma
func _on_language_changed(_locale_code):
	update_ui_texts()

func _on_PlayButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/PackSelection.tscn")

func _on_OptionsButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/Options.tscn")

func _on_AchievementsButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/Achievements.tscn")

func _on_ExitButton_pressed():
	get_tree().quit() 
