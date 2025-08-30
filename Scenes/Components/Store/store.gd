extends Control

@export var product_sku: String = "started_pack"
signal exit_canceled


@export var alert_dialog : AcceptDialog
@export var label: Label

@export var buy_button: Button
@export var consume_button: Button
@export var checkButton: Button

var payment = null # Deprecated: usamos IAPService
var test_item_purchase_token = null
var last_sku := ""

func _process_successful_purchase(_sku: String, _purchase_token: String) -> void:
	# Obsoleto: EntitlementsService gestiona el contenido adquirido.
	pass

func _ready():
	label.text = "Conectando a servicios de compra...\nSKU: %s" % product_sku
	_set_ui_enabled(false)
	if has_node("/root/IAPService"):
		var iap = get_node("/root/IAPService")
		iap.connected.connect(_on_connected)
		iap.disconnected.connect(_on_disconnected)
		iap.connect_error.connect(_on_connect_error)
		iap.sku_details.connect(_on_sku_details_query_completed)
		iap.purchase_error.connect(_on_purchase_error)
		iap.purchases_updated.connect(_on_purchases_updated)
		iap.purchase_acknowledged.connect(_on_purchase_acknowledged)
	else:
		show_alert('IAPService no está disponible')
		_set_ui_enabled(false)

func _set_ui_enabled(enabled: bool) -> void:
	buy_button.disabled = not enabled
	consume_button.disabled = not enabled
	checkButton.disabled = not enabled


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

	
