extends Node

signal connected
signal disconnected
signal sku_details(details: Array) # Array[Dictionary] normalizados
signal purchases_updated(purchases: Array) # Array[Dictionary] con {sku, purchase_token, is_acknowledged}
signal purchase_error(code: int, message: String)
signal connect_error(code: int, message: String)
signal purchase_acknowledged(token: String)
signal query_purchases_result(result: Dictionary)

const OFFICIAL_BILLING_CLIENT_PATH := "res://addons/GodotGooglePlayBilling/BillingClient.gd"

enum BillingResponseCode {
	OK = 0,
	USER_CANCELED = 1,
	SERVICE_UNAVAILABLE = 2,
	BILLING_UNAVAILABLE = 3,
	ITEM_UNAVAILABLE = 4,
	DEVELOPER_ERROR = 5,
	ERROR = 6,
	ITEM_ALREADY_OWNED = 7,
	ITEM_NOT_OWNED = 8,
	NETWORK_ERROR = 12,
	SERVICE_DISCONNECTED = -1,
	FEATURE_NOT_SUPPORTED = -2,
	SERVICE_TIMEOUT = -3
}

enum PurchaseState {
	UNSPECIFIED_STATE,
	PURCHASED,
	PENDING
}

var _billing = null
var _uses_official_wrapper := false
var default_product_type: String = "subs" # "inapp" | "subs"

func set_default_product_type(t: String) -> void:
	default_product_type = t

func is_available() -> bool:
	var is_android_runtime := OS.has_feature("android") or OS.get_name().to_lower() == "android"
	return (is_android_runtime and ResourceLoader.exists(OFFICIAL_BILLING_CLIENT_PATH)) or Engine.has_singleton("GodotGooglePlayBilling")

func initialize() -> void:
	if ResourceLoader.exists(OFFICIAL_BILLING_CLIENT_PATH) and (OS.has_feature("android") or OS.get_name().to_lower() == "android"):
		var BillingClientScript = load(OFFICIAL_BILLING_CLIENT_PATH)
		if BillingClientScript:
			_billing = BillingClientScript.new()
			_uses_official_wrapper = true
			_billing.connected.connect(_on_connected)
			_billing.disconnected.connect(_on_disconnected)
			_billing.connect_error.connect(_on_connect_error)
			_billing.query_product_details_response.connect(_on_query_product_details_response_modern)
			_billing.query_purchases_response.connect(_on_query_purchases_response_modern)
			_billing.on_purchase_updated.connect(_on_purchase_updated_modern)
			_billing.acknowledge_purchase_response.connect(_on_acknowledge_purchase_response_modern)
			return

	if not Engine.has_singleton("GodotGooglePlayBilling"):
		return

	_billing = Engine.get_singleton("GodotGooglePlayBilling")
	_uses_official_wrapper = false
	_billing.connected.connect(_on_connected)
	_billing.disconnected.connect(_on_disconnected)
	_billing.connect_error.connect(_on_connect_error)
	_billing.purchases_updated.connect(_on_purchases_updated_legacy)
	_billing.purchase_error.connect(_on_purchase_error)
	_billing.sku_details_query_completed.connect(_on_sku_details_query_completed_legacy)
	_billing.sku_details_query_error.connect(_on_sku_details_query_error)
	_billing.purchase_acknowledged.connect(_on_purchase_acknowledged)
	_billing.purchase_acknowledgement_error.connect(_on_purchase_acknowledgement_error)
	_billing.purchase_consumed.connect(func(_t): pass)
	_billing.purchase_consumption_error.connect(func(_c,_m,_t): pass)
	_billing.query_purchases_response.connect(_on_query_purchases_response_legacy)

func start_connection():
	if _billing:
		if _uses_official_wrapper:
			_billing.start_connection()
		else:
			_billing.startConnection()

func end_connection():
	if _billing:
		if _uses_official_wrapper:
			_billing.end_connection()
		else:
			_billing.endConnection()

func query_products(skus: Array, product_type: String = default_product_type):
	if not _billing:
		return
	if _uses_official_wrapper:
		_billing.query_product_details(PackedStringArray(skus), _to_modern_product_type(product_type))
	else:
		_billing.querySkuDetails(skus, product_type)

func query_purchases(product_type: String = default_product_type):
	if not _billing:
		return
	if _uses_official_wrapper:
		_billing.query_purchases(_to_modern_product_type(product_type))
	else:
		_billing.queryPurchases(product_type)

func purchase(sku: String, product_meta: Dictionary = {}) -> void:
	if not _billing:
		return
	if _uses_official_wrapper:
		if _is_subscription(product_meta):
			var base_plan_id := str(product_meta.get("base_plan_id", ""))
			var offer_id := str(product_meta.get("offer_id", ""))
			if base_plan_id == "":
				purchase_error.emit(BillingResponseCode.DEVELOPER_ERROR, "Missing base_plan_id for subscription '%s'" % sku)
				return
			var response = _billing.purchase_subscription(sku, base_plan_id, offer_id)
			if response.get("response_code", BillingResponseCode.ERROR) != BillingResponseCode.OK:
				purchase_error.emit(response.get("response_code", BillingResponseCode.ERROR), response.get("debug_message", ""))
		else:
			var modern_response = _billing.purchase(sku)
			if modern_response.get("response_code", BillingResponseCode.ERROR) != BillingResponseCode.OK:
				purchase_error.emit(modern_response.get("response_code", BillingResponseCode.ERROR), modern_response.get("debug_message", ""))
	else:
		var response = _billing.purchase(sku)
		if response.status != OK:
			purchase_error.emit(response.response_code, response.debug_message)

func acknowledge(purchase_token: String) -> void:
	if _billing:
		if _uses_official_wrapper:
			_billing.acknowledge_purchase(purchase_token)
		else:
			_billing.acknowledgePurchase(purchase_token)

func restore_purchases() -> void:
	query_purchases(default_product_type)

func open_subscriptions_page(product_id: String = "") -> void:
	if _billing and _uses_official_wrapper and _billing.has_method("open_subscriptions_page"):
		_billing.open_subscriptions_page(product_id)

func _is_subscription(product_meta: Dictionary) -> bool:
	return str(product_meta.get("product_type", default_product_type)) == "subs"

func _to_modern_product_type(product_type: String):
	if product_type == "subs":
		return _billing.ProductType.SUBS
	return _billing.ProductType.INAPP

func _extract_modern_price(details: Dictionary) -> String:
	var one_time_offer = details.get("one_time_purchase_offer_details", {})
	if typeof(one_time_offer) == TYPE_DICTIONARY and one_time_offer.has("formatted_price"):
		return str(one_time_offer.get("formatted_price", ""))

	var offers = details.get("subscription_offer_details", [])
	if typeof(offers) == TYPE_ARRAY and offers.size() > 0:
		var offer = offers[0]
		if typeof(offer) == TYPE_DICTIONARY:
			var pricing_phases = offer.get("pricing_phases", {})
			if typeof(pricing_phases) == TYPE_DICTIONARY:
				var pricing_phase_list = pricing_phases.get("pricing_phase_list", [])
				if typeof(pricing_phase_list) == TYPE_ARRAY and pricing_phase_list.size() > 0:
					return str(pricing_phase_list[0].get("formatted_price", ""))

	return str(details.get("formatted_price", ""))

func _normalize_modern_purchase(purchase: Dictionary) -> Dictionary:
	var product_ids = purchase.get("product_ids", PackedStringArray())
	var sku := ""
	if typeof(product_ids) == TYPE_PACKED_STRING_ARRAY and product_ids.size() > 0:
		sku = str(product_ids[0])
	elif typeof(product_ids) == TYPE_ARRAY and product_ids.size() > 0:
		sku = str(product_ids[0])

	return {
		"sku": sku,
		"product_ids": product_ids,
		"purchase_token": purchase.get("purchase_token", ""),
		"is_acknowledged": purchase.get("is_acknowledged", false),
		"is_auto_renewing": purchase.get("is_auto_renewing", false),
		"purchase_state": purchase.get("purchase_state", PurchaseState.UNSPECIFIED_STATE)
	}

# ===== signal handlers =====

func _on_connected():
	connected.emit()

func _on_disconnected():
	disconnected.emit()

func _on_connect_error(code, message):
	connect_error.emit(code, message)

func _on_purchase_error(code, message):
	purchase_error.emit(code, message)

func _on_sku_details_query_completed_legacy(sku_details):
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
	self.sku_details.emit(normalized)

func _on_query_product_details_response_modern(query_result: Dictionary):
	if query_result.get("response_code", BillingResponseCode.ERROR) != BillingResponseCode.OK:
		connect_error.emit(query_result.get("response_code", BillingResponseCode.ERROR), query_result.get("debug_message", ""))
		return

	var normalized: Array = []
	for details in query_result.get("product_details", []):
		normalized.append({
			"sku": details.get("product_id", ""),
			"title": details.get("name", details.get("title", details.get("product_id", ""))),
			"description": details.get("description", ""),
			"price": _extract_modern_price(details),
			"currency": "",
			"type": default_product_type,
			"raw": details
		})
	sku_details.emit(normalized)

func _on_sku_details_query_error(code, message):
	connect_error.emit(code, message)

func _on_query_purchases_response_legacy(query_result):
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

func _on_query_purchases_response_modern(query_result: Dictionary):
	var result = {
		"status": OK if query_result.get("response_code", BillingResponseCode.ERROR) == BillingResponseCode.OK else ERR_CANT_CONNECT,
		"response_code": query_result.get("response_code", BillingResponseCode.ERROR),
		"debug_message": query_result.get("debug_message", ""),
		"purchases": []
	}
	for purchase in query_result.get("purchases", []):
		result.purchases.append(_normalize_modern_purchase(purchase))
	query_purchases_result.emit(result)
	if result.status == OK:
		purchases_updated.emit(result.purchases)

func _on_purchases_updated_legacy(purchases):
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

func _on_purchase_updated_modern(query_result: Dictionary):
	if query_result.get("response_code", BillingResponseCode.ERROR) != BillingResponseCode.OK:
		purchase_error.emit(query_result.get("response_code", BillingResponseCode.ERROR), query_result.get("debug_message", ""))
		return

	var normalized: Array = []
	for purchase in query_result.get("purchases", []):
		var normalized_purchase = _normalize_modern_purchase(purchase)
		if not normalized_purchase.get("is_acknowledged", false):
			_billing.acknowledge_purchase(str(normalized_purchase.get("purchase_token", "")))
		normalized.append(normalized_purchase)
	purchases_updated.emit(normalized)

func _on_purchase_acknowledged(purchase_token):
	purchase_acknowledged.emit(purchase_token)

func _on_acknowledge_purchase_response_modern(result: Dictionary):
	if result.get("response_code", BillingResponseCode.ERROR) == BillingResponseCode.OK:
		purchase_acknowledged.emit(str(result.get("token", "")))
	else:
		purchase_error.emit(result.get("response_code", BillingResponseCode.ERROR), result.get("debug_message", ""))

func _on_purchase_acknowledgement_error(code, message):
	purchase_error.emit(code, message)
