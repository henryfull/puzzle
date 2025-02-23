extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var area2d: Area2D = $Area2D

var puzzle_image: Texture2D
var fragment_region: Rect2
var original_grid_position: Vector2
var cell_size: Vector2

var pieces_group: Array = []
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var puzzle_front: Texture2D
var puzzle_back: Texture2D
var flipped: bool = false

var only_vertical: bool = false  # Si true, el grupo solo se mueve verticalmente

func _ready():
	# Ajustar para recibir eventos de entrada
	# El Area2D está para colisiones, pero usaremos _input_event
	area2d.input_pickable = true
	pieces_group = [self]

func set_piece_data(front_tex: Texture2D, back_tex: Texture2D, region: Rect2):
	puzzle_front = front_tex
	puzzle_back = back_tex
	fragment_region = region
	update_visual()

func update_visual():
	var atlas_tex = AtlasTexture.new()
	# Si la pieza está volteada, usamos la textura trasera
	if flipped:
		atlas_tex.atlas = puzzle_back
	else:
		atlas_tex.atlas = puzzle_front
	atlas_tex.region = fragment_region
	sprite.texture = atlas_tex

func flip_piece():
	flipped = !flipped
	update_visual()

#
# EVENTOS DE ENTRADA
#
# func _input_event(viewport, event, shape_idx):
#	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
#		if event.pressed:
#			# Iniciar drag
#			dragging = true
#			drag_offset = global_position - event.position
#			bring_to_front()
#		else:
#			if dragging:
#				dragging = false
#				# Al soltar, avisar a PuzzleGame
#				if get_parent().has_method("place_piece"):
#					get_parent().place_piece(self)
#				if get_parent().has_method("on_piece_moved"):
#					get_parent().on_piece_moved()
#
#	elif event is InputEventMouseMotion and dragging:
#		# Mover el grupo entero (todas las piezas fusionadas)
#		var delta = event.relative
#		for p in pieces_group:
#			if only_vertical:
#				p.global_position.y += delta.y
#			else:
#				p.global_position += delta

#
# FUNCIONES DE APOYO
#
func bring_to_front():
	# Elevar este nodo para que se dibuje por encima de otros
	z_index = 999999
