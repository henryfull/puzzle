extends Node
class_name AudioManagerGame

"""
Este módulo gestiona el volumen del audio del juego.
Se espera que en el proyecto se configuren al menos tres buses:
  - "General"
  - "Music"
  - "SFX"

Los valores de volumen se toman de GLOBAL.settings.volume usando las siguientes llaves:
  - "general": Volumen global (aplica a todo)
  - "music": Volumen para música
  - "sfx": Volumen para efectos de sonido (sonidos)

La función update_volumes() ajusta el volumen de cada bus usando una conversión de porcentaje a decibelios.
Asegúrate de agregar este script como AutoLoad (Singleton) en el proyecto.
"""

const DEFAULT_MUSIC_PATH = "res://Assets/Sounds/Music/bg_default.wav"
const SETTINGS_FILE = "user://settings.cfg"

var music_player: AudioStreamPlayer

func _ready():
	# Cargar configuración de volumen
	load_volume_settings()
	
	# Inicializar el reproductor de música en el bus "Music"
	update_volumes()	
	music_player = AudioStreamPlayer.new()
	music_player.autoplay = true
	music_player.bus = "Music"
	music_player.stream = load(DEFAULT_MUSIC_PATH)
	add_child(music_player)
	music_player.play()
	
	# Asegurarse de que la configuración se guarde al cerrar la aplicación
	process_mode = Node.PROCESS_MODE_ALWAYS

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_volume_settings()
		print("AudioManager: Configuración guardada al cerrar la aplicación")

func load_volume_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	
	if err == OK:
		# Cargar valores de volumen desde el archivo de configuración
		var general_volume = config.get_value("audio", "general_volume", 50)
		var music_volume = config.get_value("audio", "music_volume", 10)
		var sfx_volume = config.get_value("audio", "sfx_volume", 30)
		
		# Actualizar la configuración global
		GLOBAL.settings.volume.general = general_volume
		GLOBAL.settings.volume.music = music_volume
		GLOBAL.settings.volume.sfx = sfx_volume
		
		print("Configuración de audio cargada: General=", general_volume, ", Music=", music_volume, ", SFX=", sfx_volume)
	else:
		print("No se encontró archivo de configuración o hubo un error. Usando valores predeterminados.")

func save_volume_settings():
	var config = ConfigFile.new()
	
	# Primero cargar el archivo existente para no sobrescribir otras configuraciones
	var err = config.load(SETTINGS_FILE)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error al cargar el archivo de configuración: ", err)
	
	# Guardar los valores de volumen
	config.set_value("audio", "general_volume", GLOBAL.settings.volume.general)
	config.set_value("audio", "music_volume", GLOBAL.settings.volume.music)
	config.set_value("audio", "sfx_volume", GLOBAL.settings.volume.sfx)
	
	# También guardar el idioma para asegurarnos de que no se pierda
	config.set_value("settings", "language", GLOBAL.settings.language)
	
	# Guardar el archivo
	err = config.save(SETTINGS_FILE)
	if err != OK:
		print("Error al guardar la configuración de audio: ", err)
	else:
		print("Configuración de audio guardada correctamente")
	
	# También actualizar la configuración global
	if has_node("/root/GLOBAL"):
		get_node("/root/GLOBAL").save_settings()

func update_volumes():
	var volume_settings = GLOBAL.settings.volume if GLOBAL.settings.has("volume") else {"general": 100, "music": 100, "sfx": 100}
	
	# Actualizar bus General
	var general_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(general_bus_index, percentage_to_db(volume_settings.general))
	
	# Actualizar bus Music
	var music_bus_index = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music_bus_index, percentage_to_db(volume_settings.music))
	
	# Actualizar bus SFX (sonidos)
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(sfx_bus_index, percentage_to_db(volume_settings.sfx))

func percentage_to_db(percent: float) -> float:
	# Convierte un porcentaje (0-100) a decibelios. 100% se traduce a 0 dB, 0% a -80 dB.
	var linear = clamp(percent / 100.0, 0.0, 1.0)
	if linear == 0:
		return -80
	return 20 * (log(linear) / log(10)) 

func play_sfx(sound_path: String) -> void:
	var player = AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = load(sound_path)
	add_child(player)
	player.play()
	var duration = 1.0
	if player.stream != null:
		duration = player.stream.get_length()
	await get_tree().create_timer(duration).timeout
	player.queue_free() 

func play_music(music_path: String = "") -> void:
	var path_to_load = music_path
	if path_to_load == "":
		path_to_load = DEFAULT_MUSIC_PATH
	var new_stream = load(path_to_load)
	if new_stream != null:
		music_player.stream = new_stream
		music_player.play()

# Métodos para ajustar el volumen y guardar la configuración
func set_general_volume(value: float) -> void:
	GLOBAL.settings.volume.general = value
	update_volumes()
	save_volume_settings()

func set_music_volume(value: float) -> void:
	GLOBAL.settings.volume.music = value
	update_volumes()
	save_volume_settings()

func set_sfx_volume(value: float) -> void:
	GLOBAL.settings.volume.sfx = value
	update_volumes()
	save_volume_settings()

# Métodos para obtener los valores actuales de volumen
func get_general_volume() -> float:
	return GLOBAL.settings.volume.general

func get_music_volume() -> float:
	return GLOBAL.settings.volume.music

func get_sfx_volume() -> float:
	return GLOBAL.settings.volume.sfx 
