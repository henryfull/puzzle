extends Control

signal exit_canceled

@export var alert_dialog: AcceptDialog
@export var label: Label
@export var buy_button: Button
@export var consume_button: Button
@export var checkButton: Button
@export var dlc_container: VBoxContainer
@export var scroll_container: ScrollContainer

@onready var progress_panel: PanelContainer = $CanvasLayer/DownloadPanel
@onready var progress_title: Label = $CanvasLayer/DownloadPanel/Margin/VBox/Title
@onready var progress_bar: ProgressBar = $CanvasLayer/DownloadPanel/Margin/VBox/Progress
@onready var progress_detail: Label = $CanvasLayer/DownloadPanel/Margin/VBox/Detail

var configured_products: Dictionary = {}
var available_products: Array = []
var selected_sku := ""
var current_purchase_sku := ""
var store_status := "loading"

func _ready():
	update_ui_texts()
	_connect_services()
	_load_store_products()

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		update_ui_texts()

func _trf(key: String, args: Array = []) -> String:
	var template := TranslationServer.translate(key)
	if args.is_empty():
		return template
	return template % args

func _translate_or_fallback(value: String, fallback: String) -> String:
	if value == "":
		return fallback
	var translated := TranslationServer.translate(value)
	return translated if translated != value else value

func _connect_services():
	if has_node("/root/IAPService"):
		var iap = get_node("/root/IAPService")
		if not iap.connected.is_connected(_on_connected):
			iap.connected.connect(_on_connected)
		if not iap.disconnected.is_connected(_on_disconnected):
			iap.disconnected.connect(_on_disconnected)
		if not iap.sku_details.is_connected(_on_sku_details_received):
			iap.sku_details.connect(_on_sku_details_received)
		if not iap.purchase_error.is_connected(_on_purchase_error):
			iap.purchase_error.connect(_on_purchase_error)
		if not iap.connect_error.is_connected(_on_connect_error):
			iap.connect_error.connect(_on_connect_error)
		if not iap.purchases_updated.is_connected(_on_purchases_updated):
			iap.purchases_updated.connect(_on_purchases_updated)
		if not iap.purchase_acknowledged.is_connected(_on_purchase_acknowledged):
			iap.purchase_acknowledged.connect(_on_purchase_acknowledged)
		if not iap.query_purchases_result.is_connected(_on_query_purchases_response):
			iap.query_purchases_result.connect(_on_query_purchases_response)

	if has_node("/root/EntitlementsService"):
		var entitlements = get_node("/root/EntitlementsService")
		if not entitlements.entitlements_changed.is_connected(_on_entitlements_changed):
			entitlements.entitlements_changed.connect(_on_entitlements_changed)

	if has_node("/root/DLCService"):
		var dlc_service = get_node("/root/DLCService")
		if not dlc_service.download_progress.is_connected(_on_download_progress):
			dlc_service.download_progress.connect(_on_download_progress)
		if not dlc_service.download_finished.is_connected(_on_download_finished):
			dlc_service.download_finished.connect(_on_download_finished)
		if not dlc_service.pack_installed.is_connected(_on_pack_installed):
			dlc_service.pack_installed.connect(_on_pack_installed)

func update_ui_texts():
	if buy_button:
		buy_button.text = TranslationServer.translate("common_buy")
	if consume_button:
		consume_button.text = "Manage"
	if checkButton:
		checkButton.text = "Refresh"
	if progress_title:
		progress_title.text = TranslationServer.translate("store_download_panel_title")
	_apply_status_text()
	_refresh_product_item_texts()

func _load_store_products():
	if not has_node("/root/IAPService"):
		store_status = "unavailable"
		_apply_status_text()
		return

	var iap = get_node("/root/IAPService")
	configured_products.clear()
	for product in iap.get_configured_products():
		var sku := str(product.get("sku", ""))
		if sku != "":
			configured_products[sku] = product

	if configured_products.is_empty():
		store_status = "empty"
		_apply_status_text()
		_display_products()
		return

	store_status = "connected"
	_apply_status_text()
	iap.query_products()
	iap.query_purchases()

func _apply_status_text():
	if not label:
		return

	match store_status:
		"unavailable":
			label.text = TranslationServer.translate("store_service_unavailable")
		"empty":
			label.text = "No store products are configured."
		"connected":
			label.text = TranslationServer.translate("store_connected_querying")
		"list":
			label.text = _trf("store_available_dlcs", [available_products.size()])
		_:
			label.text = TranslationServer.translate("store_loading")

func _is_owned(sku: String) -> bool:
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		return bool(global.settings.get("purchases", {}).get(sku, false))
	return false

func _merge_product_details(product_details: Dictionary) -> Dictionary:
	var sku := str(product_details.get("sku", ""))
	var merged = configured_products.get(sku, {}).duplicate(true)
	merged["sku"] = sku
	merged["title"] = str(product_details.get("title", merged.get("title", merged.get("title_fallback", sku))))
	merged["description"] = str(product_details.get("description", merged.get("description", merged.get("description_fallback", ""))))
	merged["price"] = str(product_details.get("price", merged.get("price", "")))
	merged["type"] = str(product_details.get("type", merged.get("product_type", "subs")))
	return merged

func _refresh_product_item_texts():
	if not dlc_container:
		return
	for child in dlc_container.get_children():
		var product_data = child.get_meta("product_data", {})
		if typeof(product_data) == TYPE_DICTIONARY:
			_apply_product_item_texts(child, product_data)

func _display_products():
	if not dlc_container:
		return

	for child in dlc_container.get_children():
		child.queue_free()

	var products_to_render: Array = available_products
	if products_to_render.is_empty():
		for sku in configured_products.keys():
			var fallback_product = configured_products[sku].duplicate(true)
			fallback_product["sku"] = sku
			products_to_render.append(fallback_product)

	if products_to_render.is_empty():
		store_status = "empty"
		_apply_status_text()
		return

	store_status = "list"
	_apply_status_text()

	for product in products_to_render:
		var item = _create_product_item(product)
		if item:
			dlc_container.add_child(item)

func _create_product_item(product_data: Dictionary) -> Control:
	var item_container := HBoxContainer.new()
	item_container.custom_minimum_size = Vector2(400, 96)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_font_size_override("font_size", 16)

	var desc_label := Label.new()
	desc_label.name = "DescriptionLabel"
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bottom_hbox := HBoxContainer.new()

	var price_label := Label.new()
	price_label.name = "PriceLabel"
	price_label.add_theme_font_size_override("font_size", 14)

	var action_button := Button.new()
	action_button.name = "BuyButton"
	action_button.custom_minimum_size = Vector2(120, 32)

	var sku := str(product_data.get("sku", ""))
	if sku != "":
		action_button.pressed.connect(func(): _purchase_product(sku))

	bottom_hbox.add_child(price_label)
	bottom_hbox.add_spacer(false)
	bottom_hbox.add_child(action_button)

	vbox.add_child(name_label)
	vbox.add_child(desc_label)
	vbox.add_child(bottom_hbox)

	panel.add_child(vbox)
	item_container.add_child(panel)
	item_container.set_meta("product_data", product_data)

	_apply_product_item_texts(item_container, product_data)
	return item_container

func _apply_product_item_texts(item_container: Control, product_data: Dictionary):
	var sku := str(product_data.get("sku", ""))
	var name_label = item_container.find_child("NameLabel", true, false)
	var desc_label = item_container.find_child("DescriptionLabel", true, false)
	var price_label = item_container.find_child("PriceLabel", true, false)
	var buy_btn = item_container.find_child("BuyButton", true, false)

	if name_label and name_label is Label:
		var fallback_title := str(product_data.get("title", product_data.get("title_fallback", sku)))
		name_label.text = _translate_or_fallback(fallback_title, sku)

	if desc_label and desc_label is Label:
		var fallback_description := str(product_data.get("description", product_data.get("description_fallback", "")))
		desc_label.text = _translate_or_fallback(fallback_description, fallback_description)

	if price_label and price_label is Label:
		var price := str(product_data.get("price", ""))
		price_label.text = price if price != "" else "-"

	if buy_btn and buy_btn is Button:
		if _is_owned(sku):
			buy_btn.text = "Active"
			buy_btn.disabled = true
		else:
			buy_btn.text = TranslationServer.translate("common_buy")
			buy_btn.disabled = false

func _purchase_product(sku: String):
	if not has_node("/root/IAPService"):
		show_alert(TranslationServer.translate("store_service_unavailable"))
		return

	current_purchase_sku = sku
	selected_sku = sku
	_set_ui_enabled(false)
	_show_progress_panel()
	if progress_bar:
		progress_bar.value = 15.0
	if progress_detail:
		progress_detail.text = _trf("store_purchase_starting", [sku])

	get_node("/root/IAPService").purchase(sku)

func _set_ui_enabled(enabled: bool):
	if not dlc_container:
		return

	dlc_container.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for child in dlc_container.get_children():
		var buy_btn = child.find_child("BuyButton", true, false)
		if buy_btn and buy_btn is Button:
			buy_btn.disabled = !enabled or _is_owned(str(child.get_meta("product_data", {}).get("sku", "")))

func _on_connected():
	store_status = "connected"
	_apply_status_text()
	if has_node("/root/IAPService"):
		var iap = get_node("/root/IAPService")
		iap.query_products()
		iap.query_purchases()
	_set_ui_enabled(true)

func _on_disconnected():
	store_status = "unavailable"
	_apply_status_text()
	_set_ui_enabled(false)

func _on_sku_details_received(details: Array):
	available_products.clear()
	for product_details in details:
		available_products.append(_merge_product_details(product_details))
	_display_products()

func _on_query_purchases_response(_result: Dictionary):
	_refresh_product_item_texts()

func _on_purchases_updated(purchases: Array):
	for purchase in purchases:
		var sku := str(purchase.get("sku", ""))
		if sku != "":
			selected_sku = sku

	if progress_bar:
		progress_bar.value = 55.0
	if progress_detail and selected_sku != "":
		progress_detail.text = "Purchase updated: %s" % selected_sku

func _on_purchase_acknowledged(_token: String):
	if progress_bar:
		progress_bar.value = 70.0
	if progress_detail:
		progress_detail.text = "Purchase acknowledged. Applying access..."

func _on_entitlements_changed():
	if progress_bar:
		progress_bar.value = 85.0
	if progress_detail:
		progress_detail.text = "Entitlements updated."
	_reload_store_after_purchase()

func _on_connect_error(code, message):
	store_status = "unavailable"
	_apply_status_text()
	_set_ui_enabled(false)
	show_alert(_trf("store_connect_error", [code, message]))

func _on_purchase_error(code, message):
	_set_ui_enabled(true)
	if progress_detail:
		progress_detail.text = _trf("store_purchase_error", [code, message])
	show_alert(_trf("store_purchase_error", [code, message]))
	_hide_progress_panel_delayed()

func _on_download_progress(pack_id: String, _file_path: String, received: int, total: int):
	if progress_detail:
		if total > 0:
			var percent := int((float(received) / float(total)) * 100.0)
			progress_detail.text = _trf("store_download_progress", [pack_id, percent])
		else:
			progress_detail.text = _trf("store_download_started", [pack_id])
	if progress_bar:
		progress_bar.value = 90.0

func _on_download_finished(pack_id: String, success: bool):
	if progress_detail:
		progress_detail.text = _trf("store_download_completed_install", [pack_id]) if success else _trf("store_download_failed", [pack_id])
	if not success:
		show_alert(_trf("store_download_failed", [pack_id]))
		_hide_progress_panel_delayed()

func _on_pack_installed(pack_id: String):
	if progress_bar:
		progress_bar.value = 100.0
	if progress_detail:
		progress_detail.text = _trf("store_install_success", [pack_id])
	_reload_store_after_purchase()

func _reload_store_after_purchase():
	await get_tree().create_timer(1.5).timeout
	_set_ui_enabled(true)
	_hide_progress_panel_delayed()
	if has_node("/root/IAPService"):
		var iap = get_node("/root/IAPService")
		iap.query_purchases()
		iap.query_products()

func _show_progress_panel():
	if progress_panel:
		progress_panel.visible = true

func _hide_progress_panel_delayed():
	await get_tree().create_timer(1.5).timeout
	if progress_panel:
		progress_panel.visible = false

func show_alert(text):
	if alert_dialog:
		alert_dialog.dialog_text = text
		alert_dialog.popup_centered_clamped(Vector2i(300, 0))

func exit_confirmed():
	emit_signal("exit_canceled")

func _on_QuerySkuDetailsButton_pressed():
	_load_store_products()

func _on_PurchaseButton_pressed():
	if selected_sku == "":
		var skus := configured_products.keys()
		if skus.size() > 0:
			selected_sku = str(skus[0])
	if selected_sku != "":
		_purchase_product(selected_sku)

func _on_ConsumeButton_pressed():
	if has_node("/root/IAPService"):
		get_node("/root/IAPService").open_subscriptions_page(selected_sku)
