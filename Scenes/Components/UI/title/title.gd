extends Node

@export var title: String


func _ready():
	$LabelTitle.text = TranslationServer.translate(title)

func update_ui_texts():
	$LabelTitle.text = TranslationServer.translate(title)

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		update_ui_texts()
