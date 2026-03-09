extends Node

signal catalog_updated(manifest: Dictionary)
signal daily_challenge_updated(manifest: Dictionary)
signal entitlements_updated(entitlements: Dictionary)
signal asset_downloaded(relative_path: String, local_path: String)
signal request_failed(kind: String, code: int, message: String)

const DEFAULT_CACHE_DIR := "user://catalog"
const DEFAULT_API_BASE_URL := ""
const DEFAULT_LOCAL_CONTENT_ROOT := ""
const DEFAULT_DEV_ENTITLEMENTS_PATH := ""
const DEFAULT_CATALOG_MANIFEST_PATH := "catalog/catalog_manifest.json"
const DEFAULT_DAILY_MANIFEST_PATH := "catalog/daily/%s.json"
const DEFAULT_CATALOG_ENDPOINT := "/v1/catalog"
const DEFAULT_DAILY_ENDPOINT_TEMPLATE := "/v1/catalog/daily/%s"
const DEFAULT_DAILY_COMPLETION_ENDPOINT := "/v1/challenges/daily/complete"
const DEFAULT_ENTITLEMENTS_ENDPOINT := "/v1/entitlements"
const DEFAULT_CONTENT_SIGN_ENDPOINT := "/v1/content/sign"
const DEFAULT_DAILY_REWARD_CLAIM_ENDPOINT := "/v1/rewards/daily/claim"

@export var base_url: String = ""
@export var api_base_url: String = DEFAULT_API_BASE_URL
@export var local_content_root: String = DEFAULT_LOCAL_CONTENT_ROOT
@export var dev_entitlements_path: String = DEFAULT_DEV_ENTITLEMENTS_PATH
@export var cache_dir: String = DEFAULT_CACHE_DIR
@export var catalog_manifest_path: String = DEFAULT_CATALOG_MANIFEST_PATH
@export var daily_manifest_path_template: String = DEFAULT_DAILY_MANIFEST_PATH
@export var catalog_endpoint: String = DEFAULT_CATALOG_ENDPOINT
@export var daily_endpoint_template: String = DEFAULT_DAILY_ENDPOINT_TEMPLATE
@export var daily_completion_endpoint: String = DEFAULT_DAILY_COMPLETION_ENDPOINT
@export var entitlements_endpoint: String = DEFAULT_ENTITLEMENTS_ENDPOINT
@export var content_sign_endpoint: String = DEFAULT_CONTENT_SIGN_ENDPOINT
@export var daily_reward_claim_endpoint: String = DEFAULT_DAILY_REWARD_CLAIM_ENDPOINT
@export var app_user_id: String = ""
@export var timeout_seconds: float = 15.0

var _catalog_manifest_cache: Dictionary = {}
var _daily_manifest_cache: Dictionary = {}
var _entitlements_cache: Dictionary = {}

func _ready() -> void:
	_load_project_settings()
	if app_user_id == "":
		app_user_id = _ensure_app_user_id()
	_ensure_cache_dir()
	if has_remote_catalog():
		call_deferred("_warm_catalog_cache")

func _load_project_settings() -> void:
	if ProjectSettings.has_setting("catalog/base_url"):
		base_url = str(ProjectSettings.get_setting("catalog/base_url"))
	if ProjectSettings.has_setting("catalog/api_base_url"):
		api_base_url = str(ProjectSettings.get_setting("catalog/api_base_url"))
	if ProjectSettings.has_setting("catalog/local_content_root"):
		local_content_root = str(ProjectSettings.get_setting("catalog/local_content_root"))
	if ProjectSettings.has_setting("catalog/dev_entitlements_path"):
		dev_entitlements_path = str(ProjectSettings.get_setting("catalog/dev_entitlements_path"))
	if ProjectSettings.has_setting("catalog/cache_dir"):
		cache_dir = str(ProjectSettings.get_setting("catalog/cache_dir"))
	if ProjectSettings.has_setting("catalog/catalog_manifest_path"):
		catalog_manifest_path = str(ProjectSettings.get_setting("catalog/catalog_manifest_path"))
	if ProjectSettings.has_setting("catalog/daily_manifest_path_template"):
		daily_manifest_path_template = str(ProjectSettings.get_setting("catalog/daily_manifest_path_template"))
	if ProjectSettings.has_setting("catalog/catalog_endpoint"):
		catalog_endpoint = str(ProjectSettings.get_setting("catalog/catalog_endpoint"))
	if ProjectSettings.has_setting("catalog/daily_endpoint_template"):
		daily_endpoint_template = str(ProjectSettings.get_setting("catalog/daily_endpoint_template"))
	if ProjectSettings.has_setting("catalog/daily_completion_endpoint"):
		daily_completion_endpoint = str(ProjectSettings.get_setting("catalog/daily_completion_endpoint"))
	if ProjectSettings.has_setting("catalog/entitlements_endpoint"):
		entitlements_endpoint = str(ProjectSettings.get_setting("catalog/entitlements_endpoint"))
	if ProjectSettings.has_setting("catalog/content_sign_endpoint"):
		content_sign_endpoint = str(ProjectSettings.get_setting("catalog/content_sign_endpoint"))
	if ProjectSettings.has_setting("catalog/daily_reward_claim_endpoint"):
		daily_reward_claim_endpoint = str(ProjectSettings.get_setting("catalog/daily_reward_claim_endpoint"))
	if ProjectSettings.has_setting("catalog/app_user_id"):
		app_user_id = str(ProjectSettings.get_setting("catalog/app_user_id"))
	if ProjectSettings.has_setting("catalog/timeout_seconds"):
		timeout_seconds = float(ProjectSettings.get_setting("catalog/timeout_seconds"))

func _ensure_app_user_id() -> String:
	var path := "user://app_user_id.txt"
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path).strip_edges()
	var generated_id := "%s-%s" % [str(Time.get_unix_time_from_system()), str(randi())]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(generated_id)
		file.close()
	return generated_id

func _warm_catalog_cache() -> void:
	await fetch_catalog_manifest(true)
	await fetch_entitlements(true)

func _create_http_request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = timeout_seconds
	add_child(request)
	return request

func _ensure_cache_dir() -> void:
	_ensure_relative_user_dir(cache_dir)
	_ensure_relative_user_dir(cache_dir.path_join("assets"))

func _ensure_relative_user_dir(path: String) -> void:
	var root := DirAccess.open("user://")
	if root == null:
		return
	var relative := path.trim_prefix("user://")
	if relative.is_empty():
		return
	if not root.dir_exists(relative):
		root.make_dir_recursive(relative)

func uses_backend_api() -> bool:
	return api_base_url.strip_edges() != ""

func uses_local_content_root() -> bool:
	return local_content_root.strip_edges() != ""

func has_remote_catalog() -> bool:
	return uses_backend_api() or uses_local_content_root() or base_url.strip_edges() != ""

func set_app_user_id(value: String) -> void:
	app_user_id = value.strip_edges()

func get_app_user_id() -> String:
	return app_user_id

func fetch_catalog_manifest(force_refresh: bool = false) -> Dictionary:
	if not force_refresh and not _catalog_manifest_cache.is_empty():
		return _catalog_manifest_cache
	if not has_remote_catalog():
		request_failed.emit("catalog", ERR_UNAVAILABLE, "catalog/base_url and catalog/api_base_url are empty.")
		return load_cached_catalog_manifest()

	var response := {}
	if uses_backend_api():
		response = await _request_json(_append_app_user_id(_build_api_url(catalog_endpoint)))
	elif uses_local_content_root():
		var local_manifest := _load_local_json(_local_content_path(catalog_manifest_path))
		if local_manifest.is_empty():
			request_failed.emit("catalog", ERR_DOES_NOT_EXIST, "catalog_local_manifest_missing")
			return load_cached_catalog_manifest()
		response = {"ok": true, "code": OK, "data": local_manifest}
	else:
		response = await _request_json(_build_url(catalog_manifest_path))
	if not response.get("ok", false):
		request_failed.emit("catalog", int(response.get("code", ERR_CANT_CONNECT)), str(response.get("message", "catalog_request_failed")))
		return load_cached_catalog_manifest()

	var manifest = response.get("data", {})
	_catalog_manifest_cache = manifest.duplicate(true)
	_save_cached_json(_catalog_cache_path(), manifest)
	catalog_updated.emit(manifest)
	return manifest

func fetch_daily_challenge_manifest(date_ymd: String = "") -> Dictionary:
	var resolved_date := date_ymd if date_ymd != "" else Time.get_date_string_from_system()
	if not has_remote_catalog():
		request_failed.emit("daily", ERR_UNAVAILABLE, "catalog/base_url and catalog/api_base_url are empty.")
		return load_cached_daily_challenge_manifest(resolved_date)

	var response := {}
	if uses_backend_api():
		var endpoint := daily_endpoint_template % resolved_date
		response = await _request_json(_append_app_user_id(_build_api_url(endpoint)))
	elif uses_local_content_root():
		var local_daily_path := daily_manifest_path_template % resolved_date
		var local_daily := _load_local_json(_local_content_path(local_daily_path))
		if local_daily.is_empty():
			request_failed.emit("daily", ERR_DOES_NOT_EXIST, "daily_local_manifest_missing")
			return load_cached_daily_challenge_manifest(resolved_date)
		response = {"ok": true, "code": OK, "data": local_daily}
	else:
		var relative_path := daily_manifest_path_template % resolved_date
		response = await _request_json(_build_url(relative_path))
	if not response.get("ok", false):
		request_failed.emit("daily", int(response.get("code", ERR_CANT_CONNECT)), str(response.get("message", "daily_request_failed")))
		return load_cached_daily_challenge_manifest(resolved_date)

	var manifest = response.get("data", {})
	_daily_manifest_cache[resolved_date] = manifest.duplicate(true)
	_save_cached_json(_daily_cache_path(resolved_date), manifest)
	daily_challenge_updated.emit(manifest)
	return manifest

func fetch_entitlements(force_refresh: bool = false) -> Dictionary:
	if not force_refresh and not _entitlements_cache.is_empty():
		return _entitlements_cache

	if not uses_backend_api():
		var emulated_entitlements := _load_dev_entitlements_for_current_user()
		if not emulated_entitlements.is_empty():
			var local_catalog = await fetch_catalog_manifest(force_refresh)
			emulated_entitlements["accessible_pack_ids"] = _compute_accessible_pack_ids(local_catalog, emulated_entitlements)
			_entitlements_cache = emulated_entitlements.duplicate(true)
			entitlements_updated.emit(_entitlements_cache)
			return _entitlements_cache
		var cached_catalog = await fetch_catalog_manifest(force_refresh)
		var viewer = cached_catalog.get("viewer", {})
		if typeof(viewer) == TYPE_DICTIONARY:
			_entitlements_cache = viewer.duplicate(true)
			entitlements_updated.emit(_entitlements_cache)
			return _entitlements_cache
		return {}

	var response := await _request_json(_append_app_user_id(_build_api_url(entitlements_endpoint)))
	if not response.get("ok", false):
		request_failed.emit("entitlements", int(response.get("code", ERR_CANT_CONNECT)), str(response.get("message", "entitlements_request_failed")))
		return {}

	_entitlements_cache = response.get("data", {}).duplicate(true)
	entitlements_updated.emit(_entitlements_cache)
	return _entitlements_cache

func report_daily_challenge_completion(manifest: Dictionary, stats: Dictionary = {}) -> Dictionary:
	if not uses_backend_api():
		return {"ok": false, "reason": "backend_unavailable"}

	var date := _resolve_daily_manifest_date(manifest)
	if date == "":
		return {"ok": false, "reason": "missing_date"}

	var challenge_id := _resolve_daily_manifest_challenge_id(manifest)
	var completion_session := await _resolve_daily_completion_session(manifest)
	var completion_token := str(completion_session.get("token", "")).strip_edges()
	if completion_token == "":
		return {"ok": false, "reason": "missing_completion_token"}
	var response := await _request_json(
		_build_api_url(daily_completion_endpoint),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"app_user_id": app_user_id,
			"date": date,
			"challenge_id": challenge_id,
			"completion_token": completion_token,
			"stats": stats
		}),
		["Content-Type: application/json"]
	)
	if not response.get("ok", false):
		request_failed.emit("daily_completion", int(response.get("code", ERR_CANT_CONNECT)), str(response.get("message", "daily_completion_failed")))
		return {"ok": false, "reason": str(response.get("message", "daily_completion_failed")), "code": int(response.get("code", ERR_CANT_CONNECT))}

	var payload = response.get("data", {})
	var entitlements = payload.get("entitlements", {})
	if typeof(entitlements) == TYPE_DICTIONARY and not entitlements.is_empty():
		_entitlements_cache = entitlements.duplicate(true)
		entitlements_updated.emit(_entitlements_cache)

	return payload if typeof(payload) == TYPE_DICTIONARY else {"ok": false, "reason": "invalid_completion_response"}

func queue_daily_challenge_completion_report(manifest: Dictionary, stats: Dictionary = {}) -> void:
	if manifest.is_empty() or not uses_backend_api():
		return
	call_deferred("_run_daily_completion_report", manifest.duplicate(true), stats.duplicate(true))

func _run_daily_completion_report(manifest: Dictionary, stats: Dictionary) -> void:
	await report_daily_challenge_completion(manifest, stats)

func claim_daily_challenge_reward(manifest: Dictionary) -> Dictionary:
	if not uses_backend_api():
		return {"ok": false, "reason": "backend_unavailable"}

	var date := str(manifest.get("date", "")).strip_edges()
	if date == "":
		return {"ok": false, "reason": "missing_date"}

	var challenge_id := str(manifest.get("challenge_id", "")).strip_edges()
	var response := await _request_json(
		_build_api_url(daily_reward_claim_endpoint),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"app_user_id": app_user_id,
			"date": date,
			"challenge_id": challenge_id
		}),
		["Content-Type: application/json"]
	)
	if not response.get("ok", false):
		request_failed.emit("daily_reward_claim", int(response.get("code", ERR_CANT_CONNECT)), str(response.get("message", "daily_reward_claim_failed")))
		return {"ok": false, "reason": str(response.get("message", "daily_reward_claim_failed")), "code": int(response.get("code", ERR_CANT_CONNECT))}

	var payload = response.get("data", {})
	var entitlements = payload.get("entitlements", {})
	if typeof(entitlements) == TYPE_DICTIONARY and not entitlements.is_empty():
		_entitlements_cache = entitlements.duplicate(true)
		entitlements_updated.emit(_entitlements_cache)

	return payload if typeof(payload) == TYPE_DICTIONARY else {"ok": false, "reason": "invalid_claim_response"}

func resolve_asset_urls(relative_paths: Array) -> Dictionary:
	var normalized_paths: Array = []
	for relative_path in relative_paths:
		var normalized_path := str(relative_path).trim_prefix("/")
		if normalized_path != "" and normalized_path not in normalized_paths:
			normalized_paths.append(normalized_path)

	if normalized_paths.is_empty():
		return {}

	if not uses_backend_api():
		var public_urls := {}
		for normalized_path in normalized_paths:
			public_urls[normalized_path] = {
				"access": "public",
				"url": _build_url(normalized_path)
			}
		return public_urls

	var response := await _request_json(
		_build_api_url(content_sign_endpoint),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"app_user_id": app_user_id,
			"asset_paths": normalized_paths
		}),
		["Content-Type: application/json"]
	)
	if not response.get("ok", false):
		request_failed.emit("content_sign", int(response.get("code", ERR_CANT_CONNECT)), str(response.get("message", "content_sign_failed")))
		return {}
	return response.get("data", {}).get("urls", {})

func resolve_asset_url(relative_path: String) -> String:
	var urls := await resolve_asset_urls([relative_path])
	var normalized_path := relative_path.trim_prefix("/")
	if not urls.has(normalized_path):
		return ""
	var entry = urls[normalized_path]
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	return str(entry.get("url", ""))

func load_cached_catalog_manifest() -> Dictionary:
	var cached = _load_cached_json(_catalog_cache_path())
	if not cached.is_empty():
		_catalog_manifest_cache = cached.duplicate(true)
	return cached

func load_cached_daily_challenge_manifest(date_ymd: String) -> Dictionary:
	var cached := _load_cached_json(_daily_cache_path(date_ymd))
	if not cached.is_empty():
		_daily_manifest_cache[date_ymd] = cached.duplicate(true)
	return cached

func get_catalog_manifest() -> Dictionary:
	if _catalog_manifest_cache.is_empty():
		_catalog_manifest_cache = load_cached_catalog_manifest()
	return _catalog_manifest_cache.duplicate(true)

func get_pack_entry(pack_id: String, manifest: Dictionary = {}) -> Dictionary:
	var source_manifest := manifest if not manifest.is_empty() else get_catalog_manifest()
	for pack in source_manifest.get("packs", []):
		if typeof(pack) == TYPE_DICTIONARY and str(pack.get("id", "")) == pack_id:
			return pack.duplicate(true)
	return {}

func get_catalog_pack_ids(manifest: Dictionary = {}) -> Array:
	var source_manifest := manifest if not manifest.is_empty() else get_catalog_manifest()
	var pack_ids: Array = []
	for pack in source_manifest.get("packs", []):
		if typeof(pack) != TYPE_DICTIONARY:
			continue
		var pack_id := str(pack.get("id", ""))
		if pack_id != "" and pack_id not in pack_ids:
			pack_ids.append(pack_id)
	return pack_ids

func get_accessible_pack_ids(manifest: Dictionary = {}) -> Array:
	var source_manifest := manifest if not manifest.is_empty() else get_catalog_manifest()
	var pack_ids: Array = []
	if typeof(_entitlements_cache) == TYPE_DICTIONARY:
		for pack_id in _entitlements_cache.get("accessible_pack_ids", []):
			var normalized_entitled_pack_id := str(pack_id)
			if normalized_entitled_pack_id != "" and normalized_entitled_pack_id not in pack_ids:
				pack_ids.append(normalized_entitled_pack_id)
	if not pack_ids.is_empty():
		return pack_ids
	if typeof(_entitlements_cache) == TYPE_DICTIONARY and not _entitlements_cache.is_empty():
		pack_ids = _compute_accessible_pack_ids(source_manifest, _entitlements_cache)
	if not pack_ids.is_empty():
		return pack_ids
	var viewer = source_manifest.get("viewer", {})
	if typeof(viewer) == TYPE_DICTIONARY:
		for pack_id in viewer.get("accessible_pack_ids", []):
			var normalized_pack_id := str(pack_id)
			if normalized_pack_id != "" and normalized_pack_id not in pack_ids:
				pack_ids.append(normalized_pack_id)
	if not pack_ids.is_empty():
		return pack_ids

	var fallback_pack_ids := get_active_free_pack_ids(source_manifest)
	if fallback_pack_ids.is_empty():
		fallback_pack_ids = get_catalog_pack_ids(source_manifest)
	return fallback_pack_ids

func get_rewards_inventory() -> Dictionary:
	if _entitlements_cache.is_empty():
		return {}
	var inventory = _entitlements_cache.get("rewards_inventory", {})
	return inventory.duplicate(true) if typeof(inventory) == TYPE_DICTIONARY else {}

func get_daily_completion_entry(challenge_key: String) -> Dictionary:
	if challenge_key == "" or _entitlements_cache.is_empty():
		return {}
	var completions = _entitlements_cache.get("daily_completions", {})
	if typeof(completions) != TYPE_DICTIONARY or not completions.has(challenge_key):
		return {}
	var entry = completions.get(challenge_key, {})
	return entry.duplicate(true) if typeof(entry) == TYPE_DICTIONARY else {}

func get_daily_claim_entry(challenge_key: String) -> Dictionary:
	if challenge_key == "" or _entitlements_cache.is_empty():
		return {}
	var claims = _entitlements_cache.get("daily_claims", {})
	if typeof(claims) != TYPE_DICTIONARY or not claims.has(challenge_key):
		return {}
	var entry = claims.get(challenge_key, {})
	return entry.duplicate(true) if typeof(entry) == TYPE_DICTIONARY else {}

func get_cached_daily_challenge_manifest(date_ymd: String) -> Dictionary:
	var resolved_date := date_ymd.strip_edges()
	if resolved_date == "":
		return {}
	if _daily_manifest_cache.has(resolved_date):
		var cached_entry = _daily_manifest_cache.get(resolved_date, {})
		if typeof(cached_entry) == TYPE_DICTIONARY:
			return (cached_entry as Dictionary).duplicate(true)
	return load_cached_daily_challenge_manifest(resolved_date)

func fetch_asset_json(relative_path: String) -> Dictionary:
	if uses_local_content_root():
		return _load_local_json(_local_content_path(relative_path))
	var asset_url := await resolve_asset_url(relative_path)
	if asset_url == "":
		request_failed.emit("asset_json", ERR_DOES_NOT_EXIST, "asset_url_not_found")
		return {}
	var response := await _request_json(asset_url)
	if not response.get("ok", false):
		request_failed.emit("asset_json", int(response.get("code", ERR_CANT_CONNECT)), str(response.get("message", "asset_json_failed")))
		return {}
	return response.get("data", {})

func download_asset(relative_path: String, local_path: String = "") -> Dictionary:
	if not has_remote_catalog():
		return {"ok": false, "code": ERR_UNAVAILABLE, "message": "catalog/base_url and catalog/api_base_url are empty."}

	var normalized_path := relative_path.trim_prefix("/")
	var destination := local_path if local_path != "" else _asset_cache_path(normalized_path)
	if uses_local_content_root():
		var source_path := _local_content_path(normalized_path)
		if not FileAccess.file_exists(source_path):
			return {"ok": false, "code": ERR_DOES_NOT_EXIST, "message": "asset_local_file_not_found"}
		_ensure_relative_user_dir(destination.get_base_dir())
		var source_file := FileAccess.open(source_path, FileAccess.READ)
		if source_file == null:
			return {"ok": false, "code": ERR_CANT_OPEN, "message": "asset_local_open_failed"}
		var asset_bytes := source_file.get_buffer(source_file.get_length())
		source_file.close()
		var destination_file := FileAccess.open(destination, FileAccess.WRITE)
		if destination_file == null:
			return {"ok": false, "code": ERR_CANT_CREATE, "message": "asset_local_write_failed"}
		destination_file.store_buffer(asset_bytes)
		destination_file.close()
		asset_downloaded.emit(normalized_path, destination)
		return {"ok": true, "path": destination, "response_code": OK}
	var asset_url := await resolve_asset_url(normalized_path)
	if asset_url == "":
		return {"ok": false, "code": ERR_DOES_NOT_EXIST, "message": "asset_url_not_found"}

	_ensure_relative_user_dir(destination.get_base_dir())
	var http_request := _create_http_request()
	http_request.download_file = destination

	var err := http_request.request(asset_url)
	if err != OK:
		http_request.queue_free()
		return {"ok": false, "code": err, "message": "request_failed"}

	var result = await http_request.request_completed
	http_request.queue_free()

	var transport_code := int(result[0])
	var response_code := int(result[1])
	if transport_code != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": transport_code, "message": "transport_failed"}
	if response_code < 200 or response_code >= 300:
		return {"ok": false, "code": response_code, "message": "http_error"}

	asset_downloaded.emit(normalized_path, destination)
	return {"ok": true, "path": destination, "response_code": response_code}

func get_active_free_pack_ids(manifest: Dictionary) -> Array:
	var pack_ids: Array = []
	var free_rotation = manifest.get("free_rotation", {})
	if typeof(free_rotation) != TYPE_DICTIONARY:
		return pack_ids
	for pack_id in free_rotation.get("active_pack_ids", []):
		var normalized_id := str(pack_id)
		if normalized_id != "" and normalized_id not in pack_ids:
			pack_ids.append(normalized_id)
	return pack_ids

func _request_json(url: String, method: int = HTTPClient.METHOD_GET, body: String = "", headers: Array = []) -> Dictionary:
	var http_request := _create_http_request()
	var err := http_request.request(url, headers, method, body)
	if err != OK:
		http_request.queue_free()
		return {"ok": false, "code": err, "message": "request_failed"}

	var result = await http_request.request_completed
	http_request.queue_free()
	var transport_code := int(result[0])
	var response_code := int(result[1])
	var response_body: PackedByteArray = result[3]

	if transport_code != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": transport_code, "message": "transport_failed"}
	if response_code < 200 or response_code >= 300:
		return {"ok": false, "code": response_code, "message": "http_error"}

	var parsed = JSON.parse_string(response_body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "code": ERR_PARSE_ERROR, "message": "invalid_json"}

	return {"ok": true, "code": response_code, "data": parsed}

func _save_cached_json(path: String, payload: Dictionary) -> void:
	_ensure_relative_user_dir(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

func _load_cached_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _load_local_json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _catalog_cache_path() -> String:
	return cache_dir.path_join("catalog_manifest.json")

func _daily_cache_path(date_ymd: String) -> String:
	return cache_dir.path_join("daily_%s.json" % date_ymd)

func _asset_cache_path(relative_path: String) -> String:
	var normalized_path := relative_path.trim_prefix("/")
	return cache_dir.path_join("assets").path_join(normalized_path)

func _local_content_path(relative_path: String) -> String:
	return local_content_root.path_join(relative_path.trim_prefix("/"))

func _build_url(relative_path: String) -> String:
	return base_url.rstrip("/") + "/" + relative_path.trim_prefix("/")

func _build_api_url(relative_path: String) -> String:
	return api_base_url.rstrip("/") + "/" + relative_path.trim_prefix("/")

func _append_app_user_id(url: String) -> String:
	var separator := "&" if "?" in url else "?"
	return "%s%sapp_user_id=%s" % [url, separator, app_user_id.uri_encode()]

func _resolve_daily_completion_session(manifest: Dictionary) -> Dictionary:
	var inline_session = manifest.get("completion_session", {})
	if typeof(inline_session) == TYPE_DICTIONARY and not inline_session.is_empty():
		return (inline_session as Dictionary).duplicate(true)

	var resolved_date := _resolve_daily_manifest_date(manifest)
	if resolved_date != "":
		var cached_manifest := get_cached_daily_challenge_manifest(resolved_date)
		var cached_session = cached_manifest.get("completion_session", {})
		if typeof(cached_session) == TYPE_DICTIONARY and not cached_session.is_empty():
			return (cached_session as Dictionary).duplicate(true)

		if uses_backend_api():
			var refreshed_manifest := await fetch_daily_challenge_manifest(resolved_date)
			var refreshed_session = refreshed_manifest.get("completion_session", {})
			if typeof(refreshed_session) == TYPE_DICTIONARY and not refreshed_session.is_empty():
				return (refreshed_session as Dictionary).duplicate(true)

	return {}

func _resolve_daily_manifest_date(manifest: Dictionary) -> String:
	return str(manifest.get("date", manifest.get("daily_challenge_date", ""))).strip_edges()

func _resolve_daily_manifest_challenge_id(manifest: Dictionary) -> String:
	return str(manifest.get("challenge_id", manifest.get("daily_challenge_id", ""))).strip_edges()

func _load_dev_entitlements_for_current_user() -> Dictionary:
	if dev_entitlements_path.strip_edges() == "":
		return {}
	var payload := _load_local_json(dev_entitlements_path)
	if payload.is_empty():
		return {}
	var users = payload.get("users", {})
	if typeof(users) != TYPE_DICTIONARY or not users.has(app_user_id):
		return {}
	var entry = users.get(app_user_id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var entitlements := (entry as Dictionary).duplicate(true)
	entitlements["app_user_id"] = app_user_id
	if not entitlements.has("premium_active"):
		entitlements["premium_active"] = false
	if not entitlements.has("active_skus"):
		entitlements["active_skus"] = []
	if not entitlements.has("cosmetics"):
		entitlements["cosmetics"] = []
	return entitlements

func _compute_accessible_pack_ids(manifest: Dictionary, entitlements: Dictionary) -> Array:
	var accessible_pack_ids: Array = []
	if manifest.is_empty():
		return accessible_pack_ids
	var premium_active := bool(entitlements.get("premium_active", false))
	var active_free_pack_ids := get_active_free_pack_ids(manifest)
	for pack in manifest.get("packs", []):
		if typeof(pack) != TYPE_DICTIONARY:
			continue
		var pack_id := str(pack.get("id", ""))
		if pack_id == "":
			continue
		var tier := str(pack.get("tier", "free"))
		var can_access := false
		match tier:
			"premium", "premium_exclusive", "seasonal_premium", "daily_premium":
				can_access = premium_active
			"free_rotating":
				can_access = active_free_pack_ids.is_empty() or pack_id in active_free_pack_ids
			_:
				can_access = true
		if can_access and pack_id not in accessible_pack_ids:
			accessible_pack_ids.append(pack_id)
	return accessible_pack_ids
