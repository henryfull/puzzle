extends SubViewport

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var story_label: RichTextLabel = $MarginContainer/VBoxContainer/StoryLabel

var _puzzle_data: Dictionary = {}
var _pack_data: Dictionary = {}

func _ready() -> void:
	if size == Vector2i.ZERO:
		size = Vector2i(1024, 1024)

	if _puzzle_data.is_empty():
		var selected_puzzle: Dictionary = GLOBAL.selected_puzzle if GLOBAL.selected_puzzle != null else {}
		var selected_pack: Dictionary = GLOBAL.selected_pack if GLOBAL.selected_pack != null else {}
		set_puzzle_content(selected_puzzle, selected_pack)
	else:
		_apply_content()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_apply_content()

func set_puzzle_content(puzzle_data: Dictionary, pack_data: Dictionary = {}) -> void:
	_puzzle_data = puzzle_data.duplicate(true) if typeof(puzzle_data) == TYPE_DICTIONARY else {}
	_pack_data = pack_data.duplicate(true) if typeof(pack_data) == TYPE_DICTIONARY else {}
	if is_node_ready():
		_apply_content()

func _apply_content() -> void:
	var resolved_title := _resolve_display_title()
	title_label.text = resolved_title.to_upper()
	title_label.visible = resolved_title != ""
	story_label.text = _resolve_story_text()

func _resolve_display_title() -> String:
	var puzzle_title := _resolve_localized_value(_puzzle_data.get("name_localized", null), str(_puzzle_data.get("name", ""))).strip_edges()
	if puzzle_title != "":
		return puzzle_title
	return _resolve_localized_value(_pack_data.get("name_localized", null), str(_pack_data.get("name", ""))).strip_edges()

func _resolve_story_text() -> String:
	var fallback_description := _resolve_localized_value(
		_puzzle_data.get("description_localized", null),
		str(_puzzle_data.get("description", ""))
	)
	var story_payload = _puzzle_data.get("story_localized", _puzzle_data.get("story", fallback_description))
	var story_text := _resolve_localized_value(story_payload, fallback_description).strip_edges()
	return _normalize_story_text(story_text)

func _resolve_localized_value(value, fallback: String) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var language := TranslationServer.get_locale().split("_")[0].to_lower()
		if value.has(language):
			return str(value[language])
		if value.has("es"):
			return str(value["es"])
		if value.has("en"):
			return str(value["en"])
		for key in value.keys():
			return str(value[key])
	elif typeof(value) == TYPE_STRING:
		var raw_text := str(value)
		if raw_text == "":
			return fallback
		var translated := TranslationServer.translate(raw_text)
		return translated if translated.strip_edges() != "" else raw_text
	return fallback

func _normalize_story_text(raw_text: String) -> String:
	var clean_paragraphs: PackedStringArray = []
	for paragraph in raw_text.split("\n", false):
		var clean_paragraph := paragraph.strip_edges()
		if not clean_paragraph.is_empty():
			clean_paragraphs.append(clean_paragraph)
	if clean_paragraphs.is_empty():
		return raw_text.strip_edges()
	return "\n\n".join(clean_paragraphs)
