extends Node

# Servicio de audio reutilizable. Solo requiere que existan buses: Master, Music, SFX

const DEFAULT_MUSIC_PATH = "res://Assets/Sounds/Music/bg_sunset.mp3"

var music_player: AudioStreamPlayer

func _ready():
	_ensure_music_player()
	update_volumes()
	play_music()

func _ensure_music_player():
	if not music_player:
		music_player = AudioStreamPlayer.new()
		music_player.bus = "Music"
		music_player.autoplay = true
		var stream = load(DEFAULT_MUSIC_PATH)
		if stream:
			stream.loop = true
		music_player.stream = stream
		add_child(music_player)

func update_volumes():
	var s = _get_settings_service()
	var vols := {"general": 50, "music": 10, "sfx": 80}
	if s:
		vols = s.get_volumes()
	_set_bus_volume("Master", vols.general)
	_set_bus_volume("Music", vols.music)
	_set_bus_volume("SFX", vols.sfx)

func _set_bus_volume(bus_name: String, percent: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, _percentage_to_db(percent))

func _percentage_to_db(percent: float) -> float:
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
	_ensure_music_player()
	var path = music_path if music_path != "" else DEFAULT_MUSIC_PATH
	var stream = load(path)
	if stream:
		music_player.stream = stream
		music_player.play()

# Setters con persistencia en SettingsService
func set_general_volume(value: float) -> void:
	var s = _get_settings_service()
	if s:
		var v = s.get_volumes()
		v.general = value
		s.set_volumes(v)
	update_volumes()

func set_music_volume(value: float) -> void:
	var s = _get_settings_service()
	if s:
		var v = s.get_volumes()
		v.music = value
		s.set_volumes(v)
	update_volumes()

func set_sfx_volume(value: float) -> void:
	var s = _get_settings_service()
	if s:
		var v = s.get_volumes()
		v.sfx = value
		s.set_volumes(v)
	update_volumes()

func get_general_volume() -> float:
	var s = _get_settings_service()
	return s.get_volumes().general if s else 50

func get_music_volume() -> float:
	var s = _get_settings_service()
	return s.get_volumes().music if s else 10

func get_sfx_volume() -> float:
	var s = _get_settings_service()
	return s.get_volumes().sfx if s else 80

func _get_settings_service():
	return get_node("/root/SettingsService") if has_node("/root/SettingsService") else null
