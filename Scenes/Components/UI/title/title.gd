extends Node

@export var title: String


func _ready():
	$LabelTitle.text = tr(title)
