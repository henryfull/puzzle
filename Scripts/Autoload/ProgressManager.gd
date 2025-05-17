extends Node

# Constantes para el archivo de guardado
const SAVE_FILE = "user://progress.json"
const ROUTE_DLC = "res://dlc"
const PACKS_DATA_FILE = "res://PacksData/sample_packs.json"
const DLC_PACKS_DIR = ROUTE_DLC + "/dlc_metadata.json"

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
	
	# Sincronizar lista de DLCs con GLOBAL
	if has_node("/root/GLOBAL"):
		if (GLOBAL.dlc_packs.size() > 0):
			load_dlc_packs()
	else:
		print("ProgressManager: ADVERTENCIA - No se encontró el nodo GLOBAL, no se cargarán los DLCs")
	
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
	print("ProgressManager: Intentando cargar DLCs desde: ", DLC_PACKS_DIR)
	var file = FileAccess.open(PACKS_DATA_FILE, FileAccess.READ)
	var dlc_file = FileAccess.open(DLC_PACKS_DIR, FileAccess.READ)
	
	if file:
		var json_text = file.get_as_text()
		file.close()
		print("ProgressManager: Archivo JSON leído, tamaño: ", json_text.length(), " bytes")
		var json_result = JSON.parse_string(json_text)
		if json_result and json_result.has("packs"):
			packs_data = json_result
			print("ProgressManager: Datos de packs cargados correctamente. Número de packs: ", packs_data.packs.size())
			
			# Si hay archivo de DLC, cargar también esos packs
			if dlc_file:
				var dlc_json_text = dlc_file.get_as_text()
				dlc_file.close()
				var dlc_json_result = JSON.parse_string(dlc_json_text)
				if dlc_json_result and dlc_json_result.has("packs"):
					print("ProgressManager: Encontrados ", dlc_json_result.packs.size(), " packs DLC")
					
					# Integrar los packs DLC con los packs normales
					for dlc_pack in dlc_json_result.packs:
						# Verificar si ya existe para evitar duplicados
						var already_exists = false
						for i in range(packs_data.packs.size()):
							if packs_data.packs[i].id == dlc_pack.id:
								already_exists = true
								break
						
						if not already_exists:
							# Marcar como DLC para identificación
							dlc_pack["is_dlc"] = true
							packs_data.packs.append(dlc_pack)
							print("ProgressManager: Añadido pack DLC: ", dlc_pack.id)
			
			# Imprimir información básica de cada pack para diagnóstico
			for i in range(packs_data.packs.size()):
				var pack = packs_data.packs[i]
				var dlc_tag = " (DLC)" if pack.get("is_dlc", false) else ""
				print("ProgressManager: Pack ", i, " - ID: ", pack.id, ", Name: ", pack.name, 
					", Unlocked: ", pack.get("unlocked", false), ", Puzzles: ", 
					pack.puzzles.size() if pack.has("puzzles") else "No puzzles", dlc_tag)
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
func save_puzzle_stats(stats: Dictionary, pack_id: String, puzzle_id: String, difficulty_key: String) -> void:
	if not progress_data.statistics.has(pack_id):
		progress_data.statistics[pack_id] = {}
	
	if not progress_data.statistics[pack_id].has(puzzle_id):
		progress_data.statistics[pack_id][puzzle_id] = {}
	
	if not progress_data.statistics[pack_id][puzzle_id].has(difficulty_key):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key] = {
			"best_time": 99999,
			"best_moves": 99999,
			"completions": 0,
			"best_time_date": "",
			"best_moves_date": "",
			"best_flips": 99999,
			"best_flips_date": "",
			"best_flip_moves": 99999,
			"best_flip_moves_date": "",
			"history": []
		}
	
	# Asegurar que todas las propiedades necesarias existen
	if not progress_data.statistics[pack_id][puzzle_id][difficulty_key].has("best_flips"):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flips"] = 99999
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flips_date"] = ""
	
	if not progress_data.statistics[pack_id][puzzle_id][difficulty_key].has("best_flip_moves"):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flip_moves"] = 99999
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flip_moves_date"] = ""
		
	if not progress_data.statistics[pack_id][puzzle_id][difficulty_key].has("history"):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["history"] = []
	
	# Asegurar que existe completions (antes era completion_count)
	if not progress_data.statistics[pack_id][puzzle_id][difficulty_key].has("completions"):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["completions"] = 0
		
	# Incrementar contador de completados con notación de diccionario
	progress_data.statistics[pack_id][puzzle_id][difficulty_key]["completions"] += 1
	
	if stats.has("time") and (stats.time < progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_time"] or progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_time"] == 99999):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_time"] = stats.time
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_time_date"] = stats.date
		
	if stats.has("moves") and (stats.moves < progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_moves"] or progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_moves"] == 99999):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_moves"] = stats.moves
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_moves_date"] = stats.date
	
	# Nuevas estadísticas para flips y flip_moves
	if stats.has("flips") and (stats.flips < progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flips"] or progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flips"] == 99999):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flips"] = stats.flips
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flips_date"] = stats.date
	
	if stats.has("flip_moves") and (stats.flip_moves < progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flip_moves"] or progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flip_moves"] == 99999):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flip_moves"] = stats.flip_moves
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flip_moves_date"] = stats.date
	
	# Guardar historial de partidas
	var history_entry = stats.duplicate()
	progress_data.statistics[pack_id][puzzle_id][difficulty_key]["history"].append(history_entry)
	
	# Limitar historial a las últimas 20 partidas
	if progress_data.statistics[pack_id][puzzle_id][difficulty_key]["history"].size() > 20:
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["history"].pop_front()
	
	save_progress_data()

# Nueva función para obtener estadísticas de un puzzle
func get_puzzle_stats(pack_id: String, puzzle_id: String) -> Dictionary:
	var stats = {}
	
	if progress_data.statistics.has(pack_id) and progress_data.statistics[pack_id].has(puzzle_id):
		stats = progress_data.statistics[pack_id][puzzle_id].duplicate(true)
		
		# Asegurar que todas las dificultades tienen las propiedades nuevas
		for difficulty_key in stats.keys():
			if not stats[difficulty_key].has("best_flips"):
				stats[difficulty_key]["best_flips"] = 99999
				stats[difficulty_key]["best_flips_date"] = ""
			if not stats[difficulty_key].has("best_flip_moves"):
				stats[difficulty_key]["best_flip_moves"] = 99999
				stats[difficulty_key]["best_flip_moves_date"] = ""
			if not stats[difficulty_key].has("history"):
				stats[difficulty_key]["history"] = []
				
			# Verificar el historial
			if stats[difficulty_key].has("history"):
				for entry in stats[difficulty_key].history:
					if not entry.has("flips"):
						entry["flips"] = 0
					if not entry.has("flip_moves"):
						entry["flip_moves"] = 0
					if not entry.has("gamemode"):
						entry["gamemode"] = 0
	
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
				# Usar notación de diccionario
				if puzzle_stats.has("completions"):
					player_stats["total_puzzles_completed"] += puzzle_stats["completions"]
				
				# Sumar el tiempo de todas las partidas en el historial
				if puzzle_stats.has("history"):
					for entry in puzzle_stats["history"]:
						if entry.has("time"):
							player_stats["total_time_played"] += entry["time"]
						if entry.has("moves"):
							player_stats["total_moves"] += entry["moves"]
	
	# Contar packs completados
	for pack_id in progress_data.packs.keys():
		if progress_data.packs[pack_id].has("completed") and progress_data.packs[pack_id]["completed"]:
			player_stats["packs_completed"] += 1
	
	return player_stats 

# Funciones para gestionar packs DLC
# ----------------------------------

# Carga los packs DLC disponibles desde el directorio de DLC
func load_dlc_packs() -> Array:
	print("ProgressManager: Cargando packs DLC desde: ", DLC_PACKS_DIR)
	var dlc_packs = []
	
	# Verificar primero si tenemos el nodo GLOBAL
	if not has_node("/root/GLOBAL"):
		print("ProgressManager: No se encontró el nodo GLOBAL, no se pueden comprobar los DLCs")
		return []
	
	var global_node = get_node("/root/GLOBAL")
	
	var file = FileAccess.open(DLC_PACKS_DIR, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		
		var list_packs = JSON.parse_string(json_text)
		var json_result = []
		
		# Verificar cada pack DLC antes de cargarlo
		for pack in list_packs.dlc_packs:
			# Comprobar si el pack está comprado
			var is_purchased = pack in global_node.dlc_packs
			
			# Comprobar si está en settings (guardado como comprado)
			var is_in_settings = false
			for saved_pack_id in progress_data.packs:
				if saved_pack_id == pack and progress_data.packs[saved_pack_id].purchased:
					is_in_settings = true
					break
			
			# Solo cargar el pack si cumple todas las condiciones
			if is_purchased and is_in_settings:
				print("ProgressManager: Pack DLC '" + pack + "' verificado, cargando...")
				var new_pack = ROUTE_DLC + "/packs/" + pack + ".json"
				var new_file = FileAccess.open(new_pack, FileAccess.READ)
				if new_file:
					var json_text_pack = new_file.get_as_text()
					new_file.close()
					var json_result_pack = JSON.parse_string(json_text_pack)
					json_result.append(json_result_pack)
			else:
				print("ProgressManager: Pack DLC '" + pack + "' no verificado, no se cargará (comprado: " + str(is_purchased) + ", en settings: " + str(is_in_settings) + ")")

		if json_result.size() > 0:
			dlc_packs = json_result
			print("ProgressManager: Cargados ", dlc_packs.size(), " packs DLC")
			
			# Comprobar si los DLCs ya están incluidos para evitar duplicados
			for dlc_pack in dlc_packs:
				var already_included = false
				for existing_pack in packs_data.packs:
					if existing_pack.id == dlc_pack.id:
						already_included = true
						break
				
				# Si no está incluido, añadirlo
				if not already_included:
					packs_data.packs.append(dlc_pack)
					print("ProgressManager: Añadido pack DLC: ", dlc_pack.id)
		
			# Inicializar la progresión para los nuevos packs
			for dlc_pack in dlc_packs:
				initialize_dlc_pack_progress(dlc_pack.id)
		else:
			print("ProgressManager: No se cargaron packs DLC (no hay packs verificados)")
	else:
		print("ProgressManager: No se encontró el archivo de packs DLC en: ", DLC_PACKS_DIR)
	
	return dlc_packs

# Inicializa la progresión de un pack DLC específico
func initialize_dlc_pack_progress(pack_id: String) -> void:
	if not progress_data.packs.has(pack_id):
		print("ProgressManager: Inicializando progresión para pack DLC: ", pack_id)
		
		# Buscar datos del pack en packs_data
		var pack_data = null
		if packs_data.has("packs"):
			for pack in packs_data.packs:
				if pack.id == pack_id:
					pack_data = pack
					break
		
		if pack_data:
			progress_data.packs[pack_id] = {
				"unlocked": pack_data.get("unlocked", true),  # Por defecto desbloqueado
				"purchased": pack_data.get("purchased", false), # Por defecto no comprado
				"completed": false,
				"puzzles": {}
			}
			
			# Si el pack está desbloqueado y comprado, desbloquear el primer puzzle
			if progress_data.packs[pack_id].unlocked and progress_data.packs[pack_id].purchased and pack_data.puzzles.size() > 0:
				progress_data.packs[pack_id].puzzles[pack_data.puzzles[0].id] = {
					"completed": false,
					"unlocked": true
				}
				
			save_progress_data()
			print("ProgressManager: Progresión inicializada para pack DLC: ", pack_id)
		else:
			print("ProgressManager: No se encontraron datos del pack DLC: ", pack_id)


# Comprueba si tenemos acceso a algún pack DLC específico
func has_dlc_access(pack_id: String) -> bool:
	return is_pack_purchased(pack_id) && is_pack_unlocked(pack_id)

# Devuelve una lista de todos los packs DLC comprados
func get_purchased_dlc_packs() -> Array:
	var purchased_dlcs = []
	
	for pack_id in progress_data.packs:
		if progress_data.packs[pack_id].purchased:
			# Verificar si es un pack DLC
			if packs_data.has("packs"):
				for pack in packs_data.packs:
					if pack.id == pack_id and pack.get("is_dlc", false):
						purchased_dlcs.append(pack_id)
						break
	
	return purchased_dlcs

# Actualiza y refresca los datos de los packs DLC
func refresh_dlc_packs() -> void:
	print("ProgressManager: Actualizando datos de packs DLC")
	
	# Verificar primero si tenemos el nodo GLOBAL
	if not has_node("/root/GLOBAL"):
		print("ProgressManager: No se encontró el nodo GLOBAL, no se pueden comprobar los DLCs")
		return
	
	# Cargar solo los packs DLC verificados
	var dlc_packs = load_dlc_packs()
	
	# Si hay packs DLC cargados, inicializar su progresión
	if dlc_packs.size() > 0:
		# Inicializar la progresión para los packs verificados
		for dlc_pack in dlc_packs:
			initialize_dlc_pack_progress(dlc_pack.id)

	else:
		print("ProgressManager: No hay packs DLC verificados para actualizar") 
