extends PanelContainer
@export var title : String
@export var color : Color
@export var titleLabel = Label
@export var value = Label
@export var bestValue = Label

func _ready():
	titleLabel.text = title
	$"."["theme_override_styles/panel"].bg_color = color
