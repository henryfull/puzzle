extends Node
class_name PuzzleDialogBlocker

const DIALOG_KEYWORDS := ["Dialog", "Confirm", "Exit", "Quit", "Alert", "Warning", "Popup", "Modal"]

var puzzle_game: Node = null
var enabled: bool = false
var _block_timer: Timer = null

func initialize(game: Node) -> void:
	puzzle_game = game

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if enabled:
		_start()
	else:
		_stop()

func _start() -> void:
	_ensure_timer()
	if _block_timer and _block_timer.is_stopped():
		_block_timer.start()
	_connect_global_interceptor()

func _stop() -> void:
	if _block_timer and not _block_timer.is_stopped():
		_block_timer.stop()
	_disconnect_global_interceptor()

func _exit_tree() -> void:
	_stop()

func _ensure_timer() -> void:
	if _block_timer and is_instance_valid(_block_timer):
		return
	_block_timer = Timer.new()
	_block_timer.name = "PuzzleDialogBlockerTimer"
	_block_timer.wait_time = 0.016
	_block_timer.one_shot = false
	_block_timer.timeout.connect(_on_block_timer_timeout)
	add_child(_block_timer)

func _connect_global_interceptor() -> void:
	if not puzzle_game:
		return
	var root = puzzle_game.get_node_or_null("/root")
	if root and not root.child_entered_tree.is_connected(handle_global_child_added):
		root.child_entered_tree.connect(handle_global_child_added)

func _disconnect_global_interceptor() -> void:
	if not puzzle_game:
		return
	var root = puzzle_game.get_node_or_null("/root")
	if root and root.child_entered_tree.is_connected(handle_global_child_added):
		root.child_entered_tree.disconnect(handle_global_child_added)

func _on_block_timer_timeout() -> void:
	block_all_dialogs()

func _is_dialog_node(node: Node) -> bool:
	if not node:
		return false
	for keyword in DIALOG_KEYWORDS:
		if node.name.contains(keyword):
			return true
	if node.is_in_group("exit_dialog") or node.is_in_group("dialog") or node.is_in_group("popup"):
		return true
	return false

func _hide_node(node: Node) -> void:
	if node is CanvasItem:
		node.visible = false
		node.modulate.a = 0.0

func handle_global_child_added(node: Node) -> void:
	if not enabled:
		return
	if _is_dialog_node(node):
		_hide_node(node)
		call_deferred("force_remove_node", node)

func force_remove_node(node: Node) -> void:
	if is_instance_valid(node):
		_hide_node(node)
		node.queue_free()

func block_all_dialogs() -> void:
	if not enabled or not puzzle_game:
		return

	for child in puzzle_game.get_children():
		if _is_dialog_node(child):
			force_remove_node(child)
			continue
		if child is CanvasLayer:
			for grandchild in child.get_children():
				if _is_dialog_node(grandchild):
					force_remove_node(grandchild)

	var current_scene = puzzle_game.get_tree().current_scene
	if current_scene and current_scene != puzzle_game:
		for child in current_scene.get_children():
			if _is_dialog_node(child):
				force_remove_node(child)
