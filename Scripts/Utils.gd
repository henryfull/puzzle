extends Control

func _on_HSlider_Volumen_General_value_changed(value: float) -> void:
	GLOBAL.settings.volume.general = value
	AchievementsManager.updateVolume("general", value)

func _on_HSlider_Volumen_Musica_value_changed(value: float) -> void:
	GLOBAL.settings.volume.music = value
	AchievementsManager.updateVolume("music", value)

func _on_HSlider_Volumen_VFX_value_changed(value: float) -> void:
	GLOBAL.settings.volume.vfx = value
	AchievementsManager.updateVolume("vfx", value)
