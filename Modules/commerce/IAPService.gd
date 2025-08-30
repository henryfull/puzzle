extends Node

signal connected
signal disconnected
signal sku_details(details: Array)
signal purchases_updated(purchases: Array)
signal purchase_error(code: int, message: String)
signal connect_error(code: int, message: String)
signal purchase_acknowledged(token: String)
signal query_purchases_result(result: Dictionary)

@export var default_product_type: String = "inapp" # or "subs"

var _provider: Node

func _ready():
	_select_provider()
	_wire_provider()
	_provider.initialize()
	_provider.start_connection()

func _select_provider():
	var GoogleProvider = load("res://Modules/commerce/providers/GooglePlayBillingProvider.gd")
	var DummyProvider = load("res://Modules/commerce/providers/DummyIAPProvider.gd")
	var p = GoogleProvider.new()
	if p.is_available():
		_provider = p
	else:
		_provider = DummyProvider.new()
	add_child(_provider)
	if _provider.has_method("set_default_product_type"):
		_provider.set_default_product_type(default_product_type)

func _wire_provider():
	_provider.connected.connect(func(): connected.emit())
	_provider.disconnected.connect(func(): disconnected.emit())
	_provider.sku_details.connect(func(details): sku_details.emit(details))
	_provider.purchases_updated.connect(func(p): purchases_updated.emit(p))
	_provider.purchase_acknowledged.connect(func(t): purchase_acknowledged.emit(t))
	_provider.purchase_error.connect(func(c,m): purchase_error.emit(c,m))
	_provider.connect_error.connect(func(c,m): connect_error.emit(c,m))
	_provider.query_purchases_result.connect(func(r): query_purchases_result.emit(r))

func query_products(skus: Array) -> void:
	_provider.query_products(skus, default_product_type)

func query_purchases() -> void:
	_provider.query_purchases(default_product_type)

func purchase(sku: String) -> void:
	_provider.purchase(sku)

func acknowledge(token: String) -> void:
	_provider.acknowledge(token)
