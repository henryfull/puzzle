extends Node2D
class_name ColumnPuzzlePiece

@onready var sprite: Sprite2D = $Sprite2D
@onready var area2d: Area2D = $Area2D

var color: Color = Color.WHITE

func _ready():
	# Configurar el área para recibir eventos de entrada
	area2d.input_pickable = true

func set_color(new_color: Color):
	color = new_color
	
	# Crear una textura con el color especificado
	var img = Image.create(100, 50, false, Image.FORMAT_RGBA8)
	img.fill(new_color)
	
	var texture = ImageTexture.create_from_image(img)
	sprite.texture = texture
	
	# Ajustar el tamaño del sprite
	sprite.scale = Vector2(1.0, 1.0)
	
	# Centrar el sprite
	sprite.position = Vector2(50, 25)
	
	# Ajustar el tamaño del área de colisión
	var collision_shape = area2d.get_node("CollisionShape2D")
	if collision_shape:
		collision_shape.shape.size = Vector2(100, 50)
		collision_shape.position = Vector2(50, 25)

# Esta función es llamada por el script ColumnPuzzleGame
func _input_event(_viewport, event, _shape_idx):
	# No necesitamos implementar nada aquí, ya que la lógica de arrastre
	# está en el script ColumnPuzzleGame
	pass 