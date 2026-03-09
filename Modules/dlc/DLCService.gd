extends Node

# Servicio para gestionar compras y contenido DLC descargable.

const PACKS_INDEX_PATH := "res://dlc/new_base_packs.json"
const PACKS_SOURCE_DIR := "res://dlc/packs"
const USER_DLC_DIR := "user://dlc/packs"
const METADATA_PATH := "user://dlc/dlc_metadata.json"
@export var sku_mapping_path: String = "res://Modules/commerce/config/sku_mapping.json"

signal pack_installed(pack_id)
signal download_progress(pack_id, file_path, received, total)
signal download_finished(pack_id, success)

@export var base_url: String = ""  # Puede configurarse también en ProjectSettings: dlc/base_url

var _http: HTTPRequest

func _ready():
	_ensure_dirs()
	_ensure_http()
	if base_url == "":
		if ProjectSettings.has_setting("dlc/base_url"):
			base_url = str(ProjectSettings.get_setting("dlc/base_url"))

func _ensure_dirs():
	var base_dir := DirAccess.open("user://")
	if base_dir:
		if not base_dir.dir_exists("user://dlc"):
			base_dir.make_dir("user://dlc")
		if not base_dir.dir_exists(USER_DLC_DIR):
			base_dir.make_dir_recursive(USER_DLC_DIR)

func _ensure_http():
	if _http == null or not is_instance_valid(_http):
		_http = HTTPRequest.new()
		_http.timeout = 30.0
		add_child(_http)

func _load_sku_mapping() -> Dictionary:
	var mapping_path = sku_mapping_path
	if ProjectSettings.has_setting("commerce/sku_mapping_path"):
		mapping_path = str(ProjectSettings.get_setting("commerce/sku_mapping_path"))
	if not ResourceLoader.exists(mapping_path):
		return {}
	var file := FileAccess.open(mapping_path, FileAccess.READ)
	if file == null:
		return {}
	var json_text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _load_metadata() -> Dictionary:
	if not FileAccess.file_exists(METADATA_PATH):
		return {}
	var file := FileAccess.open(METADATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _save_metadata(metadata: Dictionary) -> void:
	var file := FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(metadata))
	file.close()

func _load_pack_ids_from_index(path: String) -> Array:
	var pack_ids: Array = []
	if not FileAccess.file_exists(path):
		return pack_ids
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return pack_ids
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("packs"):
		return pack_ids
	for pack in parsed.packs:
		if typeof(pack) == TYPE_DICTIONARY and pack.has("id"):
			var pack_id := str(pack.id)
			if pack_id != "" and pack_id not in pack_ids:
				pack_ids.append(pack_id)
	return pack_ids

func get_all_catalog_pack_ids() -> Array:
	var pack_ids: Array = []
	for pack_id in _load_pack_ids_from_index("res://PacksData/sample_packs.json"):
		if pack_id not in pack_ids:
			pack_ids.append(pack_id)
	for pack_id in _load_pack_ids_from_index(PACKS_INDEX_PATH):
		if pack_id not in pack_ids:
			pack_ids.append(pack_id)
	var remote_catalog_service = _get_remote_catalog_service()
	if remote_catalog_service:
		for pack in remote_catalog_service.get_catalog_manifest().get("packs", []):
			if typeof(pack) != TYPE_DICTIONARY:
				continue
			var remote_pack_id := str(pack.get("id", ""))
			if remote_pack_id != "" and remote_pack_id not in pack_ids:
				pack_ids.append(remote_pack_id)
	return pack_ids

func get_configured_skus() -> Array:
	var skus: Array = []
	for sku in _load_sku_mapping().keys():
		skus.append(str(sku))
	skus.sort()
	return skus

func get_packs_for_sku(sku: String) -> Array:
	var mapping = _load_sku_mapping()
	if typeof(mapping) != TYPE_DICTIONARY or not mapping.has(sku):
		return []

	var resolved_packs: Array = []
	for item in mapping[sku]:
		var pack_id := str(item)
		if pack_id == "all_packs":
			for catalog_pack_id in get_all_catalog_pack_ids():
				if catalog_pack_id not in resolved_packs:
					resolved_packs.append(catalog_pack_id)
		elif pack_id != "" and pack_id not in resolved_packs:
			resolved_packs.append(pack_id)
	return resolved_packs

func has_download_support() -> bool:
	var remote_catalog_service = _get_remote_catalog_service()
	return (base_url != null and base_url != "") or (remote_catalog_service != null and remote_catalog_service.has_remote_catalog())

func mark_packs_purchased(packs: Array) -> void:
	# Actualiza GLOBAL.dlc_packs y guarda settings
	if has_node("/root/GLOBAL"):
		var g := get_node("/root/GLOBAL")
		for p in packs:
			if p not in g.dlc_packs:
				g.dlc_packs.append(p)
		g.save_settings()
	# También persiste metadata específica
	var meta := _load_metadata()
	if not meta.has("purchased_packs"):
		meta["purchased_packs"] = []
	for p in packs:
		if p not in meta.purchased_packs:
			meta.purchased_packs.append(p)
	meta["last_update"] = Time.get_datetime_string_from_system()
	_save_metadata(meta)

func get_entitled_packs() -> Array:
	if has_node("/root/GLOBAL"):
		var global_node = get_node("/root/GLOBAL")
		if global_node.get("dlc_packs") != null:
			return global_node.dlc_packs.duplicate()
	var metadata := _load_metadata()
	if metadata.has("entitled_packs"):
		return metadata.entitled_packs.duplicate()
	if metadata.has("purchased_packs"):
		return metadata.purchased_packs.duplicate()
	return []

func _file_exists_any(path: String) -> bool:
	if path.strip_edges() == "":
		return false
	if path.begins_with("user://"):
		return FileAccess.file_exists(path)
	return ResourceLoader.exists(path)

func _is_pack_installed(pack_id: String) -> bool:
	if pack_id.strip_edges() == "":
		return false
	var json_path := USER_DLC_DIR + "/" + pack_id + ".json"
	if not FileAccess.file_exists(json_path):
		return false
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var pack_data := parsed as Dictionary
	var thumbnail_path := str(pack_data.get("image_path", ""))
	if thumbnail_path != "" and not _file_exists_any(thumbnail_path):
		return false
	var music_path := str(pack_data.get("music_path", ""))
	if music_path != "" and not _file_exists_any(music_path):
		return false
	for puzzle in pack_data.get("puzzles", []):
		if typeof(puzzle) != TYPE_DICTIONARY:
			continue
		var image_path := str(puzzle.get("image", puzzle.get("image_path", "")))
		if image_path == "":
			return false
		if not _file_exists_any(image_path):
			return false
	return true

func set_entitled_packs(packs: Array) -> void:
	var normalized_packs: Array = []
	for pack in packs:
		var pack_id := str(pack)
		if pack_id != "" and pack_id not in normalized_packs:
			normalized_packs.append(pack_id)
	normalized_packs.sort()

	if has_node("/root/GLOBAL"):
		var global_node = get_node("/root/GLOBAL")
		global_node.dlc_packs = normalized_packs.duplicate()
		if global_node.has_method("save_settings"):
			global_node.save_settings()

	var metadata := _load_metadata()
	metadata["entitled_packs"] = normalized_packs.duplicate()
	metadata["last_update"] = Time.get_datetime_string_from_system()
	_save_metadata(metadata)

func sync_access_for_pack_ids(entitled_pack_ids: Array, auto_install: bool = false) -> Array:
	var normalized_packs: Array = []
	for pack_id_value in entitled_pack_ids:
		var pack_id := str(pack_id_value)
		if pack_id != "" and pack_id not in normalized_packs:
			normalized_packs.append(pack_id)
	normalized_packs.sort()

	var previous_packs := get_entitled_packs()
	set_entitled_packs(normalized_packs)

	var newly_entitled: Array = []
	for pack_id in normalized_packs:
		if pack_id not in previous_packs:
			newly_entitled.append(pack_id)

	if auto_install:
		var packs_to_install := newly_entitled.duplicate()
		for pack_id in normalized_packs:
			if pack_id not in packs_to_install and not _is_pack_installed(pack_id):
				packs_to_install.append(pack_id)
		if not packs_to_install.is_empty():
			if has_download_support():
				await download_and_install_packs(packs_to_install)
			else:
				install_packs_from_base(packs_to_install)

	return normalized_packs

func sync_access_for_skus(active_skus: Array, auto_install: bool = false) -> Array:
	var entitled_packs: Array = []
	for sku in active_skus:
		for pack_id in get_packs_for_sku(str(sku)):
			if pack_id not in entitled_packs:
				entitled_packs.append(pack_id)
	return await sync_access_for_pack_ids(entitled_packs, auto_install)

func install_pack_json(pack_id: String) -> bool:
	_ensure_dirs()
	# Copia el JSON del pack desde res:// hacia user:// (simula descarga)
	var src_path := PACKS_SOURCE_DIR + "/" + pack_id + ".json"
	if not FileAccess.file_exists(src_path):
		return false
	var src := FileAccess.open(src_path, FileAccess.READ)
	if src == null:
		return false
	var content := src.get_as_text()
	src.close()
	var dst_path := USER_DLC_DIR + "/" + pack_id + ".json"
	var dst := FileAccess.open(dst_path, FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_string(content)
	dst.close()
	pack_installed.emit(pack_id)
	return true

func install_packs_from_base(packs: Array) -> int:
	var ok := 0
	for p in packs:
		if install_pack_json(p):
			ok += 1
	return ok

# ========== Descarga HTTP y preparación de contenido ==========

func _download_to_memory(url: String) -> Dictionary:
	_ensure_http()
	var err = _http.request(url)
	if err != OK:
		return {"ok": false, "code": err, "body": PackedByteArray()}
	var result = await _http.request_completed
	var response_code: int = result[1]
	var body: PackedByteArray = result[3]
	return {"ok": response_code >= 200 and response_code < 300, "code": response_code, "body": body}

func _save_bytes(dst_path: String, bytes: PackedByteArray) -> bool:
	var dir = dst_path.get_base_dir()
	var d = DirAccess.open("user://")
	if d:
		if not d.dir_exists(dir):
			d.make_dir_recursive(dir)
	var f = FileAccess.open(dst_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	return true

func _extract_filename_from_path(path: String) -> String:
	if path == "":
		return ""
	var parts = path.split("/")
	return parts[parts.size()-1]

func _get_remote_catalog_service() -> Node:
	return get_node_or_null("/root/RemoteCatalogService")

func _get_localized_text(value, fallback: String) -> String:
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

func _build_local_pack_from_remote_manifest(pack_manifest: Dictionary, pack_id: String) -> Dictionary:
	var title_payload = _duplicate_content_value(pack_manifest.get("title", {}))
	var description_payload = _duplicate_content_value(pack_manifest.get("description", {}))
	var localized_title := _get_localized_text(title_payload, pack_id)
	var localized_description := _get_localized_text(description_payload, "")
	var local_pack := {
		"id": pack_id,
		"name": localized_title,
		"name_localized": title_payload,
		"description": localized_description,
		"description_localized": description_payload,
		"image_path": "",
		"thumbnail_path": str(pack_manifest.get("thumbnail_path", "")),
		"music_path": "",
		"unlocked": false,
		"purchased": true,
		"completed": false,
		"difficulty": str(pack_manifest.get("difficulty", "easy")),
		"puzzles": []
	}

	for puzzle in pack_manifest.get("puzzles", []):
		if typeof(puzzle) != TYPE_DICTIONARY:
			continue
		var puzzle_title_payload = _duplicate_content_value(puzzle.get("title", puzzle.get("name", {})))
		var puzzle_description_payload = _duplicate_content_value(puzzle.get("description", {}))
		var puzzle_story_payload = _duplicate_content_value(puzzle.get("story", puzzle.get("description", {})))
		var localized_story := _get_localized_text(puzzle_story_payload, _get_localized_text(puzzle_description_payload, ""))
		local_pack["puzzles"].append({
			"id": str(puzzle.get("id", "")),
			"name": _get_localized_text(puzzle_title_payload, str(puzzle.get("id", ""))),
			"name_localized": puzzle_title_payload,
			"image": "",
			"image_path": str(puzzle.get("image_path", puzzle.get("image", ""))),
			"description": localized_story,
			"description_localized": puzzle_description_payload,
			"story": localized_story,
			"story_localized": puzzle_story_payload,
			"completed": false
		})

	return local_pack

func _download_remote_pack_assets(pack_id: String, pack_manifest: Dictionary, local_pack: Dictionary) -> Dictionary:
	var remote_catalog_service = _get_remote_catalog_service()
	if remote_catalog_service == null:
		return {"ok": false, "error": "remote_catalog_service_missing"}

	var downloaded_files: Array = []
	var pack_asset_dir := USER_DLC_DIR + "/" + pack_id
	var thumbnail_path := str(pack_manifest.get("thumbnail_path", ""))
	if thumbnail_path != "":
		var thumbnail_file_name := _extract_filename_from_path(thumbnail_path)
		var thumbnail_local_path := pack_asset_dir + "/" + thumbnail_file_name
		var thumbnail_result = await remote_catalog_service.download_asset(thumbnail_path, thumbnail_local_path)
		if not thumbnail_result.get("ok", false):
			return {"ok": false, "error": "thumbnail_download_failed", "details": thumbnail_result}
		local_pack["image_path"] = thumbnail_local_path
		local_pack["thumbnail_path"] = thumbnail_local_path
		downloaded_files.append(thumbnail_local_path)
		var thumbnail_size := FileAccess.get_file_as_bytes(thumbnail_local_path).size()
		download_progress.emit(pack_id, thumbnail_file_name, thumbnail_size, -1)

	var music_path := str(pack_manifest.get("music_path", ""))
	if music_path != "":
		var music_file_name := _extract_filename_from_path(music_path)
		var music_local_path := pack_asset_dir + "/" + music_file_name
		var music_result = await remote_catalog_service.download_asset(music_path, music_local_path)
		if not music_result.get("ok", false):
			return {"ok": false, "error": "music_download_failed", "details": music_result}
		local_pack["music_path"] = music_local_path
		downloaded_files.append(music_local_path)
		var music_size := FileAccess.get_file_as_bytes(music_local_path).size()
		download_progress.emit(pack_id, music_file_name, music_size, -1)

	var puzzle_index := 0
	for puzzle in pack_manifest.get("puzzles", []):
		if typeof(puzzle) != TYPE_DICTIONARY:
			continue
		var image_path := str(puzzle.get("image_path", puzzle.get("image", "")))
		if image_path == "":
			puzzle_index += 1
			continue
		var image_file_name := _extract_filename_from_path(image_path)
		var image_local_path := pack_asset_dir + "/" + image_file_name
		var image_result = await remote_catalog_service.download_asset(image_path, image_local_path)
		if not image_result.get("ok", false):
			return {"ok": false, "error": "puzzle_asset_download_failed", "details": image_result, "puzzle_id": str(puzzle.get("id", ""))}
		if puzzle_index < local_pack["puzzles"].size():
			local_pack["puzzles"][puzzle_index]["image"] = image_local_path
			local_pack["puzzles"][puzzle_index]["image_path"] = image_local_path
		downloaded_files.append(image_local_path)
		var puzzle_size := FileAccess.get_file_as_bytes(image_local_path).size()
		download_progress.emit(pack_id, image_file_name, puzzle_size, -1)
		puzzle_index += 1

	return {"ok": true, "local_pack": local_pack, "downloaded_files": downloaded_files}

func _download_and_install_pack_from_remote_catalog(pack_id: String) -> Dictionary:
	var remote_catalog_service = _get_remote_catalog_service()
	if remote_catalog_service == null or not remote_catalog_service.has_remote_catalog():
		return {"ok": false, "error": "remote_catalog_unavailable"}

	var catalog = await remote_catalog_service.fetch_catalog_manifest()
	if catalog.is_empty():
		return {"ok": false, "error": "remote_catalog_empty"}

	var pack_entry = remote_catalog_service.get_pack_entry(pack_id, catalog)
	if pack_entry.is_empty():
		return {"ok": false, "error": "pack_not_found_in_catalog"}

	var manifest_path := str(pack_entry.get("manifest_path", ""))
	if manifest_path == "":
		return {"ok": false, "error": "pack_manifest_path_missing"}

	var pack_manifest = await remote_catalog_service.fetch_asset_json(manifest_path)
	if pack_manifest.is_empty():
		return {"ok": false, "error": "pack_manifest_download_failed"}

	var local_pack := _build_local_pack_from_remote_manifest(pack_manifest, pack_id)
	var asset_download_result := await _download_remote_pack_assets(pack_id, pack_manifest, local_pack)
	if not asset_download_result.get("ok", false):
		return asset_download_result

	var json_out_path := USER_DLC_DIR + "/" + pack_id + ".json"
	var serialized_pack := JSON.stringify(asset_download_result.get("local_pack", local_pack), "\t")
	var ok_json = _save_bytes(json_out_path, serialized_pack.to_utf8_buffer())
	if not ok_json:
		return {"ok": false, "error": "json_write_failed"}

	pack_installed.emit(pack_id)
	download_finished.emit(pack_id, true)
	return {
		"ok": true,
		"source": "remote_catalog",
		"manifest_path": manifest_path,
		"files": asset_download_result.get("downloaded_files", [])
	}

func _rewrite_pack_json_for_user(json_dict: Dictionary, pack_id: String) -> Dictionary:
	# Devuelve {json: Dictionary, files: Array[String]} con las rutas de archivos a descargar
	var files: Array[String] = []
	if json_dict.has("image_path"):
		var thumb = json_dict["image_path"]
		var tfile = _extract_filename_from_path(str(thumb))
		if tfile != "":
			json_dict["image_path"] = "user://dlc/packs/%s/%s" % [pack_id, tfile]
			files.append(tfile)
	if json_dict.has("puzzles"):
		for i in range(json_dict.puzzles.size()):
			var p = json_dict.puzzles[i]
			if p.has("image"):
				var fname = _extract_filename_from_path(str(p.image))
				if fname != "":
					json_dict.puzzles[i].image = "user://dlc/packs/%s/%s" % [pack_id, fname]
					files.append(fname)
	return {"json": json_dict, "files": files}

func download_and_install_pack(pack_id: String) -> Dictionary:
	var remote_catalog_service = _get_remote_catalog_service()
	if remote_catalog_service and remote_catalog_service.has_remote_catalog():
		var remote_result = await _download_and_install_pack_from_remote_catalog(pack_id)
		if remote_result.get("ok", false):
			return remote_result

	# Fallback legacy por URL base fija
	if base_url == null or base_url == "":
		return {"ok": false, "error": "base_url_missing"}
	var json_url = base_url.rstrip("/") + "/packs/" + pack_id + ".json"
	var r = await _download_to_memory(json_url)
	if not r.ok:
		return {"ok": false, "error": "json_download_failed", "code": r.code}
	var text = r.body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_json"}
	var rewritten = _rewrite_pack_json_for_user(parsed, pack_id)
	var json_out_path = USER_DLC_DIR + "/" + pack_id + ".json"
	var ok_json = _save_bytes(json_out_path, JSON.stringify(rewritten.json).to_utf8_buffer())
	if not ok_json:
		return {"ok": false, "error": "json_write_failed"}
	var downloaded := 0
	for fname in rewritten.files:
		var file_url = base_url.rstrip("/") + "/packs/" + pack_id + "/" + fname
		var rr = await _download_to_memory(file_url)
		if rr.ok:
			var dst = USER_DLC_DIR + "/" + pack_id + "/" + fname
			var okf = _save_bytes(dst, rr.body)
			if okf:
				downloaded += 1
		var received = rr.body.size() if rr.ok else 0
		download_progress.emit(pack_id, fname, received, -1)
	pack_installed.emit(pack_id)
	download_finished.emit(pack_id, true)
	return {"ok": true, "source": "legacy_base_url", "files": rewritten.files, "downloaded": downloaded}

func download_and_install_packs(packs: Array) -> Dictionary:
	var results = {}
	var success = 0
	for p in packs:
		var r = await download_and_install_pack(p)
		results[p] = r
		if r.ok:
			success += 1
	return {"ok": success == packs.size(), "success_count": success, "results": results}

# Utilidad: cargar textura desde res:// o user://
func load_texture_any(path: String) -> Texture2D:
	if path == null or path == "":
		return null
	if path.begins_with("user://"):
		var img := Image.new()
		var err = img.load(path)
		if err != OK:
			return null
		var tex := ImageTexture.create_from_image(img)
		return tex
	else:
		return load(path)
