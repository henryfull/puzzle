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

@export var default_product_type: String = "subs" # "inapp" | "subs"

var _provider: Node

func _ready():
	_select_provider()
	_sync_provider_configuration()
	_wire_provider()
	_provider.initialize()
	_provider.start_connection()

func _select_provider():
	var provider_scripts: Array = [
		load("res://Modules/commerce/providers/GooglePlayBillingProvider.gd"),
		load("res://Modules/commerce/providers/IOSStoreKit2Provider.gd")
	]
	var DummyProvider = load("res://Modules/commerce/providers/DummyIAPProvider.gd")
	for provider_script in provider_scripts:
		if provider_script == null:
			continue
		var candidate = provider_script.new()
		if candidate.is_available():
			_provider = candidate
			break
	if _provider == null:
		_provider = DummyProvider.new()
	add_child(_provider)

func _sync_provider_configuration() -> void:
	if _provider == null:
		return
	if _provider.has_method("set_default_product_type"):
		_provider.set_default_product_type(default_product_type)
	if _provider.has_method("set_store_products"):
		_provider.set_store_products(get_configured_products())

func _get_store_products_path() -> String:
	if ProjectSettings.has_setting("commerce/store_products_path"):
		return str(ProjectSettings.get_setting("commerce/store_products_path"))
	return STORE_PRODUCTS_PATH

func _load_store_products() -> Dictionary:
	var path := _get_store_products_path()
	if not ResourceLoader.exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _wire_provider():
	_provider.connected.connect(func(): connected.emit())
	_provider.disconnected.connect(func(): disconnected.emit())
	_provider.sku_details.connect(func(details): sku_details.emit(details))
	_provider.purchases_updated.connect(func(p): purchases_updated.emit(p))
	_provider.purchase_acknowledged.connect(func(t): purchase_acknowledged.emit(t))
	_provider.purchase_error.connect(func(c,m): purchase_error.emit(c,m))
	_provider.connect_error.connect(func(c,m): connect_error.emit(c,m))
	_provider.query_purchases_result.connect(func(r): query_purchases_result.emit(r))

func get_configured_products() -> Array:
	var configured_products: Array = []
	var stored_products = _load_store_products()
	for sku in stored_products.keys():
		var entry = stored_products[sku]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var normalized = entry.duplicate(true)
		normalized["sku"] = str(sku)
		configured_products.append(normalized)
	configured_products.sort_custom(func(a, b): return str(a.get("sku", "")) < str(b.get("sku", "")))
	return configured_products

func get_configured_skus() -> Array:
	var skus: Array = []
	for product in get_configured_products():
		skus.append(str(product.get("sku", "")))
	return skus

func get_product_config(sku: String) -> Dictionary:
	var products = _load_store_products()
	if typeof(products) == TYPE_DICTIONARY and products.has(sku):
		var config = products[sku]
		if typeof(config) == TYPE_DICTIONARY:
			var normalized = config.duplicate(true)
			normalized["sku"] = sku
			return normalized
	return {}

func is_available() -> bool:
	return _provider != null and _provider.has_method("is_available") and _provider.is_available()

func set_default_product_type(product_type: String) -> void:
	default_product_type = product_type
	if _provider and _provider.has_method("set_default_product_type"):
		_provider.set_default_product_type(product_type)

func query_products(skus: Array = []) -> void:
	if skus.is_empty():
		skus = get_configured_skus()
	_provider.query_products(skus, default_product_type)

func query_purchases() -> void:
	_provider.query_purchases(default_product_type)

func purchase(sku: String) -> void:
	_provider.purchase(sku, get_product_config(sku))

func acknowledge(token: String) -> void:
	_provider.acknowledge(token)

func restore_purchases() -> void:
	if _provider and _provider.has_method("restore_purchases"):
		_provider.restore_purchases()
	else:
		query_purchases()

func open_subscriptions_page(sku: String = "") -> void:
	if _provider and _provider.has_method("open_subscriptions_page"):
		_provider.open_subscriptions_page(sku)
