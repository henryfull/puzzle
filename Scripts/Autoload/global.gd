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
	"ui_scale": 1.0,  # Nueva configuración para escala de UI
	"puzzle": {       # Nueva sección para opciones del puzzle
		"pan_sensitivity": 1.0,
		"use_tween_effect": true,
		"tween_duration": 0.2
	},
	"gameplay": {     # Nueva sección para opciones de gameplay
		"columns": 6,
		"rows": 8,
		"progresive_difficulty": false
	}
}
var columns: int = 6
var rows: int = 8
var defeat_data = null

var selected_pack = null
var selected_puzzle = null
var change_scene : String
var gamemode : int = 1
var is_learner : bool = false
var progresive_difficulty : bool = false

# Variable para almacenar datos de la victoria
var victory_data = null

# Constante para el archivo de configuración
const SETTINGS_FILE = "user://settings.cfg"

# Variable para detectar si estamos en un dispositivo móvil
var is_mobile = false

# Función para cambiar de escena usando la pantalla de carga
func change_scene_with_loading(new_scene: String) -> void:
	change_scene = new_scene
	get_tree().change_scene_to_file("res://Scenes/LoadingScreen.tscn")

# Función para cambiar de escena directamente (sin pantalla de carga)
func change_scene_direct(new_scene: String) -> void:
	get_tree().change_scene_to_file(new_scene)

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
		
		# Cargar configuración del puzzle
		settings.puzzle.pan_sensitivity = config.get_value("puzzle", "pan_sensitivity", 1.0)
		settings.puzzle.use_tween_effect = config.get_value("puzzle", "use_tween_effect", true)
		settings.puzzle.tween_duration = config.get_value("puzzle", "tween_duration", 0.2)
		
		# Cargar configuración de gameplay
		settings.gameplay.columns = config.get_value("gameplay", "columns", 6)
		settings.gameplay.rows = config.get_value("gameplay", "rows", 8)
		settings.gameplay.progresive_difficulty = config.get_value("gameplay", "progresive_difficulty", false)
		
		# Actualizar variables globales con la configuración cargada
		columns = settings.gameplay.columns
		rows = settings.gameplay.rows
		progresive_difficulty = settings.gameplay.progresive_difficulty
		
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
	
	# Actualizar configuración con valores actuales antes de guardar
	settings.gameplay.columns = columns
	settings.gameplay.rows = rows
	settings.gameplay.progresive_difficulty = progresive_difficulty
	
	# Guardar idioma
	config.set_value("settings", "language", settings.language)
	
	# Guardar volúmenes
	config.set_value("audio", "general_volume", settings.volume.general)
	config.set_value("audio", "music_volume", settings.volume.music)
	config.set_value("audio", "sfx_volume", settings.volume.sfx)
	
	# Guardar escala de UI
	config.set_value("settings", "ui_scale", settings.ui_scale)
	
	# Guardar configuración del puzzle
	config.set_value("puzzle", "pan_sensitivity", settings.puzzle.pan_sensitivity)
	config.set_value("puzzle", "use_tween_effect", settings.puzzle.use_tween_effect)
	config.set_value("puzzle", "tween_duration", settings.puzzle.tween_duration)
	
	# Guardar configuración de gameplay
	config.set_value("gameplay", "columns", settings.gameplay.columns)
	config.set_value("gameplay", "rows", settings.gameplay.rows)
	config.set_value("gameplay", "progresive_difficulty", settings.gameplay.progresive_difficulty)
	
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
