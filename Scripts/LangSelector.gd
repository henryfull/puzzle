extends OptionButton

# Diccionario con los idiomas y sus códigos
var languages = {
	"Español": "es",
	"English": "en",
	"Catala": "ca",	
	"Français": "fr",
	"Deutsch": "de"
}

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
	
	# Actualizar TranslationLoader
	if has_node("/root/TranslationLoader"):
		get_node("/root/TranslationLoader").set_language(locale_code)
	
	# Actualizar TranslationServer
	TranslationServer.set_locale(locale_code)
	
	# Actualizar configuración global
	GLOBAL.settings.language = locale_code
	
	# Guardar la selección
	save_language(locale_code)
	
	print("Idioma cambiado a: ", locale_code)

func save_language(locale_code):
	var config = ConfigFile.new()
	
	# Cargar configuración existente para no sobrescribir otros valores
	var err = config.load("user://settings.cfg")
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error al cargar el archivo de configuración: ", err)
	
	# Guardar el idioma
	config.set_value("settings", "language", locale_code)
	err = config.save("user://settings.cfg")
	
	if err != OK:
		print("Error al guardar la configuración de idioma: ", err)
	else:
		print("Configuración de idioma guardada correctamente")

func load_language():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	var locale_code = "es"  # Predeterminado: español
	
	if err == OK:
		locale_code = config.get_value("settings", "language", "es")
	else:
		# Si no hay configuración, usar el idioma de GLOBAL
		locale_code = GLOBAL.settings.language
	
	# Actualizar TranslationServer
	TranslationServer.set_locale(locale_code)
	
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
