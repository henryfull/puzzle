extends Node

# Servicio agnóstico: escucha compras del IAPService y aplica "entitlements".

signal entitlements_changed()

@export var auto_download := true

var _local_active_skus: Array = []
var _remote_active_skus: Array = []
var _remote_accessible_pack_ids: Array = []

func _ready():
	if has_node("/root/IAPService"):
		var iap = get_node("/root/IAPService")
		iap.connected.connect(_on_iap_connected)
		iap.purchases_updated.connect(_on_purchases_updated)
		iap.purchase_acknowledged.connect(_on_purchase_acknowledged)
		iap.query_purchases_result.connect(_on_query_purchases_result)
	call_deferred("_sync_remote_entitlements_if_available")

func _on_iap_connected():
	var iap = get_node("/root/IAPService")
	iap.query_purchases()
	call_deferred("_sync_remote_entitlements_if_available")

func _on_query_purchases_result(result: Dictionary):
	if result.get("status", ERR_DOES_NOT_EXIST) == OK:
		_local_active_skus = _extract_active_skus(result.get("purchases", []))
		await _apply_effective_entitlements()

func _on_purchases_updated(purchases: Array):
	for sku in _extract_active_skus(purchases):
		if sku not in _local_active_skus:
			_local_active_skus.append(sku)
	await _apply_effective_entitlements()

func _on_purchase_acknowledged(_token: String):
	pass

func _sync_remote_entitlements_if_available() -> void:
	var remote_catalog = _get_remote_catalog_service()
	if remote_catalog == null or not remote_catalog.has_remote_catalog():
		return
	await _sync_remote_entitlements(true)

func _get_configured_skus() -> Array:
	if has_node("/root/IAPService"):
		return get_node("/root/IAPService").get_configured_skus()
	return []

func _get_remote_catalog_service() -> Node:
	return get_node_or_null("/root/RemoteCatalogService")

func _apply_local_purchase_flag(sku: String, is_active: bool) -> void:
	if sku == "":
		return
	if has_node("/root/GLOBAL"):
		var global_node = get_node("/root/GLOBAL")
		if not global_node.settings.has("purchases"):
			global_node.settings["purchases"] = {}
		global_node.settings.purchases[sku] = is_active
		if global_node.has_method("save_settings"):
			global_node.save_settings()
		return

	var cfg := ConfigFile.new()
	var err = cfg.load("user://settings.cfg")
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("EntitlementsService: no se pudo leer settings.cfg: %s" % str(err))
	var current = cfg.get_value("purchases", "sku_flags", {})
	current[sku] = is_active
	cfg.set_value("purchases", "sku_flags", current)
	cfg.save("user://settings.cfg")

func _sync_purchase_flags(active_skus: Array) -> void:
	for sku in _get_configured_skus():
		_apply_local_purchase_flag(str(sku), str(sku) in active_skus)

func _extract_active_skus(purchases: Array) -> Array:
	var active_skus: Array = []
	for purchase in purchases:
		if typeof(purchase) != TYPE_DICTIONARY:
			continue
		var sku := str(purchase.get("sku", purchase.get("product_id", "")))
		if sku != "" and sku not in active_skus:
			active_skus.append(sku)
	return active_skus

func _sync_remote_entitlements(force_refresh: bool = false) -> void:
	var remote_catalog = _get_remote_catalog_service()
	if remote_catalog == null or not remote_catalog.has_remote_catalog():
		return

	var catalog = await remote_catalog.fetch_catalog_manifest(force_refresh)
	var entitlements = await remote_catalog.fetch_entitlements(force_refresh)
	_remote_active_skus = []
	for sku in entitlements.get("active_skus", []):
		var normalized_sku := str(sku)
		if normalized_sku != "" and normalized_sku not in _remote_active_skus:
			_remote_active_skus.append(normalized_sku)
	_remote_accessible_pack_ids = remote_catalog.get_accessible_pack_ids(catalog)
	await _apply_effective_entitlements()

func _apply_effective_entitlements() -> void:
	var effective_active_skus: Array = []
	for sku in _local_active_skus:
		if sku not in effective_active_skus:
			effective_active_skus.append(sku)
	for sku in _remote_active_skus:
		if sku not in effective_active_skus:
			effective_active_skus.append(sku)

	_sync_purchase_flags(effective_active_skus)

	if has_node("/root/DLCService"):
		var svc = get_node("/root/DLCService")
		var effective_pack_ids: Array = []
		for sku in effective_active_skus:
			for pack_id in svc.get_packs_for_sku(str(sku)):
				if pack_id not in effective_pack_ids:
					effective_pack_ids.append(pack_id)
		for pack_id in _remote_accessible_pack_ids:
			var normalized_pack_id := str(pack_id)
			if normalized_pack_id != "" and normalized_pack_id not in effective_pack_ids:
				effective_pack_ids.append(normalized_pack_id)
		await svc.sync_access_for_pack_ids(effective_pack_ids, auto_download)

	if has_node("/root/ProgressManager"):
		get_node("/root/ProgressManager").refresh_dlc_packs()

	entitlements_changed.emit()
