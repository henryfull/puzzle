extends Node2D

@export var title_label: Label
@export var subtitle_label: Label
@export var status_label: Label
@export var details_label: Label
@export var reward_label: Label
@export var preview_image: TextureRect
@export var no_image_label: Label
@export var claim_reward_button: Button
@export var play_button: Button
@export var refresh_button: Button

const DEFAULT_MAX_TIME_SECONDS := 180.0
const DEFAULT_MIN_MOVES := 24
const DEFAULT_MIN_FLIPS := 4
const DEFAULT_FREE_REWARD_COINS := 25
const DEFAULT_PREMIUM_REWARD_COINS := 50

var _daily_manifest: Dictionary = {}
var _pack_manifest: Dictionary = {}
var _daily_progress: Dictionary = {}
var _loading_preview := false
var _preparing_challenge := false
var _claiming_reward := false
var _syncing_completion := false

func _ready() -> void:
	update_ui_texts()
	call_deferred("_load_daily_challenge")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		update_ui_texts()

func update_ui_texts() -> void:
	if title_label:
		title_label.text = "DESAFIO DIARIO" if _is_spanish_locale() else "DAILY CHALLENGE"
	if subtitle_label:
		if _daily_manifest.is_empty():
			subtitle_label.text = "Cargando reto..." if _is_spanish_locale() else "Loading challenge..."
		else:
			_apply_daily_manifest()
	if refresh_button:
		refresh_button.text = "Actualizar" if _is_spanish_locale() else "Refresh"
	if claim_reward_button:
		_update_claim_button_state()
	if play_button:
		_update_play_button_state()
	if not _pack_manifest.is_empty():
		_apply_pack_details()
	_update_reward_ui()

func _is_spanish_locale() -> bool:
	return TranslationServer.get_locale().to_lower().begins_with("es")

func _get_remote_catalog_service() -> Node:
	return get_node_or_null("/root/RemoteCatalogService")

func _localized_value(value, fallback: String) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var locale := TranslationServer.get_locale().to_lower()
		var language := locale.split("_")[0]
		if value.has(locale):
			return str(value[locale])
		if value.has(language):
			return str(value[language])
		if value.has("es"):
			return str(value["es"])
		if value.has("en"):
			return str(value["en"])
	elif typeof(value) == TYPE_STRING:
		return str(value)
	return fallback

func _duplicate_content_value(value):
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value

func _format_date_label(date_value: String) -> String:
	if date_value == "":
		return ""
	return date_value

func _load_daily_challenge() -> void:
	if status_label:
		status_label.text = "Conectando con el catalogo..." if _is_spanish_locale() else "Connecting to the catalog..."
	if play_button:
		play_button.disabled = true

	var remote_catalog = _get_remote_catalog_service()
	if remote_catalog == null or not remote_catalog.has_remote_catalog():
		_set_unavailable_state(
			"Configura catalog/api_base_url para usar el desafio diario."
			if _is_spanish_locale()
			else "Configure catalog/api_base_url to use the daily challenge."
		)
		return

	var daily_manifest := await remote_catalog.fetch_daily_challenge_manifest()
	if daily_manifest.is_empty():
		_set_unavailable_state(
			"No hay desafio diario disponible hoy."
			if _is_spanish_locale()
			else "There is no daily challenge available today."
		)
		return

	_daily_manifest = daily_manifest.duplicate(true)
	_pack_manifest = {}
	if remote_catalog.uses_backend_api():
		await remote_catalog.fetch_entitlements()
	_refresh_daily_progress_state()
	if _should_sync_remote_completion():
		await _sync_remote_completion_if_needed()
	_apply_daily_manifest()
	await _load_daily_preview()
	await _load_pack_manifest()
	_apply_pack_details()
	_update_reward_ui()
	_update_play_button_state()

func _apply_daily_manifest() -> void:
	if subtitle_label:
		var title_text := _localized_value(_daily_manifest.get("title", {}), "Daily challenge")
		var date_text := _format_date_label(str(_daily_manifest.get("date", "")))
		subtitle_label.text = "%s  %s" % [title_text, date_text]

	_apply_daily_status()

func _apply_daily_status() -> void:
	if status_label == null:
		return

	if _has_completed_daily_challenge():
		var completed_at := str(_daily_progress.get("completed_at", ""))
		var completed_suffix := ": %s" % completed_at if completed_at != "" else ""
		status_label.text = (
			"Completado hoy%s" % completed_suffix
			if _is_spanish_locale()
			else "Completed today%s" % completed_suffix
		)
		return

	if not _daily_manifest.is_empty():
		var expires_at := str(_daily_manifest.get("expires_at", ""))
		if expires_at != "":
			status_label.text = (
				"Disponible hasta %s" % expires_at
				if _is_spanish_locale()
				else "Available until %s" % expires_at
			)
		else:
			status_label.text = "Listo para preparar." if _is_spanish_locale() else "Ready to prepare."

func _set_unavailable_state(message: String) -> void:
	_daily_manifest.clear()
	_pack_manifest.clear()
	_daily_progress.clear()
	if subtitle_label:
		subtitle_label.text = "Sin contenido diario" if _is_spanish_locale() else "No daily content"
	if status_label:
		status_label.text = message
	if details_label:
		details_label.text = ""
	if reward_label:
		reward_label.text = ""
	if preview_image:
		preview_image.texture = null
		preview_image.visible = false
	if no_image_label:
		no_image_label.visible = true
	if play_button:
		play_button.disabled = true
		play_button.text = "No disponible" if _is_spanish_locale() else "Unavailable"
	if claim_reward_button:
		claim_reward_button.disabled = true
		claim_reward_button.text = "Sin recompensa" if _is_spanish_locale() else "No reward"

func _load_daily_preview() -> void:
	if _loading_preview:
		return
	_loading_preview = true

	var image_path := str(_daily_manifest.get("image_path", ""))
	var remote_catalog = _get_remote_catalog_service()
	if image_path == "" or remote_catalog == null:
		_loading_preview = false
		return

	var result := await remote_catalog.download_asset(image_path)
	_loading_preview = false
	if not is_inside_tree():
		return
	if not result.get("ok", false):
		return

	var local_path := str(result.get("path", ""))
	var texture := _load_texture_from_path(local_path)
	if texture and preview_image:
		preview_image.texture = texture
		preview_image.visible = true
		if no_image_label:
			no_image_label.visible = false

func _load_pack_manifest() -> void:
	var remote_catalog = _get_remote_catalog_service()
	if remote_catalog == null:
		return

	var manifest_path := str(_daily_manifest.get("pack_manifest_path", ""))
	if manifest_path == "":
		return

	_pack_manifest = await remote_catalog.fetch_asset_json(manifest_path)

func _apply_pack_details() -> void:
	if details_label == null:
		return

	if _pack_manifest.is_empty():
		details_label.text = (
			"No se pudo leer el pack del reto."
			if _is_spanish_locale()
			else "The challenge pack could not be loaded."
		)
		return

	var lines: Array[String] = []
	var pack_title := _localized_value(_pack_manifest.get("title", {}), str(_pack_manifest.get("id", "")))
	var puzzle_count := _pack_manifest.get("puzzles", []).size()
	lines.append(("Pack: %s" if _is_spanish_locale() else "Pack: %s") % pack_title)
	lines.append(("Puzzles: %d" if _is_spanish_locale() else "Puzzles: %d") % puzzle_count)

	var first_puzzle := _get_first_puzzle()
	if not first_puzzle.is_empty():
		var grid := first_puzzle.get("grid", {})
		if typeof(grid) == TYPE_DICTIONARY:
			lines.append(
				("Cuadricula: %sx%s" if _is_spanish_locale() else "Grid: %sx%s")
				% [str(grid.get("columns", "?")), str(grid.get("rows", "?"))]
			)

	var challenge_config := _get_challenge_config()
	if not challenge_config.is_empty():
		lines.append(
			("Tiempo limite: %s" if _is_spanish_locale() else "Time limit: %s")
			% _format_time_limit(float(challenge_config.get("max_time", 0.0)))
		)
		lines.append(
			("Movimientos: %s" if _is_spanish_locale() else "Moves: %s")
			% str(challenge_config.get("max_moves", 0))
		)
	else:
		lines.append(
			"Modo desafio por defecto." if _is_spanish_locale() else "Default challenge mode."
		)

	if _has_completed_daily_challenge():
		lines.append("Estado: completado hoy." if _is_spanish_locale() else "Status: completed today.")
		var best_score := int(_daily_progress.get("best_score", 0))
		if best_score > 0:
			lines.append(
				("Mejor puntuacion: %d" if _is_spanish_locale() else "Best score: %d")
				% best_score
			)
		var best_time := float(_daily_progress.get("best_time", 0.0))
		if best_time > 0.0:
			lines.append(
				("Mejor tiempo: %s" if _is_spanish_locale() else "Best time: %s")
				% _format_time_limit(best_time)
			)

	details_label.text = "\n".join(lines)

func _build_default_reward_payload() -> Dictionary:
	var tier := str(_daily_manifest.get("tier", "free")).to_lower()
	var default_coins := DEFAULT_PREMIUM_REWARD_COINS if tier.contains("premium") else DEFAULT_FREE_REWARD_COINS
	return {
		"currencies": {
			"coins": default_coins
		}
	}

func _get_reward_payload() -> Dictionary:
	var reward = _daily_manifest.get("reward", {})
	if typeof(reward) == TYPE_DICTIONARY and not reward.is_empty():
		return reward.duplicate(true)
	return _build_default_reward_payload()

func _get_progress_manager() -> Node:
	return get_node_or_null("/root/ProgressManager")

func _get_reward_inventory_snapshot() -> Dictionary:
	var remote_catalog = _get_remote_catalog_service()
	if remote_catalog and remote_catalog.has_method("get_rewards_inventory"):
		var remote_inventory = remote_catalog.get_rewards_inventory()
		if not remote_inventory.is_empty():
			return remote_inventory

	var progress_manager = _get_progress_manager()
	if progress_manager and progress_manager.has_method("get_rewards_inventory"):
		return progress_manager.get_rewards_inventory()

	return {}

func _requires_backend_completion() -> bool:
	var remote_catalog = _get_remote_catalog_service()
	return remote_catalog != null and remote_catalog.uses_backend_api()

func _get_remote_completion_entry() -> Dictionary:
	var challenge_key := _resolve_daily_challenge_key()
	if challenge_key == "":
		return {}

	var remote_catalog = _get_remote_catalog_service()
	if remote_catalog and remote_catalog.has_method("get_daily_completion_entry"):
		return remote_catalog.get_daily_completion_entry(challenge_key)
	return {}

func _has_remote_completion_record() -> bool:
	var remote_completion := _get_remote_completion_entry()
	return not remote_completion.is_empty() and bool(remote_completion.get("completed", false))

func _should_sync_remote_completion() -> bool:
	return _requires_backend_completion() and _has_completed_daily_challenge() and not _has_remote_completion_record()

func _build_completion_stats_payload() -> Dictionary:
	return {
		"pack_id": str(_daily_progress.get("pack_id", "")),
		"puzzle_id": str(_daily_progress.get("puzzle_id", "")),
		"elapsed_time": float(_daily_progress.get("last_elapsed_time", _daily_progress.get("best_time", 0.0))),
		"moves": int(_daily_progress.get("last_moves", _daily_progress.get("best_moves", 0))),
		"flips": int(_daily_progress.get("last_flips", 0)),
		"flip_moves": int(_daily_progress.get("last_flip_moves", 0)),
		"score": int(_daily_progress.get("last_score", _daily_progress.get("best_score", 0))),
		"max_streak": int(_daily_progress.get("last_max_streak", _daily_progress.get("best_max_streak", 0)))
	}

func _sync_remote_completion_if_needed() -> void:
	if not _should_sync_remote_completion():
		return

	var remote_catalog = _get_remote_catalog_service()
	if remote_catalog == null or not remote_catalog.has_method("report_daily_challenge_completion"):
		return

	_syncing_completion = true
	_update_claim_button_state()
	var result := await remote_catalog.report_daily_challenge_completion(_daily_manifest, _build_completion_stats_payload())
	_syncing_completion = false
	_refresh_daily_progress_state()
	_update_claim_button_state()

	if not bool(result.get("ok", false)) and status_label:
		status_label.text = (
			"Reto completado, pendiente de sincronizar con el servidor."
			if _is_spanish_locale()
			else "Challenge completed, waiting to sync with the server."
		)

func _format_reward_summary(reward_data: Dictionary, inventory: Dictionary = {}) -> String:
	if reward_data.is_empty():
		return "Sin recompensa configurada." if _is_spanish_locale() else "No reward configured."

	var parts: Array[String] = []
	var currencies = reward_data.get("currencies", {})
	if typeof(currencies) == TYPE_DICTIONARY:
		for currency_id in currencies.keys():
			var amount := int(currencies[currency_id])
			if amount == 0:
				continue
			var currency_name := _resolve_currency_name(str(currency_id), amount)
			parts.append("%d %s" % [amount, currency_name])

	var cosmetics = reward_data.get("cosmetics", [])
	if typeof(cosmetics) == TYPE_ARRAY:
		for cosmetic in cosmetics:
			var cosmetic_data := {}
			if typeof(cosmetic) == TYPE_DICTIONARY:
				cosmetic_data = cosmetic
			elif typeof(cosmetic) == TYPE_STRING:
				cosmetic_data = {"id": str(cosmetic)}
			else:
				continue
			var cosmetic_title := _localized_value(cosmetic_data.get("title", {}), str(cosmetic_data.get("id", "Cosmetic")))
			if cosmetic_title != "":
				parts.append(cosmetic_title)

	if parts.is_empty():
		return "Sin recompensa configurada." if _is_spanish_locale() else "No reward configured."

	var summary := ", ".join(parts)
	if inventory.is_empty():
		return (
			"Recompensa: %s" % summary
			if _is_spanish_locale()
			else "Reward: %s" % summary
		)

	var coins_balance := 0
	var inventory_currencies = inventory.get("currencies", {})
	if typeof(inventory_currencies) == TYPE_DICTIONARY:
		coins_balance = int(inventory_currencies.get("coins", 0))
	return (
		"Recompensa: %s. Saldo monedas: %d" % [summary, coins_balance]
		if _is_spanish_locale()
		else "Reward: %s. Coin balance: %d" % [summary, coins_balance]
	)

func _resolve_currency_name(currency_id: String, amount: int) -> String:
	match currency_id:
		"coins":
			if _is_spanish_locale():
				return "moneda" if amount == 1 else "monedas"
			return "coin" if amount == 1 else "coins"
		"gems":
			if _is_spanish_locale():
				return "gema" if amount == 1 else "gemas"
			return "gem" if amount == 1 else "gems"
		_:
			return currency_id

func _build_claim_error_message(reason: String) -> String:
	if _is_spanish_locale():
		if reason == "reward_already_claimed":
			return "Ya has reclamado esta recompensa."
		if reason == "challenge_not_completed":
			return "Completa el reto antes de reclamar."
		return "No se pudo reclamar la recompensa."

	if reason == "reward_already_claimed":
		return "You already claimed this reward."
	if reason == "challenge_not_completed":
		return "Finish the challenge before claiming."
	return "The reward could not be claimed."

func _update_reward_ui() -> void:
	if reward_label == null:
		return

	var reward_payload := _get_reward_payload()
	if _daily_manifest.is_empty():
		reward_label.text = ""
	elif _has_completed_daily_challenge():
		if bool(_daily_progress.get("reward_claimed", false)):
			var inventory := _get_reward_inventory_snapshot()
			reward_label.text = (
				"Recompensa reclamada. %s" % _format_reward_summary(reward_payload, inventory)
				if _is_spanish_locale()
				else "Reward claimed. %s" % _format_reward_summary(reward_payload, inventory)
			)
		else:
			reward_label.text = (
				"Recompensa lista para reclamar. %s" % _format_reward_summary(reward_payload)
				if _is_spanish_locale()
				else "Reward ready to claim. %s" % _format_reward_summary(reward_payload)
			)
	else:
		reward_label.text = (
			"Completa el reto para reclamar. %s" % _format_reward_summary(reward_payload)
			if _is_spanish_locale()
			else "Complete the challenge to claim it. %s" % _format_reward_summary(reward_payload)
		)

	_update_claim_button_state()

func _resolve_daily_challenge_key() -> String:
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if progress_manager and progress_manager.has_method("get_daily_challenge_key"):
		return str(progress_manager.get_daily_challenge_key(_daily_manifest))

	var date_key := str(_daily_manifest.get("date", "")).strip_edges()
	if date_key != "":
		return date_key
	return str(_daily_manifest.get("challenge_id", _daily_manifest.get("id", ""))).strip_edges()

func _refresh_daily_progress_state() -> void:
	_daily_progress.clear()
	if _daily_manifest.is_empty():
		return

	var progress_manager = get_node_or_null("/root/ProgressManager")
	if progress_manager == null:
		return

	var challenge_key := _resolve_daily_challenge_key()
	if challenge_key == "":
		return

	if progress_manager.has_method("get_daily_challenge_progress"):
		_daily_progress = progress_manager.get_daily_challenge_progress(challenge_key)

	var remote_catalog = _get_remote_catalog_service()
	if remote_catalog and remote_catalog.has_method("get_daily_completion_entry"):
		var remote_completion = remote_catalog.get_daily_completion_entry(challenge_key)
		if not remote_completion.is_empty():
			_daily_progress["completed"] = true
			_daily_progress["completed_at"] = str(remote_completion.get("completed_at", remote_completion.get("last_completed_at", "")))
			_daily_progress["pack_id"] = str(remote_completion.get("last_stats", {}).get("pack_id", _daily_progress.get("pack_id", "")))
			_daily_progress["puzzle_id"] = str(remote_completion.get("last_stats", {}).get("puzzle_id", _daily_progress.get("puzzle_id", "")))
			if remote_completion.has("best_time"):
				_daily_progress["best_time"] = float(remote_completion.get("best_time", 0.0))
			if remote_completion.has("best_moves"):
				_daily_progress["best_moves"] = int(remote_completion.get("best_moves", 0))
			if remote_completion.has("best_score"):
				_daily_progress["best_score"] = int(remote_completion.get("best_score", 0))
			var last_stats = remote_completion.get("last_stats", {})
			if typeof(last_stats) == TYPE_DICTIONARY:
				if last_stats.has("elapsed_time"):
					_daily_progress["last_elapsed_time"] = float(last_stats.get("elapsed_time", 0.0))
				if last_stats.has("moves"):
					_daily_progress["last_moves"] = int(last_stats.get("moves", 0))
				if last_stats.has("flips"):
					_daily_progress["last_flips"] = int(last_stats.get("flips", 0))
				if last_stats.has("flip_moves"):
					_daily_progress["last_flip_moves"] = int(last_stats.get("flip_moves", 0))
				if last_stats.has("score"):
					_daily_progress["last_score"] = int(last_stats.get("score", 0))
				if last_stats.has("max_streak"):
					_daily_progress["last_max_streak"] = int(last_stats.get("max_streak", 0))
	if remote_catalog and remote_catalog.has_method("get_daily_claim_entry"):
		var remote_claim = remote_catalog.get_daily_claim_entry(challenge_key)
		if not remote_claim.is_empty():
			_daily_progress["completed"] = true
			_daily_progress["reward_claimed"] = bool(remote_claim.get("reward_claimed", true))
			if not _daily_progress.has("completed_at"):
				_daily_progress["completed_at"] = str(remote_claim.get("claimed_at", remote_claim.get("completed_at", "")))
			if remote_claim.has("claimed_at"):
				_daily_progress["reward_claimed_at"] = str(remote_claim.get("claimed_at", ""))
			if remote_claim.has("reward") and typeof(remote_claim.get("reward")) == TYPE_DICTIONARY:
				_daily_progress["reward"] = (remote_claim.get("reward") as Dictionary).duplicate(true)

func _has_completed_daily_challenge() -> bool:
	return bool(_daily_progress.get("completed", false))

func _update_claim_button_state() -> void:
	if claim_reward_button == null:
		return

	if _daily_manifest.is_empty():
		claim_reward_button.disabled = true
		claim_reward_button.text = "Sin recompensa" if _is_spanish_locale() else "No reward"
		return

	if _syncing_completion:
		claim_reward_button.disabled = true
		claim_reward_button.text = "Sincronizando..." if _is_spanish_locale() else "Syncing..."
		return

	if _claiming_reward:
		claim_reward_button.disabled = true
		claim_reward_button.text = "Reclamando..." if _is_spanish_locale() else "Claiming..."
		return

	if not _has_completed_daily_challenge():
		claim_reward_button.disabled = true
		claim_reward_button.text = "Completa el reto" if _is_spanish_locale() else "Finish challenge"
		return

	if bool(_daily_progress.get("reward_claimed", false)):
		claim_reward_button.disabled = true
		claim_reward_button.text = "Reclamada" if _is_spanish_locale() else "Claimed"
		return

	if _requires_backend_completion() and not _has_remote_completion_record():
		claim_reward_button.disabled = true
		claim_reward_button.text = "Pendiente sync" if _is_spanish_locale() else "Pending sync"
		return

	claim_reward_button.disabled = false
	claim_reward_button.text = "Reclamar recompensa" if _is_spanish_locale() else "Claim reward"

func _update_play_button_state() -> void:
	if play_button == null:
		return

	play_button.disabled = _daily_manifest.is_empty() or _pack_manifest.is_empty() or _preparing_challenge
	if _preparing_challenge:
		play_button.text = "Preparando reto" if _is_spanish_locale() else "Preparing challenge"
	elif _daily_manifest.is_empty():
		play_button.text = "Preparar reto" if _is_spanish_locale() else "Prepare challenge"
	elif _pack_manifest.is_empty():
		play_button.text = "Preparando reto" if _is_spanish_locale() else "Preparing challenge"
	elif _has_completed_daily_challenge():
		play_button.text = "Rejugar reto" if _is_spanish_locale() else "Replay challenge"
	else:
		play_button.text = "Jugar reto" if _is_spanish_locale() else "Play challenge"

func _get_first_puzzle() -> Dictionary:
	for puzzle in _pack_manifest.get("puzzles", []):
		if typeof(puzzle) == TYPE_DICTIONARY:
			return puzzle
	return {}

func _get_challenge_config() -> Dictionary:
	var challenge_config = _daily_manifest.get("challenge", {})
	return challenge_config if typeof(challenge_config) == TYPE_DICTIONARY else {}

func _build_default_limits(columns: int, rows: int) -> Dictionary:
	var pieces := max(columns * rows, 1)
	return {
		"game_mode": 4,
		"max_moves": max(DEFAULT_MIN_MOVES, pieces * 2),
		"max_time": max(DEFAULT_MAX_TIME_SECONDS, float(pieces * 10)),
		"max_flips": max(DEFAULT_MIN_FLIPS, int(ceil(float(pieces) / 3.0))),
		"max_flip_moves": max(DEFAULT_MIN_MOVES, pieces * 2)
	}

func _format_time_limit(limit_seconds: float) -> String:
	var total_seconds := int(ceil(max(limit_seconds, 0.0)))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _resolve_difficulty_index(columns: int, rows: int) -> int:
	for index in range(GLOBAL.difficulties.size()):
		var difficulty = GLOBAL.difficulties[index]
		if int(difficulty.get("columns", -1)) == columns and int(difficulty.get("rows", -1)) == rows:
			return index
	return GLOBAL.current_difficult

func _prepare_runtime_pack() -> Dictionary:
	if _pack_manifest.is_empty():
		return {}

	var remote_catalog = _get_remote_catalog_service()
	if remote_catalog == null:
		return {}

	var source_pack_id := str(_pack_manifest.get("id", _daily_manifest.get("pack_id", "daily-runtime")))
	var challenge_key := _resolve_daily_challenge_key()
	var pack_id := _build_runtime_pack_id(source_pack_id, challenge_key)
	var pack_title_payload = _duplicate_content_value(_pack_manifest.get("title", {}))
	var pack_description_payload = _duplicate_content_value(_pack_manifest.get("description", {}))
	var local_pack := {
		"id": pack_id,
		"name": _localized_value(pack_title_payload, source_pack_id),
		"name_localized": pack_title_payload,
		"description": _localized_value(pack_description_payload, ""),
		"description_localized": pack_description_payload,
		"image_path": "",
		"music_path": "",
		"thumbnail_path": str(_daily_manifest.get("image_path", _pack_manifest.get("thumbnail_path", ""))),
		"unlocked": true,
		"purchased": true,
		"completed": false,
		"is_dlc": true,
		"remote_catalog": true,
		"is_daily_challenge": true,
		"hidden_from_catalog": true,
		"source_pack_id": source_pack_id,
		"daily_challenge_key": challenge_key,
		"daily_challenge_id": str(_daily_manifest.get("challenge_id", challenge_key)),
		"daily_challenge_date": str(_daily_manifest.get("date", challenge_key)),
		"daily_challenge_title": _localized_value(_daily_manifest.get("title", {}), "Daily challenge"),
		"daily_challenge_reward": _get_reward_payload(),
		"puzzles": []
	}

	var hero_path := str(_daily_manifest.get("image_path", _pack_manifest.get("thumbnail_path", "")))
	if hero_path != "":
		var hero_result := await remote_catalog.download_asset(hero_path)
		if hero_result.get("ok", false):
			local_pack["image_path"] = str(hero_result.get("path", ""))

	var music_path := str(_pack_manifest.get("music_path", ""))
	if music_path != "":
		var music_result := await remote_catalog.download_asset(music_path)
		if music_result.get("ok", false):
			local_pack["music_path"] = str(music_result.get("path", ""))

	for puzzle in _pack_manifest.get("puzzles", []):
		if typeof(puzzle) != TYPE_DICTIONARY:
			continue
		var image_path := str(puzzle.get("image_path", puzzle.get("image", "")))
		if image_path == "":
			continue

		var image_result := await remote_catalog.download_asset(image_path)
		if not image_result.get("ok", false):
			return {}

		var puzzle_title_payload = _duplicate_content_value(puzzle.get("title", puzzle.get("name", {})))
		var puzzle_description_payload = _duplicate_content_value(puzzle.get("description", {}))
		var puzzle_story_payload = _duplicate_content_value(puzzle.get("story", puzzle.get("description", {})))
		var localized_story := _localized_value(puzzle_story_payload, _localized_value(puzzle_description_payload, ""))

		local_pack["puzzles"].append({
			"id": str(puzzle.get("id", "")),
			"name": _localized_value(puzzle_title_payload, str(puzzle.get("id", ""))),
			"name_localized": puzzle_title_payload,
			"description": localized_story,
			"description_localized": puzzle_description_payload,
			"story": localized_story,
			"story_localized": puzzle_story_payload,
			"image": str(image_result.get("path", "")),
			"completed": false,
			"unlocked": local_pack["puzzles"].is_empty()
		})

	if local_pack["puzzles"].is_empty():
		return {}

	return local_pack

func _build_runtime_pack_id(source_pack_id: String, challenge_key: String) -> String:
	var normalized_key := challenge_key.strip_edges().replace("-", "").replace(":", "_").replace("/", "_")
	if normalized_key == "":
		normalized_key = Time.get_date_string_from_system().replace("-", "")
	return "daily_%s_%s" % [normalized_key, source_pack_id]

func _apply_runtime_challenge_config(first_puzzle: Dictionary) -> void:
	var grid := first_puzzle.get("grid", {})
	var columns := int(grid.get("columns", GLOBAL.columns))
	var rows := int(grid.get("rows", GLOBAL.rows))
	var resolved_defaults := _build_default_limits(columns, rows)
	var challenge_config := _get_challenge_config()

	GLOBAL.columns = int(challenge_config.get("columns", columns))
	GLOBAL.rows = int(challenge_config.get("rows", rows))
	GLOBAL.current_difficult = int(challenge_config.get("difficulty", _resolve_difficulty_index(GLOBAL.columns, GLOBAL.rows)))
	GLOBAL.gamemode = int(challenge_config.get("game_mode", resolved_defaults.get("game_mode", 4)))
	GLOBAL.puzzle_limits.max_moves = int(challenge_config.get("max_moves", resolved_defaults.get("max_moves", 0)))
	GLOBAL.puzzle_limits.max_time = float(challenge_config.get("max_time", resolved_defaults.get("max_time", 0.0)))
	GLOBAL.puzzle_limits.max_flips = int(challenge_config.get("max_flips", resolved_defaults.get("max_flips", 0)))
	GLOBAL.puzzle_limits.max_flip_moves = int(challenge_config.get("max_flip_moves", resolved_defaults.get("max_flip_moves", GLOBAL.puzzle_limits.max_moves)))

func _load_texture_from_path(path: String) -> Texture2D:
	if path.is_empty():
		return null

	if path.begins_with("user://"):
		if not FileAccess.file_exists(path):
			return null
		var image := Image.new()
		var err := image.load(path)
		if err != OK:
			return null
		return ImageTexture.create_from_image(image)

	if not ResourceLoader.exists(path):
		return null

	return load(path) as Texture2D

func _on_refresh_button_pressed() -> void:
	_daily_manifest.clear()
	_pack_manifest.clear()
	_daily_progress.clear()
	if preview_image:
		preview_image.texture = null
		preview_image.visible = false
	if no_image_label:
		no_image_label.visible = true
	await _load_daily_challenge()

func _on_claim_reward_button_pressed() -> void:
	var progress_manager = _get_progress_manager()
	if progress_manager == null or not progress_manager.has_method("claim_daily_challenge_reward"):
		return

	var challenge_key := _resolve_daily_challenge_key()
	if challenge_key == "":
		return

	if _requires_backend_completion() and not _has_remote_completion_record():
		await _sync_remote_completion_if_needed()
		if not _has_remote_completion_record():
			if status_label:
				status_label.text = (
					"El reto esta completado, pero todavia no se ha sincronizado con el servidor."
					if _is_spanish_locale()
					else "The challenge is completed, but it has not synced with the server yet."
				)
			return

	_claiming_reward = true
	_update_claim_button_state()

	var result := {}
	var remote_catalog = _get_remote_catalog_service()
	if remote_catalog and remote_catalog.uses_backend_api() and remote_catalog.has_method("claim_daily_challenge_reward"):
		result = await remote_catalog.claim_daily_challenge_reward(_daily_manifest)
		if bool(result.get("ok", false)):
			var entitlements = result.get("entitlements", {})
			if typeof(entitlements) == TYPE_DICTIONARY:
				var inventory = entitlements.get("rewards_inventory", {})
				if progress_manager.has_method("replace_rewards_inventory") and typeof(inventory) == TYPE_DICTIONARY:
					progress_manager.replace_rewards_inventory(inventory)
			progress_manager.mark_daily_challenge_reward_claimed(challenge_key, _get_reward_payload())
		elif result.get("code", 0) == 200 and bool(result.get("already_claimed", false)):
			progress_manager.mark_daily_challenge_reward_claimed(challenge_key, _get_reward_payload())
	else:
		result = progress_manager.claim_daily_challenge_reward(challenge_key, _get_reward_payload())

	_claiming_reward = false

	if not bool(result.get("ok", false)):
		var reason := str(result.get("reason", "reward_claim_failed"))
		if status_label:
			status_label.text = _build_claim_error_message(reason)
		_refresh_daily_progress_state()
		_update_reward_ui()
		return

	_refresh_daily_progress_state()
	if result.has("entry") and typeof(result.get("entry")) == TYPE_DICTIONARY:
		_daily_progress = (result.get("entry") as Dictionary).duplicate(true)
	_apply_daily_status()
	_apply_pack_details()
	_update_reward_ui()

func _on_play_button_pressed() -> void:
	if _preparing_challenge or _pack_manifest.is_empty():
		return

	_preparing_challenge = true
	if status_label:
		status_label.text = "Preparando desafio..." if _is_spanish_locale() else "Preparing challenge..."
	if play_button:
		_update_play_button_state()

	var runtime_pack := await _prepare_runtime_pack()
	_preparing_challenge = false
	if runtime_pack.is_empty():
		if status_label:
			status_label.text = (
				"No se pudo preparar el contenido del reto."
				if _is_spanish_locale()
				else "The challenge content could not be prepared."
			)
		if play_button:
			_update_play_button_state()
		return

	var first_puzzle := runtime_pack["puzzles"][0]
	_apply_runtime_challenge_config(first_puzzle)

	var progress_manager = get_node_or_null("/root/ProgressManager")
	if progress_manager and progress_manager.has_method("register_runtime_pack"):
		var registered_pack = progress_manager.register_runtime_pack(runtime_pack)
		if not registered_pack.is_empty():
			runtime_pack = registered_pack

	GLOBAL.selected_pack = runtime_pack
	GLOBAL.selected_puzzle = runtime_pack["puzzles"][0]

	var puzzle_state_manager = get_node_or_null("/root/PuzzleStateManager")
	if puzzle_state_manager and puzzle_state_manager.has_method("clear_all_state"):
		puzzle_state_manager.clear_all_state()

	GLOBAL.change_scene_with_loading("res://Scenes/PuzzleGame.tscn")
