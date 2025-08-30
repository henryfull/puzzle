extends Node

signal connected
signal disconnected
signal sku_details(details: Array) # Array[Dictionary] normalizados
signal purchases_updated(purchases: Array) # Array[Dictionary] con {sku, purchase_token, is_acknowledged}
signal purchase_error(code: int, message: String)
signal connect_error(code: int, message: String)
signal purchase_acknowledged(token: String)
signal query_purchases_result(result: Dictionary)

var _billing = null
var default_product_type: String = "inapp" # o "subs"

func set_default_product_type(t: String) -> void:
	default_product_type = t

func is_available() -> bool:
	return Engine.has_singleton("GodotGooglePlayBilling")

func initialize() -> void:
	if not is_available():
		return
	_billing = Engine.get_singleton("GodotGooglePlayBilling")
	_billing.connected.connect(_on_connected)
	_billing.disconnected.connect(_on_disconnected)
	_billing.connect_error.connect(_on_connect_error)
	_billing.purchases_updated.connect(_on_purchases_updated)
	_billing.purchase_error.connect(_on_purchase_error)
	_billing.sku_details_query_completed.connect(_on_sku_details_query_completed)
	_billing.sku_details_query_error.connect(_on_sku_details_query_error)
	_billing.purchase_acknowledged.connect(_on_purchase_acknowledged)
	_billing.purchase_acknowledgement_error.connect(_on_purchase_acknowledgement_error)
	_billing.purchase_consumed.connect(func(_t): pass)
	_billing.purchase_consumption_error.connect(func(_c,_m,_t): pass)
	_billing.query_purchases_response.connect(_on_query_purchases_response)

func start_connection():
	if _billing:
		_billing.startConnection()

func end_connection():
	if _billing:
		_billing.endConnection()

func query_products(skus: Array, product_type: String = default_product_type):
	if _billing:
		_billing.querySkuDetails(skus, product_type)

func query_purchases(product_type: String = default_product_type):
	if _billing:
		_billing.queryPurchases(product_type)

func purchase(sku: String) -> void:
	if _billing:
		var response = _billing.purchase(sku)
		if response.status != OK:
			purchase_error.emit(response.response_code, response.debug_message)

func acknowledge(purchase_token: String) -> void:
	if _billing:
		_billing.acknowledgePurchase(purchase_token)

# ===== signal handlers =====

func _on_connected():
	connected.emit()

func _on_disconnected():
	disconnected.emit()

func _on_connect_error(code, message):
	connect_error.emit(code, message)

func _on_purchase_error(code, message):
	purchase_error.emit(code, message)

func _on_sku_details_query_completed(sku_details):
	var normalized: Array = []
	for d in sku_details:
		normalized.append({
			"sku": d.get("sku", ""),
			"title": d.get("title", ""),
			"description": d.get("description", ""),
			"price": d.get("price", d.get("formatted_price", "")),
			"currency": d.get("price_currency_code", ""),
			"type": d.get("type", default_product_type)
		})
	sku_details.emit(normalized)

func _on_sku_details_query_error(code, message):
	connect_error.emit(code, message)

func _on_query_purchases_response(query_result):
	var result = {
		"status": query_result.status,
		"response_code": query_result.response_code,
		"debug_message": query_result.debug_message,
		"purchases": []
	}
	for p in query_result.purchases:
		result.purchases.append({
			"sku": p.get("sku", ""),
			"purchase_token": p.get("purchase_token", ""),
			"is_acknowledged": p.get("is_acknowledged", false)
		})
	query_purchases_result.emit(result)
	if result.status == OK:
		purchases_updated.emit(result.purchases)

func _on_purchases_updated(purchases):
	var normalized: Array = []
	for p in purchases:
		if not p.is_acknowledged:
			_billing.acknowledgePurchase(p.purchase_token)
		normalized.append({
			"sku": p.get("sku", ""),
			"purchase_token": p.get("purchase_token", ""),
			"is_acknowledged": p.get("is_acknowledged", false)
		})
	purchases_updated.emit(normalized)

func _on_purchase_acknowledged(purchase_token):
	purchase_acknowledged.emit(purchase_token)

func _on_purchase_acknowledgement_error(code, message):
	purchase_error.emit(code, message)
