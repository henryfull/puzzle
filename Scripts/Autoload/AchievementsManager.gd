extends Node

# Constantes para la gestión de archivos
const ACHIEVEMENTS_SAVE_FILE = "user://achievements.json"

# Señal para informar de logros desbloqueados
signal achievement_unlocked(achievement_id, achievement_data)

# Lista para almacenar los logros desbloqueados durante la sesión de juego actual
var achievements_unlocked_this_session = []

# Diccionario que contiene los logros del juego
# Incluye información sobre el progreso, no solo si está desbloqueado
var achievements = {
	"primer_paso": {
		"name": "Primer Paso",
		"desc": "Completa tu primer puzle.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_first_step.png",
		"secret": false,
		"progress": 0,
		"max_progress": 1,
		"platform_ids": {
			"steam": "ACHIEVEMENT_FIRST_STEP",
			"google_play": "CgkIh5jdi9EIEAIQAQ",
			"game_center": "first_step"
		}
	},
	"velocidad_relampago": {
		"name": "Velocidad Relámpago",
		"desc": "Completa un puzle en Modo Contrarreloj con tiempo sobrante ≥ 30s.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_speed.png",
		"secret": false,
		"progress": 0,
		"max_progress": 1,
		"platform_ids": {
			"steam": "ACHIEVEMENT_SPEED",
			"google_play": "CgkIh5jdi9EIEAIQBA",
			"game_center": "speed_achievement"
		}
	},
	"el_coleccionista": {
		"name": "El Coleccionista",
		"desc": "Completa 10 puzles diferentes.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_collector.png",
		"secret": false,
		"progress": 0,
		"max_progress": 10,
		"platform_ids": {
			"steam": "ACHIEVEMENT_COLLECTOR",
			"google_play": "CgkIh5jdi9EIEAIQBQ",
			"game_center": "collector"
		}
	},
	"sin_mirar_atras": {
		"name": "Sin Mirar Atrás",
		"desc": "Completa un puzle sin usar la función de Flip.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_no_flip.png",
		"secret": false,
		"progress": 0,
		"max_progress": 1,
		"platform_ids": {
			"steam": "ACHIEVEMENT_NO_FLIP",
			"google_play": "CgkIh5jdi9EIEAIQCA",
			"game_center": "no_flip"
		}
	},
	"eficiencia_maxima": {
		"name": "Eficiencia Máxima",
		"desc": "Termina un puzle realizando menos de 20 movimientos.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_efficiency.png",
		"secret": false,
		"progress": 0,
		"max_progress": 1,
		"platform_ids": {
			"steam": "ACHIEVEMENT_EFFICIENCY",
			"google_play": "CgkIh5jdi9EIEAIQCQ",
			"game_center": "max_efficiency"
		}
	},
	"maestro_de_la_noche": {
		"name": "Maestro de la Noche",
		"desc": "Completa 3 puzles en Modo Contrarreloj en máxima dificultad.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_master.png",
		"secret": true,
		"progress": 0,
		"max_progress": 3,
		"platform_ids": {
			"steam": "ACHIEVEMENT_NIGHT_MASTER",
			"google_play": "CgkIh5jdi9EIEAIQDA",
			"game_center": "night_master"
		}
	},
	"perfecto_en_todo_sentido": {
		"name": "Perfecto en Todo Sentido",
		"desc": "Obtén la máxima puntuación posible en un puzle.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_perfect.png",
		"secret": true,
		"progress": 0,
		"max_progress": 1,
		"platform_ids": {
			"steam": "ACHIEVEMENT_PERFECT",
			"google_play": "CgkIh5jdi9EIEAIQDQ",
			"game_center": "perfect_score"
		}
	},
	"pack_completo": {
		"name": "Coleccionista Principiante",
		"desc": "Completa tu primer pack de puzles.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_pack_complete.png",
		"secret": false,
		"progress": 0,
		"max_progress": 1,
		"platform_ids": {
			"steam": "ACHIEVEMENT_PACK_COMPLETE",
			"google_play": "CgkIh5jdi9EIEAIQDg",
			"game_center": "pack_complete"
		}
	},
	"velocista_extremo": {
		"name": "Velocista Extremo",
		"desc": "Completa un puzle en menos de 1 segundo. ¿Eso fue suerte?",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_super_speed.png",
		"secret": true,
		"progress": 0,
		"max_progress": 1,
		"platform_ids": {
			"steam": "ACHIEVEMENT_SUPER_SPEED",
			"google_play": "CgkIh5jdi9EIEAIQDw",
			"game_center": "super_speed"
		}
	},
	"desafiante_experimentado": {
		"name": "Desafiante Experimentado",
		"desc": "Completa un pack de puzles en dificultad difícil.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_hard_pack.png",
		"secret": false,
		"progress": 0,
		"max_progress": 1,
		"platform_ids": {
			"steam": "ACHIEVEMENT_HARD_PACK",
			"google_play": "CgkIh5jdi9EIEAIQEA",
			"game_center": "hard_pack"
		}
	},
	"maestro_puzles": {
		"name": "Maestro de Puzles",
		"desc": "Completa un pack de puzles en dificultad súper difícil.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_super_hard_pack.png",
		"secret": false,
		"progress": 0,
		"max_progress": 1,
		"platform_ids": {
			"steam": "ACHIEVEMENT_SUPER_HARD_PACK",
			"google_play": "CgkIh5jdi9EIEAIQEQ",
			"game_center": "super_hard_pack"
		}
	},
	"aficionado_puzles": {
		"name": "Aficionado de Puzles",
		"desc": "Completa 10 puzles en total.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_10_puzzles.png",
		"secret": false,
		"progress": 0,
		"max_progress": 10,
		"platform_ids": {
			"steam": "ACHIEVEMENT_10_PUZZLES",
			"google_play": "CgkIh5jdi9EIEAIQEg",
			"game_center": "puzzles_10"
		}
	},
	"entusiasta_puzles": {
		"name": "Entusiasta de Puzles",
		"desc": "Completa 50 puzles en total.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_50_puzzles.png",
		"secret": false,
		"progress": 0,
		"max_progress": 50,
		"platform_ids": {
			"steam": "ACHIEVEMENT_50_PUZZLES",
			"google_play": "CgkIh5jdi9EIEAIQEw",
			"game_center": "puzzles_50"
		}
	},
	"experto_puzles": {
		"name": "Experto en Puzles",
		"desc": "Completa 100 puzles en total.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_100_puzzles.png",
		"secret": false,
		"progress": 0,
		"max_progress": 100,
		"platform_ids": {
			"steam": "ACHIEVEMENT_100_PUZZLES",
			"google_play": "CgkIh5jdi9EIEAIQFA",
			"game_center": "puzzles_100"
		}
	},
	"veterano_puzles": {
		"name": "Veterano de Puzles",
		"desc": "Completa 500 puzles en total. ¡Increíble dedicación!",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_500_puzzles.png",
		"secret": false,
		"progress": 0,
		"max_progress": 500,
		"platform_ids": {
			"steam": "ACHIEVEMENT_500_PUZZLES",
			"google_play": "CgkIh5jdi9EIEAIQFQ",
			"game_center": "puzzles_500"
		}
	},
	"leyenda_puzles": {
		"name": "Leyenda de los Puzles",
		"desc": "Completa 1000 puzles en total. ¡Eres una leyenda viviente!",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_1000_puzzles.png",
		"secret": false,
		"progress": 0,
		"max_progress": 1000,
		"platform_ids": {
			"steam": "ACHIEVEMENT_1000_PUZZLES",
			"google_play": "CgkIh5jdi9EIEAIQFg",
			"game_center": "puzzles_1000"
		}
	},
	"movimiento_perfecto": {
		"name": "Movimiento Perfecto",
		"desc": "Completa un puzle en un solo movimiento. ¡Precisión absoluta!",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_one_move.png",
		"secret": true,
		"progress": 0,
		"max_progress": 1,
		"platform_ids": {
			"steam": "ACHIEVEMENT_ONE_MOVE",
			"google_play": "CgkIh5jdi9EIEAIQFw",
			"game_center": "one_move"
		}
	},
	"velocista_dificil": {
		"name": "Velocista Difícil",
		"desc": "Completa un puzle difícil en menos de 2 minutos.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_hard_quick.png",
		"secret": false,
		"progress": 0,
		"max_progress": 1,
		"platform_ids": {
			"steam": "ACHIEVEMENT_HARD_QUICK",
			"google_play": "CgkIh5jdi9EIEAIQGA",
			"game_center": "hard_quick"
		}
	},
	"fiel_seguidor": {
		"name": "Fiel Seguidor",
		"desc": "Completa el mismo puzle 10 veces. ¿Te gusta la familiaridad?",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_same_10.png",
		"secret": true,
		"progress": 0,
		"max_progress": 10,
		"platform_ids": {
			"steam": "ACHIEVEMENT_SAME_10",
			"google_play": "CgkIh5jdi9EIEAIQGQ",
			"game_center": "same_puzzle_10"
		}
	},
	"amante_devotado": {
		"name": "Amante Devotado",
		"desc": "Completa el mismo puzle 100 veces. ¿Obsesión o perfeccionismo?",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_same_100.png",
		"secret": true,
		"progress": 0,
		"max_progress": 100,
		"platform_ids": {
			"steam": "ACHIEVEMENT_SAME_100",
			"google_play": "CgkIh5jdi9EIEAIQGg",
			"game_center": "same_puzzle_100"
		}
	},
	"jugador_dedicado": {
		"name": "Jugador Dedicado",
		"desc": "Juega durante más de 1 hora en total. El tiempo vuela cuando te diviertes.",
		"unlocked": false,
		"icon": "res://Assets/Icons/achievement_time_played.png",
		"secret": false,
		"progress": 0,
		"max_progress": 3600,
		"platform_ids": {
			"steam": "ACHIEVEMENT_TIME_PLAYED",
			"google_play": "CgkIh5jdi9EIEAIQGw",
			"game_center": "time_played"
		}
	}
}

# Variable para almacenar la configuración del sistema de notificaciones
var notification_config = {
	"enabled": true,
	"duration": 3.0,
	"position": "top_right"
}

# Variables para detectar la plataforma
var is_steam = false
var is_android = false
var is_ios = false

# Nodo para mostrar notificaciones de logros
var notification_scene = null
var notification_container = null

func _ready():
	# Detectar plataforma
	detect_platform()
	
	# Cargar los datos guardados
	load_achievements_data()
	
	# Inicializar el sistema de notificaciones
	initialize_notification_system()
	
	print("AchievementsManager: Sistema de logros inicializado")

# Detecta la plataforma actual
func detect_platform():
	is_steam = OS.has_feature("steam")
	is_android = OS.has_feature("android")
	is_ios = OS.has_feature("ios")
	
	print("AchievementsManager: Plataforma detectada - Steam: ", is_steam, 
		", Android: ", is_android, ", iOS: ", is_ios)

# Inicializa el sistema de notificaciones
func initialize_notification_system():
	# Verificar si la escena existe antes de cargarla
	if ResourceLoader.exists("res://Scenes/Components/AchievementNotification/AchievementNotification.tscn"):
		# Cargar la escena de notificación
		notification_scene = load("res://Scenes/Components/AchievementNotification/AchievementNotification.tscn")
	else:
		# La escena no existe, mostrar mensaje de error en consola
		print("AchievementsManager: No se encontró la escena de notificación de logros")
		# Desactivar las notificaciones en pantalla
		notification_config.enabled = false
	
	# Solo crear el contenedor si tenemos la escena de notificación
	if notification_scene != null:
		# Crear un contenedor de notificaciones si no existe
		if get_tree().root.has_node("AchievementNotifications"):
			notification_container = get_tree().root.get_node("AchievementNotifications")
		else:
			notification_container = Control.new()
			notification_container.name = "AchievementNotifications"
			notification_container.anchor_right = 1.0
			notification_container.anchor_bottom = 1.0
			notification_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Ignora los eventos del mouse
			get_tree().root.call_deferred("add_child", notification_container)

# Guarda los datos de logros en un archivo JSON
func save_achievements_data():
	var file = FileAccess.open(ACHIEVEMENTS_SAVE_FILE, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(achievements, "\t")
		file.store_string(json_text)
		file.close()
		print("AchievementsManager: Datos de logros guardados correctamente")
	else:
		print("AchievementsManager: Error al guardar los datos de logros")

# Carga los datos de logros desde un archivo JSON
func load_achievements_data():
	var file = FileAccess.open(ACHIEVEMENTS_SAVE_FILE, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json_result = JSON.parse_string(json_text)
		if json_result:
			# Actualizar solo los campos de progreso y desbloqueo, manteniendo las definiciones
			for achievement_id in json_result:
				if achievements.has(achievement_id):
					achievements[achievement_id].unlocked = json_result[achievement_id].unlocked
					achievements[achievement_id].progress = json_result[achievement_id].progress
			
			print("AchievementsManager: Datos de logros cargados correctamente")
		else:
			print("AchievementsManager: Error al analizar el JSON de logros")
	else:
		print("AchievementsManager: No se encontró archivo de logros, se usarán los valores por defecto")

# Función para actualizar el progreso de un logro
func update_progress(achievement_id: String, progress_value: float) -> void:
	if achievements.has(achievement_id):
		var achievement = achievements[achievement_id]
		
		# Ignorar si ya está desbloqueado
		if achievement.unlocked:
			return
			
		# Actualizar progreso
		achievement.progress = min(progress_value, achievement.max_progress)
		
		# Verificar si se ha completado
		if achievement.progress >= achievement.max_progress:
			unlock_achievement(achievement_id)
		else:
			# Guardar el progreso actual
			save_achievements_data()
			
			# Reportar progreso a plataformas
			report_progress_to_platforms(achievement_id, achievement)

# Función para desbloquear un logro
func unlock_achievement(achievement_id: String) -> void:
	if achievements.has(achievement_id) and not achievements[achievement_id].unlocked:
		achievements[achievement_id].unlocked = true
		achievements[achievement_id].progress = achievements[achievement_id].max_progress
		
		print("AchievementsManager: Logro desbloqueado: " + achievements[achievement_id].name)
		
		# Añadir a la lista de logros desbloqueados en esta sesión
		achievements_unlocked_this_session.append(achievement_id)
		
		# Guardar el progreso
		save_achievements_data()
		
		# Reportar a las plataformas
		report_achievement_to_platforms(achievement_id, achievements[achievement_id])
		
		# Mostrar notificación
		if notification_config.enabled:
			show_achievement_notification(achievement_id)
		
		# Emitir señal
		emit_signal("achievement_unlocked", achievement_id, achievements[achievement_id])

# Función para reportar logros a plataformas externas
func report_achievement_to_platforms(achievement_id: String, achievement: Dictionary) -> void:
	# Steam
	if is_steam and Engine.has_singleton("Steam"):
		var steam = Engine.get_singleton("Steam")
		if achievement.platform_ids.has("steam"):
			steam.set_achievement(achievement.platform_ids.steam)
			steam.store_stats()
	
	# Google Play Games (Android)
	if is_android and Engine.has_singleton("GooglePlay"):
		var play_services = Engine.get_singleton("GooglePlay")
		if achievement.platform_ids.has("google_play"):
			play_services.unlock_achievement(achievement.platform_ids.google_play)
	
	# Game Center (iOS)
	if is_ios and Engine.has_singleton("GameCenter"):
		var game_center = Engine.get_singleton("GameCenter")
		if achievement.platform_ids.has("game_center"):
			game_center.report_achievement(achievement.platform_ids.game_center, 100.0)

# Función para reportar progreso a plataformas externas
func report_progress_to_platforms(achievement_id: String, achievement: Dictionary) -> void:
	var progress_percent = (achievement.progress / achievement.max_progress) * 100.0
	
	# No reportar a Steam ya que solo admite desbloqueado/no desbloqueado
	
	# Google Play Games (Android)
	if is_android and Engine.has_singleton("GooglePlay"):
		var play_services = Engine.get_singleton("GooglePlay")
		if achievement.platform_ids.has("google_play"):
			play_services.reveal_achievement(achievement.platform_ids.google_play)
			play_services.set_achievement_steps(achievement.platform_ids.google_play, 
				int(achievement.progress), int(achievement.max_progress))
	
	# Game Center (iOS)
	if is_ios and Engine.has_singleton("GameCenter"):
		var game_center = Engine.get_singleton("GameCenter")
		if achievement.platform_ids.has("game_center"):
			game_center.report_achievement(achievement.platform_ids.game_center, progress_percent)

# Función para obtener la información de un logro
func get_achievement(achievement_id: String) -> Dictionary:
	if achievements.has(achievement_id):
		return achievements[achievement_id]
	return {}

# Función para obtener todos los logros
func get_all_achievements() -> Dictionary:
	return achievements

# Función para mostrar la notificación de logro
func show_achievement_notification(achievement_id: String) -> void:
	# Verificar que tengamos todo lo necesario para mostrar la notificación
	if not notification_config.enabled or notification_scene == null or notification_container == null:
		print("AchievementsManager: No se puede mostrar notificación, sistema de notificaciones no disponible")
		return
		
	if achievements.has(achievement_id):
		var achievement = achievements[achievement_id]
		var notification = notification_scene.instantiate()
		notification_container.add_child(notification)
		
		# Configurar la notificación
		notification.setup(achievement.name, achievement.desc, achievement.icon, notification_config.duration)
		notification.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)  # Ignorar interacciones del mouse
		notification.show_notification()

# Función para reiniciar todos los logros (para pruebas)
func reset_all_achievements() -> void:
	for achievement_id in achievements:
		achievements[achievement_id].unlocked = false
		achievements[achievement_id].progress = 0
	
	save_achievements_data()
	print("AchievementsManager: Todos los logros han sido reiniciados")

# Funciones auxiliares para eventos específicos del juego
# Estas funciones pueden ser llamadas desde diferentes partes del juego

# Registrar la finalización de un puzzle
func register_puzzle_completed(difficulty_level: Dictionary, moves: int, time: float, used_flip: bool) -> void:
	# Logro: Primer Paso
	update_progress("primer_paso", 1)
	
	# Logro: El Coleccionista
	update_progress("el_coleccionista", achievements["el_coleccionista"].progress + 1)
	
	# Actualizar contadores globales de puzzles completados
	update_progress("aficionado_puzles", achievements["aficionado_puzles"].progress + 1)
	update_progress("entusiasta_puzles", achievements["entusiasta_puzles"].progress + 1)
	update_progress("experto_puzles", achievements["experto_puzles"].progress + 1)
	update_progress("veterano_puzles", achievements["veterano_puzles"].progress + 1)
	update_progress("leyenda_puzles", achievements["leyenda_puzles"].progress + 1)
	
	# Logro: Sin Mirar Atrás
	if not used_flip:
		update_progress("sin_mirar_atras", 1)
		
	# Logro: Eficiencia Máxima
	if moves <= 20:
		update_progress("eficiencia_maxima", 1)
	
	# Logro: Movimiento Perfecto
	if moves == 1:
		update_progress("movimiento_perfecto", 1)
	
	# Logro: Velocista Extremo
	if time < 1.0:
		update_progress("velocista_extremo", 1)
	
	# Logro: Velocista Difícil
	# Verificamos si es un puzle difícil basándonos en el tamaño del tablero (filas y columnas)
	if difficulty_level.has("rows") and difficulty_level.has("columns") and difficulty_level.rows >= 5 and difficulty_level.columns >= 5 and time < 120.0:
		update_progress("velocista_dificil", 1)
	
	# Logro: Velocidad Relámpago (para modo contrarreloj)
	# Suponiendo que hay un modo contrarreloj con tiempo límite
	if GLOBAL.has_method("get"):
		var game_mode = GLOBAL.get("game_mode")
		if game_mode == "time_trial":
			var time_limit = GLOBAL.get("time_limit")
			if time_limit != null:
				var time_left = time_limit - time
				if time_left >= 30:
					update_progress("velocidad_relampago", 1)
	
	# Logro: Maestro de la Noche
	# Si es dificultad máxima y modo contrarreloj
	if difficulty_level.has("rows") and difficulty_level.has("columns") and difficulty_level.rows >= 6 and difficulty_level.columns >= 6:
		if GLOBAL.has_method("get"):
			var game_mode = GLOBAL.get("game_mode")
			if game_mode == "time_trial":
				update_progress("maestro_de_la_noche", achievements["maestro_de_la_noche"].progress + 1)
	
	# Logro: Perfecto en Todo Sentido
	# Si completa con puntuación perfecta (lógica a definir según el juego)
	var perfect_score = (moves <= difficulty_level.rows * difficulty_level.columns * 0.2) and time < 120.0
	if perfect_score:
		update_progress("perfecto_en_todo_sentido", 1)
	
	# Actualizar el contador para el mismo puzzle (requiere ID de puzzle)
	if GLOBAL.has_method("get"):
		var puzzle_id = GLOBAL.get("current_puzzle_id")
		if puzzle_id != null and puzzle_id != "":
			_update_same_puzzle_counter(puzzle_id)

# Función para registrar la finalización de un pack
func register_pack_completed(pack_difficulty: String) -> void:
	# Logro: Pack Completo
	update_progress("pack_completo", 1)
	
	# Logro: Desafiante Experimentado
	if pack_difficulty == "difficult":
		update_progress("desafiante_experimentado", 1)
	
	# Logro: Maestro de Puzles
	if pack_difficulty == "super_difficult":
		update_progress("maestro_puzles", 1)

# Función para actualizar el tiempo total jugado
func update_play_time(delta_time: float) -> void:
	if achievements.has("jugador_dedicado") and not achievements["jugador_dedicado"].unlocked:
		update_progress("jugador_dedicado", achievements["jugador_dedicado"].progress + delta_time)

# Diccionario para rastrear cuántas veces se ha completado cada puzzle
var puzzle_completion_counts = {}

# Función para actualizar el contador de veces que se ha completado el mismo puzzle
func _update_same_puzzle_counter(puzzle_id: String) -> void:
	if not puzzle_completion_counts.has(puzzle_id):
		puzzle_completion_counts[puzzle_id] = 0
	
	puzzle_completion_counts[puzzle_id] += 1
	var count = puzzle_completion_counts[puzzle_id]
	
	# Actualizar logros relacionados
	if count >= 10:
		update_progress("fiel_seguidor", 10)
	
	if count >= 100:
		update_progress("amante_devotado", 100)

func loadFile(path) -> String:
	var file = FileAccess.open(path, FileAccess.READ)

	if file != null:
		var content = file.get_as_text()
		return content
	else: 
		return ''

func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn") 
	
func updateVolume(field, value):
	GLOBAL.settings.volume[field] = value

# Obtiene los logros desbloqueados durante esta sesión de juego
func get_achievements_unlocked_this_session() -> Array:
	return achievements_unlocked_this_session

# Limpia la lista de logros desbloqueados en esta sesión
func clear_achievements_unlocked_this_session() -> void:
	achievements_unlocked_this_session.clear()
