extends Control

signal exit_canceled

@export var alert_dialog: AcceptDialog
@export var label: Label

# UI para mostrar DLC disponibles
@export var dlc_container: VBoxContainer
@export var scroll_container: ScrollContainer

# UI de progreso de descarga/instalación de DLC
@onready var progress_panel: PanelContainer = $CanvasLayer/DownloadPanel
@onready var progress_bar: ProgressBar = $CanvasLayer/DownloadPanel/Margin/VBox/Progress
@onready var progress_detail: Label = $CanvasLayer/DownloadPanel/Margin/VBox/Detail

# DLC Item scene for displaying individual DLC packs
# var dlc_item_scene = preload("res://Scenes/Components/Store/DLCItem.tscn")

var available_dlcs = []
var current_purchase_pack_id = ""
var product_sku = ""
var last_sku = ""
var test_item_purchase_token = null
func _process_successful_purchase(_sku: String, _purchase_token: String) -> void:
	# Obsoleto: EntitlementsService gestiona el contenido adquirido.
	pass

func _ready():
	label.text = "Cargando tienda DLC..."
	
	# Conectar al nuevo IapService para compras y descargas
	if has_node("/root/IapService"):
		var iap_service = get_node("/root/IapService")
		if not iap_service.is_connected("purchase_started", Callable(self, "_on_purchase_started")):
			iap_service.purchase_started.connect(Callable(self, "_on_purchase_started"))
		if not iap_service.is_connected("purchase_completed", Callable(self, "_on_purchase_completed")):
			iap_service.purchase_completed.connect(Callable(self, "_on_purchase_completed"))
		if not iap_service.is_connected("download_started", Callable(self, "_on_download_started")):
			iap_service.download_started.connect(Callable(self, "_on_download_started"))
		if not iap_service.is_connected("download_progress", Callable(self, "_on_download_progress")):
			iap_service.download_progress.connect(Callable(self, "_on_download_progress"))
		if not iap_service.is_connected("download_completed", Callable(self, "_on_download_completed")):
			iap_service.download_completed.connect(Callable(self, "_on_download_completed"))
		if not iap_service.is_connected("installation_completed", Callable(self, "_on_installation_completed")):
			iap_service.installation_completed.connect(Callable(self, "_on_installation_completed"))
		
		# Cargar DLC disponibles
		_load_available_dlcs()
	else:
		show_alert('IapService no está disponible')
		label.text = "Error: Servicio de compras no disponible"

# Cargar DLC disponibles para compra
func _load_available_dlcs():
	print("Store: Cargando DLC disponibles...")
	
	var iap_service = get_node("/root/IapService")
	if iap_service:
		available_dlcs = iap_service.get_available_packs_for_purchase()
		print("Store: Encontrados ", available_dlcs.size(), " DLC disponibles")
		_display_dlc_items()
	else:
		print("Store: Error - IapService no encontrado")

# Mostrar items de DLC en la UI
func _display_dlc_items():
	if not dlc_container:
		print("Store: Error - dlc_container no encontrado")
		return
	
	# Limpiar items existentes
	for child in dlc_container.get_children():
		child.queue_free()
	
	if available_dlcs.is_empty():
		label.text = "No hay DLC disponibles para compra\nTodos los packs ya están instalados"
		return
	
	label.text = "DLC Disponibles (" + str(available_dlcs.size()) + ")"
	
	# Crear item para cada DLC
	for dlc in available_dlcs:
		var item = _create_dlc_item(dlc)
		if item:
			dlc_container.add_child(item)

# Crear item individual de DLC
func _create_dlc_item(dlc_data: Dictionary) -> Control:
	# Por ahora crear un item simple hasta que tengamos la escena DLCItem
	var item_container = HBoxContainer.new()
	item_container.custom_minimum_size = Vector2(400, 80)
	
	# Panel de fondo
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	
	# Nombre del pack
	var name_label = Label.new()
	name_label.text = dlc_data.get("name", "DLC Pack")
	name_label.add_theme_font_size_override("font_size", 16)
	
	# Descripción
	var desc_label = Label.new()
	desc_label.text = dlc_data.get("description", "Pack de contenido adicional")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Precio y botón de compra
	var bottom_hbox = HBoxContainer.new()
	var price_label = Label.new()
	price_label.text = dlc_data.get("price", "2.99€")
	price_label.add_theme_font_size_override("font_size", 14)
	
	var buy_btn = Button.new()
	buy_btn.text = "Comprar"
	buy_btn.custom_minimum_size = Vector2(100, 30)
	
	# Conectar señal de compra
	var pack_id = dlc_data.get("id", "")
	if pack_id != "":
		buy_btn.pressed.connect(func(): _purchase_dlc(pack_id))
	
	# Construir jerarquía
	bottom_hbox.add_child(price_label)
	bottom_hbox.add_child(buy_btn)
	
	vbox.add_child(name_label)
	vbox.add_child(desc_label)
	vbox.add_child(bottom_hbox)
	
	panel.add_child(vbox)
	item_container.add_child(panel)
	
	return item_container

# Iniciar compra de DLC
func _purchase_dlc(pack_id: String):
	print("Store: Iniciando compra de DLC: ", pack_id)
	current_purchase_pack_id = pack_id
	
	var iap_service = get_node("/root/IapService")
	if iap_service:
		iap_service.purchase_and_install_pack(pack_id)
	else:
		show_alert("Error: Servicio de compras no disponible")


func show_alert(text):
	alert_dialog.dialog_text = text
	alert_dialog.popup_centered_clamped(Vector2i(300, 0))


func _on_connected():
	print("PurchaseManager connected")
	label.text = "Conectado. Consultando compras y detalles del producto..."
	if has_node("/root/IAPService"):
		var iap = get_node("/root/IAPService")
		iap.query_purchases()
		iap.query_products([product_sku])
	_set_ui_enabled(true)


func _set_ui_enabled(enabled: bool) -> void:
	if dlc_container:
		dlc_container.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	
	# Habilitar/deshabilitar botones de compra si existen
	for child in dlc_container.get_children():
		var buy_btn = child.find_child("Button", true, false)
		if buy_btn and buy_btn is Button:
			buy_btn.disabled = !enabled


func _on_query_purchases_response(_query_result):
	# Gestionado por IAPService; dejamos el stub por compatibilidad
	pass


func _on_sku_details_query_completed(sku_details):
	if sku_details.is_empty():
		var not_found = "No se encontró el producto en la Play Store: %s" % product_sku
		show_alert(not_found)
		label.text = not_found
		return
	# Mostramos información del primer SKU (estamos consultando solo uno).
	var first = sku_details[0]
	var sku_id = first.get("sku", product_sku)
	var title = first.get("title", sku_id)
	var description = first.get("description", "")
	var price = first.get("price", first.get("formatted_price", "-"))
	var currency = first.get("price_currency_code", "")
	var type = first.get("type", "inapp")

	var price_text = "%s%s" % [price, currency]
	if currency == "":
		price_text = "%s" % price

	var details_text = "Producto encontrado:"
	details_text += "\nID: %s" % sku_id
	details_text += "\nNombre: %s" % title
	details_text += "\nPrecio: %s" % price_text
	details_text += "\nTipo: %s" % type
	if description != "":
		details_text += "\n\nDescripción:\n%s" % description

	label.text = details_text

	# Mensaje flotante para confirmar visualmente.
	show_alert("SKU cargado: %s" % sku_id)


func _on_purchases_updated(purchases):
	print("Purchases updated: %s" % JSON.new().stringify(purchases))
	if purchases.size() > 0:
		var last = purchases[purchases.size() - 1]
		test_item_purchase_token = last.get("purchase_token", null)
		last_sku = last.get("sku", "")


func _on_purchase_acknowledged(purchase_token):
	print("Purchase acknowledged: %s" % purchase_token)
	# Registrar compra y preparar descarga/instalación de contenido
	var sku_to_use = last_sku if last_sku != "" else product_sku
	label.text = "Compra confirmada: %s" % sku_to_use
	show_alert("Compra confirmada: %s" % sku_to_use)


func _on_purchase_consumed(purchase_token):
	show_alert("Purchase consumed successfully: %s" % purchase_token)


func _on_connect_error(code, message):
	var msg = "Connect error %d: %s" % [code, message]
	label.text = msg
	show_alert(msg)


func _on_purchase_error(code, message):
	var msg = "Purchase error %d: %s" % [code, message]
	label.text = msg
	show_alert(msg)


func _on_purchase_acknowledgement_error(code, message):
	var msg = "Purchase acknowledgement error %d: %s" % [code, message]
	label.text = msg
	show_alert(msg)


func _on_purchase_consumption_error(code, message, purchase_token):
	var msg = "Purchase consumption error %d: %s, token: %s" % [code, message, purchase_token]
	label.text = msg
	show_alert(msg)


func _on_sku_details_query_error(code, message):
	var msg = "SKU details query error %d: %s" % [code, message]
	label.text = msg
	show_alert(msg)


func _on_disconnected():
	label.text = "Desconectado. Reintentando conexión en 10s..."
	show_alert("IAPService disconnected. Will try to reconnect in 10s...")
	await get_tree().create_timer(10).timeout
	# Reconexión manejada por IAPService


# GUI
func _on_QuerySkuDetailsButton_pressed():
	print('sku', product_sku)
	if has_node("/root/IAPService"):
		get_node("/root/IAPService").query_products([product_sku])


func _on_PurchaseButton_pressed():
	if has_node("/root/IAPService"):
		get_node("/root/IAPService").purchase(product_sku)


func _on_ConsumeButton_pressed():
	show_alert("Consume no soportado en esta tienda genérica")

func exit_confirmed():
	emit_signal("exit_canceled")

	
# ========== Manejo de señales del IapService ==========
func _on_purchase_started(pack_id: String):
	print("Store: Compra iniciada para: ", pack_id)
	_show_progress_panel()
	if progress_detail:
		progress_detail.text = "Iniciando compra de: " + pack_id
	if progress_bar:
		progress_bar.value = 10.0

func _on_purchase_completed(pack_id: String, success: bool):
	print("Store: Compra completada para ", pack_id, " - Éxito: ", success)
	if success:
		if progress_detail:
			progress_detail.text = "Compra exitosa: " + pack_id + "\nIniciando descarga..."
		if progress_bar:
			progress_bar.value = 30.0
	else:
		if progress_detail:
			progress_detail.text = "Error en la compra de: " + pack_id
		show_alert("Error en la compra de: " + pack_id)
		_hide_progress_panel_delayed()

func _on_download_started(pack_id: String):
	print("Store: Descarga iniciada para: ", pack_id)
	if progress_detail:
		progress_detail.text = "Descargando: " + pack_id
	if progress_bar:
		progress_bar.value = 40.0

func _on_download_progress(pack_id: String, progress: float):
	print("Store: Progreso de descarga para ", pack_id, ": ", progress * 100, "%")
	if progress_bar:
		# Mapear progreso de descarga al rango 40-80%
		var bar_progress = 40.0 + (progress * 40.0)
		progress_bar.value = bar_progress
	if progress_detail:
		progress_detail.text = "Descargando: " + pack_id + "\n" + str(int(progress * 100)) + "% completado"

func _on_download_completed(pack_id: String, success: bool):
	print("Store: Descarga completada para ", pack_id, " - Éxito: ", success)
	if success:
		if progress_detail:
			progress_detail.text = "Descarga completada: " + pack_id + "\nInstalando..."
		if progress_bar:
			progress_bar.value = 80.0
	else:
		if progress_detail:
			progress_detail.text = "Error en la descarga de: " + pack_id
		show_alert("Error en la descarga de: " + pack_id)
		_hide_progress_panel_delayed()

func _on_installation_completed(pack_id: String, success: bool):
	print("Store: Instalación completada para ", pack_id, " - Éxito: ", success)
	if success:
		if progress_detail:
			progress_detail.text = "¡Pack instalado exitosamente!\n" + pack_id
		if progress_bar:
			progress_bar.value = 100.0
		show_alert("¡Pack " + pack_id + " instalado exitosamente!")
		
		# Recargar la lista de DLC disponibles
		_reload_store_after_purchase()
	else:
		if progress_detail:
			progress_detail.text = "Error en la instalación de: " + pack_id
		show_alert("Error en la instalación de: " + pack_id)
	
	_hide_progress_panel_delayed()

# Recargar tienda después de una compra exitosa
func _reload_store_after_purchase():
	await get_tree().create_timer(2.0).timeout # Esperar un poco antes de recargar
	print("Store: Recargando tienda después de compra...")
	_load_available_dlcs()

# ========== UI Progress helpers ==========
func _show_progress_panel():
	if progress_panel:
		progress_panel.visible = true

func _hide_progress_panel_delayed():
	await get_tree().create_timer(2.0).timeout
	if progress_panel:
		progress_panel.visible = false
