# PuzzleStateManager.gd
# Sistema de guardado automático del estado del puzzle
# Permite a los jugadores continuar donde lo dejaron

extends Node

# Constante para el archivo de guardado del estado
const PUZZLE_STATE_FILE = "user://puzzle_state.json"

# Estructura para el estado del puzzle
var puzzle_state = {
	"has_saved_state": false,
	"pack_id": "",
	"puzzle_id": "",
	"game_mode": 2,
	"difficulty": 3,
	"counters": {
		"elapsed_time": 0.0,
		"total_moves": 0,
		"flip_count": 0,
		"flip_move_count": 0,
		"time_left": 0.0
	},
	"pieces_data": [],
	"groups_data": [],
	"puzzle_config": {
		"columns": 6,
		"rows": 8,
		"image_path": "",
		"max_moves": 0,
		"max_time": 0.0,
		"max_flips": 0,
		"max_flip_moves": 0
	},
	"save_timestamp": 0.0
}

# Variables para el guardado automático
var auto_save_timer: Timer
var is_auto_save_enabled: bool = true
var auto_save_interval: float = 2.0  # Guardar cada 2 segundos (más frecuente)

func _ready():
	print("PuzzleStateManager: Inicializando sistema de guardado automático...")
	
	# Cargar estado guardado si existe
	load_puzzle_state()
	
	# Configurar timer de guardado automático
	setup_auto_save_timer()
	
	print("PuzzleStateManager: Sistema inicializado")

# Configurar el timer de guardado automático
func setup_auto_save_timer():
	auto_save_timer = Timer.new()
	auto_save_timer.name = "AutoSaveTimer"
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.one_shot = false
	auto_save_timer.autostart = false
	auto_save_timer.connect("timeout", Callable(self, "_on_auto_save_timeout"))
	add_child(auto_save_timer)

# Callback del timer de guardado automático
func _on_auto_save_timeout():
	if is_auto_save_enabled and puzzle_state.has_saved_state:
		save_puzzle_state()

# Inicializar un nuevo estado de puzzle
func start_new_puzzle_state(pack_id: String, puzzle_id: String, game_mode: int = 2, difficulty: int = 3):
	print("PuzzleStateManager: Iniciando nuevo estado para puzzle: ", puzzle_id, " del pack: ", pack_id)
	
	puzzle_state.has_saved_state = true
	puzzle_state.pack_id = pack_id
	puzzle_state.puzzle_id = puzzle_id
	puzzle_state.game_mode = game_mode
	puzzle_state.difficulty = difficulty
	puzzle_state.save_timestamp = Time.get_unix_time_from_system()
	
	# Resetear contadores
	puzzle_state.counters.elapsed_time = 0.0
	puzzle_state.counters.total_moves = 0
	puzzle_state.counters.flip_count = 0
	puzzle_state.counters.flip_move_count = 0
	puzzle_state.counters.time_left = 0.0
	
	# Configurar límites del puzzle
	puzzle_state.puzzle_config.columns = GLOBAL.columns
	puzzle_state.puzzle_config.rows = GLOBAL.rows
	puzzle_state.puzzle_config.image_path = GLOBAL.selected_puzzle.image if GLOBAL.selected_puzzle else ""
	puzzle_state.puzzle_config.max_moves = GLOBAL.puzzle_limits.max_moves
	puzzle_state.puzzle_config.max_time = GLOBAL.puzzle_limits.max_time
	puzzle_state.puzzle_config.max_flips = GLOBAL.puzzle_limits.max_flips
	puzzle_state.puzzle_config.max_flip_moves = GLOBAL.puzzle_limits.max_flip_moves
	
	# Limpiar datos de piezas y grupos
	puzzle_state.pieces_data.clear()
	puzzle_state.groups_data.clear()
	
	# Iniciar guardado automático
	if auto_save_timer and not auto_save_timer.is_stopped():
		auto_save_timer.stop()
	auto_save_timer.start()
	
	# Guardar estado inicial
	save_puzzle_state()

# Actualizar contadores del estado
func update_counters(elapsed_time: float = -1, total_moves: int = -1, flip_count: int = -1, 
					flip_move_count: int = -1, time_left: float = -1):
	if not puzzle_state.has_saved_state:
		return
	
	if elapsed_time >= 0:
		puzzle_state.counters.elapsed_time = elapsed_time
	if total_moves >= 0:
		puzzle_state.counters.total_moves = total_moves
	if flip_count >= 0:
		puzzle_state.counters.flip_count = flip_count
	if flip_move_count >= 0:
		puzzle_state.counters.flip_move_count = flip_move_count
	if time_left >= 0:
		puzzle_state.counters.time_left = time_left

# Actualizar posiciones de las piezas desde el PuzzlePieceManager
func update_pieces_positions_from_manager(piece_manager):
	if not puzzle_state.has_saved_state or not piece_manager:
		return
	
	puzzle_state.pieces_data.clear()
	var pieces_count = 0
	
	# Obtener datos directamente del PuzzlePieceManager, que incluye current_cell
	var manager_pieces = piece_manager.get_pieces()
	for piece_obj in manager_pieces:
		if piece_obj and piece_obj.node and is_instance_valid(piece_obj.node):
			var piece_data = piece_obj.node.get_puzzle_piece_data()
			
			# 🔧 CRUCIAL: Verificar y corregir información de celda
			if not piece_data.has("current_cell") or piece_data.current_cell == null:
				print("PuzzleStateManager: ⚠️ Pieza ", piece_obj.order_number, " sin current_cell, calculando...")
				piece_data["current_cell"] = {
					"x": piece_obj.current_cell.x,
					"y": piece_obj.current_cell.y
				}
			else:
				# Verificar que los datos coincidan con el piece_obj
				var saved_cell = Vector2(piece_data.current_cell.x, piece_data.current_cell.y)
				if saved_cell != piece_obj.current_cell:
					print("PuzzleStateManager: 🔧 Sincronizando current_cell para pieza ", piece_obj.order_number)
					print("  - Nodo: ", saved_cell, " vs Manager: ", piece_obj.current_cell)
					# Usar la información del manager como fuente de verdad
					piece_data["current_cell"] = {
						"x": piece_obj.current_cell.x,
						"y": piece_obj.current_cell.y
					}
			
			# 🔧 NUEVO: Validar datos antes de guardar
			if _validate_piece_data(piece_data, piece_obj):
				puzzle_state.pieces_data.append(piece_data)
				pieces_count += 1
			else:
				print("PuzzleStateManager: ⚠️ Datos inválidos para pieza ", piece_obj.order_number, ", omitiendo...")
	
	print("PuzzleStateManager: Actualizadas posiciones de ", pieces_count, " piezas con información de celda verificada")
	
	# Forzar guardado inmediato después de actualizar posiciones
	save_puzzle_state()

# 🔧 NUEVA FUNCIÓN: Validar datos de pieza antes de guardar
func _validate_piece_data(piece_data: Dictionary, piece_obj) -> bool:
	# Verificar que tenga order_number
	if not piece_data.has("order_number") or piece_data.order_number != piece_obj.order_number:
		print("PuzzleStateManager: Datos inválidos - order_number faltante o incorrecto")
		return false
	
	# Verificar que tenga current_position
	if not piece_data.has("current_position"):
		print("PuzzleStateManager: Datos inválidos - current_position faltante")
		return false
	
	# Verificar que tenga current_cell
	if not piece_data.has("current_cell") or piece_data.current_cell == null:
		print("PuzzleStateManager: Datos inválidos - current_cell faltante")
		return false
	
	# Verificar que current_cell tenga x e y
	if not piece_data.current_cell.has("x") or not piece_data.current_cell.has("y"):
		print("PuzzleStateManager: Datos inválidos - current_cell sin coordenadas x,y")
		return false
	
	# Verificar que group_id exista (puede ser -1 para piezas individuales)
	if not piece_data.has("group_id"):
		piece_data["group_id"] = -1  # Valor por defecto para piezas individuales
	
	return true

# Mantener función original para compatibilidad
func update_pieces_positions(pieces_container: Node2D):
	if not puzzle_state.has_saved_state or not pieces_container:
		return
	
	puzzle_state.pieces_data.clear()
	var pieces_count = 0
	
	for child in pieces_container.get_children():
		if child.has_method("get_puzzle_piece_data"):
			var piece_data = child.get_puzzle_piece_data()
			puzzle_state.pieces_data.append(piece_data)
			pieces_count += 1
	
	print("PuzzleStateManager: Actualizadas posiciones de ", pieces_count, " piezas (método legacy)")
	
	# Forzar guardado inmediato después de actualizar posiciones
	save_puzzle_state()

# Actualizar datos de grupos
func update_groups_data(groups: Array):
	if not puzzle_state.has_saved_state:
		return
	
	puzzle_state.groups_data = groups.duplicate(true)

# Completar puzzle - limpiar estado guardado pero mantener pack y puzzle
func complete_puzzle():
	print("PuzzleStateManager: Puzzle completado, limpiando estado pero manteniendo selección")
	
	# Guardar pack y puzzle actuales
	var current_pack = puzzle_state.pack_id
	var current_puzzle = puzzle_state.puzzle_id
	
	# Limpiar contadores y posiciones
	puzzle_state.counters.elapsed_time = 0.0
	puzzle_state.counters.total_moves = 0
	puzzle_state.counters.flip_count = 0
	puzzle_state.counters.flip_move_count = 0
	puzzle_state.counters.time_left = 0.0
	puzzle_state.pieces_data.clear()
	puzzle_state.groups_data.clear()
	
	# Mantener pack y puzzle para acceso rápido
	puzzle_state.pack_id = current_pack
	puzzle_state.puzzle_id = current_puzzle
	puzzle_state.has_saved_state = false
	
	# Detener guardado automático
	if auto_save_timer:
		auto_save_timer.stop()
	
	# Guardar estado limpio
	save_puzzle_state()

# Cargar estado del puzzle desde archivo
func load_puzzle_state():
	var file = FileAccess.open(PUZZLE_STATE_FILE, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json_result = JSON.parse_string(json_text)
		if json_result:
			puzzle_state = json_result
			print("PuzzleStateManager: Estado del puzzle cargado correctamente")
			
			# Validar integridad del estado
			if not validate_puzzle_state():
				print("PuzzleStateManager: Estado inválido, creando nuevo estado")
				reset_puzzle_state()
		else:
			print("PuzzleStateManager: Error al analizar JSON del estado")
			reset_puzzle_state()
	else:
		print("PuzzleStateManager: No se encontró archivo de estado, creando nuevo")
		reset_puzzle_state()

# Guardar estado del puzzle a archivo
func save_puzzle_state():
	puzzle_state.save_timestamp = Time.get_unix_time_from_system()
	
	var file = FileAccess.open(PUZZLE_STATE_FILE, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(puzzle_state, "\t")
		file.store_string(json_text)
		file.close()
		print("PuzzleStateManager: Estado del puzzle guardado correctamente")
	else:
		print("PuzzleStateManager: Error al guardar el estado del puzzle")

# Validar la integridad del estado cargado
func validate_puzzle_state() -> bool:
	# Verificar estructura básica
	if not puzzle_state.has("has_saved_state"):
		return false
	if not puzzle_state.has("pack_id"):
		return false
	if not puzzle_state.has("puzzle_id"):
		return false
	if not puzzle_state.has("counters"):
		return false
	if not puzzle_state.has("pieces_data"):
		return false
	if not puzzle_state.has("groups_data"):
		return false
	if not puzzle_state.has("puzzle_config"):
		return false
	
	return true

# Resetear estado a valores por defecto
func reset_puzzle_state():
	puzzle_state = {
		"has_saved_state": false,
		"pack_id": "",
		"puzzle_id": "",
		"game_mode": 2,
		"difficulty": 3,
		"counters": {
			"elapsed_time": 0.0,
			"total_moves": 0,
			"flip_count": 0,
			"flip_move_count": 0,
			"time_left": 0.0
		},
		"pieces_data": [],
		"groups_data": [],
		"puzzle_config": {
			"columns": 6,
			"rows": 8,
			"image_path": "",
			"max_moves": 0,
			"max_time": 0.0,
			"max_flips": 0,
			"max_flip_moves": 0
		},
		"save_timestamp": 0.0
	}

# Verificar si hay un estado guardado para continuar
func has_saved_state() -> bool:
	return puzzle_state.has_saved_state

# Obtener el pack del estado guardado
func get_saved_pack_id() -> String:
	return puzzle_state.pack_id

# Obtener el puzzle del estado guardado
func get_saved_puzzle_id() -> String:
	return puzzle_state.puzzle_id

# Obtener los contadores guardados
func get_saved_counters() -> Dictionary:
	return puzzle_state.counters.duplicate()

# Obtener la configuración del puzzle guardado
func get_saved_puzzle_config() -> Dictionary:
	return puzzle_state.puzzle_config.duplicate()

# Obtener datos de piezas guardadas
func get_saved_pieces_data() -> Array:
	return puzzle_state.pieces_data.duplicate(true)

# Obtener datos de grupos guardados  
func get_saved_groups_data() -> Array:
	return puzzle_state.groups_data.duplicate(true)

# Aplicar configuración guardada a GLOBAL
func apply_saved_config_to_global():
	if not puzzle_state.has_saved_state:
		return
	
	# Aplicar configuración del puzzle
	GLOBAL.columns = puzzle_state.puzzle_config.columns
	GLOBAL.rows = puzzle_state.puzzle_config.rows
	GLOBAL.gamemode = puzzle_state.game_mode
	GLOBAL.current_difficult = puzzle_state.difficulty
	
	# Aplicar límites del puzzle
	GLOBAL.puzzle_limits.max_moves = puzzle_state.puzzle_config.max_moves
	GLOBAL.puzzle_limits.max_time = puzzle_state.puzzle_config.max_time
	GLOBAL.puzzle_limits.max_flips = puzzle_state.puzzle_config.max_flips
	GLOBAL.puzzle_limits.max_flip_moves = puzzle_state.puzzle_config.max_flip_moves
	
	print("PuzzleStateManager: Configuración aplicada a GLOBAL")

# Configurar puzzle y pack para continuar partida
func setup_continue_game():
	if not puzzle_state.has_saved_state:
		return false
	
	# Buscar el pack en los datos cargados
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("PuzzleStateManager: Error - No se encontró ProgressManager")
		return false
	
	# Buscar pack
	var found_pack = null
	var found_puzzle = null
	
	for pack in progress_manager.packs_data.packs:
		if pack.id == puzzle_state.pack_id:
			found_pack = pack
			# Buscar puzzle dentro del pack
			for puzzle in pack.puzzles:
				if puzzle.id == puzzle_state.puzzle_id:
					found_puzzle = puzzle
					break
			break
	
	if not found_pack or not found_puzzle:
		print("PuzzleStateManager: No se encontró el pack o puzzle guardado")
		return false
	
	# Configurar GLOBAL con pack y puzzle encontrados
	GLOBAL.selected_pack = found_pack
	GLOBAL.selected_puzzle = found_puzzle
	
	# Aplicar configuración guardada
	apply_saved_config_to_global()
	
	print("PuzzleStateManager: Juego configurado para continuar - Pack: ", found_pack.name, ", Puzzle: ", found_puzzle.id)
	return true

# Limpiar completamente el estado (útil para empezar de cero)
func clear_all_state():
	reset_puzzle_state()
	if auto_save_timer:
		auto_save_timer.stop()
	save_puzzle_state()
	print("PuzzleStateManager: Estado completamente limpiado")

# === SISTEMA DE CONFIGURACIONES POR DEFECTO ===

# Cargar una configuración por defecto para un puzzle específico
func load_default_puzzle_config(pack_id: String, puzzle_id: String, config_name: String = "default") -> bool:
	var config_path = "user://puzzle_configs/" + pack_id + "_" + puzzle_id + "_" + config_name + ".json"
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json_result = JSON.parse_string(json_text)
		if json_result:
			# Aplicar la configuración cargada
			_apply_default_config(json_result)
			print("PuzzleStateManager: Configuración por defecto cargada: ", config_name)
			return true
		else:
			print("PuzzleStateManager: Error al analizar configuración por defecto")
	else:
		print("PuzzleStateManager: No se encontró configuración por defecto: ", config_name)
	
	return false

# Guardar la configuración actual como configuración por defecto
func save_default_puzzle_config(pack_id: String, puzzle_id: String, config_name: String = "default") -> bool:
	# Crear directorio si no existe
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("puzzle_configs"):
		dir.make_dir("puzzle_configs")
	
	var config_path = "user://puzzle_configs/" + pack_id + "_" + puzzle_id + "_" + config_name + ".json"
	
	# Crear configuración basada en el estado actual
	var config_data = {
		"config_name": config_name,
		"pack_id": pack_id,
		"puzzle_id": puzzle_id,
		"game_mode": GLOBAL.gamemode,
		"difficulty": GLOBAL.current_difficult,
		"puzzle_config": {
			"columns": GLOBAL.columns,
			"rows": GLOBAL.rows,
			"max_moves": GLOBAL.puzzle_limits.max_moves,
			"max_time": GLOBAL.puzzle_limits.max_time,
			"max_flips": GLOBAL.puzzle_limits.max_flips,
			"max_flip_moves": GLOBAL.puzzle_limits.max_flip_moves
		},
		"description": "Configuración guardada el " + Time.get_datetime_string_from_system(),
		"save_timestamp": Time.get_unix_time_from_system()
	}
	
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(config_data, "\t")
		file.store_string(json_text)
		file.close()
		print("PuzzleStateManager: Configuración por defecto guardada: ", config_name)
		return true
	else:
		print("PuzzleStateManager: Error al guardar configuración por defecto")
		return false

# Obtener lista de configuraciones disponibles para un puzzle
func get_available_configs(pack_id: String, puzzle_id: String) -> Array:
	var configs = []
	var dir = DirAccess.open("user://puzzle_configs/")
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var prefix = pack_id + "_" + puzzle_id + "_"
		
		while file_name != "":
			if file_name.begins_with(prefix) and file_name.ends_with(".json"):
				var config_name = file_name.replace(prefix, "").replace(".json", "")
				configs.append(config_name)
			file_name = dir.get_next()
	
	return configs

# Aplicar una configuración por defecto
func _apply_default_config(config_data: Dictionary):
	if config_data.has("game_mode"):
		GLOBAL.gamemode = config_data.game_mode
	
	if config_data.has("difficulty"):
		GLOBAL.current_difficult = config_data.difficulty
	
	if config_data.has("puzzle_config"):
		var puzzle_config = config_data.puzzle_config
		if puzzle_config.has("columns"):
			GLOBAL.columns = puzzle_config.columns
		if puzzle_config.has("rows"):
			GLOBAL.rows = puzzle_config.rows
		if puzzle_config.has("max_moves"):
			GLOBAL.puzzle_limits.max_moves = puzzle_config.max_moves
		if puzzle_config.has("max_time"):
			GLOBAL.puzzle_limits.max_time = puzzle_config.max_time
		if puzzle_config.has("max_flips"):
			GLOBAL.puzzle_limits.max_flips = puzzle_config.max_flips
		if puzzle_config.has("max_flip_moves"):
			GLOBAL.puzzle_limits.max_flip_moves = puzzle_config.max_flip_moves
	
	print("PuzzleStateManager: Configuración por defecto aplicada")

# Crear configuración de desafío personalizada
func create_challenge_config(pack_id: String, puzzle_id: String, config_name: String, 
							max_moves: int, max_time: float, max_flips: int) -> bool:
	# Crear directorio si no existe
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("puzzle_configs"):
		dir.make_dir("puzzle_configs")
	
	var config_path = "user://puzzle_configs/" + pack_id + "_" + puzzle_id + "_" + config_name + ".json"
	
	var config_data = {
		"config_name": config_name,
		"pack_id": pack_id,
		"puzzle_id": puzzle_id,
		"game_mode": 4,  # Modo desafío
		"difficulty": GLOBAL.current_difficult,
		"puzzle_config": {
			"columns": GLOBAL.columns,
			"rows": GLOBAL.rows,
			"max_moves": max_moves,
			"max_time": max_time,
			"max_flips": max_flips,
			"max_flip_moves": max_moves  # Por defecto, mismo que max_moves
		},
		"description": "Desafío personalizado: " + str(max_moves) + " movimientos, " + str(max_time) + "s, " + str(max_flips) + " flips",
		"save_timestamp": Time.get_unix_time_from_system()
	}
	
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(config_data, "\t")
		file.store_string(json_text)
		file.close()
		print("PuzzleStateManager: Configuración de desafío creada: ", config_name)
		return true
	else:
		print("PuzzleStateManager: Error al crear configuración de desafío")
		return false 
