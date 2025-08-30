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

func get_packs_for_sku(sku: String) -> Array:
	var mapping_path = sku_mapping_path
	if ProjectSettings.has_setting("commerce/sku_mapping_path"):
		mapping_path = str(ProjectSettings.get_setting("commerce/sku_mapping_path"))
	if not ResourceLoader.exists(mapping_path):
		return []
	var file := FileAccess.open(mapping_path, FileAccess.READ)
	if file == null:
		return []
	var json_text := file.get_as_text()
	file.close()
	var mapping = JSON.parse_string(json_text)
	if typeof(mapping) == TYPE_DICTIONARY and mapping.has(sku):
		return mapping[sku]
	return []

func has_download_support() -> bool:
	return base_url != null and base_url != ""

func mark_packs_purchased(packs: Array) -> void:
	# Actualiza GLOBAL.dlc_packs y guarda settings
	if has_node("/root/GLOBAL"):
		var g := get_node("/root/GLOBAL")
		for p in packs:
			if p not in g.dlc_packs:
				g.dlc_packs.append(p)
		g.save_settings()
	# También persiste metadata específica
	var meta := {}
	if FileAccess.file_exists(METADATA_PATH):
		var f := FileAccess.open(METADATA_PATH, FileAccess.READ)
		if f:
			var t := f.get_as_text()
			f.close()
			var existing = JSON.parse_string(t)
			if typeof(existing) == TYPE_DICTIONARY:
				meta = existing
	if not meta.has("purchased_packs"):
		meta["purchased_packs"] = []
	for p in packs:
		if p not in meta.purchased_packs:
			meta.purchased_packs.append(p)
	meta["last_update"] = Time.get_datetime_string_from_system()
	var wf := FileAccess.open(METADATA_PATH, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(meta))
		wf.close()

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
	# 1) Descargar JSON de pack
	if not has_download_support():
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
	# 2) Descargar archivos referenciados
	var downloaded := 0
	for fname in rewritten.files:
		var file_url = base_url.rstrip("/") + "/packs/" + pack_id + "/" + fname
		var rr = await _download_to_memory(file_url)
		if rr.ok:
			var dst = USER_DLC_DIR + "/" + pack_id + "/" + fname
			var okf = _save_bytes(dst, rr.body)
			if okf:
				downloaded += 1
		# Emitir progreso básico (sin total fiable)
		var received = rr.body.size() if rr.ok else 0
		download_progress.emit(pack_id, fname, received, -1)
	pack_installed.emit(pack_id)
	download_finished.emit(pack_id, true)
	return {"ok": true, "files": rewritten.files, "downloaded": downloaded}

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
