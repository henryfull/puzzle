extends Node

signal sync_success()
signal sync_failed(error_message)
signal data_pull_completed()
signal data_push_completed()

# Constantes para rutas de archivos
const SYNC_CONFIG_FILE = "user://cloud_sync_config.json"

# Variables de config
var sync_config = {
	"auto_sync_on_start": true,
	"auto_sync_on_end": true,
	"sync_achievements": true,
	"sync_progress": true,
	"sync_settings": true,
	"sync_purchases": true,  # Nueva opción para sincronizar compras
	"last_sync_timestamp": 0
}

# HTTP Request para comunicación con el backend
var http_request: HTTPRequest

# Estado
var is_syncing = false
var sync_queue = []

func _ready():
	# Crear el objeto HTTPRequest
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	
	# Cargar configuración
	load_sync_config()
	
	# Realizar sincronización automática si está habilitado
	if sync_config.auto_sync_on_start and AuthManager.is_logged_in():
		sync_all_data()
	
	print("CloudSyncManager: Sistema de sincronización inicializado")

# Cargar configuración de sincronización
func load_sync_config():
	var file = FileAccess.open(SYNC_CONFIG_FILE, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json_result = JSON.parse_string(json_text)
		if json_result:
			sync_config = json_result
			print("CloudSyncManager: Configuración de sincronización cargada correctamente")
		else:
			print("CloudSyncManager: Error al analizar el JSON de configuración")
	else:
		print("CloudSyncManager: No se encontró archivo de configuración, usando valores por defecto")
		save_sync_config()

# Guardar configuración de sincronización
func save_sync_config():
	var file = FileAccess.open(SYNC_CONFIG_FILE, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(sync_config, "\t")
		file.store_string(json_text)
		file.close()
		print("CloudSyncManager: Configuración de sincronización guardada correctamente")
	else:
		print("CloudSyncManager: Error al guardar la configuración de sincronización")

# Sincronizar todos los datos
func sync_all_data():
	if is_syncing:
		print("CloudSyncManager: Ya hay un proceso de sincronización en marcha")
		return
		
	if not AuthManager.is_logged_in():
		print("CloudSyncManager: No se puede sincronizar, el usuario no ha iniciado sesión")
		emit_signal("sync_failed", "Usuario no autenticado")
		return
	
	is_syncing = true
	print("CloudSyncManager: Iniciando sincronización completa...")
	
	# Primero obtenemos los datos más recientes del servidor
	pull_data_from_cloud()

# Enviar datos locales a la nube (subir)
func push_data_to_cloud():
	print("CloudSyncManager: Enviando datos a la nube...")
	
	# Coleccionar todos los datos que queremos sincronizar
	var data_to_sync = {
		"user_id": AuthManager.get_user_info().user_id,
		"timestamp": Time.get_unix_time_from_system(),
		"client_version": ProjectSettings.get_setting("application/config/version", "0.0.0")
	}
	
	# Agregar datos de progreso si está habilitado
	if sync_config.sync_progress:
		var progress_data = ProgressManager.get_progress_data()
		data_to_sync["progress"] = progress_data
	
	# Agregar datos de logros si está habilitado
	if sync_config.sync_achievements:
		var achievements_data = AchievementsManager.get_all_achievements()
		data_to_sync["achievements"] = achievements_data
	
	# Agregar configuraciones si está habilitado
	if sync_config.sync_settings:
		data_to_sync["settings"] = GLOBAL.settings
	
	# Agregar compras si está habilitado
	if sync_config.sync_purchases and has_node("/root/PurchaseManager"):
		var purchase_manager = get_node("/root/PurchaseManager")
		data_to_sync["purchases"] = purchase_manager.purchased_packs
	
	# Convertir a JSON
	var json_data = JSON.stringify(data_to_sync)
	
	# Preparar headers para la petición
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + AuthManager.get_user_info().user_id # En un sistema real, usarías un token de auth adecuado
	]
	
	# URL de tu API backend
	var url = "https://api.tucloudstorage.com/sync" # Reemplazar con tu URL real
	
	# Aquí enviamos los datos al servidor
	# En un entorno real, esto sería una llamada HTTP real
	# http_request.request(url, headers, HTTPClient.METHOD_POST, json_data)
	
	# Simulamos una respuesta exitosa
	await get_tree().create_timer(1.0).timeout
	
	_on_push_completed(true, "")
	
	print("CloudSyncManager: Datos enviados a la nube correctamente")

# Obtener datos de la nube (descargar)
func pull_data_from_cloud():
	print("CloudSyncManager: Obteniendo datos de la nube...")
	
	# URL de tu API backend
	var url = "https://api.tucloudstorage.com/sync?user_id=" + AuthManager.get_user_info().user_id
	
	# Preparar headers para la petición
	var headers = [
		"Authorization: Bearer " + AuthManager.get_user_info().user_id # En un sistema real, usarías un token de auth adecuado
	]
	
	# Aquí obtendríamos los datos del servidor
	# En un entorno real, esto sería una llamada HTTP real
	# http_request.request(url, headers, HTTPClient.METHOD_GET)
	
	# Simulamos una respuesta exitosa
	await get_tree().create_timer(1.0).timeout
	
	# Simulamos datos recibidos del servidor
	var mock_data = {
		"timestamp": Time.get_unix_time_from_system(),
		"progress": null,  # Sin datos de progreso en el servidor (primera sincronización)
		"achievements": null,  # Sin datos de logros en el servidor
		"settings": null,  # Sin datos de configuración en el servidor
		"purchases": null  # Sin datos de compras en el servidor
	}
	
	_on_pull_completed(true, mock_data)
	
	print("CloudSyncManager: Datos obtenidos de la nube correctamente")

# Manejar respuesta de subida de datos
func _on_push_completed(success, error_message = ""):
	if success:
		sync_config.last_sync_timestamp = Time.get_unix_time_from_system()
		save_sync_config()
		emit_signal("data_push_completed")
		
		# Completar el proceso de sincronización
		is_syncing = false
		emit_signal("sync_success")
	else:
		is_syncing = false
		emit_signal("sync_failed", error_message)
		print("CloudSyncManager: Error al enviar datos: ", error_message)

# Manejar respuesta de descarga de datos
func _on_pull_completed(success, data = null, error_message = ""):
	if success and data != null:
		# Verificar si hay datos más recientes en el servidor
		if data.has("timestamp") and data.timestamp > sync_config.last_sync_timestamp:
			# Aplicar datos del servidor si existen y son más recientes
			
			# Aplicar progreso
			if sync_config.sync_progress and data.has("progress") and data.progress != null:
				ProgressManager.apply_cloud_data(data.progress)
				
			# Aplicar logros
			if sync_config.sync_achievements and data.has("achievements") and data.achievements != null:
				AchievementsManager.apply_cloud_data(data.achievements)
			
			# Aplicar configuración
			if sync_config.sync_settings and data.has("settings") and data.settings != null:
				GLOBAL.apply_cloud_settings(data.settings)
			
			# Aplicar compras
			if sync_config.sync_purchases and data.has("purchases") and data.purchases != null and has_node("/root/PurchaseManager"):
				var purchase_manager = get_node("/root/PurchaseManager")
				_apply_purchases_from_cloud(purchase_manager, data.purchases)
		
		emit_signal("data_pull_completed")
		
		# Después de obtener datos, enviamos los nuestros
		push_data_to_cloud()
	else:
		# Si falla la descarga, intentamos subir nuestros datos de todos modos
		if error_message.is_empty():
			push_data_to_cloud()
		else:
			is_syncing = false
			emit_signal("sync_failed", error_message)
			print("CloudSyncManager: Error al obtener datos: ", error_message)

# Aplicar datos de compras desde la nube
func _apply_purchases_from_cloud(purchase_manager, cloud_purchases):
	print("CloudSyncManager: Aplicando datos de compras desde la nube")
	
	var local_purchases = purchase_manager.purchased_packs
	var updated = false
	
	# Fusionar compras de la nube con las locales
	for pack_id in cloud_purchases:
		if cloud_purchases[pack_id] == true and (not local_purchases.has(pack_id) or local_purchases[pack_id] != true):
			local_purchases[pack_id] = true
			
			# Actualizar el ProgressManager para desbloquear el pack
			if has_node("/root/ProgressManager"):
				var progress_manager = get_node("/root/ProgressManager")
				progress_manager.unlock_pack(pack_id)
			
			updated = true
			print("CloudSyncManager: Pack desbloqueado desde la nube: ", pack_id)
	
	if updated:
		purchase_manager.save_purchases()

# Callback para completar peticiones HTTP
func _on_http_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if result != HTTPRequest.RESULT_SUCCESS:
		is_syncing = false
		emit_signal("sync_failed", "Error de red: " + str(result))
		return
		
	if response_code != 200:
		is_syncing = false
		emit_signal("sync_failed", "Error del servidor: " + str(response_code))
		return
		
	if parse_result != OK:
		is_syncing = false
		emit_signal("sync_failed", "Error al analizar respuesta JSON")
		return
		
	var response = json.get_data()
	
	# Procesar según el tipo de operación que estábamos realizando
	# Este código se implementaría según la lógica de tu API
	
	print("CloudSyncManager: Respuesta del servidor recibida correctamente")

# Configurar sincronización automática
func set_auto_sync(on_start: bool, on_end: bool):
	sync_config.auto_sync_on_start = on_start
	sync_config.auto_sync_on_end = on_end
	save_sync_config()

# Configurar qué datos sincronizar
func set_sync_data_types(achievements: bool, progress: bool, settings: bool, purchases: bool = true):
	sync_config.sync_achievements = achievements
	sync_config.sync_progress = progress
	sync_config.sync_settings = settings
	sync_config.sync_purchases = purchases
	save_sync_config()

# Verificar si hay una sincronización en progreso
func is_sync_in_progress():
	return is_syncing 