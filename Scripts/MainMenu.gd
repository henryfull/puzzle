extends Node2D

func _ready():
	# Inicialización del menú principal
	pass

func _on_PlayButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/PackSelection.tscn")

func _on_OptionsButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/Options.tscn")

func _on_AchievementsButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/Achievements.tscn")

func _on_ExitButton_pressed():
	get_tree().quit() 
