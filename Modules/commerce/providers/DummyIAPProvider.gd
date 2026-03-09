extends Node

signal connected
signal disconnected
signal sku_details(details: Array)
signal purchases_updated(purchases: Array)
signal purchase_error(code: int, message: String)
signal connect_error(code: int, message: String)
signal purchase_acknowledged(token: String)
signal query_purchases_result(result: Dictionary)

var default_product_type: String = "subs"
var owned: Array = []

func set_default_product_type(t: String) -> void:
    default_product_type = t

func is_available() -> bool:
    return true

func initialize():
    await get_tree().process_frame
    connected.emit()

func start_connection():
    await get_tree().process_frame
    connected.emit()

func end_connection():
    disconnected.emit()

func query_products(skus: Array, _product_type: String = default_product_type):
    var details: Array = []
    for s in skus:
        details.append({"sku": s, "title": s.capitalize(), "description": "Demo product "+s, "price": "1.99", "currency": "EUR", "type": default_product_type})
    sku_details.emit(details)

func query_purchases(_product_type: String = default_product_type):
    var result = {"status": OK, "response_code": 0, "debug_message": "", "purchases": owned}
    query_purchases_result.emit(result)
    purchases_updated.emit(owned)

func purchase(sku: String, _product_meta: Dictionary = {}) -> void:
    var token = "dummy_"+sku+"_"+str(Time.get_ticks_msec())
    var p = {"sku": sku, "purchase_token": token, "is_acknowledged": false}
    owned.append(p)
    purchases_updated.emit([p])
    await get_tree().create_timer(0.1).timeout
    purchase_acknowledged.emit(token)

func acknowledge(_token: String) -> void:
    pass

func restore_purchases() -> void:
    query_purchases()

func open_subscriptions_page(_sku: String = "") -> void:
    pass
