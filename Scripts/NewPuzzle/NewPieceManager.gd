# NewPieceManager.gd
# Mecánica nueva y aislada: grid estricta, movimientos suaves, unión irreversible de grupos

extends Node
class_name NewPieceManager

signal piece_merged(piece_count: int)
signal invalid_move()
signal group_moved()
signal puzzle_completed()

# Referencias
var pieces_container: Node2D
var audio_manager: Node = null
var global_node: Node = null

# Configuración del puzzle
var rows: int = 0
var cols: int = 0
var cell_size: Vector2 = Vector2.ZERO
var offset: Vector2 = Vector2.ZERO
var texture: Texture2D

# Datos
var grid := {}  # key "c_r": Piece
var pieces: Array = []
var total_pieces: int = 0

# Clases
class Piece:
	var node: Node2D
	var sprite: Sprite2D
	var original_cell: Vector2
	var current_cell: Vector2
	var group_id: int
	var group_members: Array
	var drag_offset: Vector2 = Vector2.ZERO
	var drag_start_cell: Vector2 = Vector2.ZERO

	func _init(n: Node2D, s: Sprite2D, cell: Vector2, gid: int):
		node = n
		sprite = s
		original_cell = cell
		current_cell = cell
		group_id = gid
		group_members = [self]

# Inicialización
func initialize(container: Node2D, image: Texture2D, r: int, c: int, viewport_size: Vector2, device_scale: float):
	pieces_container = container
	texture = image
	rows = r
	cols = c
	_total_reset()

	# Calcular tamaño y offset (centrado)
	var img_w = float(texture.get_width())
	var img_h = float(texture.get_height())
	var scale_w = (viewport_size.x * device_scale) / img_w
	var scale_h = (viewport_size.y * device_scale) / img_h
	var scale = min(scale_w, scale_h, 1.0)
	var puzzle_w = img_w * scale
	var puzzle_h = img_h * scale
	cell_size = Vector2(puzzle_w / cols, puzzle_h / rows)
	offset = (viewport_size - Vector2(puzzle_w, puzzle_h)) * 0.5

	_create_pieces()
	_shuffle_grid()

func set_services(_audio_manager: Node, _global: Node):
	audio_manager = _audio_manager
	global_node = _global

# Utilidades
func _total_reset():
	grid.clear()
	for child in (pieces_container.get_children() if pieces_container else []):
		child.queue_free()
	pieces.clear()
	total_pieces = rows * cols

func _cell_key(cell: Vector2) -> String:
	return "%d_%d" % [int(cell.x), int(cell.y)]

func _set_piece_at(cell: Vector2, p: Piece) -> void:
	grid[_cell_key(cell)] = p
	p.current_cell = cell

func _get_piece_at(cell: Vector2) -> Piece:
	return grid.get(_cell_key(cell))

func _remove_piece_at(cell: Vector2) -> void:
	grid.erase(_cell_key(cell))

func _create_pieces():
	var piece_scene: PackedScene = load("res://Scenes/Components/PuzzlePiece/PuzzlePiece.tscn")
	var img_w = float(texture.get_width())
	var img_h = float(texture.get_height())
	var sub_w = img_w / cols
	var sub_h = img_h / rows
	var gid = 1
	for r in range(rows):
		for c in range(cols):
			var node: Node2D = piece_scene.instantiate()
			pieces_container.add_child(node)
			node.z_index = 5
			var sprite: Sprite2D = node.get_node("Sprite2D") if node.has_node("Sprite2D") else null
			if sprite:
				sprite.texture = texture
				sprite.region_enabled = true
				sprite.region_rect = Rect2(c * sub_w, r * sub_h, sub_w, sub_h)
				# Escalar sprite para encajar exactamente en la celda
				var scale_x = cell_size.x / sub_w
				var scale_y = cell_size.y / sub_h
				sprite.scale = Vector2(scale_x, scale_y)
				sprite.position = Vector2.ZERO
			var p := Piece.new(node, sprite, Vector2(c, r), gid)
			pieces.append(p)
			_set_piece_at(p.current_cell, p)
			# Posicion inicial (ordenada)
			var pos = offset + p.current_cell * cell_size
			node.global_position = pos
			gid += 1

func _shuffle_grid():
	var cells: Array = []
	for r in range(rows):
		for c in range(cols):
			cells.append(Vector2(c, r))
	cells.shuffle()
	# Reposicionar todas las piezas en celdas mezcladas (manteniendo original_cell)
	grid.clear()
	for i in range(pieces.size()):
		var p: Piece = pieces[i]
		var new_cell: Vector2 = cells[i]
		_set_piece_at(new_cell, p)
		p.node.global_position = offset + new_cell * cell_size

# Conversión posición->celda
func get_cell_from_position(global_pos: Vector2) -> Vector2:
	var px = global_pos.x - offset.x
	var py = global_pos.y - offset.y
	return Vector2(round(px / cell_size.x), round(py / cell_size.y))

# Interacción de arrastre
func begin_drag_at_position(global_pos: Vector2) -> Piece:
	# Encontrar pieza top-most bajo el cursor
	var best: Piece = null
	for p in pieces:
		if not is_instance_valid(p.node):
			continue
		var rect = Rect2(offset + p.current_cell * cell_size, cell_size)
		if rect.has_point(global_pos):
			if best == null or p.node.z_index > best.node.z_index:
				best = p
	if best:
		best.drag_start_cell = best.current_cell
		var _center = offset + best.current_cell * cell_size + cell_size * 0.5
		best.drag_offset = best.node.global_position - global_pos
		# Elevar z de su grupo
		for m in get_group(best):
			m.node.z_index = 9999
	return best

func drag_move(piece: Piece, global_pos: Vector2):
	if piece == null:
		return
	var group := get_group(piece)
	var delta := global_pos + piece.drag_offset - piece.node.global_position
	for m in group:
		m.node.global_position += delta

func end_drag(piece: Piece, _global_pos: Vector2):
	if piece == null:
		return
	# Snap a la celda más cercana del líder
	var leader: Piece = get_group_leader(piece)
	var target_cell := get_cell_from_position(leader.node.global_position)
	var success := _attempt_place_group(leader, target_cell)
	if success:
		_emit_valid_move_feedback(true)
		if _is_completed():
			_emit_victory()
	else:
		# Volver con tween a su celda de inicio
		_revert_group_to_start(leader)
		_emit_valid_move_feedback(false)

func _emit_valid_move_feedback(is_merge: bool):
	if audio_manager and audio_manager.has_method("play_sfx"):
		var s = "res://Assets/Sounds/SFX/bubble.wav" if is_merge else "res://Assets/Sounds/SFX/plop.mp3"
		audio_manager.play_sfx(s)
	if global_node and global_node.has_method("is_haptic_enabled") and global_node.is_haptic_enabled():
		if is_merge:
			global_node.trigger_haptic_feedback(120)
		else:
			global_node.trigger_haptic_feedback(40)
	if is_merge:
		piece_merged.emit(_largest_group_size())
	else:
		invalid_move.emit()

# Grupos
func get_group(p: Piece) -> Array:
	# Miembros comparten group_id. Construir on-demand por robustez.
	var gid = p.group_id
	var result: Array = []
	for x in pieces:
		if x.group_id == gid:
			result.append(x)
	return result

func get_group_leader(p: Piece) -> Piece:
	var g = get_group(p)
	var leader: Piece = g[0]
	for m in g:
		if m.original_cell.y < leader.original_cell.y or (m.original_cell.y == leader.original_cell.y and m.original_cell.x < leader.original_cell.x):
			leader = m
	return leader

func _largest_group_size() -> int:
	var seen := {}
	var best := 1
	for p in pieces:
		if p.group_id in seen:
			continue
		var s = get_group(p).size()
		best = max(best, s)
		seen[p.group_id] = true
	return best

# Colocación/Unión
func _attempt_place_group(leader: Piece, target_anchor: Vector2) -> bool:
	# Determinar celdas requeridas por el grupo relativo al líder
	var group := get_group(leader)
	var required: Array = []
	for m in group:
		var rel = m.original_cell - leader.original_cell
		required.append(target_anchor + rel)

	# Verificar qué celdas están libres u ocupadas
	var blockers: Array = []
	for cell in required:
		if cell.x < 0 or cell.x >= cols:
			return false
		if cell.y < 0:
			# expandir hacia arriba
			_expand_rows_top(abs(int(cell.y)))
		elif cell.y >= rows:
			# expandir hacia abajo
			_expand_rows_bottom(int(cell.y) - (rows - 1))
		var occ = _get_piece_at(cell)
		if occ != null and not (occ.group_id == leader.group_id):
			blockers.append(cell)

	# Si todos libres -> mover
	if blockers.is_empty():
		_move_group_to_cells(group, required)
		return true

	# Intentar desplazar cadena de bloqueadores a celdas cercanas
	var displaced_ok = _displace_blockers(blockers)
	if not displaced_ok:
		return false
	_move_group_to_cells(group, required)
	# Intentar uniones con vecinos correctos
	_try_merge_neighbors(group)
	return true

func _move_group_to_cells(group: Array, cells: Array):
	var duration = 0.18
	for i in range(group.size()):
		var m: Piece = group[i]
		_remove_piece_at(m.current_cell)
	for i in range(group.size()):
		var m: Piece = group[i]
		var cell: Vector2 = cells[i]
		_set_piece_at(cell, m)
		var target_pos = offset + cell * cell_size
		_animate_to(m.node, target_pos, duration)
		m.drag_start_cell = cell
	group_moved.emit()

func _revert_group_to_start(leader: Piece):
	var group := get_group(leader)
	var duration = 0.18
	for m in group:
		var target_pos = offset + m.drag_start_cell * cell_size
		_animate_to(m.node, target_pos, duration)

func _animate_to(node: Node2D, target_pos: Vector2, duration: float):
	var t = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_QUART)
	t.tween_property(node, "global_position", target_pos, duration)

func _expand_rows_top(num_rows: int):
	if num_rows <= 0:
		return
	# Desplazar todas las piezas hacia abajo y aumentar rows
	for n in range(num_rows):
		for p in pieces:
			_remove_piece_at(p.current_cell)
			p.current_cell.y += 1
			_set_piece_at(p.current_cell, p)
		offset.y -= cell_size.y
		rows += 1
		for p in pieces:
			_animate_to(p.node, offset + p.current_cell * cell_size, 0.0)

func _expand_rows_bottom(num_rows: int):
	if num_rows <= 0:
		return
	rows += num_rows

func _displace_blockers(blocker_cells: Array) -> bool:
	# BFS simple: por cada celda bloqueada, buscar la celda libre más cercana y desplazar cadena si es necesario
	for bc in blocker_cells:
		var success = _displace_one_chain(bc)
		if not success:
			return false
	return true

func _displace_one_chain(start_cell: Vector2) -> bool:
	var visited := {}
	var q := []
	q.append(start_cell)
	visited[_cell_key(start_cell)] = true
	var parent := {}
	var free_target: Vector2 = Vector2(-999, -999)
	while not q.is_empty():
		var cur: Vector2 = q.pop_front()
		# vecinos 4-dir
		for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var nxt = cur + dir
			if nxt.x < 0 or nxt.x >= cols:
				continue
			if nxt.y < 0:
				_expand_rows_top(1)
				nxt.y = 0
			elif nxt.y >= rows:
				_expand_rows_bottom(1)
			if _cell_key(nxt) in visited:
				continue
			visited[_cell_key(nxt)] = true
			parent[_cell_key(nxt)] = cur
			if _get_piece_at(nxt) == null:
				free_target = nxt
				q.clear()
				break
			else:
				q.append(nxt)
	if free_target.x == -999:
		return false
	# reconstruir camino desde free_target a start_cell y desplazar piezas a lo largo del camino
	var path := []
	var cur2 = free_target
	while _cell_key(cur2) in parent:
		path.append(cur2)
		cur2 = parent[_cell_key(cur2)]
	path.append(start_cell)
	path.reverse()  # Godot retorna void
	# desplazar piezas a lo largo de path
	for i in range(path.size() - 1, 0, -1):
		var from_cell: Vector2 = path[i-1]
		var to_cell: Vector2 = path[i]
		var occ: Piece = _get_piece_at(from_cell)
		if occ != null:
			_remove_piece_at(from_cell)
			_set_piece_at(to_cell, occ)
			_animate_to(occ.node, offset + to_cell * cell_size, 0.12)
	return true

func _try_merge_neighbors(group: Array):
	# Si hay piezas vecinas que corresponden por original, fusionar grupos (unificar group_id)
	var leader: Piece = get_group_leader(group[0])
	var changed := true
	while changed:
		changed = false
		for m in group:
			for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				var ncell = m.current_cell + dir
				var neigh: Piece = _get_piece_at(ncell)
				if neigh == null:
					continue
				# comprobar si neigh es el vecino correcto por original
				if neigh.group_id != m.group_id and (neigh.original_cell - m.original_cell) == dir:
					_unify_groups(m, neigh)
					group = get_group(leader)
					changed = true
					break
			if changed:
				break
	if _largest_group_size() == total_pieces:
		puzzle_completed.emit()

func _unify_groups(a: Piece, b: Piece):
	var ga = get_group(a)
	var gb = get_group(b)
	var new_gid = min(a.group_id, b.group_id)
	for m in ga:
		m.group_id = new_gid
	for m in gb:
		m.group_id = new_gid
	# Alinear posiciones exactas a celdas actuales
	for m in get_group(a):
		_animate_to(m.node, offset + m.current_cell * cell_size, 0.08)
	piece_merged.emit(get_group(a).size())

func _is_completed() -> bool:
	return _largest_group_size() == total_pieces

func _emit_victory():
	# Pequeño tween global y señal
	var t = create_tween()
	t.tween_interval(0.25)
	puzzle_completed.emit()


