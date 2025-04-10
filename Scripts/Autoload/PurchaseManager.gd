extends Node

# Señales para notificar sobre el estado de las compras
signal purchase_initiated(pack_id)
signal purchase_completed(pack_id)
signal purchase_failed(pack_id, error_message)
signal purchase_canceled(pack_id)
signal purchases_restored(success, message)

# Constante para el archivo de packs comprados
const PURCHASES_FILE = "user://purchases.json"

# Variable para guardar los packs comprados
var purchased_packs = {}

# Variables para detectar la plataforma
var is_android = false
var is_ios = false
var is_using_iap = false

# Referencia al singleton ProgressManager (para actualizar el progreso cuando se compra un pack)
var progress_manager

func _ready():
	# Detectar plataforma
	is_android = OS.has_feature("android")
	is_ios = OS.has_feature("ios")
	
	# Verificar si podemos usar compras en la plataforma actual
	is_using_iap = (is_android or is_ios)
	
	# Obtener referencia al ProgressManager
	if has_node("/root/ProgressManager"):
		progress_manager = get_node("/root/ProgressManager")
	
	# Cargar los packs ya comprados
	load_purchases()
	
	# Si estamos en iOS o Android, inicializar la API de compras
	if is_using_iap:
		_initialize_store_api()
	
	print("PurchaseManager: Sistema de compras inicializado. Usando IAP: ", is_using_iap)

# Inicializar la API de compras según la plataforma
func _initialize_store_api():
	if is_android:
		# Inicializar Google Play Billing
		if Engine.has_singleton("GodotGooglePlayBilling"):
			var play_billing = Engine.get_singleton("GodotGooglePlayBilling")
			# Conectar señales
			play_billing.connect("connected", Callable(self, "_on_play_billing_connected"))
			play_billing.connect("disconnected", Callable(self, "_on_play_billing_disconnected"))
			play_billing.connect("purchases_updated", Callable(self, "_on_play_billing_purchases_updated"))
			play_billing.connect("purchase_error", Callable(self, "_on_play_billing_purchase_error"))
			
			# Iniciar conexión con Google Play
			play_billing.startConnection()
			print("PurchaseManager: Iniciando conexión con Google Play Billing")
		else:
			print("PurchaseManager: GodotGooglePlayBilling no disponible")
			is_using_iap = false
	
	elif is_ios:
		# Inicializar StoreKit
		if Engine.has_singleton("GodotAppleIAP"):
			var apple_iap = Engine.get_singleton("GodotAppleIAP")
			# Conectar señales
			apple_iap.connect("purchase_completed", Callable(self, "_on_apple_iap_purchase_completed"))
			apple_iap.connect("purchase_failed", Callable(self, "_on_apple_iap_purchase_failed"))
			apple_iap.connect("purchases_restored", Callable(self, "_on_apple_iap_purchases_restored"))
			
			# Inicializar StoreKit
			apple_iap.initialize()
			print("PurchaseManager: Iniciando StoreKit")
		else:
			print("PurchaseManager: GodotAppleIAP no disponible")
			is_using_iap = false

# Cargar compras guardadas localmente
func load_purchases():
	var file = FileAccess.open(PURCHASES_FILE, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json_result = JSON.parse_string(json_text)
		if json_result:
			purchased_packs = json_result
			print("PurchaseManager: Compras cargadas correctamente")
		else:
			print("PurchaseManager: Error al analizar el JSON de compras")
	else:
		print("PurchaseManager: No se encontró archivo de compras, se usarán valores por defecto")
		purchased_packs = {}
		save_purchases()

# Guardar compras localmente
func save_purchases():
	var file = FileAccess.open(PURCHASES_FILE, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(purchased_packs)
		file.store_string(json_text)
		file.close()
		print("PurchaseManager: Compras guardadas correctamente")
	else:
		print("PurchaseManager: Error al guardar las compras")

# Verificar si un pack ha sido comprado
func is_pack_purchased(pack_id):
	return purchased_packs.has(pack_id) and purchased_packs[pack_id]

# Solicitar la compra de un pack
func request_purchase(pack):
	if not pack.has("id"):
		print("PurchaseManager: Error - El pack no tiene ID")
		emit_signal("purchase_failed", "", "El pack no tiene ID")
		return
	
	var pack_id = pack.id
	print("PurchaseManager: Solicitando compra del pack ", pack_id)
	
	# Si el pack ya está comprado, no continuar
	if is_pack_purchased(pack_id):
		print("PurchaseManager: El pack ", pack_id, " ya está comprado")
		emit_signal("purchase_completed", pack_id)
		return
	
	# Si estamos autenticados, intentar compra a través de la tienda
	if AuthManager.is_logged_in() and is_using_iap:
		_purchase_through_store(pack)
	else:
		# Para pruebas o sin IAP, simular una compra exitosa
		_simulate_purchase(pack)

# Realizar compra a través de la tienda (Google Play o App Store)
func _purchase_through_store(pack):
	var pack_id = pack.id
	var product_id = _get_product_id_for_pack(pack_id)
	
	emit_signal("purchase_initiated", pack_id)
	
	if is_android:
		if Engine.has_singleton("GodotGooglePlayBilling"):
			var play_billing = Engine.get_singleton("GodotGooglePlayBilling")
			play_billing.purchase(product_id)
			print("PurchaseManager: Iniciando compra en Google Play: ", product_id)
		else:
			_simulate_purchase(pack)
	
	elif is_ios:
		if Engine.has_singleton("GodotAppleIAP"):
			var apple_iap = Engine.get_singleton("GodotAppleIAP")
			apple_iap.purchase(product_id)
			print("PurchaseManager: Iniciando compra en App Store: ", product_id)
		else:
			_simulate_purchase(pack)
	
	else:
		_simulate_purchase(pack)

# Obtener el ID de producto para la tienda basado en el ID del pack
func _get_product_id_for_pack(pack_id):
	# Aquí debes definir un mapeo entre los IDs de tus packs y los IDs de producto en las tiendas
	# Por ejemplo:
	var product_mapping = {
		"pack_animals": "com.tuempresa.tujuego.pack_animals",
		"pack_numbers": "com.tuempresa.tujuego.pack_numbers",
		"pack_fruits": "com.tuempresa.tujuego.pack_fruits"
	}
	
	if product_mapping.has(pack_id):
		return product_mapping[pack_id]
	else:
		# Si no hay un mapeo específico, usar el ID del pack como ID del producto
		return "com.tuempresa.tujuego." + pack_id

# Simular una compra exitosa (para pruebas o versión de desarrollo)
func _simulate_purchase(pack):
	var pack_id = pack.id
	print("PurchaseManager: Simulando compra del pack ", pack_id)
	
	# Simular un proceso de compra
	emit_signal("purchase_initiated", pack_id)
	
	# Esperar un poco para simular el proceso
	await get_tree().create_timer(1.5).timeout
	
	# Registrar la compra
	purchased_packs[pack_id] = true
	save_purchases()
	
	# Actualizar el progreso para marcar el pack como desbloqueado
	if progress_manager:
		progress_manager.unlock_pack(pack_id)
	
	# Notificar que la compra se completó
	emit_signal("purchase_completed", pack_id)
	print("PurchaseManager: Compra simulada completada para el pack ", pack_id)

# Restaurar compras previas
func restore_purchases():
	print("PurchaseManager: Restaurando compras...")
	
	if is_android:
		if Engine.has_singleton("GodotGooglePlayBilling"):
			var play_billing = Engine.get_singleton("GodotGooglePlayBilling")
			play_billing.queryPurchases("inapp")
			print("PurchaseManager: Consultando compras en Google Play")
		else:
			emit_signal("purchases_restored", false, "Google Play Billing no disponible")
	
	elif is_ios:
		if Engine.has_singleton("GodotAppleIAP"):
			var apple_iap = Engine.get_singleton("GodotAppleIAP")
			apple_iap.restore_purchases()
			print("PurchaseManager: Restaurando compras en App Store")
		else:
			emit_signal("purchases_restored", false, "Apple IAP no disponible")
	
	else:
		# Para pruebas o cuando no estamos en plataformas móviles
		emit_signal("purchases_restored", true, "No hay compras que restaurar en esta plataforma")

# Cancelar una compra en curso
func cancel_purchase():
	print("PurchaseManager: Cancelando compra")
	emit_signal("purchase_canceled", "")

# Callbacks para Google Play Billing
func _on_play_billing_connected():
	print("PurchaseManager: Conectado a Google Play Billing")

func _on_play_billing_disconnected():
	print("PurchaseManager: Desconectado de Google Play Billing")

func _on_play_billing_purchases_updated(purchases):
	print("PurchaseManager: Compras actualizadas en Google Play")
	
	for purchase in purchases:
		var product_id = purchase.product_id
		var pack_id = _get_pack_id_from_product(product_id)
		
		if not pack_id.is_empty():
			purchased_packs[pack_id] = true
			
			# Actualizar el progreso
			if progress_manager:
				progress_manager.unlock_pack(pack_id)
			
			emit_signal("purchase_completed", pack_id)
	
	save_purchases()

func _on_play_billing_purchase_error(error_code, error_message):
	print("PurchaseManager: Error de compra en Google Play - ", error_message)
	emit_signal("purchase_failed", "", error_message)

# Callbacks para Apple IAP
func _on_apple_iap_purchase_completed(product_id):
	print("PurchaseManager: Compra completada en App Store: ", product_id)
	
	var pack_id = _get_pack_id_from_product(product_id)
	
	if not pack_id.is_empty():
		purchased_packs[pack_id] = true
		
		# Actualizar el progreso
		if progress_manager:
			progress_manager.unlock_pack(pack_id)
		
		emit_signal("purchase_completed", pack_id)
		
		save_purchases()
	else:
		print("PurchaseManager: No se pudo determinar el pack para el producto: ", product_id)

func _on_apple_iap_purchase_failed(product_id, error_message):
	print("PurchaseManager: Error de compra en App Store - ", error_message)
	
	var pack_id = _get_pack_id_from_product(product_id)
	emit_signal("purchase_failed", pack_id, error_message)

func _on_apple_iap_purchases_restored(success):
	print("PurchaseManager: Restauración de compras en App Store - Éxito: ", success)
	
	if success:
		emit_signal("purchases_restored", true, "Compras restauradas correctamente")
	else:
		emit_signal("purchases_restored", false, "Error al restaurar las compras")

# Obtener el ID del pack a partir del ID del producto
func _get_pack_id_from_product(product_id):
	# Aquí debes definir un mapeo inverso entre los IDs de producto en las tiendas y los IDs de tus packs
	var product_mapping = {
		"com.tuempresa.tujuego.pack_animals": "pack_animals",
		"com.tuempresa.tujuego.pack_numbers": "pack_numbers",
		"com.tuempresa.tujuego.pack_fruits": "pack_fruits"
	}
	
	if product_mapping.has(product_id):
		return product_mapping[product_id]
	
	# Si no hay un mapeo exacto, intentar extraer el ID del pack del ID del producto
	if product_id.begins_with("com.tuempresa.tujuego."):
		return product_id.substr(23)
	
	return ""

# Sincronizar compras con la nube (si el usuario está autenticado)
func sync_purchases_with_cloud():
	if AuthManager.is_logged_in():
		print("PurchaseManager: Sincronizando compras con la nube...")
		# Aquí implementarías la lógica para sincronizar las compras con tu backend
		# Esta función sería llamada por CloudSyncManager
	else:
		print("PurchaseManager: No se pueden sincronizar las compras sin autenticación") 