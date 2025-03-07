extends Node

var settings = {
	"language": "es",
	"font_size" : 14,
	"volume" : {
		"general": 50,
		"music": 10,
		"sfx": 30,
		"voices": 30
	}
}

var selected_pack = null
var selected_puzzle = null

# Variable para almacenar datos de la victoria
var victory_data = null

# Constante para el archivo de configuración
const SETTINGS_FILE = "user://settings.cfg"

func _ready():
	# Cargar configuración al iniciar el juego
	load_settings()

# Función para cargar todas las configuraciones
func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	
	if err == OK:
		# Cargar idioma
		settings.language = config.get_value("settings", "language", "es")
		
		# Cargar volúmenes
		settings.volume.general = config.get_value("audio", "general_volume", 50)
		settings.volume.music = config.get_value("audio", "music_volume", 10)
		settings.volume.sfx = config.get_value("audio", "sfx_volume", 30)
		
		print("GLOBAL: Configuración cargada correctamente")
	else:
		print("GLOBAL: No se encontró archivo de configuración o hubo un error. Usando valores predeterminados.")
	
	# Aplicar configuración de idioma
	if has_node("/root/TranslationLoader"):
		get_node("/root/TranslationLoader").set_language(settings.language)
	
	# Aplicar configuración de audio
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").update_volumes()

# Función para guardar todas las configuraciones
# Esta función ahora es accesible como una función de instancia
func save_settings() -> void:
	var config = ConfigFile.new()
	
	# Primero cargar el archivo existente para no sobrescribir otras configuraciones
	var err = config.load(SETTINGS_FILE)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error al cargar el archivo de configuración: ", err)
	
	# Guardar idioma
	config.set_value("settings", "language", settings.language)
	
	# Guardar volúmenes
	config.set_value("audio", "general_volume", settings.volume.general)
	config.set_value("audio", "music_volume", settings.volume.music)
	config.set_value("audio", "sfx_volume", settings.volume.sfx)
	
	# Guardar el archivo
	err = config.save(SETTINGS_FILE)
	if err != OK:
		print("Error al guardar la configuración: ", err)
	else:
		print("Configuración guardada correctamente")
