extends Node

@export var path: String


func _on_pressed() -> void:
	get_tree().change_scene_to_file(path)
