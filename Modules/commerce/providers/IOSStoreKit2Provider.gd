extends Node

signal connected
signal disconnected
signal sku_details(details: Array)
signal purchases_updated(purchases: Array)
signal purchase_error(code: int, message: String)
signal connect_error(code: int, message: String)
signal purchase_acknowledged(token: String)
signal query_purchases_result(result: Dictionary)

const STORE_PRODUCTS_PATH := "res://Modules/commerce/config/store_products.json"

enum BillingResponseCode {
	OK = 0,
	USER_CANCELED = 1,
	SERVICE_UNAVAILABLE = 2,
	BILLING_UNAVAILABLE = 3,
	ITEM_UNAVAILABLE = 4,
	DEVELOPER_ERROR = 5,
	ERROR = 6,
	ITEM_ALREADY_OWNED = 7,
	ITEM_NOT_OWNED = 8
}

enum TransactionState {
	FAILED,
	REFUNDED,
	PENDING,
	DEFERRED,
	PURCHASED,
	RESTORED,
	EXPIRED,
	CANCELED
}

var default_product_type: String = "subs"
var _store_kit: RefCounted = null
var _store_products: Dictionary = {}
var _active_purchases: Dictionary = {}

func set_default_product_type(product_type: String) -> void:
	default_product_type = product_type

func set_store_products(products: Array) -> void:
	_store_products.clear()
	for product in products:
		if typeof(product) != TYPE_DICTIONARY:
			continue
		var sku := str(product.get("sku", ""))
		if sku != "":
			_store_products[sku] = product.duplicate(true)

func is_available() -> bool:
	var is_ios_runtime := OS.has_feature("ios") or OS.get_name().to_lower() == "ios"
	return is_ios_runtime and ClassDB.class_exists("GodotStoreKit2")

func initialize() -> void:
	if not is_available():
		return
	_store_kit = ClassDB.instantiate("GodotStoreKit2")
	if _store_kit == null:
		return
	_store_kit.transaction_state_changed.connect(_on_transaction_state_changed)
	_store_kit.synchronized.connect(_on_synchronized)

func start_connection() -> void:
	if _store_kit:
		call_deferred("_emit_connected")
	else:
		connect_error.emit(BillingResponseCode.BILLING_UNAVAILABLE, "StoreKit 2 plugin is not enabled in the iOS export preset.")

func _emit_connected() -> void:
	connected.emit()

func end_connection() -> void:
	disconnected.emit()

func query_products(skus: Array, _product_type: String = default_product_type) -> void:
	if _store_kit == null:
		connect_error.emit(BillingResponseCode.BILLING_UNAVAILABLE, "StoreKit 2 is not available.")
		return
	_query_products_async(skus)

func query_purchases(_product_type: String = default_product_type) -> void:
	if _store_kit == null:
		query_purchases_result.emit({
			"status": ERR_UNAVAILABLE,
			"response_code": BillingResponseCode.BILLING_UNAVAILABLE,
			"debug_message": "StoreKit 2 is not available.",
			"purchases": []
		})
		return
	_query_purchases_async()

func purchase(sku: String, _product_meta: Dictionary = {}) -> void:
	if _store_kit == null:
		purchase_error.emit(BillingResponseCode.BILLING_UNAVAILABLE, "StoreKit 2 is not available.")
		return
	_store_kit.purchase_product(sku, 1)

func acknowledge(_purchase_token: String) -> void:
	pass

func restore_purchases() -> void:
	if _store_kit == null:
		purchase_error.emit(BillingResponseCode.BILLING_UNAVAILABLE, "StoreKit 2 is not available.")
		return
	_store_kit.sync()

func open_subscriptions_page(_product_id: String = "") -> void:
	OS.shell_open("https://apps.apple.com/account/subscriptions")

func _get_store_products_path() -> String:
	if ProjectSettings.has_setting("commerce/store_products_path"):
		return str(ProjectSettings.get_setting("commerce/store_products_path"))
	return STORE_PRODUCTS_PATH

func _load_store_products() -> Dictionary:
	if not _store_products.is_empty():
		return _store_products
	var path := _get_store_products_path()
	if not ResourceLoader.exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _get_configured_skus() -> Array:
	var skus: Array = []
	for sku in _load_store_products().keys():
		skus.append(str(sku))
	skus.sort()
	return skus

func _query_products_async(skus: Array) -> void:
	var normalized: Array = []
	var first_error := ""
	for raw_sku in skus:
		var sku := str(raw_sku)
		if sku == "":
			continue
		var result = await _store_kit.request_product_info(sku)
		if typeof(result) != TYPE_DICTIONARY:
			continue
		var error_message := str(result.get("error", ""))
		if error_message != "":
			if first_error == "":
				first_error = error_message
			continue
		normalized.append(_normalize_product_info(result))
	if normalized.is_empty() and first_error != "":
		connect_error.emit(BillingResponseCode.ITEM_UNAVAILABLE, first_error)
		return
	sku_details.emit(normalized)

func _query_purchases_async() -> void:
	var purchases: Array = []
	for sku in _get_configured_skus():
		var result = await _store_kit.request_product_info(sku)
		if typeof(result) != TYPE_DICTIONARY:
			continue
		if str(result.get("error", "")) != "":
			continue
		if bool(result.get("is_purchased", false)):
			purchases.append(_normalize_purchase(str(result.get("product_id", sku)), TransactionState.PURCHASED))

	_active_purchases.clear()
	for purchase in purchases:
		_active_purchases[str(purchase.get("sku", ""))] = purchase

	query_purchases_result.emit({
		"status": OK,
		"response_code": BillingResponseCode.OK,
		"debug_message": "",
		"purchases": purchases
	})
	purchases_updated.emit(purchases)

func _normalize_product_info(info: Dictionary) -> Dictionary:
	return {
		"sku": str(info.get("product_id", "")),
		"title": str(info.get("display_name", info.get("product_id", ""))),
		"description": str(info.get("description", "")),
		"price": str(info.get("localized_price", "")),
		"currency": str(info.get("currency_code", "")),
		"type": default_product_type,
		"raw": info
	}

func _normalize_purchase(sku: String, transaction_state: int) -> Dictionary:
	return {
		"sku": sku,
		"product_ids": [sku],
		"purchase_token": "ios:%s" % sku,
		"is_acknowledged": true,
		"transaction_state": transaction_state
	}

func _on_transaction_state_changed(transaction: Dictionary) -> void:
	if typeof(transaction) != TYPE_DICTIONARY:
		return
	var error_message := str(transaction.get("error", ""))
	if error_message != "":
		purchase_error.emit(BillingResponseCode.ERROR, error_message)
		return

	var sku := str(transaction.get("product_id", ""))
	var transaction_state := int(transaction.get("transaction_state", TransactionState.FAILED))

	match transaction_state:
		TransactionState.PURCHASED, TransactionState.RESTORED:
			var purchase := _normalize_purchase(sku, transaction_state)
			_active_purchases[sku] = purchase
			purchases_updated.emit([purchase])
			purchase_acknowledged.emit(str(purchase.get("purchase_token", "")))
			query_purchases()
		TransactionState.REFUNDED, TransactionState.EXPIRED:
			_active_purchases.erase(sku)
			query_purchases()
		TransactionState.CANCELED:
			purchase_error.emit(BillingResponseCode.USER_CANCELED, "Purchase canceled by user.")
		TransactionState.PENDING, TransactionState.DEFERRED:
			purchase_error.emit(BillingResponseCode.SERVICE_UNAVAILABLE, "Purchase is pending confirmation.")
		_:
			purchase_error.emit(BillingResponseCode.ERROR, "StoreKit transaction failed for '%s'." % sku)

func _on_synchronized(_error_message = "") -> void:
	query_purchases()
