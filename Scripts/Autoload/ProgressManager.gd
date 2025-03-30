extends Node

# Constantes para el archivo de guardado
const SAVE_FILE = "user://progress.json"
const PACKS_DATA_FILE = "res://PacksData/sample_packs.json"

# Datos de progresión
var progress_data = {
	"packs": {},
	"statistics": {}  # Nueva sección para estadísticas de partidas
}

# Datos de packs originales (desde el archivo JSON)
var packs_data = {}

func _ready():
	# Imprimir un mensaje de diagnóstico al inicio
	print("ProgressManager: Inicializando...")
	
	# Cargar los datos de progresión al iniciar
	load_progress_data()
	
	# Cargar los datos de packs desde el archivo JSON
	load_packs_data()
	
	# Verificar si los packs se cargaron correctamente
	if packs_data.is_empty() or not packs_data.has("packs") or packs_data.packs.size() == 0:
		print("ProgressManager: ERROR - Fallo al cargar los packs, intentando cargar manualmente")
		# Intentar cargar directamente el archivo JSON
		var file = FileAccess.open(PACKS_DATA_FILE, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var json_result = JSON.parse_string(json_text)
			if json_result and json_result.has("packs"):
				packs_data = json_result
				print("ProgressManager: Datos de packs cargados manualmente. Número de packs: ", packs_data.packs.size())
			else:
				print("ProgressManager: ERROR - No se pudo cargar manualmente el archivo de packs")
				# Crear una estructura mínima para evitar errores
				packs_data = {"packs": []}
		else:
			print("ProgressManager: ERROR - No se pudo abrir el archivo para carga manual")
			# Crear una estructura mínima para evitar errores
			packs_data = {"packs": []}
	
	# Inicializar la progresión si es necesario
	initialize_progress_if_needed()
	
	print("ProgressManager: Inicialización completada")

# Carga los datos de progresión desde el archivo de guardado
func load_progress_data():
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json_result = JSON.parse_string(json_text)
		if json_result:
			progress_data = json_result
			print("ProgressManager: Datos de progresión cargados correctamente")
		else:
			print("ProgressManager: Error al analizar el JSON de progresión")
	else:
		print("ProgressManager: No se encontró archivo de progresión, se creará uno nuevo")

# Guarda los datos de progresión en el archivo de guardado
func save_progress_data():
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(progress_data, "\t")
		file.store_string(json_text)
		file.close()
		print("ProgressManager: Datos de progresión guardados correctamente")
	else:
		print("ProgressManager: Error al guardar los datos de progresión")

# Carga los datos de packs desde el archivo JSON
func load_packs_data():
	print("ProgressManager: Intentando cargar packs desde: ", PACKS_DATA_FILE)
	var file = FileAccess.open(PACKS_DATA_FILE, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		print("ProgressManager: Archivo JSON leído, tamaño: ", json_text.length(), " bytes")
		var json_result = JSON.parse_string(json_text)
		if json_result and json_result.has("packs"):
			packs_data = json_result
			print("ProgressManager: Datos de packs cargados correctamente. Número de packs: ", packs_data.packs.size())
			
			# Imprimir información básica de cada pack para diagnóstico
			for i in range(packs_data.packs.size()):
				var pack = packs_data.packs[i]
				print("ProgressManager: Pack ", i, " - ID: ", pack.id, ", Name: ", pack.name, 
					", Unlocked: ", pack.get("unlocked", false), ", Puzzles: ", 
					pack.puzzles.size() if pack.has("puzzles") else "No puzzles")
		else:
			print("ProgressManager: ERROR - No se pudo analizar el JSON de packs o no tiene la estructura esperada")
			
			# Intentar diagnóstico adicional
			if json_result:
				print("ProgressManager: El JSON se analizó pero no tiene la clave 'packs'")
				print("ProgressManager: Claves disponibles: ", json_result.keys())
			else:
				print("ProgressManager: Error al analizar el JSON")
	else:
		print("ProgressManager: ERROR - No se encontró el archivo de packs en: ", PACKS_DATA_FILE)
		
		# Intentar verificar la existencia del directorio y archivo
		var dir = DirAccess.open("res://PacksData")
		if dir:
			print("ProgressManager: El directorio PacksData existe")
			var files = dir.get_files()
			print("ProgressManager: Archivos en PacksData: ", files)
		else:
			print("ProgressManager: ERROR - No se pudo abrir el directorio PacksData")

# Inicializa la progresión si es necesario
func initialize_progress_if_needed():
	# Si no hay datos de progresión o están vacíos, inicializarlos
	if not progress_data.has("packs") or progress_data.packs.is_empty():
		progress_data.packs = {}
	
	# Inicializar la sección de estadísticas si no existe
	if not progress_data.has("statistics"):
		progress_data.statistics = {}
		
	# Asegurarse de que todos los packs del archivo JSON estén en los datos de progresión
	if packs_data.has("packs"):
		for pack in packs_data.packs:
			var pack_id = pack.id
			
			# Si el pack no existe en los datos de progresión, inicializarlo
			if not progress_data.packs.has(pack_id):
				progress_data.packs[pack_id] = {
					"unlocked": pack.unlocked,
					"purchased": pack.purchased,
					"completed": pack.completed,
					"puzzles": {}
				}
				
				# Inicializar el primer puzzle como desbloqueado si el pack está desbloqueado
				if pack.unlocked and pack.purchased and pack.puzzles.size() > 0:
					progress_data.packs[pack_id].puzzles[pack.puzzles[0].id] = {
						"completed": false,
						"unlocked": true
					}
		
		# Guardar los datos inicializados
		save_progress_data()

# Verifica si un pack está desbloqueado
func is_pack_unlocked(pack_id: String) -> bool:
	if progress_data.packs.has(pack_id):
		return progress_data.packs[pack_id].unlocked
	return false

# Verifica si un pack ha sido comprado
func is_pack_purchased(pack_id: String) -> bool:
	if progress_data.packs.has(pack_id):
		return progress_data.packs[pack_id].purchased
	return false

# Verifica si un pack está disponible para jugar (desbloqueado y comprado)
func is_pack_available(pack_id: String) -> bool:
	return is_pack_unlocked(pack_id) and is_pack_purchased(pack_id)

# Verifica si un puzzle está desbloqueado
func is_puzzle_unlocked(pack_id: String, puzzle_id: String) -> bool:
	if progress_data.packs.has(pack_id) and progress_data.packs[pack_id].puzzles.has(puzzle_id):
		return progress_data.packs[pack_id].puzzles[puzzle_id].unlocked
	return false

# Verifica si un puzzle ha sido completado
func is_puzzle_completed(pack_id: String, puzzle_id: String) -> bool:
	if progress_data.packs.has(pack_id) and progress_data.packs[pack_id].puzzles.has(puzzle_id):
		return progress_data.packs[pack_id].puzzles[puzzle_id].completed
	return false

# Marca un puzzle como completado y desbloquea el siguiente
func complete_puzzle(pack_id: String, puzzle_id: String):
	print("ProgressManager: Marcando puzzle como completado - Pack: " + pack_id + ", Puzzle: " + puzzle_id)
	
	if not progress_data.packs.has(pack_id):
		print("ProgressManager: El pack no existe en los datos de progresión, inicializándolo")
		progress_data.packs[pack_id] = {
			"unlocked": true,
			"purchased": true,
			"completed": false,
			"puzzles": {}
		}
		
	# Marcar el puzzle como completado
	if not progress_data.packs[pack_id].puzzles.has(puzzle_id):
		print("ProgressManager: Inicializando datos del puzzle: " + puzzle_id)
		progress_data.packs[pack_id].puzzles[puzzle_id] = {
			"completed": true,
			"unlocked": true
		}
	else:
		print("ProgressManager: Actualizando estado del puzzle: " + puzzle_id)
		progress_data.packs[pack_id].puzzles[puzzle_id].completed = true
	
	# Buscar el siguiente puzzle en el pack
	var next_puzzle_index = -1
	var current_puzzle_index = -1
	var current_pack_index = -1
	
	# Encontrar el índice del pack actual y el siguiente
	if packs_data.has("packs"):
		for i in range(packs_data.packs.size()):
			var pack = packs_data.packs[i]
			if pack.id == pack_id:
				current_pack_index = i
				for j in range(pack.puzzles.size()):
					if pack.puzzles[j].id == puzzle_id:
						current_puzzle_index = j
						next_puzzle_index = j + 1
						break
				break
	
	print("ProgressManager: Índices - Pack: " + str(current_pack_index) + ", Puzzle actual: " + str(current_puzzle_index) + ", Siguiente puzzle: " + str(next_puzzle_index))
	
	# Si hay un siguiente puzzle, desbloquearlo
	if current_pack_index >= 0 and next_puzzle_index >= 0 and next_puzzle_index < packs_data.packs[current_pack_index].puzzles.size():
		var next_puzzle_id = packs_data.packs[current_pack_index].puzzles[next_puzzle_index].id
		
		# Asegurarse de que el siguiente puzzle esté desbloqueado
		if not progress_data.packs[pack_id].puzzles.has(next_puzzle_id):
			progress_data.packs[pack_id].puzzles[next_puzzle_id] = {
				"completed": false,
				"unlocked": true
			}
			print("ProgressManager: Desbloqueado nuevo puzzle: " + next_puzzle_id)
		else:
			# Asegurarse de que esté marcado como desbloqueado incluso si ya existe
			progress_data.packs[pack_id].puzzles[next_puzzle_id].unlocked = true
			print("ProgressManager: Actualizado estado de desbloqueo para puzzle: " + next_puzzle_id)
	else:
		# Si no hay más puzzles, marcar el pack como completado
		progress_data.packs[pack_id].completed = true
		print("ProgressManager: Pack completado: " + pack_id)
		
		# Desbloquear el siguiente pack
		unlock_next_pack(pack_id)
	
	# Guardar los cambios inmediatamente
	save_progress_data()
	print("ProgressManager: Progreso guardado después de completar puzzle")

# Desbloquea el siguiente pack
func unlock_next_pack(current_pack_id: String):
	var next_pack_index = -1
	var current_pack_index = -1
	
	# Encontrar el índice del pack actual y el siguiente
	if packs_data.has("packs"):
		for i in range(packs_data.packs.size()):
			if packs_data.packs[i].id == current_pack_id:
				current_pack_index = i
				next_pack_index = i + 1
				break
	
	# Si hay un siguiente pack, desbloquearlo
	if next_pack_index >= 0 and next_pack_index < packs_data.packs.size():
		var next_pack_id = packs_data.packs[next_pack_index].id
		
		if not progress_data.packs.has(next_pack_id):
			progress_data.packs[next_pack_id] = {
				"unlocked": true,
				"purchased": packs_data.packs[next_pack_index].purchased,
				"completed": false,
				"puzzles": {}
			}
		else:
			progress_data.packs[next_pack_id].unlocked = true
		
		# Si el pack está comprado, desbloquear su primer puzzle
		if progress_data.packs[next_pack_id].purchased and packs_data.packs[next_pack_index].puzzles.size() > 0:
			var first_puzzle_id = packs_data.packs[next_pack_index].puzzles[0].id
			
			if not progress_data.packs[next_pack_id].puzzles.has(first_puzzle_id):
				progress_data.packs[next_pack_id].puzzles[first_puzzle_id] = {
					"completed": false,
					"unlocked": true
				}
			else:
				progress_data.packs[next_pack_id].puzzles[first_puzzle_id].unlocked = true
		
		# Guardar los cambios
		save_progress_data()

# Marca un pack como comprado y desbloquea su primer puzzle
func purchase_pack(pack_id: String):
	if not progress_data.packs.has(pack_id):
		print("ProgressManager: El pack no existe en los datos de progresión")
		return
	
	# Marcar el pack como comprado
	progress_data.packs[pack_id].purchased = true
	
	# Buscar el pack en los datos originales
	var pack_index = -1
	if packs_data.has("packs"):
		for i in range(packs_data.packs.size()):
			if packs_data.packs[i].id == pack_id:
				pack_index = i
				break
	
	# Si el pack está desbloqueado y tiene puzzles, desbloquear el primero
	if progress_data.packs[pack_id].unlocked and pack_index >= 0 and packs_data.packs[pack_index].puzzles.size() > 0:
		var first_puzzle_id = packs_data.packs[pack_index].puzzles[0].id
		
		if not progress_data.packs[pack_id].puzzles.has(first_puzzle_id):
			progress_data.packs[pack_id].puzzles[first_puzzle_id] = {
				"completed": false,
				"unlocked": true
			}
		else:
			progress_data.packs[pack_id].puzzles[first_puzzle_id].unlocked = true
	
	# Guardar los cambios
	save_progress_data()

# Obtiene los datos de un pack con información de progresión
func get_pack_with_progress(pack_id: String) -> Dictionary:
	var pack_data = {}
	
	print("ProgressManager: Obteniendo pack con progresión: " + pack_id)
	
	# Buscar el pack en los datos originales
	if packs_data.has("packs"):
		for pack in packs_data.packs:
			if pack.id == pack_id:
				# Copiar los datos del pack
				pack_data = pack.duplicate(true)
				
				# Actualizar el estado de desbloqueo y compra desde los datos de progresión
				if progress_data.packs.has(pack_id):
					pack_data.unlocked = progress_data.packs[pack_id].unlocked
					pack_data.purchased = progress_data.packs[pack_id].purchased
					pack_data.completed = progress_data.packs[pack_id].completed
					
					print("ProgressManager: Cargando datos de progresión para pack: " + pack_id)
					print("ProgressManager: - Desbloqueado: " + str(pack_data.unlocked))
					print("ProgressManager: - Comprado: " + str(pack_data.purchased))
					print("ProgressManager: - Completado: " + str(pack_data.completed))
				
				# Actualizar el estado de cada puzzle
				for i in range(pack_data.puzzles.size()):
					var puzzle_id = pack_data.puzzles[i].id
					
					# Establecer el estado de desbloqueo y completado
					if progress_data.packs.has(pack_id) and progress_data.packs[pack_id].puzzles.has(puzzle_id):
						pack_data.puzzles[i].completed = progress_data.packs[pack_id].puzzles[puzzle_id].completed
						pack_data.puzzles[i].unlocked = progress_data.packs[pack_id].puzzles[puzzle_id].unlocked
						
						print("ProgressManager: Puzzle " + puzzle_id + " - Desbloqueado: " + 
							str(pack_data.puzzles[i].unlocked) + ", Completado: " + 
							str(pack_data.puzzles[i].completed))
					else:
						# Por defecto, solo el primer puzzle está desbloqueado si el pack está disponible
						pack_data.puzzles[i].unlocked = (i == 0 and is_pack_available(pack_id))
						pack_data.puzzles[i].completed = false
						
						print("ProgressManager: Puzzle " + puzzle_id + " no tiene datos de progresión, estado por defecto - Desbloqueado: " + 
							str(pack_data.puzzles[i].unlocked) + ", Completado: " + 
							str(pack_data.puzzles[i].completed))
				
				break
	
	return pack_data

# Obtiene todos los packs con información de progresión
func get_all_packs_with_progress() -> Array:
	print("ProgressManager: get_all_packs_with_progress() - Obteniendo todos los packs con progresión")
	var packs_with_progress = []
	
	if packs_data.has("packs"):
		print("ProgressManager: Número de packs en packs_data: ", packs_data.packs.size())
		for pack in packs_data.packs:
			print("ProgressManager: Procesando pack: ", pack.id)
			var pack_with_progress = get_pack_with_progress(pack.id)
			if not pack_with_progress.is_empty():
				packs_with_progress.append(pack_with_progress)
				print("ProgressManager: Pack añadido a la lista: ", pack.id)
			else:
				print("ProgressManager: ERROR - No se pudo obtener datos del pack: ", pack.id)
	else:
		print("ProgressManager: ERROR - No hay packs en packs_data o no tiene la estructura esperada")
		print("ProgressManager: Claves en packs_data: ", packs_data.keys())
	
	print("ProgressManager: Total de packs con progresión: ", packs_with_progress.size())
	return packs_with_progress

# Reinicia la progresión (para pruebas)
func reset_progress():
	progress_data = {
		"packs": {},
		"statistics": {}
	}
	initialize_progress_if_needed()
	save_progress_data()

# Obtiene el siguiente puzzle desbloqueado después del puzzle actual
func get_next_unlocked_puzzle(pack_id: String, current_puzzle_id: String):
	print("ProgressManager: Buscando siguiente puzzle desbloqueado - Pack: " + pack_id + ", Puzzle actual: " + current_puzzle_id)
	
	# Verificar que el pack existe en los datos
	if not packs_data.has("packs"):
		print("ProgressManager: No hay datos de packs disponibles")
		return null
	
	# Buscar el pack y el puzzle actual
	var current_pack = null
	var current_puzzle_index = -1
	
	for pack in packs_data.packs:
		if pack.id == pack_id:
			current_pack = pack
			for i in range(pack.puzzles.size()):
				if pack.puzzles[i].id == current_puzzle_id:
					current_puzzle_index = i
					break
			break
	
	if current_pack == null or current_puzzle_index == -1:
		print("ProgressManager: No se encontró el pack o el puzzle actual")
		return null
	
	print("ProgressManager: Puzzle actual encontrado en índice: " + str(current_puzzle_index))
	
	# Verificar si hay un siguiente puzzle
	if current_puzzle_index + 1 < current_pack.puzzles.size():
		var next_puzzle = current_pack.puzzles[current_puzzle_index + 1]
		print("ProgressManager: Siguiente puzzle encontrado: " + next_puzzle.id)
		
		# Asegurarse de que el siguiente puzzle esté desbloqueado
		if not progress_data.packs.has(pack_id):
			print("ProgressManager: El pack no existe en los datos de progresión, inicializándolo")
			progress_data.packs[pack_id] = {
				"unlocked": true,
				"purchased": true,
				"completed": false,
				"puzzles": {}
			}
			
		# Desbloquear el siguiente puzzle si no está ya desbloqueado
		if not progress_data.packs[pack_id].puzzles.has(next_puzzle.id):
			print("ProgressManager: Desbloqueando nuevo puzzle: " + next_puzzle.id)
			progress_data.packs[pack_id].puzzles[next_puzzle.id] = {
				"completed": false,
				"unlocked": true
			}
			save_progress_data()
			print("ProgressManager: Progreso guardado después de desbloquear puzzle")
		elif not progress_data.packs[pack_id].puzzles[next_puzzle.id].unlocked:
			print("ProgressManager: Actualizando estado de desbloqueo para puzzle: " + next_puzzle.id)
			progress_data.packs[pack_id].puzzles[next_puzzle.id].unlocked = true
			save_progress_data()
			print("ProgressManager: Progreso guardado después de actualizar estado de desbloqueo")
		else:
			print("ProgressManager: El puzzle ya estaba desbloqueado: " + next_puzzle.id)
		
		return next_puzzle
	
	# Si no hay siguiente puzzle, devolver null
	print("ProgressManager: No hay siguiente puzzle disponible")
	return null

# Nueva función para guardar estadísticas de una partida
func save_puzzle_stats(pack_id: String, puzzle_id: String, stats: Dictionary):
	print("ProgressManager: Guardando estadísticas para el puzzle - Pack: " + pack_id + ", Puzzle: " + puzzle_id)
	
	# Asegurar que la estructura existe
	if not progress_data.statistics.has(pack_id):
		progress_data.statistics[pack_id] = {}
	
	if not progress_data.statistics[pack_id].has(puzzle_id):
		progress_data.statistics[pack_id][puzzle_id] = {}
	
	# Determinamos clave basada en dificultad
	var difficulty_key = str(stats.columns) + "x" + str(stats.rows)
	
	if not progress_data.statistics[pack_id][puzzle_id].has(difficulty_key):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key] = {
			"completions": 0,
			"best_time": 99999,
			"best_moves": 99999,
			"history": []
		}
	
	# Incrementar contador de completaciones
	progress_data.statistics[pack_id][puzzle_id][difficulty_key].completions += 1
	
	# Actualizar mejores tiempos y movimientos si corresponde
	if stats.time < progress_data.statistics[pack_id][puzzle_id][difficulty_key].best_time:
		progress_data.statistics[pack_id][puzzle_id][difficulty_key].best_time = stats.time
	
	if stats.moves < progress_data.statistics[pack_id][puzzle_id][difficulty_key].best_moves:
		progress_data.statistics[pack_id][puzzle_id][difficulty_key].best_moves = stats.moves
	
	# Guardar registro en el historial (limitamos a los últimos 10 intentos)
	var history_entry = {
		"date": Time.get_datetime_string_from_system(),
		"time": stats.time,
		"moves": stats.moves
	}
	
	progress_data.statistics[pack_id][puzzle_id][difficulty_key].history.push_front(history_entry)
	
	# Limitar el historial a 10 entradas
	if progress_data.statistics[pack_id][puzzle_id][difficulty_key].history.size() > 10:
		progress_data.statistics[pack_id][puzzle_id][difficulty_key].history.resize(10)
	
	# Guardar los datos
	save_progress_data()
	print("ProgressManager: Estadísticas guardadas correctamente")

# Nueva función para obtener estadísticas de un puzzle
func get_puzzle_stats(pack_id: String, puzzle_id: String) -> Dictionary:
	var stats = {}
	
	if progress_data.statistics.has(pack_id) and progress_data.statistics[pack_id].has(puzzle_id):
		stats = progress_data.statistics[pack_id][puzzle_id].duplicate(true)
	
	return stats

# Nueva función para obtener las estadísticas generales de un jugador
func get_player_stats() -> Dictionary:
	var player_stats = {
		"total_puzzles_completed": 0,
		"total_time_played": 0,
		"total_moves": 0,
		"packs_completed": 0
	}
	
	# Recorrer estadísticas para calcular totales
	for pack_id in progress_data.statistics.keys():
		for puzzle_id in progress_data.statistics[pack_id].keys():
			for difficulty in progress_data.statistics[pack_id][puzzle_id].keys():
				var puzzle_stats = progress_data.statistics[pack_id][puzzle_id][difficulty]
				player_stats.total_puzzles_completed += puzzle_stats.completions
				
				# Sumar el tiempo de todas las partidas en el historial
				for entry in puzzle_stats.history:
					player_stats.total_time_played += entry.time
					player_stats.total_moves += entry.moves
	
	# Contar packs completados
	for pack_id in progress_data.packs.keys():
		if progress_data.packs[pack_id].completed:
			player_stats.packs_completed += 1
	
	return player_stats 