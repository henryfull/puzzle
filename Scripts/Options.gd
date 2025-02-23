extends Node2D

func _ready():
	# Inicialización de la pantalla de opciones
	# Aquí puedes configurar sliders para música y efectos, y otros ajustes
	$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer/HSlider_Volumen_General.set_value_no_signal(GLOBAL.settings.volume.general)

	$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer2/HSlider_Volumen_Musica.set_value_no_signal(GLOBAL.settings.volume.music)
	
	$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer3/HSlider_Volumen_VFX.set_value_no_signal(GLOBAL.settings.volume.vfx)

func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_HSlider_Volumen_General_value_changed(value: float) -> void:
	GLOBAL.settings.volume.general = value
	AchievementsManager.updateVolume("general", value)

func _on_HSlider_Volumen_Musica_value_changed(value: float) -> void:
	GLOBAL.settings.volume.music = value
	AchievementsManager.updateVolume("music", value)

func _on_HSlider_Volumen_VFX_value_changed(value: float) -> void:
	GLOBAL.settings.volume.vfx = value
	AchievementsManager.updateVolume("vfx", value)
