extends Node

signal packs_refreshed()
signal daily_challenge_progress_updated(challenge_key: String, entry: Dictionary)
signal rewards_inventory_updated(inventory: Dictionary)

# Constantes para el archivo de guardado
const SAVE_FILE = "user://progress.json"
const ROUTE_DLC = "res://dlc"
const PACKS_DATA_FILE = "res://PacksData/sample_packs.json"
const DLC_PACKS_DIR = ROUTE_DLC + "/dlc_metadata.json"
const LOCAL_DLC_BACKUP_PACKS_DIR = "res://dlc_backup_20250901_190152/packs"
var FREE_TO_PLAY_MODE := true
var REMOTE_CATALOG_SANDBOX_MODE := false
var _sandbox_remote_sync_in_flight := false

# Datos de progresión
var progress_data = {
	"packs": {},
	"statistics": {}, # Nueva sección para estadísticas de partidas
	"daily_challenges": {},
	"rewards": {
		"currencies": {},
		"cosmetics": {}
	}
}

# Datos de packs originales (desde el archivo JSON)
var packs_data = {}

func _ready():
	# Imprimir un mensaje de diagnóstico al inicio
	print("ProgressManager: Inicializando...")
	_load_runtime_flags()
	_connect_remote_catalog_service()
	
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
	
	# Limpiar historial existente (eliminamos esta funcionalidad)
	clean_existing_history()
	
	# Forzar carga de todos los DLCs disponibles
	force_load_all_dlcs()
	
	print("ProgressManager: Inicialización completada")
	
	# Debug: Imprimir información de todos los packs cargados
	debug_print_packs_info()

func _load_runtime_flags() -> void:
	if ProjectSettings.has_setting("commerce/free_to_play_mode"):
		FREE_TO_PLAY_MODE = bool(ProjectSettings.get_setting("commerce/free_to_play_mode"))
	if ProjectSettings.has_setting("commerce/remote_catalog_sandbox_mode"):
		REMOTE_CATALOG_SANDBOX_MODE = bool(ProjectSettings.get_setting("commerce/remote_catalog_sandbox_mode"))
	if REMOTE_CATALOG_SANDBOX_MODE:
		FREE_TO_PLAY_MODE = false
		print("ProgressManager: remote_catalog_sandbox_mode activo - solo packs base locales + catálogo remoto.")

func _connect_remote_catalog_service() -> void:
	var remote_catalog_service = _get_remote_catalog_service()
	if remote_catalog_service == null:
		return
	if not remote_catalog_service.catalog_updated.is_connected(_on_remote_catalog_updated):
		remote_catalog_service.catalog_updated.connect(_on_remote_catalog_updated)
	if not remote_catalog_service.entitlements_updated.is_connected(_on_remote_entitlements_updated):
		remote_catalog_service.entitlements_updated.connect(_on_remote_entitlements_updated)

func _on_remote_catalog_updated(_manifest: Dictionary) -> void:
	call_deferred("refresh_dlc_packs")

func _on_remote_entitlements_updated(_entitlements: Dictionary) -> void:
	call_deferred("refresh_dlc_packs")

# Función debug para imprimir información de los packs
func debug_print_packs_info():
	print("=== DEBUG: Información de packs cargados ===")
	if packs_data.has("packs"):
		for i in range(packs_data.packs.size()):
			var pack = packs_data.packs[i]
			print("Pack ", i + 1, ": ")
			print("  ID: ", pack.id)
			print("  Nombre: ", pack.name)
			print("  Desbloqueado: ", pack.get("unlocked", false))
			print("  Comprado: ", pack.get("purchased", false))
			print("  Puzzles: ", pack.puzzles.size() if pack.has("puzzles") else "Sin puzzles")
			print("  ---")
	else:
		print("ERROR: No se encontraron packs cargados")
	print("=== FIN DEBUG ===")

# Carga los datos de progresión desde el archivo de guardado
func load_progress_data():
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json_result = JSON.parse_string(json_text)
		if json_result:
			progress_data = json_result
			_ensure_progress_schema()
			print("ProgressManager: Datos de progresión cargados correctamente")
		else:
			print("ProgressManager: Error al analizar el JSON de progresión")
	else:
		print("ProgressManager: No se encontró archivo de progresión, se creará uno nuevo")
	_ensure_progress_schema()

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
	var dlc_file = null if REMOTE_CATALOG_SANDBOX_MODE else FileAccess.open(DLC_PACKS_DIR, FileAccess.READ)
	
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
	_ensure_progress_schema()

	# Si no hay datos de progresión o están vacíos, inicializarlos
	if not progress_data.has("packs") or progress_data.packs.is_empty():
		progress_data.packs = {}
	
	# Inicializar la sección de estadísticas si no existe
	if not progress_data.has("statistics"):
		progress_data.statistics = {}
	if not progress_data.has("daily_challenges"):
		progress_data.daily_challenges = {}
		
	# Asegurarse de que todos los packs del archivo JSON estén en los datos de progresión
	if packs_data.has("packs"):
		for pack in packs_data.packs:
			var pack_id = pack.id
			if FREE_TO_PLAY_MODE:
				pack["purchased"] = true
			_ensure_pack_progress_entry(pack_id, pack)
			_unlock_first_puzzle_if_needed(pack_id, pack)
	
	# Guardar para persistir migraciones/reconciliaciones
	save_progress_data()

func _ensure_pack_progress_entry(pack_id: String, pack_data: Dictionary) -> void:
	if not progress_data.has("packs"):
		progress_data["packs"] = {}
	
	if not progress_data.packs.has(pack_id):
		progress_data.packs[pack_id] = {
			"unlocked": pack_data.get("unlocked", false),
			"purchased": pack_data.get("purchased", false),
			"completed": pack_data.get("completed", false),
			"hidden_from_catalog": bool(pack_data.get("hidden_from_catalog", false)),
			"is_daily_challenge": bool(pack_data.get("is_daily_challenge", false)),
			"source_pack_id": str(pack_data.get("source_pack_id", "")),
			"puzzles": {}
		}
	
	if not progress_data.packs[pack_id].has("puzzles"):
		progress_data.packs[pack_id]["puzzles"] = {}
	if not progress_data.packs[pack_id].has("completed"):
		progress_data.packs[pack_id]["completed"] = false
	if not progress_data.packs[pack_id].has("unlocked"):
		progress_data.packs[pack_id]["unlocked"] = false
	if not progress_data.packs[pack_id].has("purchased"):
		progress_data.packs[pack_id]["purchased"] = false
	if not progress_data.packs[pack_id].has("hidden_from_catalog"):
		progress_data.packs[pack_id]["hidden_from_catalog"] = false
	if not progress_data.packs[pack_id].has("is_daily_challenge"):
		progress_data.packs[pack_id]["is_daily_challenge"] = false
	if not progress_data.packs[pack_id].has("source_pack_id"):
		progress_data.packs[pack_id]["source_pack_id"] = ""
	
	# Nunca degradar flags ya activados en progreso
	progress_data.packs[pack_id]["unlocked"] = progress_data.packs[pack_id].get("unlocked", false) or pack_data.get("unlocked", false)
	progress_data.packs[pack_id]["purchased"] = progress_data.packs[pack_id].get("purchased", false) or pack_data.get("purchased", false)
	progress_data.packs[pack_id]["hidden_from_catalog"] = progress_data.packs[pack_id].get("hidden_from_catalog", false) or bool(pack_data.get("hidden_from_catalog", false))
	progress_data.packs[pack_id]["is_daily_challenge"] = progress_data.packs[pack_id].get("is_daily_challenge", false) or bool(pack_data.get("is_daily_challenge", false))
	var source_pack_id := str(pack_data.get("source_pack_id", ""))
	if source_pack_id != "":
		progress_data.packs[pack_id]["source_pack_id"] = source_pack_id
	
	if FREE_TO_PLAY_MODE:
		progress_data.packs[pack_id]["purchased"] = true

func _ensure_progress_schema() -> void:
	if typeof(progress_data) != TYPE_DICTIONARY:
		progress_data = {}
	if not progress_data.has("packs") or typeof(progress_data.get("packs", {})) != TYPE_DICTIONARY:
		progress_data["packs"] = {}
	if not progress_data.has("statistics") or typeof(progress_data.get("statistics", {})) != TYPE_DICTIONARY:
		progress_data["statistics"] = {}
	if not progress_data.has("daily_challenges") or typeof(progress_data.get("daily_challenges", {})) != TYPE_DICTIONARY:
		progress_data["daily_challenges"] = {}
	if not progress_data.has("rewards") or typeof(progress_data.get("rewards", {})) != TYPE_DICTIONARY:
		progress_data["rewards"] = {}
	if not progress_data.rewards.has("currencies") or typeof(progress_data.rewards.get("currencies", {})) != TYPE_DICTIONARY:
		progress_data.rewards["currencies"] = {}
	if not progress_data.rewards.has("cosmetics") or typeof(progress_data.rewards.get("cosmetics", {})) != TYPE_DICTIONARY:
		progress_data.rewards["cosmetics"] = {}

func _unlock_first_puzzle_if_needed(pack_id: String, pack_data: Dictionary) -> void:
	if not progress_data.packs.has(pack_id):
		return
	if not pack_data.has("puzzles") or pack_data.puzzles.size() == 0:
		return
	if not progress_data.packs[pack_id].get("unlocked", false) or not progress_data.packs[pack_id].get("purchased", false):
		return
	
	var first_puzzle_id = str(pack_data.puzzles[0].id)
	if not progress_data.packs[pack_id].puzzles.has(first_puzzle_id):
		progress_data.packs[pack_id].puzzles[first_puzzle_id] = {
			"completed": false,
			"unlocked": true
		}
	else:
		progress_data.packs[pack_id].puzzles[first_puzzle_id]["unlocked"] = true
		if not progress_data.packs[pack_id].puzzles[first_puzzle_id].has("completed"):
			progress_data.packs[pack_id].puzzles[first_puzzle_id]["completed"] = false

func _find_pack_index(pack_id: String) -> int:
	if not packs_data.has("packs"):
		return -1
	for i in range(packs_data.packs.size()):
		if packs_data.packs[i].id == pack_id:
			return i
	return -1

func is_remote_catalog_sandbox_mode() -> bool:
	return REMOTE_CATALOG_SANDBOX_MODE

func _extract_filename(path: String) -> String:
	if path.is_empty():
		return ""
	return path.get_file()

func _path_exists_any(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("user://"):
		return FileAccess.file_exists(path)
	return ResourceLoader.exists(path)

func _resolve_pack_asset_path(pack_id: String, original_path: String, source_pack_file_path: String) -> String:
	if original_path.is_empty():
		return original_path
	
	if _path_exists_any(original_path):
		return original_path
	
	var file_name = _extract_filename(original_path)
	if file_name.is_empty():
		return original_path
	
	var candidates: Array[String] = []
	
	# Relativo al origen del JSON cargado
	var source_base_dir = source_pack_file_path.get_base_dir()
	if not source_base_dir.is_empty():
		candidates.append(source_base_dir + "/" + file_name)
		if source_pack_file_path.begins_with("user://"):
			candidates.append(source_base_dir + "/" + pack_id + "/" + file_name)
	
	# Rutas conocidas del proyecto
	candidates.append("user://dlc/packs/" + pack_id + "/" + file_name)
	candidates.append("res://dlc/packs/" + pack_id + "/" + file_name)
	candidates.append(LOCAL_DLC_BACKUP_PACKS_DIR + "/" + pack_id + "/" + file_name)
	
	for candidate in candidates:
		if _path_exists_any(candidate):
			return candidate
	
	return original_path

func _get_remote_catalog_service() -> Node:
	return get_node_or_null("/root/RemoteCatalogService")

func _get_localized_catalog_text(value, fallback: String) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var locale := TranslationServer.get_locale().to_lower()
		var language := locale.split("_")[0]
		if value.has(locale):
			return str(value[locale])
		if value.has(language):
			return str(value[language])
		if value.has("es"):
			return str(value["es"])
		if value.has("en"):
			return str(value["en"])
	elif typeof(value) == TYPE_STRING:
		return str(value)
	return fallback

func _resolve_localized_content_text(value, fallback: String) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		return _get_localized_catalog_text(value, fallback)
	if typeof(value) == TYPE_STRING:
		var raw_value := str(value)
		if raw_value == "":
			return fallback
		var translated_value := TranslationServer.translate(raw_value)
		return translated_value if translated_value.strip_edges() != "" else raw_value
	return fallback

func _apply_localized_fields_to_pack(pack_data: Dictionary) -> void:
	if pack_data.has("name_localized"):
		pack_data["name"] = _resolve_localized_content_text(pack_data.get("name_localized", {}), str(pack_data.get("name", "")))
	if pack_data.has("description_localized"):
		pack_data["description"] = _resolve_localized_content_text(pack_data.get("description_localized", {}), str(pack_data.get("description", "")))

	if not pack_data.has("puzzles") or typeof(pack_data.get("puzzles", [])) != TYPE_ARRAY:
		return

	for i in range(pack_data.puzzles.size()):
		var puzzle = pack_data.puzzles[i]
		if typeof(puzzle) != TYPE_DICTIONARY:
			continue
		if puzzle.has("name_localized"):
			pack_data.puzzles[i]["name"] = _resolve_localized_content_text(puzzle.get("name_localized", {}), str(puzzle.get("name", "")))
		if puzzle.has("description_localized"):
			pack_data.puzzles[i]["description"] = _resolve_localized_content_text(puzzle.get("description_localized", {}), str(puzzle.get("description", "")))
		if puzzle.has("story_localized"):
			var resolved_story := _resolve_localized_content_text(puzzle.get("story_localized", {}), str(puzzle.get("story", puzzle.get("description", ""))))
			pack_data.puzzles[i]["story"] = resolved_story
			pack_data.puzzles[i]["description"] = resolved_story
		elif puzzle.has("story"):
			var translated_story := _resolve_localized_content_text(puzzle.get("story", ""), str(puzzle.get("description", "")))
			pack_data.puzzles[i]["story"] = translated_story
			pack_data.puzzles[i]["description"] = translated_story

func _load_embedded_base_packs_manifest() -> Dictionary:
	if not FileAccess.file_exists(PACKS_DATA_FILE):
		return {}
	var file := FileAccess.open(PACKS_DATA_FILE, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _restore_embedded_base_packs() -> void:
	var embedded_manifest := _load_embedded_base_packs_manifest()
	if typeof(embedded_manifest) != TYPE_DICTIONARY or not embedded_manifest.has("packs"):
		return

	for base_pack in embedded_manifest.get("packs", []):
		if typeof(base_pack) != TYPE_DICTIONARY:
			continue
		var base_pack_id := str(base_pack.get("id", ""))
		if base_pack_id == "":
			continue
		_register_dlc_metadata_pack(base_pack.duplicate(true))

func _prune_sandbox_catalog_packs(allowed_remote_pack_ids: Array) -> void:
	if not packs_data.has("packs"):
		return

	var allowed_lookup := {}
	for pack_id in allowed_remote_pack_ids:
		var normalized_pack_id := str(pack_id)
		if normalized_pack_id != "":
			allowed_lookup[normalized_pack_id] = true

	var filtered_packs: Array = []
	for pack in packs_data.packs:
		if typeof(pack) != TYPE_DICTIONARY:
			continue
		var pack_id := str(pack.get("id", ""))
		var is_dlc_pack := bool(pack.get("is_dlc", false))
		var is_remote_pack := bool(pack.get("remote_catalog", false))
		if not is_dlc_pack:
			filtered_packs.append(pack)
			continue
		if is_remote_pack and allowed_lookup.has(pack_id):
			filtered_packs.append(pack)
			continue
		if bool(pack.get("hidden_from_catalog", false)) or bool(pack.get("is_daily_challenge", false)):
			filtered_packs.append(pack)
			continue
		print("ProgressManager: Eliminando pack sandbox no permitido del catálogo: ", pack_id)

	packs_data.packs = filtered_packs

func _is_current_sandbox_catalog_snapshot(catalog_manifest: Dictionary) -> bool:
	if catalog_manifest.is_empty():
		return false
	var remote_catalog_service = _get_remote_catalog_service()
	if remote_catalog_service != null and remote_catalog_service.has_method("uses_backend_api") and not remote_catalog_service.uses_backend_api():
		return true
	var viewer = catalog_manifest.get("viewer", {})
	if typeof(viewer) != TYPE_DICTIONARY:
		return false
	if remote_catalog_service == null or not remote_catalog_service.has_method("get_app_user_id"):
		return false
	return str(viewer.get("app_user_id", "")).strip_edges() == str(remote_catalog_service.get_app_user_id()).strip_edges()

func _request_sandbox_remote_refresh() -> void:
	if _sandbox_remote_sync_in_flight:
		return
	var remote_catalog_service = _get_remote_catalog_service()
	if remote_catalog_service == null or not remote_catalog_service.has_remote_catalog():
		print("ProgressManager: Sandbox remoto requiere catálogo remoto configurado.")
		return
	_sandbox_remote_sync_in_flight = true
	call_deferred("_run_sandbox_remote_refresh")

func _run_sandbox_remote_refresh() -> void:
	var remote_catalog_service = _get_remote_catalog_service()
	if remote_catalog_service == null or not remote_catalog_service.has_remote_catalog():
		_sandbox_remote_sync_in_flight = false
		return
	await remote_catalog_service.fetch_catalog_manifest(true)
	await remote_catalog_service.fetch_entitlements(true)
	_sandbox_remote_sync_in_flight = false

func _get_sandbox_accessible_pack_ids() -> Array:
	var remote_catalog_service = _get_remote_catalog_service()
	if remote_catalog_service == null or not remote_catalog_service.has_remote_catalog():
		return []
	var catalog_manifest = remote_catalog_service.get_catalog_manifest()
	if catalog_manifest.is_empty():
		return []
	if remote_catalog_service.has_method("get_accessible_pack_ids"):
		return remote_catalog_service.get_accessible_pack_ids(catalog_manifest)
	if remote_catalog_service.has_method("get_catalog_pack_ids"):
		return remote_catalog_service.get_catalog_pack_ids(catalog_manifest)
	return []

func _register_dlc_metadata_pack(metadata_pack: Dictionary) -> void:
	if not packs_data.has("packs"):
		packs_data["packs"] = []

	var pack_id := str(metadata_pack.get("id", ""))
	if pack_id == "":
		return

	for i in range(packs_data.packs.size()):
		if str(packs_data.packs[i].get("id", "")) != pack_id:
			continue
		for key in metadata_pack.keys():
			var value = metadata_pack[key]
			if key == "puzzles" and typeof(value) == TYPE_ARRAY:
				var existing_puzzles = packs_data.packs[i].get("puzzles", [])
				if typeof(existing_puzzles) == TYPE_ARRAY and existing_puzzles.size() > 0 and value.is_empty():
					continue
			if key == "image_path" and str(value) == "" and str(packs_data.packs[i].get("image_path", "")) != "":
				continue
			packs_data.packs[i][key] = value
		return

	packs_data.packs.append(metadata_pack)

func _is_remote_catalog_pack(pack_id: String) -> bool:
	var pack_index := _find_pack_index(pack_id)
	if pack_index < 0:
		return false
	return bool(packs_data.packs[pack_index].get("remote_catalog", false))

func register_runtime_pack(pack_data: Dictionary) -> Dictionary:
	if pack_data.is_empty():
		return {}

	var normalized_pack := pack_data.duplicate(true)
	var pack_id := str(normalized_pack.get("id", ""))
	if pack_id == "":
		return {}

	normalized_pack["is_dlc"] = true
	_register_dlc_metadata_pack(normalized_pack)
	_ensure_pack_progress_entry(pack_id, normalized_pack)
	_unlock_first_puzzle_if_needed(pack_id, normalized_pack)
	save_progress_data()
	return get_pack_with_progress(pack_id)

func get_daily_challenge_key(source) -> String:
	if typeof(source) == TYPE_DICTIONARY:
		var source_dict: Dictionary = source
		var date_key := str(source_dict.get("daily_challenge_date", source_dict.get("date", ""))).strip_edges()
		if date_key != "":
			return date_key

		var explicit_key := str(source_dict.get("daily_challenge_key", source_dict.get("challenge_id", source_dict.get("id", "")))).strip_edges()
		if explicit_key != "":
			return explicit_key

		return str(source_dict.get("pack_id", source_dict.get("source_pack_id", ""))).strip_edges()

	return str(source).strip_edges()

func get_daily_challenge_progress(challenge_key: String) -> Dictionary:
	_ensure_progress_schema()
	if challenge_key == "":
		return {}
	if not progress_data.daily_challenges.has(challenge_key):
		return {}
	return progress_data.daily_challenges[challenge_key].duplicate(true)

func has_completed_daily_challenge(challenge_key: String) -> bool:
	var entry := get_daily_challenge_progress(challenge_key)
	return bool(entry.get("completed", false))

func record_daily_challenge_completion_from_pack(pack_data: Dictionary, stats: Dictionary = {}) -> Dictionary:
	if pack_data.is_empty() or not bool(pack_data.get("is_daily_challenge", false)):
		return {}

	var challenge_key := get_daily_challenge_key(pack_data)
	if challenge_key == "":
		challenge_key = Time.get_date_string_from_system()

	return record_daily_challenge_completion(challenge_key, pack_data, stats)

func record_daily_challenge_completion(challenge_key: String, metadata: Dictionary = {}, stats: Dictionary = {}) -> Dictionary:
	_ensure_progress_schema()
	if challenge_key == "":
		return {}

	var entry := get_daily_challenge_progress(challenge_key)
	entry["challenge_key"] = challenge_key
	entry["date"] = str(metadata.get("daily_challenge_date", metadata.get("date", challenge_key)))
	entry["challenge_id"] = str(metadata.get("daily_challenge_id", metadata.get("challenge_id", challenge_key)))
	entry["title"] = str(metadata.get("daily_challenge_title", metadata.get("title", "")))
	entry["pack_id"] = str(stats.get("pack_id", metadata.get("id", "")))
	entry["source_pack_id"] = str(metadata.get("source_pack_id", metadata.get("pack_id", "")))
	entry["puzzle_id"] = str(stats.get("puzzle_id", metadata.get("puzzle_id", "")))
	entry["completed"] = true
	entry["completed_at"] = Time.get_datetime_string_from_system()
	entry["completion_count"] = int(entry.get("completion_count", 0)) + 1
	entry["reward_claimed"] = bool(entry.get("reward_claimed", false))
	var reward_payload = _extract_reward_payload(metadata)
	if not reward_payload.is_empty():
		entry["reward"] = reward_payload

	var elapsed_time := float(stats.get("elapsed_time", stats.get("completion_time", 0.0)))
	if elapsed_time > 0.0:
		entry["last_elapsed_time"] = elapsed_time
		var best_time := float(entry.get("best_time", 0.0))
		if best_time <= 0.0 or elapsed_time < best_time:
			entry["best_time"] = elapsed_time

	var total_moves := int(stats.get("moves", stats.get("total_moves", 0)))
	if total_moves > 0:
		entry["last_moves"] = total_moves
		var best_moves := int(entry.get("best_moves", 0))
		if best_moves <= 0 or total_moves < best_moves:
			entry["best_moves"] = total_moves

	var flip_count := int(stats.get("flips", stats.get("flip_uses", 0)))
	if flip_count > 0:
		entry["last_flips"] = flip_count

	var flip_move_count := int(stats.get("flip_moves", 0))
	if flip_move_count > 0:
		entry["last_flip_moves"] = flip_move_count

	var final_score := int(stats.get("final_score", stats.get("score", 0)))
	entry["last_score"] = final_score
	if final_score > int(entry.get("best_score", 0)):
		entry["best_score"] = final_score

	var max_streak := int(stats.get("max_streak", 0))
	if max_streak > 0:
		entry["last_max_streak"] = max_streak
		if max_streak > int(entry.get("best_max_streak", 0)):
			entry["best_max_streak"] = max_streak

	progress_data.daily_challenges[challenge_key] = entry.duplicate(true)
	save_progress_data()
	daily_challenge_progress_updated.emit(challenge_key, entry.duplicate(true))
	return entry

func mark_daily_challenge_reward_claimed(challenge_key: String, reward_data: Dictionary = {}) -> Dictionary:
	_ensure_progress_schema()
	if challenge_key == "":
		return {}

	var entry := get_daily_challenge_progress(challenge_key)
	if entry.is_empty():
		entry["challenge_key"] = challenge_key
		entry["date"] = challenge_key

	entry["reward_claimed"] = true
	entry["reward_claimed_at"] = Time.get_datetime_string_from_system()
	if not reward_data.is_empty():
		entry["reward"] = reward_data.duplicate(true)

	progress_data.daily_challenges[challenge_key] = entry.duplicate(true)
	save_progress_data()
	daily_challenge_progress_updated.emit(challenge_key, entry.duplicate(true))
	return entry

func claim_daily_challenge_reward(challenge_key: String, reward_data: Dictionary = {}) -> Dictionary:
	_ensure_progress_schema()
	if challenge_key == "":
		return {"ok": false, "reason": "missing_challenge_key"}

	var entry := get_daily_challenge_progress(challenge_key)
	if entry.is_empty() or not bool(entry.get("completed", false)):
		return {"ok": false, "reason": "challenge_not_completed"}
	if bool(entry.get("reward_claimed", false)):
		return {
			"ok": false,
			"reason": "reward_already_claimed",
			"entry": entry,
			"inventory": get_rewards_inventory()
		}

	var resolved_reward := reward_data.duplicate(true)
	if resolved_reward.is_empty():
		resolved_reward = _extract_reward_payload(entry)

	var applied_reward := _apply_reward_payload(resolved_reward)
	entry["reward_claimed"] = true
	entry["reward_claimed_at"] = Time.get_datetime_string_from_system()
	entry["reward"] = resolved_reward
	entry["claimed_reward"] = applied_reward
	progress_data.daily_challenges[challenge_key] = entry.duplicate(true)
	save_progress_data()
	daily_challenge_progress_updated.emit(challenge_key, entry.duplicate(true))
	rewards_inventory_updated.emit(get_rewards_inventory())
	return {
		"ok": true,
		"entry": entry.duplicate(true),
		"inventory": get_rewards_inventory(),
		"applied_reward": applied_reward
	}

func get_rewards_inventory() -> Dictionary:
	_ensure_progress_schema()
	return progress_data.rewards.duplicate(true)

func replace_rewards_inventory(snapshot: Dictionary) -> Dictionary:
	_ensure_progress_schema()
	if typeof(snapshot) != TYPE_DICTIONARY:
		return get_rewards_inventory()

	var normalized_inventory := {
		"currencies": {},
		"cosmetics": {}
	}

	var currencies = snapshot.get("currencies", {})
	if typeof(currencies) == TYPE_DICTIONARY:
		for currency_id in currencies.keys():
			var normalized_currency_id := str(currency_id).strip_edges()
			if normalized_currency_id == "":
				continue
			normalized_inventory["currencies"][normalized_currency_id] = int(currencies[currency_id])

	var cosmetics = snapshot.get("cosmetics", {})
	if typeof(cosmetics) == TYPE_DICTIONARY:
		for cosmetic_id in cosmetics.keys():
			var normalized_cosmetic_id := str(cosmetic_id).strip_edges()
			var cosmetic_payload = cosmetics[cosmetic_id]
			if normalized_cosmetic_id == "" or typeof(cosmetic_payload) != TYPE_DICTIONARY:
				continue
			normalized_inventory["cosmetics"][normalized_cosmetic_id] = (cosmetic_payload as Dictionary).duplicate(true)

	progress_data["rewards"] = normalized_inventory
	save_progress_data()
	rewards_inventory_updated.emit(get_rewards_inventory())
	return get_rewards_inventory()

func get_currency_balance(currency_id: String) -> int:
	_ensure_progress_schema()
	if currency_id == "":
		return 0
	return int(progress_data.rewards.currencies.get(currency_id, 0))

func has_owned_cosmetic(cosmetic_id: String) -> bool:
	_ensure_progress_schema()
	if cosmetic_id == "":
		return false
	return progress_data.rewards.cosmetics.has(cosmetic_id)

func _extract_reward_payload(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	var reward = source.get("daily_challenge_reward", source.get("reward", {}))
	return reward.duplicate(true) if typeof(reward) == TYPE_DICTIONARY else {}

func _apply_reward_payload(reward_data: Dictionary) -> Dictionary:
	_ensure_progress_schema()
	var applied := {
		"currencies": {},
		"cosmetics": [],
		"duplicate_cosmetics": []
	}

	if reward_data.is_empty():
		return applied

	var currencies = reward_data.get("currencies", {})
	if typeof(currencies) == TYPE_DICTIONARY:
		for currency_id in currencies.keys():
			var normalized_currency_id := str(currency_id).strip_edges()
			var amount := int(currencies[currency_id])
			if normalized_currency_id == "" or amount == 0:
				continue
			progress_data.rewards.currencies[normalized_currency_id] = int(progress_data.rewards.currencies.get(normalized_currency_id, 0)) + amount
			applied["currencies"][normalized_currency_id] = amount

	var cosmetics = reward_data.get("cosmetics", [])
	if typeof(cosmetics) == TYPE_ARRAY:
		for cosmetic_entry in cosmetics:
			var cosmetic_payload := {}
			if typeof(cosmetic_entry) == TYPE_STRING:
				cosmetic_payload = {"id": str(cosmetic_entry)}
			elif typeof(cosmetic_entry) == TYPE_DICTIONARY:
				cosmetic_payload = (cosmetic_entry as Dictionary).duplicate(true)
			else:
				continue

			var cosmetic_id := str(cosmetic_payload.get("id", "")).strip_edges()
			if cosmetic_id == "":
				continue

			if progress_data.rewards.cosmetics.has(cosmetic_id):
				applied["duplicate_cosmetics"].append(cosmetic_id)
				continue

			cosmetic_payload["owned"] = true
			cosmetic_payload["unlocked_at"] = Time.get_datetime_string_from_system()
			cosmetic_payload["source"] = str(cosmetic_payload.get("source", "daily_challenge"))
			progress_data.rewards.cosmetics[cosmetic_id] = cosmetic_payload
			applied["cosmetics"].append(cosmetic_payload.duplicate(true))

	return applied

# Verifica si un pack está desbloqueado
func is_pack_unlocked(pack_id: String) -> bool:
	if progress_data.packs.has(pack_id):
		return progress_data.packs[pack_id].unlocked
	return false

# Verifica si un pack ha sido comprado
func is_pack_purchased(pack_id: String) -> bool:
	if FREE_TO_PLAY_MODE:
		return true
	if progress_data.packs.has(pack_id):
		return progress_data.packs[pack_id].purchased
	return false

# Verifica si un pack está disponible para jugar (desbloqueado y comprado)
func is_pack_available(pack_id: String) -> bool:
	if FREE_TO_PLAY_MODE:
		return is_pack_unlocked(pack_id)
	return is_pack_unlocked(pack_id) and is_pack_purchased(pack_id)

func is_free_to_play_mode() -> bool:
	return FREE_TO_PLAY_MODE

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
				if pack.has("puzzles"):
					for j in range(pack.puzzles.size()):
						if pack.puzzles[j].id == puzzle_id:
							current_puzzle_index = j
							next_puzzle_index = j + 1
							break
				break
	
	print("ProgressManager: Índices - Pack: " + str(current_pack_index) + ", Puzzle actual: " + str(current_puzzle_index) + ", Siguiente puzzle: " + str(next_puzzle_index))
	
	# Si hay un siguiente puzzle, desbloquearlo
	if current_pack_index >= 0 and next_puzzle_index >= 0 and packs_data.packs[current_pack_index].has("puzzles") and next_puzzle_index < packs_data.packs[current_pack_index].puzzles.size():
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
		if not _is_non_catalog_pack(pack_id):
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
		if progress_data.packs[next_pack_id].purchased and packs_data.packs[next_pack_index].has("puzzles") and packs_data.packs[next_pack_index].puzzles.size() > 0:
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
				if pack_data.has("puzzles"):
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
				else:
					print("ProgressManager: El pack " + pack_id + " no tiene puzzles cargados (posible DLC no comprado)")

				_apply_localized_fields_to_pack(pack_data)
				break
	
	return pack_data

# Obtiene todos los packs con información de progresión
func get_all_packs_with_progress() -> Array:
	print("ProgressManager: get_all_packs_with_progress() - Obteniendo todos los packs con progresión")
	var packs_with_progress = []
	var sandbox_allowed_lookup := {}
	if REMOTE_CATALOG_SANDBOX_MODE:
		for allowed_pack_id in _get_sandbox_accessible_pack_ids():
			var normalized_allowed_pack_id := str(allowed_pack_id)
			if normalized_allowed_pack_id != "":
				sandbox_allowed_lookup[normalized_allowed_pack_id] = true
	
	if packs_data.has("packs"):
		print("ProgressManager: Número de packs en packs_data: ", packs_data.packs.size())
		for pack in packs_data.packs:
			if bool(pack.get("hidden_from_catalog", false)):
				continue
			if REMOTE_CATALOG_SANDBOX_MODE and bool(pack.get("is_dlc", false)) and not sandbox_allowed_lookup.has(str(pack.get("id", ""))):
				continue
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
		"statistics": {},
		"daily_challenges": {},
		"rewards": {
			"currencies": {},
			"cosmetics": {}
		}
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
			if pack.has("puzzles"):
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
	if current_pack.has("puzzles") and current_puzzle_index + 1 < current_pack.puzzles.size():
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
			"best_score": 0,
			"best_score_date": ""
		}
	
	# Asegurar que todas las propiedades necesarias existen
	if not progress_data.statistics[pack_id][puzzle_id][difficulty_key].has("best_flips"):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flips"] = 99999
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flips_date"] = ""
	
	if not progress_data.statistics[pack_id][puzzle_id][difficulty_key].has("best_flip_moves"):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flip_moves"] = 99999
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_flip_moves_date"] = ""
	
	# Asegurar que el campo best_score existe (nuevo sistema de puntuación)
	if not progress_data.statistics[pack_id][puzzle_id][difficulty_key].has("best_score"):
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_score"] = 0
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_score_date"] = ""
	
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
	
	# Estadística para puntuación (mayor es mejor)
	if stats.has("score") and stats.score > progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_score"]:
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_score"] = stats.score
		progress_data.statistics[pack_id][puzzle_id][difficulty_key]["best_score_date"] = stats.date
	
	# Ya no guardamos historial de partidas - solo los mejores resultados
	save_progress_data()

# Función para limpiar historial existente de los datos guardados
func clean_existing_history():
	"""Elimina el historial existente de todas las estadísticas guardadas"""
	print("ProgressManager: Limpiando historial existente...")
	var cleaned_count = 0
	
	for pack_id in progress_data.statistics.keys():
		for puzzle_id in progress_data.statistics[pack_id].keys():
			for difficulty_key in progress_data.statistics[pack_id][puzzle_id].keys():
				var stats = progress_data.statistics[pack_id][puzzle_id][difficulty_key]
				if stats.has("history"):
					stats.erase("history")
					cleaned_count += 1
	
	if cleaned_count > 0:
		print("ProgressManager: Eliminado historial de ", cleaned_count, " dificultades")
		save_progress_data()
	else:
		print("ProgressManager: No se encontró historial para limpiar")

# Nueva función para obtener estadísticas de un puzzle
func get_puzzle_stats(pack_id: String, puzzle_id: String) -> Dictionary:
	var stats = {}
	
	if progress_data.statistics.has(pack_id) and progress_data.statistics[pack_id].has(puzzle_id):
		stats = progress_data.statistics[pack_id][puzzle_id].duplicate(true)
		
		# Migrar estadísticas antiguas automáticamente
		_ensure_stats_migration(stats)
		
		# Asegurar que todas las dificultades tienen las propiedades nuevas
		for difficulty_key in stats.keys():
			if not stats[difficulty_key].has("best_flips"):
				stats[difficulty_key]["best_flips"] = 99999
				stats[difficulty_key]["best_flips_date"] = ""
			if not stats[difficulty_key].has("best_flip_moves"):
				stats[difficulty_key]["best_flip_moves"] = 99999
				stats[difficulty_key]["best_flip_moves_date"] = ""
			if not stats[difficulty_key].has("best_score"):
				stats[difficulty_key]["best_score"] = 0
				stats[difficulty_key]["best_score_date"] = ""
				print("ProgressManager: Inicializando best_score para dificultad ", difficulty_key)
	
	return stats

# Nueva función para migrar estadísticas antiguas
func _ensure_stats_migration(stats: Dictionary):
	"""Asegura que todas las estadísticas tengan los campos nuevos"""
	for difficulty_key in stats.keys():
		var difficulty_stats = stats[difficulty_key]
		
		# Asegurar campos de puntuación (nuevo)
		if not difficulty_stats.has("best_score"):
			difficulty_stats["best_score"] = 0
			difficulty_stats["best_score_date"] = ""
			print("ProgressManager: Migrado best_score para dificultad ", difficulty_key)
		
		# Asegurar otros campos si no existen
		if not difficulty_stats.has("best_flips"):
			difficulty_stats["best_flips"] = 99999
			difficulty_stats["best_flips_date"] = ""
		
		if not difficulty_stats.has("best_flip_moves"):
			difficulty_stats["best_flip_moves"] = 99999
			difficulty_stats["best_flip_moves_date"] = ""

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
					
					# Sumar estadísticas basadas en los mejores resultados y número de completados
					if puzzle_stats.has("best_time") and puzzle_stats["best_time"] < 99999:
						player_stats["total_time_played"] += puzzle_stats["best_time"] * puzzle_stats["completions"]
					if puzzle_stats.has("best_moves") and puzzle_stats["best_moves"] < 99999:
						player_stats["total_moves"] += puzzle_stats["best_moves"] * puzzle_stats["completions"]
	
	# Contar packs completados
	for pack_id in progress_data.packs.keys():
		if _is_non_catalog_pack(pack_id):
			continue
		if progress_data.packs[pack_id].has("completed") and progress_data.packs[pack_id]["completed"]:
			player_stats["packs_completed"] += 1

	return player_stats

func _is_non_catalog_pack(pack_id: String) -> bool:
	if progress_data.has("packs") and progress_data.packs.has(pack_id):
		var pack_progress = progress_data.packs[pack_id]
		if bool(pack_progress.get("hidden_from_catalog", false)) or bool(pack_progress.get("is_daily_challenge", false)):
			return true

	var pack_index := _find_pack_index(pack_id)
	if pack_index < 0:
		return false

	var pack_data = packs_data.packs[pack_index]
	return bool(pack_data.get("hidden_from_catalog", false)) or bool(pack_data.get("is_daily_challenge", false))

# Funciones para gestionar packs DLC
# ----------------------------------

# Función para cargar solo DLCs comprados (verificar entitlements)
func force_load_all_dlcs():
	if REMOTE_CATALOG_SANDBOX_MODE:
		print("ProgressManager: Sandbox remoto activo - usando solo acceso remoto simulado.")
		_restore_embedded_base_packs()
		var sandbox_pack_ids: Array = []
		var remote_catalog_service = _get_remote_catalog_service()
		if remote_catalog_service == null or not remote_catalog_service.has_remote_catalog():
			print("ProgressManager: Sandbox remoto sin catálogo configurado. Se mostrarán solo packs base locales.")
			_prune_sandbox_catalog_packs([])
			load_dlc_metadata()
			_sync_active_dlc_state([])
			return
		if remote_catalog_service:
			var catalog_manifest = remote_catalog_service.get_catalog_manifest()
			if _is_current_sandbox_catalog_snapshot(catalog_manifest):
				sandbox_pack_ids = _get_sandbox_accessible_pack_ids()
			else:
				print("ProgressManager: Cache remoto sandbox vacío o no sincronizado. Esperando catálogo fresco.")
				_request_sandbox_remote_refresh()
		_prune_sandbox_catalog_packs(sandbox_pack_ids)
		load_dlc_metadata()
		_sync_active_dlc_state(sandbox_pack_ids)
		load_purchased_dlc_content(sandbox_pack_ids)
		return

	if FREE_TO_PLAY_MODE:
		print("ProgressManager: Modo gratuito activo - cargando todo el contenido sin compras")
		load_dlc_metadata()
		var free_pack_ids = get_all_available_dlc_ids()
		load_purchased_dlc_content(free_pack_ids)
		return
	
	var purchased_dlcs = []
	
	# Fallback local SIEMPRE, incluso cuando falle red/entitlements
	var local_dlcs = get_locally_verified_dlcs()
	for local_pack_id in local_dlcs:
		if local_pack_id not in purchased_dlcs:
			purchased_dlcs.append(local_pack_id)
	
	print("ProgressManager: Packs DLC combinados (remote+local): ", purchased_dlcs)
	
	# Cargar metadatos de todos los DLCs disponibles
	load_dlc_metadata()
	_sync_active_dlc_state(purchased_dlcs)
	
	# Solo cargar contenido para packs comprados
	load_purchased_dlc_content(purchased_dlcs)

# Obtener todos los IDs de DLC disponibles
func get_all_available_dlc_ids() -> Array:
	var all_dlc_ids = []
	if not REMOTE_CATALOG_SANDBOX_MODE:
		var new_base_file = FileAccess.open("res://dlc/new_base_packs.json", FileAccess.READ)
		if new_base_file:
			var json_text = new_base_file.get_as_text()
			new_base_file.close()
			var json_result = JSON.parse_string(json_text)

			if json_result and json_result.has("packs"):
				for pack in json_result.packs:
					if pack.has("id"):
						all_dlc_ids.append(pack.id)

	var remote_catalog_service = _get_remote_catalog_service()
	if remote_catalog_service:
		var catalog_manifest = remote_catalog_service.get_catalog_manifest()
		var remote_pack_ids: Array = []
		if FREE_TO_PLAY_MODE and remote_catalog_service.has_method("get_catalog_pack_ids"):
			remote_pack_ids = remote_catalog_service.get_catalog_pack_ids(catalog_manifest)
		elif remote_catalog_service.has_method("get_accessible_pack_ids"):
			remote_pack_ids = remote_catalog_service.get_accessible_pack_ids(catalog_manifest)
		for pack_id in remote_pack_ids:
			var normalized_pack_id := str(pack_id)
			if normalized_pack_id != "" and normalized_pack_id not in all_dlc_ids:
				all_dlc_ids.append(normalized_pack_id)
	
	return all_dlc_ids

# Verificación local de DLCs (fallback)
func get_locally_verified_dlcs() -> Array:
	if REMOTE_CATALOG_SANDBOX_MODE:
		return []

	var local_dlcs = []
	
	# Verificar en GLOBAL.dlc_packs
	if has_node("/root/GLOBAL"):
		var global_node = get_node("/root/GLOBAL")
		if global_node.has_method("get") and global_node.get("dlc_packs"):
			local_dlcs = global_node.dlc_packs.duplicate()
	
	# También verificar en metadata local
	var metadata_file = FileAccess.open("user://dlc/dlc_metadata.json", FileAccess.READ)
	if metadata_file:
		var json_text = metadata_file.get_as_text()
		metadata_file.close()
		var metadata = JSON.parse_string(json_text)
		if metadata and metadata.has("entitled_packs"):
			for pack_id in metadata.entitled_packs:
				if pack_id not in local_dlcs:
					local_dlcs.append(pack_id)
		elif metadata and metadata.has("purchased_packs"):
			for pack_id in metadata.purchased_packs:
				if pack_id not in local_dlcs:
					local_dlcs.append(pack_id)
	
	return local_dlcs

# Cargar metadatos de DLC (info para mostrar en tienda)
func load_dlc_metadata():
	print("ProgressManager: Cargando metadatos de DLC para tienda...")
	if not REMOTE_CATALOG_SANDBOX_MODE:
		var new_base_file = FileAccess.open("res://dlc/new_base_packs.json", FileAccess.READ)
		if new_base_file:
			var json_text = new_base_file.get_as_text()
			new_base_file.close()
			var json_result = JSON.parse_string(json_text)

			if json_result and json_result.has("packs"):
				# Añadir metadatos de DLC como "no comprado" por defecto
				for new_pack in json_result.packs:
					var already_exists = false
					for i in range(packs_data.packs.size()):
						if packs_data.packs[i].id == new_pack.id:
							already_exists = true
							break
					
					if not already_exists:
						# Añadir solo metadatos (sin puzzles)
						var metadata_pack = new_pack.duplicate(true)
						metadata_pack["is_dlc"] = true
						metadata_pack["purchased"] = FREE_TO_PLAY_MODE
						metadata_pack["unlocked"] = false
						metadata_pack["puzzles"] = []
						_register_dlc_metadata_pack(metadata_pack)
						print("ProgressManager: Añadido metadata de DLC: ", new_pack.id)

	var remote_catalog_service = _get_remote_catalog_service()
	if remote_catalog_service == null or not remote_catalog_service.has_remote_catalog():
		return

	var catalog_manifest = remote_catalog_service.get_catalog_manifest()
	if REMOTE_CATALOG_SANDBOX_MODE and not _is_current_sandbox_catalog_snapshot(catalog_manifest):
		return
	var sandbox_allowed_lookup := {}
	if REMOTE_CATALOG_SANDBOX_MODE:
		for allowed_pack_id in _get_sandbox_accessible_pack_ids():
			var normalized_allowed_pack_id := str(allowed_pack_id)
			if normalized_allowed_pack_id != "":
				sandbox_allowed_lookup[normalized_allowed_pack_id] = true
	for remote_pack in catalog_manifest.get("packs", []):
		if typeof(remote_pack) != TYPE_DICTIONARY:
			continue
		var remote_pack_id := str(remote_pack.get("id", ""))
		if remote_pack_id == "":
			continue
		if REMOTE_CATALOG_SANDBOX_MODE and not sandbox_allowed_lookup.has(remote_pack_id):
			continue

		var metadata_pack := {
			"id": remote_pack_id,
			"name": _get_localized_catalog_text(remote_pack.get("title", {}), remote_pack_id),
			"name_localized": remote_pack.get("title", {}).duplicate(true) if typeof(remote_pack.get("title", {})) == TYPE_DICTIONARY else remote_pack.get("title", remote_pack_id),
			"description": _get_localized_catalog_text(remote_pack.get("description", {}), ""),
			"description_localized": remote_pack.get("description", {}).duplicate(true) if typeof(remote_pack.get("description", {})) == TYPE_DICTIONARY else remote_pack.get("description", ""),
			"image_path": "",
			"thumbnail_path": str(remote_pack.get("thumbnail_path", "")),
			"manifest_path": str(remote_pack.get("manifest_path", "")),
			"music_path": str(remote_pack.get("music_path", "")),
			"tier": str(remote_pack.get("tier", "free")),
			"is_dlc": true,
			"remote_catalog": true,
			"purchased": FREE_TO_PLAY_MODE,
			"unlocked": false,
			"completed": false,
			"difficulty": str(remote_pack.get("difficulty", "easy")),
			"puzzles": []
		}
		_register_dlc_metadata_pack(metadata_pack)
		print("ProgressManager: Añadido metadata de catálogo remoto: ", remote_pack_id)

# Cargar contenido solo para DLCs comprados
func load_purchased_dlc_content(purchased_pack_ids: Array):
	print("ProgressManager: Cargando contenido para packs comprados: ", purchased_pack_ids)
	
	for pack_id in purchased_pack_ids:
		# Marcar como comprado en los datos
		mark_pack_as_purchased(pack_id)
		
		# Cargar puzzles solo cuando el pack sea DLC o no tenga contenido todavía.
		# Evita sobreescribir packs base que ya traen puzzles completos.
		var pack_index = _find_pack_index(pack_id)
		if pack_index >= 0:
			var pack_data = packs_data.packs[pack_index]
			var is_dlc_pack = pack_data.get("is_dlc", false)
			var has_embedded_puzzles = pack_data.has("puzzles") and pack_data.puzzles.size() > 0
			
			if is_dlc_pack or not has_embedded_puzzles:
				load_dlc_pack_puzzles(pack_id)

func _sync_active_dlc_state(active_pack_ids: Array) -> void:
	var active_lookup := {}
	for pack_id in active_pack_ids:
		active_lookup[str(pack_id)] = true

	if not packs_data.has("packs"):
		return

	for pack in packs_data.packs:
		if not pack.get("is_dlc", false):
			continue

		var pack_id := str(pack.get("id", ""))
		var is_active := FREE_TO_PLAY_MODE or active_lookup.has(pack_id)
		pack["purchased"] = is_active
		if not FREE_TO_PLAY_MODE and not is_active:
			pack["unlocked"] = false

		_ensure_pack_progress_entry(pack_id, pack)
		progress_data.packs[pack_id]["purchased"] = is_active
		if not FREE_TO_PLAY_MODE and not is_active:
			progress_data.packs[pack_id]["unlocked"] = false

	save_progress_data()

# Marcar un pack como comprado
func mark_pack_as_purchased(pack_id: String):
	var pack_index = _find_pack_index(pack_id)
	if pack_index < 0:
		print("ProgressManager: WARNING - No se encontró el pack al marcar compra: ", pack_id)
		return
	
	packs_data.packs[pack_index]["purchased"] = true
	if not FREE_TO_PLAY_MODE:
		packs_data.packs[pack_index]["unlocked"] = true
	print("ProgressManager: Pack marcado como comprado: ", pack_id)
	
	# Reconciliar progresión incluso si el pack ya existía
	_ensure_pack_progress_entry(pack_id, packs_data.packs[pack_index])
	progress_data.packs[pack_id]["purchased"] = true
	if not FREE_TO_PLAY_MODE:
		progress_data.packs[pack_id]["unlocked"] = true
	_unlock_first_puzzle_if_needed(pack_id, packs_data.packs[pack_index])
	save_progress_data()

# Función para cargar los puzzles de un pack DLC específico
func load_dlc_pack_puzzles(pack_id: String):
	# 1) Intentar desde almacenamiento del usuario (descargado)
	var user_pack_path = "user://dlc/packs/" + pack_id + ".json"
	var pack_file = FileAccess.open(user_pack_path, FileAccess.READ)
	var pack_file_path = user_pack_path
	
	# 2) Si no existe en user://, usar el pack embebido en res://
	if pack_file == null:
		pack_file_path = "res://dlc/packs/" + pack_id + ".json"
		pack_file = FileAccess.open(pack_file_path, FileAccess.READ)
	
	# 3) Si tampoco existe, intentar desde backup local incluido en el proyecto
	if pack_file == null:
		pack_file_path = LOCAL_DLC_BACKUP_PACKS_DIR + "/" + pack_id + ".json"
		pack_file = FileAccess.open(pack_file_path, FileAccess.READ)

	if pack_file == null and _is_remote_catalog_pack(pack_id):
		print("ProgressManager: Pack remoto pendiente de descarga o sincronización: ", pack_id)
		return
	
	if pack_file:
		var json_text = pack_file.get_as_text()
		pack_file.close()
		var json_result = JSON.parse_string(json_text)

		# Soportar dos formatos:
		# 1) { "puzzles": [...] }
		# 2) { "packs": [ { id: pack_id, puzzles: [...] } ] }
		var puzzles := []
		var pack_meta := {}

		if json_result:
			if json_result.has("puzzles") and typeof(json_result.puzzles) == TYPE_ARRAY:
				puzzles = json_result.puzzles
				pack_meta = json_result
			elif json_result.has("packs") and typeof(json_result.packs) == TYPE_ARRAY:
				for p in json_result.packs:
					if typeof(p) == TYPE_DICTIONARY and p.has("id") and str(p.id) == str(pack_id):
						if p.has("puzzles") and typeof(p.puzzles) == TYPE_ARRAY:
							puzzles = p.puzzles
							pack_meta = p
						break
		
		if puzzles.size() > 0:
			if pack_meta.has("image_path"):
				pack_meta["image_path"] = _resolve_pack_asset_path(pack_id, str(pack_meta["image_path"]), pack_file_path)
			
			for j in range(puzzles.size()):
				if puzzles[j].has("image"):
					puzzles[j]["image"] = _resolve_pack_asset_path(pack_id, str(puzzles[j]["image"]), pack_file_path)
			
			# Encontrar el pack en packs_data y actualizar sus puzzles
			for i in range(packs_data.packs.size()):
				if packs_data.packs[i].id == pack_id:
					packs_data.packs[i].puzzles = puzzles
					# Opcional: actualizar algunos metadatos si están presentes
					for k in ["name", "name_localized", "description", "description_localized", "image_path", "music_path", "unlocked", "purchased", "completed", "difficulty"]:
						if pack_meta.has(k):
							packs_data.packs[i][k] = pack_meta[k]
					print("ProgressManager: Cargados ", puzzles.size(), " puzzles para pack: ", pack_id)

					# Inicializar progresión para este pack
					initialize_dlc_pack_progress(pack_id)
					break
		else:
			print("ProgressManager: ERROR - No se encontraron puzzles en el pack: ", pack_id,
				". Revisa el formato del JSON (se espera 'puzzles' o 'packs[0].puzzles')")
	else:
		print("ProgressManager: ERROR - No se pudo abrir el archivo del pack: ", pack_file_path)

# Inicializa la progresión de un pack DLC específico
func initialize_dlc_pack_progress(pack_id: String) -> void:
	# Buscar datos del pack en packs_data
	var pack_data = null
	if packs_data.has("packs"):
		for pack in packs_data.packs:
			if pack.id == pack_id:
				pack_data = pack
				break
	
	if pack_data == null:
		print("ProgressManager: No se encontraron datos del pack DLC: ", pack_id)
		return
	
	_ensure_pack_progress_entry(pack_id, pack_data)
	_unlock_first_puzzle_if_needed(pack_id, pack_data)
	save_progress_data()
	print("ProgressManager: Progresión reconciliada para pack DLC: ", pack_id)


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
	
	# Forzar recarga de todos los DLCs
	force_load_all_dlcs()
	packs_refreshed.emit()
	
	print("ProgressManager: Datos de packs DLC actualizados")
