extends OptionButton

var languages = {
	"Español": "es",
	"English": "en",
	"Catala": "ca"
}

# Señal para notificar cambios de idioma
signal language_changed(locale_code)

func _ready():
	# Primero poblamos los idiomas disponibles
	populate_languages()
	
	# Esperamos un frame para asegurarnos de que GLOBAL y TranslationLoader estén inicializados
	await get_tree().process_frame
	
	# Cargamos y seleccionamos el idioma actual
	load_language()
	
	# Conectamos la señal para cambios futuros
	connect("item_selected", Callable(self, "_on_language_selected"))

func populate_languages():
	clear()
	for lang in languages.keys():
		add_item(lang)  # Agrega cada idioma al OptionButton

func _on_language_selected(index):
	var selected_language = get_item_text(index)
	var locale_code = languages[selected_language]
	
	if has_node("/root/TranslationLoader"):
		get_node("/root/TranslationLoader").set_language(locale_code)
	else:
		TranslationServer.set_locale(locale_code)
		GLOBAL.settings.language = locale_code
		if has_node("/root/GLOBAL"):
			get_node("/root/GLOBAL").save_settings()
	
	# Emitir señal de cambio de idioma
	emit_signal("language_changed", locale_code)
	
	print("Idioma cambiado a: ", locale_code)

func load_language():
	var locale_code = GLOBAL.settings.language
	if has_node("/root/TranslationLoader"):
		locale_code = get_node("/root/TranslationLoader").current_language
	
	# Seleccionar el idioma correcto en el menú
	var found = false
	for i in range(get_item_count()):
		if languages[get_item_text(i)] == locale_code:
			select(i)
			found = true
			break
	
	if not found and get_item_count() > 0:
		# Si no se encontró el idioma, seleccionar el primero
		select(0)
		
	print("LangSelector: Idioma cargado y seleccionado: ", locale_code)
