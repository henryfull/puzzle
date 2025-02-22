extends Node2D

var flipped: bool = false

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		flip_piece()
		
func flip_piece():
	flipped = !flipped
	update_visual()

func update_visual():
	# Actualiza el Sprite o la animación según el estado de 'flipped'.
	if has_node("Sprite"):
		var sprite = get_node("Sprite")
		if flipped:
			sprite.texture = preload("res://Assets/Images/Pieces/piece_back.jpg")
		else:
			sprite.texture = preload("res://Assets/Images/Pieces/piece_front.jpg")

func is_in_correct_position() -> bool:
	# Implementa la lógica para verificar si la pieza está en la posición correcta.
	# Por ahora, devolvemos true como stub.
	return true 
