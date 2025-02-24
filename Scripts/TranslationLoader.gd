extends Node

var translations = {}  # Diccionario donde guardamos las traducciones
var current_language = "es"  # Idioma por defecto (puedes cambiarlo dinámicamente)

# Cargar el archivo CSV al iniciar
func _ready():
	load_csv("res://PacksData/translation.csv")
	set_language(GLOBAL.settings.language)
	print(current_language)

# Función para leer el CSV y almacenar los textos
func load_csv(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Error al abrir el archivo de traducciones.")
		return
	
	# Leer todas las líneas del CSV
	var lines = file.get_as_text().split("\n")
	var headers = lines[0].split(",")  # Primera línea con los nombres de los idiomas
	
	# Procesar cada línea del CSV
	for i in range(1, lines.size()):
		var row = lines[i].split(",")
		if row.size() < 2:
			continue
		
		var key = row[0]  # La primera columna es la clave del texto
		translations[key] = {}  # Diccionario para almacenar las traducciones
		
		# Asignar valores según el idioma
		for j in range(1, row.size()):
			var lang_code = headers[j]  # Código del idioma (es, en, fr, etc.)
			translations[key][lang_code] = row[j]  # Guardamos la traducción

# Función para obtener un texto en el idioma actual
func get_translation(key):
	if key in translations and current_language in translations[key]:
		return translations[key][current_language]
	return key  # Devuelve la clave si no hay traducción

# Cambiar el idioma en tiempo real
func set_language(lang):
	if lang in translations.values()[0]:  # Verificar si el idioma existe
		current_language = lang
