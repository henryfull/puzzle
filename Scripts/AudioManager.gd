extends Node
class_name GameAudioManager

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

var music_player: AudioStreamPlayer

func _ready():
	# Inicializar el reproductor de música en el bus "Music"
	update_volumes()	
	music_player = AudioStreamPlayer.new()
	music_player.autoplay = true
	music_player.bus = "Music"
	music_player.stream = load(DEFAULT_MUSIC_PATH)
	add_child(music_player)
	music_player.play()
	

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
