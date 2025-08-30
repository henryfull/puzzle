# NewInputHandler.gd
# Encapsula el input para la nueva mecánica: drag & drop de piezas y grupos con tween

extends Node
class_name NewInputHandler

var manager
var is_touch: bool = false
var dragging_piece = null

func initialize(m):
	manager = m
	set_process_input(true)
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if manager == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging_piece = manager.begin_drag_at_position(event.position)
			else:
				manager.end_drag(dragging_piece, event.position)
				dragging_piece = null
	elif event is InputEventMouseMotion:
		if dragging_piece:
			manager.drag_move(dragging_piece, event.position)
	elif event is InputEventScreenTouch:
		is_touch = true
		if event.pressed:
			dragging_piece = manager.begin_drag_at_position(event.position)
		else:
			manager.end_drag(dragging_piece, event.position)
			dragging_piece = null
	elif event is InputEventScreenDrag:
		if dragging_piece:
			manager.drag_move(dragging_piece, event.position)


