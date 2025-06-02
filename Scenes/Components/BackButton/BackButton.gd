extends Node

@export var path: String


func _on_pressed() -> void:
	GLOBAL.change_scene_direct("res://Scenes/PuzzleSelection.tscn")
