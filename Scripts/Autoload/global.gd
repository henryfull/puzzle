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
var current_difficult: int = 3

# Nuevas variables para los límites del puzzle
var puzzle_limits = {
	"max_moves": 0,
	"max_time": 0.0,
	"max_flips": 0,
	"max_flip_moves": 0
}

var selected_pack = null
var selected_puzzle = null
var change_scene : String
var gamemode : int = 1
var is_learner : bool = false
var progresive_difficulty : bool = false

var modes = [
	{"name": "difficulty_learner", "id": 0, "color": "ButtonBlue", "HeaderColor": "PanelHeaderBlue", "PanelColor": "PanelBlue", "description": "difficulty_learner_description", "tiki": "tiki-learn"},
	{"name": "Relax", "id": 1, "color": "ButtonPurple", "HeaderColor": "PanelHeaderPurple", "PanelColor": "PanelPurple", "description": "game_mode_relax", "tiki": "tiki-zen"},
	{"name": "normal", "id": 2, "color": "", "HeaderColor": "PanelHeaderGreen", "PanelColor": "", "description": "game_mode_normal", "tiki": "tiki-stayed"},
	{"name": "common_timetrial", "id": 3, "color": "ButtonYellow", "HeaderColor": "PanelHeaderYellow", "PanelColor": "PanelYellow", "description": "game_mode_timetrial", "tiki": "tiki-combat"},
	{"name": "common_challenge", "id": 4, "color": "ButtonRed", "HeaderColor": "PanelHeaderRed", "PanelColor": "PanelRed", "description": "game_mode_chagenlle", "tiki": "tiki-fury"},
	]
var difficulties = [
	{"name": "difficulty_very_easy", "columns": 1, "rows": 8, "color": "", "description": "difficulty_very_easy_description"},
	{"name": "difficulty_easy", "columns": 2, "rows": 8, "color": "", "description": "difficulty_easy_description"},
	{"name": "difficulty_normal", "columns": 3, "rows": 8, "color": "ButtonYellow", "description": "difficulty_normal_description"},
	{"name": "difficulty_medium", "columns": 4, "rows": 6, "color": "ButtonYellow", "description": "difficulty_medium_description"},
	{"name": "difficulty_challenge", "columns": 4, "rows": 8, "color": "ButtonYellow", "description": "difficulty_challenge_description"},
	{"name": "difficulty_hard", "columns": 6, "rows": 8, "color": "ButtonRed", "description": "difficulty_hard_description"},
	{"name": "difficulty_very_hard", "columns": 8, "rows": 8, "color": "ButtonRed", "description": "difficulty_very_hard_description"},
	{"name": "difficulty_expert", "columns": 10, "rows": 10, "color": "ButtonRed", "description": "difficulty_expert_description"}
]
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
		
		# Cargar límites del puzzle
		puzzle_limits.max_moves = config.get_value("puzzle", "max_moves", 0)
		puzzle_limits.max_time = config.get_value("puzzle", "max_time", 0.0)
		puzzle_limits.max_flips = config.get_value("puzzle", "max_flips", 0)
		puzzle_limits.max_flip_moves = config.get_value("puzzle", "max_flip_moves", 0)
		
		# Cargar configuración de gameplay
		settings.gameplay.columns = config.get_value("gameplay", "columns", 6)
		settings.gameplay.rows = config.get_value("gameplay", "rows", 8)
		settings.gameplay.difficult = config.get_value("gameplay","difficult", 3)
		settings.gameplay.gamemode = config.get_value("gameplay","gamemode", 2)
		settings.gameplay.progresive_difficulty = config.get_value("gameplay", "progresive_difficulty", false)
		
		# Actualizar variables globales con la configuración cargada
		columns = settings.gameplay.columns
		rows = settings.gameplay.rows
		progresive_difficulty = settings.gameplay.progresive_difficulty
		gamemode = settings.gameplay.gamemode
		
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
	settings.gameplay.difficult = GLOBAL.current_difficult
	settings.gameplay.gamemode = GLOBAL.gamemode

	
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
	
	# Guardar límites del puzzle
	config.set_value("puzzle", "max_moves", puzzle_limits.max_moves)
	config.set_value("puzzle", "max_time", puzzle_limits.max_time)
	config.set_value("puzzle", "max_flips", puzzle_limits.max_flips)
	config.set_value("puzzle", "max_flip_moves", puzzle_limits.max_flip_moves)
	
	# Guardar configuración de gameplay
	config.set_value("gameplay", "columns", settings.gameplay.columns)
	config.set_value("gameplay", "rows", settings.gameplay.rows)
	config.set_value("gameplay", "gamemode", settings.gameplay.gamemode)
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

# Función para calcular los límites del puzzle según la dificultad actual
func calculate_puzzle_limits(game_mode: int = -1) -> void:
	# Si no se especifica el modo de juego, usar el global
	if game_mode < 0:
		game_mode = gamemode
	
	var total_tiles = columns * rows
	
	# Cálculo base de movimientos permitidos según el número de fichas
	var move_multiplier = 0.0
	if total_tiles <= 20:  # Muy fácil (ej: 1x8, 2x8)
		move_multiplier = 1.1
	elif total_tiles <= 40:  # Fácil a normal (ej: 3x8, 4x6)
		move_multiplier = 1.1
	elif total_tiles <= 60:  # Medio a difícil (ej: 6x8, 8x8)
		move_multiplier = 1.1
	else:  # Muy difícil a experto (mayores dimensiones)
		move_multiplier = 1.1
	
	puzzle_limits.max_moves = int(total_tiles * move_multiplier)
	
	# Cálculo base de tiempo en segundos (3-5 segundos por ficha)
	var time_per_tile = 0.0
	if total_tiles <= 20:
		time_per_tile = 5.0
	elif total_tiles <= 40:
		time_per_tile = 4.0
	elif total_tiles <= 60:
		time_per_tile = 3.5
	else:
		time_per_tile = 3.0
	
	puzzle_limits.max_time = total_tiles * time_per_tile
	
	# Calcular máximos de volteos
	puzzle_limits.max_flips = int(total_tiles * 0.3)  # ~30% del total
	puzzle_limits.max_flip_moves = int(total_tiles * 0.45)  # ~45% del total
	
	# Ajustes según el modo de juego
	match game_mode:
		0, 1:  # Aprendizaje o Relax - sin límites
			puzzle_limits.max_moves = 0
			puzzle_limits.max_time = 0
			puzzle_limits.max_flips = 0
			puzzle_limits.max_flip_moves = 0
		3:  # Contrareloj (TimeTrial)
			puzzle_limits.max_time *= 0.7  # 30% menos de tiempo
			puzzle_limits.max_moves = 0  # Sin límite de movimientos
		4:  # Desafío (Challenge)
			puzzle_limits.max_moves = int(puzzle_limits.max_moves * move_multiplier)  # 20% menos de movimientos
			puzzle_limits.max_time *= 0.8  # 20% menos de tiempo
			puzzle_limits.max_flips = int(puzzle_limits.max_flips * 0.85)  # 15% menos de volteos
	
	# Guardar la configuración
	save_settings()
	
	print("Límites calculados: Movimientos=%d, Tiempo=%.1f, Volteos=%d, Movimientos de volteo=%d" % 
		[puzzle_limits.max_moves, puzzle_limits.max_time, puzzle_limits.max_flips, puzzle_limits.max_flip_moves])

# Esta función devuelve una descripción del objetivo del puzzle según el modo de juego
func get_puzzle_goal_description(game_mode: int = -1) -> String:
	# Si no se especifica el modo de juego, usar el global
	if game_mode < 0:
		game_mode = gamemode
	
	var desc_text = ""
	
	match game_mode:
		0:  # Aprendizaje
			desc_text = "Completa el puzzle a tu ritmo. Sin límites."
		1:  # Relax
			desc_text = "Completa el puzzle a tu ritmo. Sin límites."
		2:  # Normal
			if puzzle_limits.max_moves > 0:
				desc_text = "Completa el puzzle en %d movimientos o menos." % puzzle_limits.max_moves
			else:
				desc_text = "Completa el puzzle sin límite de movimientos."
		3:  # Contrareloj
			var minutes = int(puzzle_limits.max_time / 60)
			var seconds = int(puzzle_limits.max_time) % 60
			desc_text = "Completa el puzzle antes de que se acabe el tiempo: %d:%02d" % [minutes, seconds]
		4:  # Desafío
			var minutes = int(puzzle_limits.max_time / 60)
			var seconds = int(puzzle_limits.max_time) % 60
			desc_text = "Completa el puzzle en %d movimientos y antes de %d:%02d" % [puzzle_limits.max_moves, minutes, seconds]
			
			if puzzle_limits.max_flips > 0:
				desc_text += " No puedes realizar más de %d volteos." % puzzle_limits.max_flips
	
	return desc_text

func setColorMode(panelColor, headerColor):
	var global_gamemode = self.gamemode
	var global_panel_color = self.modes[global_gamemode].PanelColor
	var global_header_color = self.modes[global_gamemode].HeaderColor
	
	panelColor.theme_type_variation = global_panel_color
	headerColor.theme_type_variation = global_header_color
