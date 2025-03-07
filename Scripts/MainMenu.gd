extends Node2D

func _ready():
	# Esperar un frame para asegurarnos de que GLOBAL y TranslationLoader estén inicializados
	await get_tree().process_frame
	
	# Actualizar los textos según el idioma actual
	update_ui_texts()
	
	# Conectar señal de cambio de idioma
	if has_node("/root/TranslationLoader"):
		get_node("/root/TranslationLoader").connect("language_changed", Callable(self, "_on_language_changed"))

# Función para actualizar los textos de la UI
func update_ui_texts():
	$CanvasLayer/VBoxContainer/BTN_options.text = tr("common_options")
	$CanvasLayer/VBoxContainer/BTN_play.text = tr("common_play")
	print("MainMenu: Textos actualizados con idioma: ", TranslationServer.get_locale())

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
