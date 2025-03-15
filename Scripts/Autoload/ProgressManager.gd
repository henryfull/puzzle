extends Node

# Constantes para el archivo de guardado
const SAVE_FILE = "user://progress.json"
const PACKS_DATA_FILE = "res://PacksData/sample_packs.json"

# Datos de progresión
var progress_data = {
	"packs": {}
}

# Datos de packs originales (desde el archivo JSON)
var packs_data = {}

func _ready():
	# Cargar los datos de progresión al iniciar
	load_progress_data()
	
	# Cargar los datos de packs desde el archivo JSON
	load_packs_data()
	
	# Inicializar la progresión si es necesario
	initialize_progress_if_needed()

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
	var file = FileAccess.open(PACKS_DATA_FILE, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json_result = JSON.parse_string(json_text)
		if json_result and json_result.has("packs"):
			packs_data = json_result
			print("ProgressManager: Datos de packs cargados correctamente")
		else:
			print("ProgressManager: Error al analizar el JSON de packs")
	else:
		print("ProgressManager: No se encontró el archivo de packs")

# Inicializa la progresión si es necesario
func initialize_progress_if_needed():
	# Si no hay datos de progresión o están vacíos, inicializarlos
	if not progress_data.has("packs") or progress_data.packs.is_empty():
		progress_data.packs = {}
		
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
	var packs_with_progress = []
	
	if packs_data.has("packs"):
		for pack in packs_data.packs:
			var pack_with_progress = get_pack_with_progress(pack.id)
			if not pack_with_progress.is_empty():
				packs_with_progress.append(pack_with_progress)
	
	return packs_with_progress

# Reinicia la progresión (para pruebas)
func reset_progress():
	progress_data = {
		"packs": {}
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