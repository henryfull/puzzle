extends Node2D

func _ready():
	# Inicialización de la pantalla de opciones
	update_ui_texts()
	load_current_settings()
	
	# Conectar señal de cambio de idioma
	if has_node("/root/TranslationLoader"):
		get_node("/root/TranslationLoader").connect("language_changed", Callable(self, "_on_language_changed"))

# Función para actualizar los textos de la UI según el idioma actual
func update_ui_texts():
	$"CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerResolución/Label_resolution".text = tr("common_resolution")
	$"CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer4/Label_general".text = tr("common_general")
	$"CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer2/label music".text = tr("common_music")
	$"CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer3/label sfx".text = tr("common_sfx")
	$"CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerIdioma/Label idioma".text = tr("common_language")
	print("Options: Textos actualizados con idioma: ", TranslationServer.get_locale())

# Función para cargar la configuración actual
func load_current_settings():
	$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer4/HSlider_Volumen_General.set_value_no_signal(GLOBAL.settings.volume.general)
	$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer2/HSlider_Volumen_Musica.set_value_no_signal(GLOBAL.settings.volume.music)
	$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer3/HSlider_Volumen_VFX.set_value_no_signal(GLOBAL.settings.volume.sfx)

# Función para manejar cambios de idioma
func _on_language_changed(_locale_code):
	update_ui_texts()

func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_HSlider_Volumen_General_value_changed(value: float) -> void:
	GLOBAL.settings.volume.general = value
	AchievementsManager.updateVolume("general", value)
	AudioManager.update_volumes()
	# Guardar la configuración inmediatamente
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").save_volume_settings()
	# También actualizar la configuración global
	if has_node("/root/GLOBAL"):
		get_node("/root/GLOBAL").save_settings()

func _on_HSlider_Volumen_Musica_value_changed(value: float) -> void:
	GLOBAL.settings.volume.music = value
	AchievementsManager.updateVolume("music", value)
	AudioManager.update_volumes()
	# Guardar la configuración inmediatamente
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").save_volume_settings()
	# También actualizar la configuración global
	if has_node("/root/GLOBAL"):
		get_node("/root/GLOBAL").save_settings()

func _on_HSlider_Volumen_VFX_value_changed(value: float) -> void:
	GLOBAL.settings.volume.sfx = value
	AchievementsManager.updateVolume("sfx", value)
	AudioManager.update_volumes()
	# Guardar la configuración inmediatamente
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").save_volume_settings()
	# También actualizar la configuración global
	if has_node("/root/GLOBAL"):
		get_node("/root/GLOBAL").save_settings()
