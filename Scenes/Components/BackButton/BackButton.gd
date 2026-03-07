extends Node

@export var path: String = "res://Scenes/MainMenu.tscn"


func _on_pressed() -> void:
	GLOBAL.change_scene_direct(path)
