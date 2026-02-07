extends Node

const API_BASE = "https://api.tu-dominio.com"
var game_id := "tikitiki-puzzle"
var app_user_id := ""  # genera UUID y persiste en user:// si no tienes login

# Señales para comunicación con la UI
signal purchase_started(pack_id: String)
signal purchase_completed(pack_id: String, success: bool)
signal download_started(pack_id: String)
signal download_progress(pack_id: String, progress: float)
signal download_completed(pack_id: String, success: bool)
signal installation_completed(pack_id: String, success: bool)

func _ready():
	if app_user_id == "":
		app_user_id = _ensure_app_user_id()
	
	print("IapService: Inicializado con user_id: ", app_user_id)

func _ensure_app_user_id() -> String:
	var path = "user://app_user_id.txt"
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	var uuid = str(Time.get_unix_time_from_system()) + "-" + str(randi())
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(uuid); f.close()
	return uuid

# === Entitlements desde backend ===
func fetch_entitlements() -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var url = API_BASE + "/v1/entitlements?app_user_id=%s&game_id=%s" % [app_user_id, game_id]
	var err = http.request(url, [], HTTPClient.METHOD_GET)
	if err != OK: return {}
	var res = await http.request_completed
	if res[1] != 200: return {}
	return JSON.parse_string(res[3].get_string_from_utf8())

func has_full_unlock(entitlements: Dictionary) -> bool:
	for e in entitlements.get("entitlements", []):
		if e.product_key == "full_game_unlock" and e.status == "active":
			return true
	return false

# === Verificación de compra -> backend ===
func verify_purchase(platform: String, product_key: String, token_or_receipt: String) -> bool:
	var http := HTTPRequest.new()
	add_child(http)
	var body = {
		"app_user_id": app_user_id,
		"game_id": game_id,
		"platform": platform,         # "android" | "ios" | "steam"
		"product_key": product_key,   # "full_game_unlock"
	}
	if platform == "android":
		body["token"] = token_or_receipt
	elif platform == "ios":
		body["receipt"] = token_or_receipt

	var headers = ["Content-Type: application/json"]
	var err = http.request(API_BASE + "/v1/purchases/verify", headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK: return false
	var res = await http.request_completed
	if res[1] != 200: return false
	var data = JSON.parse_string(res[3].get_string_from_utf8())
	return data.get("granted", false)

# === Descarga de PCK firmado ===
func download_pack(pack_id: String, version := "") -> bool:
	var url = API_BASE + "/v1/content/signed-url"
	var http := HTTPRequest.new()
	add_child(http)

	var body = {
		"app_user_id": app_user_id,
		"game_id": game_id,
		"pack_id": pack_id
	}
	if version != "": body["version"] = version

	var headers = ["Content-Type: application/json"]
	var err = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK: return false
	var res = await http.request_completed
	if res[1] != 200: return false

	var signed = JSON.parse_string(res[3].get_string_from_utf8())
	var pck_url = signed.url
	var sha256 = signed.sha256

	# descargar PCK
	var http2 := HTTPRequest.new()
	add_child(http2)
	var err2 = http2.request(pck_url)
	if err2 != OK: return false
	var res2 = await http2.request_completed
	if res2[1] != 200: return false
	var body_bytes: PackedByteArray = res2[3]

	var path = "user://%s_%s.pck" % [pack_id, signed.version]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(body_bytes); f.close()

	# TODO: verificar sha256 del archivo guardado con 'Crypto' (Godot 4)
	# var hash_ok = _verify_sha256(path, sha256)

	return ProjectSettings.load_resource_pack(path)

# === Flujo completo de compra e instalación ===
func purchase_and_install_pack(pack_id: String) -> bool:
	print("IapService: Iniciando compra e instalación para pack: ", pack_id)
	purchase_started.emit(pack_id)
	
	# 1. Simular compra (aquí integrarías con Google Play, App Store, etc.)
	var purchase_success = await simulate_platform_purchase(pack_id)
	if not purchase_success:
		print("IapService: Falló la compra del pack: ", pack_id)
		purchase_completed.emit(pack_id, false)
		return false
	
	# 2. Verificar compra en backend
	var verification_success = await verify_purchase("android", "pack_" + pack_id, "dummy_token_" + pack_id)
	if not verification_success:
		print("IapService: Falló la verificación de compra: ", pack_id)
		purchase_completed.emit(pack_id, false)
		return false
	
	purchase_completed.emit(pack_id, true)
	
	# 3. Descargar e instalar contenido
	return await download_and_install_pack_content(pack_id)

# Simular compra de plataforma (reemplazar con IAP real)
func simulate_platform_purchase(pack_id: String) -> bool:
	print("IapService: Simulando compra de plataforma para: ", pack_id)
	# Aquí simularemos un delay de compra
	await get_tree().create_timer(1.0).timeout
	
	# Por ahora siempre devuelve true para desarrollo
	# En producción, aquí irían las llamadas a Google Play Billing, App Store, etc.
	return true

# Descargar e instalar contenido del pack
func download_and_install_pack_content(pack_id: String) -> bool:
	print("IapService: Iniciando descarga para pack: ", pack_id)
	download_started.emit(pack_id)
	
	# 1. Descargar desde backup local (temporalmente)
	var success = await download_from_local_backup(pack_id)
	
	if success:
		download_completed.emit(pack_id, true)
		
		# 2. Instalar en ProgressManager
		var installation_success = install_pack_in_progress_manager(pack_id)
		installation_completed.emit(pack_id, installation_success)
		
		return installation_success
	else:
		download_completed.emit(pack_id, false)
		installation_completed.emit(pack_id, false)
		return false

# Descargar desde backup local (temporal hasta tener servidor)
func download_from_local_backup(pack_id: String) -> bool:
	print("IapService: Descargando desde backup local: ", pack_id)
	
	# Crear directorios necesarios
	_ensure_user_dlc_dirs()
	
	# Simular progreso de descarga
	for i in range(10):
		await get_tree().create_timer(0.1).timeout
		download_progress.emit(pack_id, (i + 1) / 10.0)
	
	# Copiar desde backup a user://dlc/packs/
	var backup_json_path = "res://dlc_backup_20250901_190152/packs/" + pack_id + ".json"
	var backup_assets_dir = "res://dlc_backup_20250901_190152/packs/" + pack_id + "/"
	
	var dest_json_path = "user://dlc/packs/" + pack_id + ".json"
	var dest_assets_dir = "user://dlc/packs/" + pack_id + "/"
	
	# Copiar JSON del pack
	if FileAccess.file_exists(backup_json_path):
		var source_file = FileAccess.open(backup_json_path, FileAccess.READ)
		if source_file:
			var content = source_file.get_as_text()
			source_file.close()
			
			var dest_file = FileAccess.open(dest_json_path, FileAccess.WRITE)
			if dest_file:
				dest_file.store_string(content)
				dest_file.close()
				print("IapService: JSON copiado para pack: ", pack_id)
			else:
				print("IapService: Error al escribir JSON destino: ", dest_json_path)
				return false
		else:
			print("IapService: Error al leer JSON fuente: ", backup_json_path)
			return false
	else:
		print("IapService: No se encontró JSON en backup: ", backup_json_path)
		return false
	
	# Copiar assets (por ahora skipeamos esto para simplificar, el JSON es suficiente)
	# En una implementación real, aquí copiarías todas las imágenes del pack
	
	return true

# Asegurar que existen los directorios de DLC del usuario
func _ensure_user_dlc_dirs():
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("dlc"):
			dir.make_dir("dlc")
		if not dir.dir_exists("dlc/packs"):
			dir.make_dir_recursive("dlc/packs")

# Instalar pack en ProgressManager
func install_pack_in_progress_manager(pack_id: String) -> bool:
	print("IapService: Instalando pack en ProgressManager: ", pack_id)
	
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if not progress_manager:
		print("IapService: Error - ProgressManager no encontrado")
		return false
	
	# Marcar pack como comprado
	progress_manager.mark_pack_as_purchased(pack_id)
	
	# Cargar puzzles del pack
	progress_manager.load_dlc_pack_puzzles(pack_id)
	
	# Guardar metadata de compra
	_save_purchase_metadata(pack_id)
	
	print("IapService: Pack instalado exitosamente: ", pack_id)
	return true

# Guardar metadata de compra
func _save_purchase_metadata(pack_id: String):
	var metadata_path = "user://dlc/dlc_metadata.json"
	var metadata = {}
	
	# Cargar metadata existente
	if FileAccess.file_exists(metadata_path):
		var file = FileAccess.open(metadata_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(content)
			if parsed and typeof(parsed) == TYPE_DICTIONARY:
				metadata = parsed
	
	# Añadir nuevo pack comprado
	if not metadata.has("purchased_packs"):
		metadata["purchased_packs"] = []
	
	if pack_id not in metadata.purchased_packs:
		metadata.purchased_packs.append(pack_id)
	
	metadata["last_purchase"] = Time.get_datetime_string_from_system()
	
	# Guardar metadata actualizada
	var file = FileAccess.open(metadata_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(metadata))
		file.close()
		print("IapService: Metadata de compra guardada para: ", pack_id)

# Obtener lista de packs disponibles para compra
func get_available_packs_for_purchase() -> Array:
	var available_packs = []
	
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if not progress_manager:
		return available_packs
	
	# Obtener todos los packs y filtrar los no comprados
	if progress_manager.packs_data.has("packs"):
		for pack in progress_manager.packs_data.packs:
			if pack.get("is_dlc", false) and not pack.get("purchased", false):
				available_packs.append({
					"id": pack.id,
					"name": pack.name,
					"description": pack.get("description", ""),
					"image_path": pack.get("image_path", ""),
					"price": "2.99€"  # Precio por defecto
				})
	
	return available_packs
