extends Node

const DEFAULT_LANGUAGE := "es"
const SETTINGS_FILE := "user://settings.cfg"
const SUPPORTED_LANGUAGES := ["es", "en", "ca"]

var current_language := DEFAULT_LANGUAGE

signal language_changed(locale_code)

func _ready() -> void:
	load_language_from_config()
	print("TranslationLoader: Idioma actual cargado: ", current_language)

func load_language_from_config() -> void:
	var locale_code := DEFAULT_LANGUAGE
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE)

	if err == OK:
		locale_code = str(config.get_value("settings", "language", DEFAULT_LANGUAGE))
	elif has_node("/root/GLOBAL"):
		locale_code = str(GLOBAL.settings.language)

	set_language(locale_code, false)

func set_language(lang: String, save_config: bool = true) -> void:
	var normalized_language := _normalize_language(lang)
	current_language = normalized_language

	if has_node("/root/GLOBAL"):
		GLOBAL.settings.language = normalized_language

	TranslationServer.set_locale(normalized_language)

	if save_config:
		_save_language_to_config(normalized_language)

	emit_signal("language_changed", normalized_language)
	call_deferred("_refresh_translatable_ui")
	print("TranslationLoader: Idioma establecido a: ", normalized_language)

func _normalize_language(lang: String) -> String:
	if SUPPORTED_LANGUAGES.has(lang):
		return lang

	return DEFAULT_LANGUAGE

func _save_language_to_config(locale_code: String) -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("TranslationLoader: Error al cargar settings.cfg: ", err)

	config.set_value("settings", "language", locale_code)

	err = config.save(SETTINGS_FILE)
	if err != OK:
		print("TranslationLoader: Error al guardar settings.cfg: ", err)

func _refresh_translatable_ui() -> void:
	var root := get_tree().root
	if root == null:
		return

	_refresh_node(root)

func _refresh_node(node: Node) -> void:
	if node.has_method("update_ui_texts"):
		node.update_ui_texts()

	for child in node.get_children():
		_refresh_node(child)
