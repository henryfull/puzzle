extends Node

var settings = {
	"language": "es",
	"font_size" : 14,
	"volume" : {
		"general": 50,
		"music": 10,
		"sfx": 30,
		"voices": 30
	},
	"ui_scale": 1.0  # Nueva configuración para escala de UI
}
var columns: int = 6
var rows: int = 8

var selected_pack = null
var selected_puzzle = null

# Variable para almacenar datos de la victoria
var victory_data = null

# Constante para el archivo de configuración
const SETTINGS_FILE = "user://settings.cfg"

# Variable para detectar si estamos en un dispositivo móvil
var is_mobile = false

func _ready():
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Cargar configuración al iniciar el juego
	load_settings()
	
	# Configurar la UI según el dispositivo
	configure_ui_for_device()

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
		
		# Cargar escala de UI
		settings.ui_scale = config.get_value("settings", "ui_scale", 1.0)
		
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
	
	# Guardar escala de UI
	config.set_value("settings", "ui_scale", settings.ui_scale)
	
	# Guardar el archivo
	err = config.save(SETTINGS_FILE)
	if err != OK:
		print("Error al guardar la configuración: ", err)
	else:
		print("Configuración guardada correctamente")

# Configurar la UI según el dispositivo
func configure_ui_for_device():
	if is_mobile:
		print("Configurando UI para dispositivo móvil")
		
		# Ajustar escala de UI para móviles si no está ya configurada
		if settings.ui_scale < 1.2:
			# Usar la escala recomendada por UIScaler
			if ResourceLoader.exists("res://Scripts/UIScaler.gd"):
				var UIScaler = load("res://Scripts/UIScaler.gd")
				settings.ui_scale = UIScaler.get_scale_factor()
			else:
				# Si no existe el script UIScaler, usar un valor predeterminado
				settings.ui_scale = 1.5
		
		# Configurar tamaño de fuente global
		var default_theme = ThemeDB.get_default_theme()
		if default_theme:
			# Escalar tamaños de fuente para diferentes controles
			var controls = ["Button", "Label", "LineEdit", "RichTextLabel"]
			for control in controls:
				var base_size = default_theme.get_font_size("font_size", control)
				default_theme.set_font_size("font_size", control, base_size * settings.ui_scale)
	else:
		print("Configurando UI para PC")
		
		# Restaurar escala predeterminada si es necesario
		if settings.ui_scale > 1.2:
			settings.ui_scale = 1.0
	
	# Guardar la configuración actualizada
	save_settings()
