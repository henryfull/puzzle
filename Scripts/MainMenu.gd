extends Node2D

var btn_play: Button
var btn_options : Button
var btn_stats : Button
var btn_achievements : Button
var btn_exit : Button
var label_version: Label

func _ready():
	# Esperar un frame para asegurarnos de que GLOBAL y TranslationLoader estén inicializados
	btn_options = $CanvasLayer/MarginContainer/VBoxContainer/BTN_options
	btn_play = $CanvasLayer/MarginContainer/VBoxContainer/BTN_play
	btn_stats = $CanvasLayer/MarginContainer/VBoxContainer/BTN_stats
	btn_achievements = $CanvasLayer/MarginContainer/VBoxContainer/BTN_achievements
	btn_exit = $CanvasLayer/MarginContainer/VBoxContainer/BTN_exit
	label_version = $CanvasLayer/LabelVersion
	
	# Mostrar la versión del juego
	update_version_label()
	
	await get_tree().process_frame
	
	# Actualizar los textos según el idioma actual
	update_ui_texts()
	
	
	# Conectar señal de cambio de idioma
	if has_node("/root/TranslationLoader"):
		get_node("/root/TranslationLoader").connect("language_changed", Callable(self, "_on_language_changed"))
	

# Función para actualizar la etiqueta de versión
func update_version_label():
	# Obtener la versión del juego desde ProjectSettings
	var version = ProjectSettings.get_setting("application/config/version", "0.0.0")
	
	# Mostrar la versión en el LabelVersion
	if label_version:
		label_version.text = "v. " + version
		print("MainMenu: Versión del juego: ", version)

# Función para actualizar los textos de la UI
func update_ui_texts():
	btn_options.text = tr("common_options")
	btn_play.text = tr("common_play")
	btn_stats.text = tr("common_stats")
	btn_achievements.text = tr("common_achievements")
	btn_exit.text = tr("common_exit")
	print("MainMenu: Textos actualizados con idioma: ", TranslationServer.get_locale())


# Función para manejar cambios de idioma
func _on_language_changed(_locale_code):
	update_ui_texts()
	
	# Actualizar textos del menú de opciones si está visible
	if has_node("/root/OptionsManager"):
		get_node("/root/OptionsManager").update_texts_if_visible()

func _on_PlayButton_pressed():
	# Si el menú de opciones está visible, ocultarlo primero
	if has_node("/root/OptionsManager") and get_node("/root/OptionsManager").is_visible():
		get_node("/root/OptionsManager").hide_options()
		await get_tree().create_timer(0.3).timeout  # Esperar a que termine la animación
	
	get_tree().change_scene_to_file("res://Scenes/PackSelection.tscn")

func _on_OptionsButton_pressed():
	OptionsManager.show_options(self)

# Función para manejar el cierre del menú de opciones
func _on_options_closed():
	# Esta función se llama cuando el menú de opciones se cierra
	# Puedes realizar acciones adicionales aquí si es necesario
	pass

func _on_AchievementsButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/Achievements.tscn")

func _on_ExitButton_pressed():
	get_tree().quit() 


func _on_btn_exit_pressed() -> void:
	get_tree().quit()

func _on_StatsButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/StatsScreen.tscn")
