extends Control

signal exit_canceled

@export var alert_dialog: AcceptDialog
@export var label: Label
@export var buy_button: Button
@export var consume_button: Button
@export var checkButton: Button

# UI para mostrar DLC disponibles
@export var dlc_container: VBoxContainer
@export var scroll_container: ScrollContainer

# UI de progreso de descarga/instalación de DLC
@onready var progress_panel: PanelContainer = $CanvasLayer/DownloadPanel
@onready var progress_title: Label = $CanvasLayer/DownloadPanel/Margin/VBox/Title
@onready var progress_bar: ProgressBar = $CanvasLayer/DownloadPanel/Margin/VBox/Progress
@onready var progress_detail: Label = $CanvasLayer/DownloadPanel/Margin/VBox/Detail

var available_dlcs: Array = []
var current_purchase_pack_id := ""
var product_sku := ""
var last_sku := ""
var test_item_purchase_token = null
var store_status := "loading"

func _trf(key: String, args: Array = []) -> String:
	var template := TranslationServer.translate(key)
	if args.is_empty():
		return template
	return template % args

func _translate_content(value, fallback_key: String = "") -> String:
	if typeof(value) == TYPE_STRING and not value.is_empty():
		return TranslationServer.translate(value)

	return TranslationServer.translate(fallback_key) if not fallback_key.is_empty() else ""

func _process_successful_purchase(_sku: String, _purchase_token: String) -> void:
	# Obsoleto: EntitlementsService gestiona el contenido adquirido.
	pass

func _ready():
	update_ui_texts()

	if has_node("/root/IapService"):
		var iap_service = get_node("/root/IapService")
		if not iap_service.is_connected("purchase_started", Callable(self, "_on_purchase_started")):
			iap_service.purchase_started.connect(Callable(self, "_on_purchase_started"))
		if not iap_service.is_connected("purchase_completed", Callable(self, "_on_purchase_completed")):
			iap_service.purchase_completed.connect(Callable(self, "_on_purchase_completed"))
		if not iap_service.is_connected("download_started", Callable(self, "_on_download_started")):
			iap_service.download_started.connect(Callable(self, "_on_download_started"))
		if not iap_service.is_connected("download_progress", Callable(self, "_on_download_progress")):
			iap_service.download_progress.connect(Callable(self, "_on_download_progress"))
		if not iap_service.is_connected("download_completed", Callable(self, "_on_download_completed")):
			iap_service.download_completed.connect(Callable(self, "_on_download_completed"))
		if not iap_service.is_connected("installation_completed", Callable(self, "_on_installation_completed")):
			iap_service.installation_completed.connect(Callable(self, "_on_installation_completed"))

		_load_available_dlcs()
	else:
		store_status = "unavailable"
		_apply_static_texts()
		show_alert(TranslationServer.translate("store_service_unavailable"))

func update_ui_texts():
	_apply_static_texts()
	_refresh_dlc_item_texts()

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		update_ui_texts()

func _apply_static_texts():
	if buy_button:
		buy_button.text = TranslationServer.translate("common_buy")

	if consume_button:
		consume_button.text = TranslationServer.translate("common_consume")

	if checkButton:
		checkButton.text = TranslationServer.translate("common_check")

	if progress_title:
		progress_title.text = TranslationServer.translate("store_download_panel_title")

	_apply_status_text()

func _apply_status_text():
	if not label:
		return

	match store_status:
		"unavailable":
			label.text = TranslationServer.translate("store_service_unavailable")
		"empty":
			label.text = TranslationServer.translate("store_no_dlcs_available")
		"connected":
			label.text = TranslationServer.translate("store_connected_querying")
		"list":
			label.text = _trf("store_available_dlcs", [available_dlcs.size()])
		_:
			label.text = TranslationServer.translate("store_loading")

func _refresh_dlc_item_texts():
	if not dlc_container:
		return

	for child in dlc_container.get_children():
		var dlc_data = child.get_meta("dlc_data", {})
		if typeof(dlc_data) == TYPE_DICTIONARY:
			_apply_dlc_item_texts(child, dlc_data)

func _load_available_dlcs():
	print("Store: Cargando DLC disponibles...")

	var iap_service = get_node("/root/IapService")
	if not iap_service:
		print("Store: Error - IapService no encontrado")
		store_status = "unavailable"
		_apply_status_text()
		return

	available_dlcs = iap_service.get_available_packs_for_purchase()
	store_status = "list" if not available_dlcs.is_empty() else "empty"
	print("Store: Encontrados ", available_dlcs.size(), " DLC disponibles")
	_display_dlc_items()

func _display_dlc_items():
	if not dlc_container:
		print("Store: Error - dlc_container no encontrado")
		return

	for child in dlc_container.get_children():
		child.queue_free()

	if available_dlcs.is_empty():
		store_status = "empty"
		_apply_status_text()
		return

	store_status = "list"
	_apply_status_text()

	for dlc in available_dlcs:
		var item = _create_dlc_item(dlc)
		if item:
			dlc_container.add_child(item)

func _create_dlc_item(dlc_data: Dictionary) -> Control:
	var item_container := HBoxContainer.new()
	item_container.custom_minimum_size = Vector2(400, 80)

	var panel := PanelContainer.new()
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
	price_label.text = dlc_data.get("price", "2.99€")
	price_label.add_theme_font_size_override("font_size", 14)

	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.custom_minimum_size = Vector2(100, 30)

	var pack_id = dlc_data.get("id", "")
	if pack_id != "":
		buy_btn.pressed.connect(func(): _purchase_dlc(pack_id))

	bottom_hbox.add_child(price_label)
	bottom_hbox.add_child(buy_btn)

	vbox.add_child(name_label)
	vbox.add_child(desc_label)
	vbox.add_child(bottom_hbox)

	panel.add_child(vbox)
	item_container.add_child(panel)
	item_container.set_meta("dlc_data", dlc_data)

	_apply_dlc_item_texts(item_container, dlc_data)
	return item_container

func _apply_dlc_item_texts(item_container: Control, dlc_data: Dictionary):
	var name_label = item_container.find_child("NameLabel", true, false)
	var desc_label = item_container.find_child("DescriptionLabel", true, false)
	var buy_btn = item_container.find_child("BuyButton", true, false)

	if name_label and name_label is Label:
		name_label.text = _translate_content(dlc_data.get("name", ""), "store_default_pack_name")

	if desc_label and desc_label is Label:
		desc_label.text = _translate_content(dlc_data.get("description", ""), "store_default_pack_description")

	if buy_btn and buy_btn is Button:
		buy_btn.text = TranslationServer.translate("common_buy")

func _purchase_dlc(pack_id: String):
	print("Store: Iniciando compra de DLC: ", pack_id)
	current_purchase_pack_id = pack_id

	var iap_service = get_node("/root/IapService")
	if iap_service:
		iap_service.purchase_and_install_pack(pack_id)
	else:
		show_alert(TranslationServer.translate("store_service_unavailable"))

func show_alert(text):
	alert_dialog.dialog_text = text
	alert_dialog.popup_centered_clamped(Vector2i(300, 0))

func _on_connected():
	print("PurchaseManager connected")
	store_status = "connected"
	_apply_status_text()

	if has_node("/root/IAPService"):
		var iap = get_node("/root/IAPService")
		iap.query_purchases()
		iap.query_products([product_sku])

	_set_ui_enabled(true)

func _set_ui_enabled(enabled: bool) -> void:
	if dlc_container:
		dlc_container.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

	for child in dlc_container.get_children():
		var buy_btn = child.find_child("BuyButton", true, false)
		if buy_btn and buy_btn is Button:
			buy_btn.disabled = !enabled

func _on_query_purchases_response(_query_result):
	pass

func _on_sku_details_query_completed(sku_details):
	if sku_details.is_empty():
		var not_found = _trf("store_product_not_found", [product_sku])
		show_alert(not_found)
		label.text = not_found
		return

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

	var details_text = TranslationServer.translate("store_product_found")
	details_text += "\n%s: %s" % [TranslationServer.translate("store_product_id"), sku_id]
	details_text += "\n%s: %s" % [TranslationServer.translate("store_product_name"), title]
	details_text += "\n%s: %s" % [TranslationServer.translate("store_product_price"), price_text]
	details_text += "\n%s: %s" % [TranslationServer.translate("store_product_type"), type]
	if description != "":
		details_text += "\n\n%s:\n%s" % [TranslationServer.translate("store_product_description"), description]

	label.text = details_text
	show_alert(_trf("store_sku_loaded", [sku_id]))

func _on_purchases_updated(purchases):
	print("Purchases updated: %s" % JSON.new().stringify(purchases))
	if purchases.size() > 0:
		var last = purchases[purchases.size() - 1]
		test_item_purchase_token = last.get("purchase_token", null)
		last_sku = last.get("sku", "")

func _on_purchase_acknowledged(_purchase_token):
	var sku_to_use = last_sku if last_sku != "" else product_sku
	label.text = _trf("store_purchase_confirmed", [sku_to_use])
	show_alert(_trf("store_purchase_confirmed", [sku_to_use]))

func _on_purchase_consumed(purchase_token):
	show_alert(_trf("store_purchase_consumed_success", [purchase_token]))

func _on_connect_error(code, message):
	var msg = _trf("store_connect_error", [code, message])
	label.text = msg
	show_alert(msg)

func _on_purchase_error(code, message):
	var msg = _trf("store_purchase_error", [code, message])
	label.text = msg
	show_alert(msg)

func _on_purchase_acknowledgement_error(code, message):
	var msg = _trf("store_purchase_ack_error", [code, message])
	label.text = msg
	show_alert(msg)

func _on_purchase_consumption_error(code, message, purchase_token):
	var msg = _trf("store_purchase_consumption_error", [code, message, purchase_token])
	label.text = msg
	show_alert(msg)

func _on_sku_details_query_error(code, message):
	var msg = _trf("store_sku_details_error", [code, message])
	label.text = msg
	show_alert(msg)

func _on_disconnected():
	label.text = TranslationServer.translate("store_disconnected_retry")
	show_alert(TranslationServer.translate("store_disconnected_retry"))
	await get_tree().create_timer(10).timeout

func _on_QuerySkuDetailsButton_pressed():
	if has_node("/root/IAPService"):
		get_node("/root/IAPService").query_products([product_sku])

func _on_PurchaseButton_pressed():
	if has_node("/root/IAPService"):
		get_node("/root/IAPService").purchase(product_sku)

func _on_ConsumeButton_pressed():
	show_alert(TranslationServer.translate("store_consume_not_supported"))

func exit_confirmed():
	emit_signal("exit_canceled")

func _on_purchase_started(pack_id: String):
	print("Store: Compra iniciada para: ", pack_id)
	_show_progress_panel()
	if progress_detail:
		progress_detail.text = _trf("store_purchase_starting", [pack_id])
	if progress_bar:
		progress_bar.value = 10.0

func _on_purchase_completed(pack_id: String, success: bool):
	print("Store: Compra completada para ", pack_id, " - Éxito: ", success)
	if success:
		if progress_detail:
			progress_detail.text = _trf("store_purchase_success_download", [pack_id])
		if progress_bar:
			progress_bar.value = 30.0
	else:
		if progress_detail:
			progress_detail.text = _trf("store_purchase_failed", [pack_id])
		show_alert(_trf("store_purchase_failed", [pack_id]))
		_hide_progress_panel_delayed()

func _on_download_started(pack_id: String):
	print("Store: Descarga iniciada para: ", pack_id)
	if progress_detail:
		progress_detail.text = _trf("store_download_started", [pack_id])
	if progress_bar:
		progress_bar.value = 40.0

func _on_download_progress(pack_id: String, progress: float):
	print("Store: Progreso de descarga para ", pack_id, ": ", progress * 100, "%")
	if progress_bar:
		var bar_progress = 40.0 + (progress * 40.0)
		progress_bar.value = bar_progress
	if progress_detail:
		progress_detail.text = _trf("store_download_progress", [pack_id, int(progress * 100)])

func _on_download_completed(pack_id: String, success: bool):
	print("Store: Descarga completada para ", pack_id, " - Éxito: ", success)
	if success:
		if progress_detail:
			progress_detail.text = _trf("store_download_completed_install", [pack_id])
		if progress_bar:
			progress_bar.value = 80.0
	else:
		if progress_detail:
			progress_detail.text = _trf("store_download_failed", [pack_id])
		show_alert(_trf("store_download_failed", [pack_id]))
		_hide_progress_panel_delayed()

func _on_installation_completed(pack_id: String, success: bool):
	print("Store: Instalación completada para ", pack_id, " - Éxito: ", success)
	if success:
		if progress_detail:
			progress_detail.text = _trf("store_install_success", [pack_id])
		if progress_bar:
			progress_bar.value = 100.0
		show_alert(_trf("store_install_success_alert", [pack_id]))
		_reload_store_after_purchase()
	else:
		if progress_detail:
			progress_detail.text = _trf("store_install_failed", [pack_id])
		show_alert(_trf("store_install_failed", [pack_id]))

	_hide_progress_panel_delayed()

func _reload_store_after_purchase():
	await get_tree().create_timer(2.0).timeout
	print("Store: Recargando tienda después de compra...")
	_load_available_dlcs()

func _show_progress_panel():
	if progress_panel:
		progress_panel.visible = true

func _hide_progress_panel_delayed():
	await get_tree().create_timer(2.0).timeout
	if progress_panel:
		progress_panel.visible = false
