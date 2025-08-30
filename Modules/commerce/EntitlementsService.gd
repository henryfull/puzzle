extends Node

# Servicio agnóstico: escucha compras del IAPService y aplica "entitlements".

signal entitlements_changed()

@export var auto_download := true

func _ready():
    if has_node("/root/IAPService"):
        var iap = get_node("/root/IAPService")
        iap.connected.connect(_on_iap_connected)
        iap.purchases_updated.connect(_on_purchases_updated)
        iap.purchase_acknowledged.connect(_on_purchase_acknowledged)
        iap.query_purchases_result.connect(_on_query_purchases_result)

func _on_iap_connected():
    # Consultar compras existentes al conectar
    var iap = get_node("/root/IAPService")
    iap.query_purchases()

func _on_query_purchases_result(result: Dictionary):
    if result.get("status", ERR_DOES_NOT_EXIST) == OK:
        for p in result.get("purchases", []):
            _apply_entitlement_for_purchase(p)

func _on_purchases_updated(purchases: Array):
    for p in purchases:
        _apply_entitlement_for_purchase(p)

func _on_purchase_acknowledged(_token: String):
    # Nada extra por ahora; _apply_entitlement_for_purchase ya maneja el contenido
    pass

func _apply_entitlement_for_purchase(purchase: Dictionary):
    var sku: String = purchase.get("sku", "")
    var token: String = purchase.get("purchase_token", "")
    if sku == "":
        return
    # Flag por SKU en settings (usar GLOBAL si existe; si no, persistir directamente)
    if has_node("/root/GLOBAL"):
        var g = get_node("/root/GLOBAL")
        if not g.settings.has("purchases"):
            g.settings["purchases"] = {}
        g.settings.purchases[sku] = true
        if g.has_method("save_settings"):
            g.save_settings()
    else:
        var cfg := ConfigFile.new()
        var err = cfg.load("user://settings.cfg")
        if err != OK and err != ERR_FILE_NOT_FOUND:
            push_warning("EntitlementsService: no se pudo leer settings.cfg: %s" % str(err))
        var current = cfg.get_value("purchases", "sku_flags", {})
        current[sku] = true
        cfg.set_value("purchases", "sku_flags", current)
        cfg.save("user://settings.cfg")
    # Mapeo SKU->packs y descarga/instalación
    if has_node("/root/DLCService"):
        var svc = get_node("/root/DLCService")
        var packs: Array = svc.get_packs_for_sku(sku)
        if packs.size() > 0:
            svc.mark_packs_purchased(packs)
            if auto_download:
                if svc.has_download_support():
                    await svc.download_and_install_packs(packs)
                else:
                    svc.install_packs_from_base(packs)
            if has_node("/root/ProgressManager"):
                get_node("/root/ProgressManager").refresh_dlc_packs()
            entitlements_changed.emit()
