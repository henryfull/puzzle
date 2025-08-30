extends Node

# Servicio genérico de settings en user://settings.cfg
# Ofrece API simple para get/set por secciones y utilidades comunes (volumen, idioma, etc.)

const SETTINGS_FILE := "user://settings.cfg"

var _cfg := ConfigFile.new()
var _loaded := false

func _ready():
	load_settings()

func load_settings() -> int:
	var err = _cfg.load(SETTINGS_FILE)
	_loaded = (err == OK)
	return err

func save_settings() -> int:
	return _cfg.save(SETTINGS_FILE)

func get_value(section: String, key: String, default_value: Variant = null) -> Variant:
	if not _loaded:
		load_settings()
	return _cfg.get_value(section, key, default_value)

func set_value(section: String, key: String, value: Variant) -> void:
	_cfg.set_value(section, key, value)

func get_section(section: String) -> Dictionary:
	if not _loaded:
		load_settings()
	var dict := {}
	var keys = _cfg.get_section_keys(section)
	if keys:
		for k in keys:
			dict[k] = _cfg.get_value(section, k)
	return dict

func set_section(section: String, values: Dictionary) -> void:
	for k in values.keys():
		_cfg.set_value(section, k, values[k])

# Volumen utilidades
func get_volumes() -> Dictionary:
	var general = int(get_value("audio", "general_volume", 50))
	var music = int(get_value("audio", "music_volume", 10))
	var sfx = int(get_value("audio", "sfx_volume", 80))
	return {"general": general, "music": music, "sfx": sfx}

func set_volumes(v: Dictionary) -> void:
	if v.has("general"):
		set_value("audio", "general_volume", v.general)
	if v.has("music"):
		set_value("audio", "music_volume", v.music)
	if v.has("sfx"):
		set_value("audio", "sfx_volume", v.sfx)
	save_settings()

func get_language(default_lang := "es") -> String:
	return str(get_value("settings", "language", default_lang))

func set_language(lang: String) -> void:
	set_value("settings", "language", lang)
	save_settings()
