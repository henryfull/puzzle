extends Node2D

# Variable para detectar si estamos en un dispositivo móvil
var is_mobile = false
var labelGeneral: Label
var labelMusic: Label
var labelSFX: Label
var labelLanguage: Label
var labelResolution: Label
# Nuevas etiquetas para opciones de sensibilidad
var labelPanSensitivity: Label
var labelTweenEffect: Label
var labelTweenDuration: Label
# Etiqueta para mostrar estado de conexión de plataforma
var labelPlatformConnection: Label
var buttonClose: Button
var buttonRestore: Button
var buttonPlatformConnect: Button
# Variable para mostrar estado de autenticación
var authenticating = false
var platform_spinner = null
@export var sliderVolumeGeneral = HSlider
@export var sliderVolumeSFX = HSlider
@export var sliderVolumeMusic = HSlider
# Nuevos sliders para opciones de sensibilidad
@export var sliderPanSensitivity = HSlider
@export var sliderTweenDuration = HSlider
@export var checkTweenEffect = CheckBox
var selectLanguage = OptionButton
var selectResolution = OptionButton
var sliderOptionGeneral = null
var sliderOptionMusic = null
var sliderOptionSFX = null

# Valores por defecto para opciones de sensibilidad (deben coincidir con los de PuzzleGame)
var pan_sensitivity: float = 1.0
var use_tween_effect: bool = true
var tween_duration: float = 0.2

func _ready():
	print("Options: Inicializando...")
	print("Options: Verificando nodos autoload disponibles:")
	var children = get_node("/root").get_children()
	for child in children:
		print("- " + child.name)
	print("¿ConnectStores existe? " + str(has_node("/root/ConnectStores")))
	
	labelGeneral = $%Label_general
	labelMusic = $%LabelMusic
	labelSFX = $%LabelSFX
	labelLanguage = $%LabelIdioma
	labelResolution = $%Label_resolution
	# Inicializar nuevas etiquetas
	labelPanSensitivity = $%LabelPanSensitivity
	labelTweenEffect = $%LabelTweenEffect
	labelTweenDuration = $%LabelTweenDuration
	# Inicializar etiqueta de conexión de plataforma
	labelPlatformConnection = $%LabelPlatformConnection
	
	buttonClose = %ButtonClose
	buttonRestore = %RestoreButton
	buttonPlatformConnect = $%ButtonPlatformConnect
	
	# Inicializar nuevos controles
	
	selectLanguage = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/LangSelector
	if ($CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/ResolutionButton):
		selectResolution = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/ResolutionButton
	
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	# Verificar la estructura del nodo CanvasLayer
	if has_node("CanvasLayer"):
		print("Options: CanvasLayer encontrado")
		var canvas_layer = get_node("CanvasLayer")
		print("Options: CanvasLayer tiene ", canvas_layer.get_child_count(), " hijos")
	else:
		print("Options: ERROR - CanvasLayer no encontrado")
	
	# Actualizar estado de conexión de plataforma
	update_platform_connection_status()
	
	# Cargar valores actuales
	load_current_values()
	
	# Adaptar la UI para dispositivos móviles
	# adapt_ui_for_device()
	
	# Actualizar textos de la UI
	update_ui_texts()

	# Conectar la señal del botón de conexión
	if buttonPlatformConnect:
		buttonPlatformConnect.pressed.connect(_on_platform_connect_pressed)

	# Conectar señales de ConnectStores si existe
	if has_node("/root/ConnectStores"):
		var connect_stores = get_node("/root/ConnectStores")
		if connect_stores.has_signal("connected_to_service"):
			connect_stores.connected_to_service.connect(_on_connected_to_service)
		if connect_stores.has_signal("connection_failed"):
			connect_stores.connection_failed.connect(_on_connection_failed)
	
	print("Options: Inicialización completada")

# Función para actualizar los textos de la UI según el idioma actual
func update_ui_texts():

	labelResolution.text = tr("common_resolution")
	labelLanguage.text = tr("common_language")
	labelGeneral.text = tr("common_general")
	labelMusic.text = tr("common_music")
	labelSFX.text = tr("common_sfx")
	
	# Actualizar textos para las nuevas etiquetas
	if labelPanSensitivity:
		labelPanSensitivity.text = tr("options_pan_sensitivity")
	if labelTweenEffect:
		labelTweenEffect.text = tr("options_tween_effect")
	if labelTweenDuration:
		labelTweenDuration.text = tr("options_tween_duration")
	if labelPlatformConnection:
		labelPlatformConnection.text = tr("options_platform_connection")
	
	#buttonClose.text = tr("common_back")
	buttonRestore.text = tr("options_restore_purchases")
	
	# Actualizar estado de conexión de plataforma
	update_platform_connection_status()
	
	print("Options: Textos actualizados con idioma: ", TranslationServer.get_locale())

# Callback cuando se conecta exitosamente a un servicio
func _on_connected_to_service(service_name):
	print("Options: Conectado a servicio: " + service_name)
	authenticating = false
	update_platform_connection_status()
	_remove_spinner()
	
	# Mostrar mensaje de éxito
	OS.alert(tr("options_connection_success") + ": " + service_name, tr("common_success"))

# Callback cuando falla la conexión a un servicio
func _on_connection_failed(service_name, error_message):
	print("Options: Error al conectar con " + service_name + ": " + error_message)
	authenticating = false
	update_platform_connection_status()
	_remove_spinner()
	
	# Mostrar mensaje de error al usuario
	OS.alert(tr("options_connection_error") + ": " + error_message, tr("common_error"))
	
	if buttonPlatformConnect:
		buttonPlatformConnect.disabled = false

# Función para verificar y mostrar el estado de conexión de plataforma
func update_platform_connection_status():
	if not labelPlatformConnection:
		return
		
	var platform_status = $%TextPlatformStatus
	if not platform_status:
		return
	
	# Si está en proceso de autenticación, mostrar estado de carga
	if authenticating:
		platform_status.text = tr("options_connecting")
		platform_status.add_theme_color_override("font_color", Color(0.3, 0.3, 0.8, 1)) # Azul
		if buttonPlatformConnect:
			buttonPlatformConnect.text = tr("common_cancel")
			buttonPlatformConnect.disabled = true
		return
		
	var platform_name = "---"
	var is_connected = false
	
	# Utilizar ConnectStores para obtener información (método preferido)
	if has_node("/root/ConnectStores"):
		var connect_stores = get_node("/root/ConnectStores")
		is_connected = connect_stores.is_authenticated()
		
		if is_connected:
			platform_name = connect_stores.get_service_name()
	
	# Fallback al método directo si ConnectStores no está disponible o devuelve que no está conectado
	if not is_connected:
		# Comprobar si estamos en Google Play
		if Engine.has_singleton("GodotPlayGames"):
			var play_games = Engine.get_singleton("GodotPlayGames")
			if play_games.isSignedIn():
				platform_name = "Google Play Games"
				is_connected = true
		# Si estamos en Android con el plugin GooglePlay
		elif Engine.has_singleton("GooglePlay"):
			var play_services = Engine.get_singleton("GooglePlay")
			if play_services.isSignedIn():
				platform_name = "Google Play Games"
				is_connected = true
		# Comprobar si estamos en Game Center (Apple)
		elif Engine.has_singleton("GameCenter"):
			var game_center = Engine.get_singleton("GameCenter")
			if game_center.isAuthenticated():
				platform_name = "Apple Game Center" 
				is_connected = true
	
	# Actualizar el texto de estado
	if is_connected:
		platform_status.text = platform_name
		platform_status.add_theme_color_override("font_color", Color(0, 0.7, 0, 1)) # Verde
		if buttonPlatformConnect:
			buttonPlatformConnect.text = tr("common_exit")
			buttonPlatformConnect.disabled = false
	else:
		platform_status.text = tr("options_not_connected")
		platform_status.add_theme_color_override("font_color", Color(0.7, 0, 0, 1)) # Rojo
		if buttonPlatformConnect:
			buttonPlatformConnect.text = tr("common_connect")
			
			# Verificar si hay servicios disponibles
			var services_available = false
			if has_node("/root/ConnectStores"):
				services_available = get_node("/root/ConnectStores").are_services_available()
			else:
				services_available = Engine.has_singleton("GameCenter") or Engine.has_singleton("GooglePlay") or Engine.has_singleton("GodotPlayGames")
			
			buttonPlatformConnect.disabled = not services_available

# Crea un indicador de carga durante la autenticación
func _show_spinner():
	_remove_spinner() # Asegurarse de que no hay un spinner existente
	
	# Crear un nodo ColorRect como spinner simple
	platform_spinner = Control.new()
	platform_spinner.name = "PlatformSpinner"
	platform_spinner.custom_minimum_size = Vector2(24, 24)
	
	# Crear un ColorRect para representar el spinner
	var spinner_indicator = ColorRect.new()
	spinner_indicator.name = "SpinnerIndicator"
	spinner_indicator.color = Color(0.0, 0.5, 1.0, 0.8)  # Azul semitransparente
	spinner_indicator.size = Vector2(8, 8)
	spinner_indicator.position = Vector2(8, 0)  # Posición inicial
	platform_spinner.add_child(spinner_indicator)
	
	# Añadir el spinner a HBoxContainerPlatform
	var platform_container = $CanvasLayer/PanelContainer2/MarginContainer/ScrollContainer/VBoxContainer/HBoxContainerPlatform
	if platform_container:
		platform_container.add_child(platform_spinner)
		
		# Crear una animación para rotar el spinner
		var tween = create_tween().set_loops()
		tween.tween_property(spinner_indicator, "position", Vector2(8, 16), 0.25)
		tween.tween_property(spinner_indicator, "position", Vector2(16, 8), 0.25)
		tween.tween_property(spinner_indicator, "position", Vector2(8, 0), 0.25)
		tween.tween_property(spinner_indicator, "position", Vector2(0, 8), 0.25)

# Elimina el indicador de carga
func _remove_spinner():
	if platform_spinner and is_instance_valid(platform_spinner):
		platform_spinner.queue_free()
		platform_spinner = null

# Función para manejar el botón de conexión/desconexión de la plataforma
func _on_platform_connect_pressed():
	print("Options: Botón de plataforma presionado")
	
	# Verificar si ConnectStores existe
	if not has_node("/root/ConnectStores"):
		print("Options: ERROR - ConnectStores no está disponible como autoload")
		OS.alert("Error: El servicio de conexión no está disponible", "Error")
		return
	
	var connect_stores_instance = get_node("/root/ConnectStores")
	print("Options: ConnectStores disponible. Es iOS: " + str(connect_stores_instance.is_ios))
	print("Options: Servicios disponibles: " + str(connect_stores_instance.are_services_available()))
	
	var platform_status = $%TextPlatformStatus
	
	# Si está en medio de un proceso de autenticación, cancelarlo
	if authenticating:
		authenticating = false
		update_platform_connection_status()
		_remove_spinner()
		if buttonPlatformConnect:
			buttonPlatformConnect.disabled = false
		return
	
	var is_connected = platform_status and platform_status.text != tr("options_not_connected")
	print("Options: Estado actual de conexión: " + str(is_connected))
	
	if is_connected:
		# Desconectar de la plataforma
		if has_node("/root/ConnectStores"):
			var stores_instance = get_node("/root/ConnectStores")
			# Intentar cerrar sesión según la plataforma
			if stores_instance.is_ios and Engine.has_singleton("GameCenter"):
				# Game Center no tiene función de cierre de sesión directo
				OS.alert(tr("options_gamecenter_sign_out_info"), tr("common_info"))
			elif stores_instance.is_android and Engine.has_singleton("GooglePlay"):
				var play_services = Engine.get_singleton("GooglePlay")
				if play_services.has_method("sign_out"):
					play_services.sign_out()
			elif stores_instance.is_android and Engine.has_singleton("GodotPlayGames"):
				var play_games = Engine.get_singleton("GodotPlayGames")
				if play_games.has_method("signOut"):
					play_games.signOut()
		else:
			# Fallback si ConnectStores no está disponible
			if Engine.has_singleton("GodotPlayGames"):
				var play_games = Engine.get_singleton("GodotPlayGames")
				if play_games.has_method("signOut"):
					play_games.signOut()
			elif Engine.has_singleton("GooglePlay"):
				var play_services = Engine.get_singleton("GooglePlay")
				if play_services.has_method("sign_out"):
					play_services.sign_out()
			elif Engine.has_singleton("GameCenter"):
				# Game Center no permite cerrar sesión directamente
				OS.alert(tr("options_gamecenter_sign_out_info"), tr("common_info"))
	else:
		# Iniciar proceso de autenticación
		authenticating = true
		_show_spinner()
		update_platform_connection_status()
		
		# Conectar a la plataforma
		if has_node("/root/ConnectStores"):
			var stores_instance = get_node("/root/ConnectStores")
			
			# Primero conectamos las señales si no se hizo en _ready
			if not stores_instance.is_connected("connected_to_service", _on_connected_to_service):
				print("Options: Conectando señal connected_to_service")
				stores_instance.connected_to_service.connect(_on_connected_to_service)
			if not stores_instance.is_connected("connection_failed", _on_connection_failed):
				print("Options: Conectando señal connection_failed")
				stores_instance.connection_failed.connect(_on_connection_failed)
			
			# Iniciar proceso de conexión adecuado para la plataforma
			if not stores_instance.connection_initialized:
				print("Options: Iniciando conexión por primera vez")
				stores_instance.initialize_connection()
			else:
				# Reintentar la conexión según la plataforma
				print("Options: Reintentando conexión en plataforma: iOS=" + str(stores_instance.is_ios) + ", Android=" + str(stores_instance.is_android))
				if stores_instance.is_ios:
					stores_instance.init_game_center()
				elif stores_instance.is_android:
					stores_instance.init_google_play()
				else:
					# En plataforma de escritorio, simular una conexión
					print("Options: Simulando conexión en plataforma de escritorio")
					await get_tree().create_timer(1.5).timeout
					if authenticating: # Verificar que no se haya cancelado
						_on_connected_to_service("Servicios de juego")
		else:
			# Fallback si ConnectStores no está disponible
			var connection_successful = false
			
			if Engine.has_singleton("GodotPlayGames"):
				var play_games = Engine.get_singleton("GodotPlayGames")
				if play_games.has_method("signIn"):
					play_games.signIn()
					connection_successful = true
			elif Engine.has_singleton("GooglePlay"):
				var play_services = Engine.get_singleton("GooglePlay")
				if play_services.has_method("sign_in"):
					play_services.sign_in()
					connection_successful = true
			elif Engine.has_singleton("GameCenter"):
				var game_center = Engine.get_singleton("GameCenter")
				if game_center.has_method("authenticate"):
					game_center.authenticate()
					connection_successful = true
			
			# Si no se pudo iniciar ningún proceso de autenticación
			if not connection_successful:
				authenticating = false
				_remove_spinner()
				OS.alert(tr("options_no_services_available"), tr("common_error"))
				update_platform_connection_status()
				return
			
			# Si se inició algún proceso, esperar un tiempo y luego actualizar estado
			await get_tree().create_timer(3.0).timeout
			authenticating = false
			update_platform_connection_status()
	
	buttonPlatformConnect.disabled = false

# Función para cargar los valores actuales
func load_current_values():
	# Cargar volúmenes desde GLOBAL
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		
		# Volumen general
		var slider_general = sliderVolumeGeneral
		if slider_general:
			slider_general.value = global.settings.volume.general
		
		# Volumen música
		var slider_music = sliderVolumeMusic
		if slider_music:
			slider_music.value = global.settings.volume.music
		
		# Volumen efectos
		var slider_sfx = sliderVolumeSFX
		if slider_sfx:
			slider_sfx.value = global.settings.volume.sfx
		
		# Cargar opciones de sensibilidad si existen en GLOBAL
		if "puzzle" in global.settings and global.settings.puzzle != null:
			# Sensibilidad de desplazamiento
			if sliderPanSensitivity and "pan_sensitivity" in global.settings.puzzle:
				sliderPanSensitivity.value = global.settings.puzzle.pan_sensitivity
				pan_sensitivity = global.settings.puzzle.pan_sensitivity
			
			# Usar efecto tween
			if checkTweenEffect and "use_tween_effect" in global.settings.puzzle:
				checkTweenEffect.button_pressed = global.settings.puzzle.use_tween_effect
				use_tween_effect = global.settings.puzzle.use_tween_effect
			
			# Duración del efecto tween
			if sliderTweenDuration and "tween_duration" in global.settings.puzzle:
				sliderTweenDuration.value = global.settings.puzzle.tween_duration
				tween_duration = global.settings.puzzle.tween_duration
		else:
			print("Options: No se encontraron ajustes de puzzle en GLOBAL.settings")
			
			# Si OptionsManager existe, intentar cargar desde ahí
			if has_node("/root/OptionsManager"):
				var options_manager = get_node("/root/OptionsManager")
				if options_manager.has_method("get_option"):
					# Cargar la sensibilidad de desplazamiento
					var saved_sensitivity = options_manager.get_option("pan_sensitivity", pan_sensitivity)
					pan_sensitivity = saved_sensitivity
					if sliderPanSensitivity:
						sliderPanSensitivity.value = pan_sensitivity
					
					# Cargar configuración de efecto tween
					var saved_tween_effect = options_manager.get_option("use_tween_effect", use_tween_effect)
					use_tween_effect = saved_tween_effect
					if checkTweenEffect:
						checkTweenEffect.button_pressed = use_tween_effect
					
					# Cargar duración del efecto tween
					var saved_tween_duration = options_manager.get_option("tween_duration", tween_duration)
					tween_duration = saved_tween_duration
					if sliderTweenDuration:
						sliderTweenDuration.value = tween_duration
		
		# Idioma
		var lang_selector = selectLanguage
		if lang_selector:
			# Seleccionar el idioma actual
			for i in range(lang_selector.get_item_count()):
				if lang_selector.get_item_text(i) == global.settings.language:
					lang_selector.select(i)
					break


func _on_HSlider_Volumen_General_value_changed(value):
	if has_node("/root/GLOBAL") and has_node("/root/AudioManager"):
		var global = get_node("/root/GLOBAL")
		var audio_manager = get_node("/root/AudioManager")
		
		global.settings.volume.general = value
		audio_manager.update_volumes()
		global.save_settings()

func _on_HSlider_Volumen_Musica_value_changed(value):
	if has_node("/root/GLOBAL") and has_node("/root/AudioManager"):
		var global = get_node("/root/GLOBAL")
		var audio_manager = get_node("/root/AudioManager")
		
		global.settings.volume.music = value
		audio_manager.update_volumes()
		global.save_settings()

func _on_HSlider_Volumen_VFX_value_changed(value):
	if has_node("/root/GLOBAL") and has_node("/root/AudioManager"):
		var global = get_node("/root/GLOBAL")
		var audio_manager = get_node("/root/AudioManager")
		
		global.settings.volume.sfx = value
		audio_manager.update_volumes()
		global.save_settings()

# Nuevas funciones para manejar las opciones de sensibilidad
func _on_pan_sensitivity_changed(value):
	print("Options: Sensibilidad cambiada a: ", value)
	pan_sensitivity = value
	
	# Guardar en GLOBAL si existe
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		
		# Asegurarnos de que exista la sección puzzle en settings
		if not "puzzle" in global.settings:
			global.settings.puzzle = {}
		
		global.settings.puzzle.pan_sensitivity = value
		
		# Guardar la configuración
		if global.has_method("save_settings"):
			global.save_settings()
	
	# Guardar también en OptionsManager para compatibilidad
	if has_node("/root/OptionsManager"):
		var options_manager = get_node("/root/OptionsManager")
		if options_manager.has_method("save_option"):
			options_manager.save_option("pan_sensitivity", value)

func _on_tween_effect_toggled(toggled):
	print("Options: Efecto Tween: ", toggled)
	use_tween_effect = toggled
	
	# Actualizar la visibilidad del control de duración de tween
	if sliderTweenDuration:
		sliderTweenDuration.editable = toggled
		if labelTweenDuration:
			labelTweenDuration.modulate.a = 1.0 if toggled else 0.5
	
	# Guardar en GLOBAL
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		
		# Asegurarnos de que exista la sección puzzle en settings
		if not "puzzle" in global.settings:
			global.settings.puzzle = {}
		
		global.settings.puzzle.use_tween_effect = toggled
		
		# Guardar la configuración
		if global.has_method("save_settings"):
			global.save_settings()
	
	# Guardar también en OptionsManager para compatibilidad
	if has_node("/root/OptionsManager"):
		var options_manager = get_node("/root/OptionsManager")
		if options_manager.has_method("save_option"):
			options_manager.save_option("use_tween_effect", toggled)

func _on_tween_duration_changed(value):
	print("Options: Duración del efecto Tween: ", value)
	tween_duration = value
	
	# Guardar en GLOBAL
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		
		# Asegurarnos de que exista la sección puzzle en settings
		if not "puzzle" in global.settings:
			global.settings.puzzle = {}
		
		global.settings.puzzle.tween_duration = value
		
		# Guardar la configuración
		if global.has_method("save_settings"):
			global.save_settings()
	
	# Guardar también en OptionsManager para compatibilidad
	if has_node("/root/OptionsManager"):
		var options_manager = get_node("/root/OptionsManager")
		if options_manager.has_method("save_option"):
			options_manager.save_option("tween_duration", value)

func _on_button_close_pressed() -> void:
	OptionsManager.hide_options()

func _on_restore_button_pressed() -> void:
	print("Restaurando acceso a los puzzles - SOLUCIÓN DRÁSTICA...")
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		
		# SOLUCIÓN DRÁSTICA: Cargar los packs directamente desde el archivo JSON
		var packs_file = FileAccess.open("res://PacksData/sample_packs.json", FileAccess.READ)
		if packs_file:
			var json_string = packs_file.get_as_text()
			var json = JSON.parse_string(json_string)
			if json and "packs" in json and json.packs.size() > 0:
				# Reemplazar completamente los packs en las configuraciones
				global.settings.packs = json.packs
				
				# Asegurar que TODOS los packs estén correctamente configurados
				for i in range(global.settings.packs.size()):
					# Los primeros dos packs siempre desbloqueados y comprados
					if i == 0 or i == 1:  # Primer pack (fruits) y segundo pack (numbers)
						global.settings.packs[i].unlocked = true
						global.settings.packs[i].purchased = true
						
						# Asegurarse de que todos los puzzles en estos packs estén desbloqueados
						if "puzzles" in global.settings.packs[i]:
							for puzzle in global.settings.packs[i].puzzles:
								puzzle.unlocked = true
					
				print("Packs restaurados completamente desde sample_packs.json")
			else:
				print("ERROR: JSON de packs no válido")
		else:
			print("ERROR: No se pudo abrir el archivo sample_packs.json")
			
			# Plan B: Si no se puede cargar el archivo, intentar desbloquear lo que ya existe
			if "packs" in global.settings and global.settings.packs.size() > 0:
				# Asegurar que los dos primeros packs están desbloqueados y comprados
				for i in range(min(2, global.settings.packs.size())):
					global.settings.packs[i].unlocked = true
					global.settings.packs[i].purchased = true
					
					# Asegurarse de que todos los puzzles estén desbloqueados
					if "puzzles" in global.settings.packs[i]:
						for puzzle in global.settings.packs[i].puzzles:
							puzzle.unlocked = true
						
				print("Primeros packs desbloqueados manualmente")
		
		# Restaurar progreso
		if has_node("/root/Progress"):
			var progress = get_node("/root/Progress")
			if progress.has_method("load_progress"):
				progress.load_progress()
			if progress.has_method("reset_progress"):
				progress.reset_progress() # Intentar reiniciar el progreso como último recurso
		
		# Intentar restaurar compras
		if has_node("/root/IAP"):
			var iap = get_node("/root/IAP")
			if iap.has_method("restore_purchases"):
				iap.restore_purchases()
		
		# Guardar los cambios
		if global.has_method("save_settings"):
			global.save_settings()
		
		# Forzar la recarga completa del juego si es posible
		if has_node("/root/SceneManager"):
			var scene_manager = get_node("/root/SceneManager")
			if scene_manager.has_method("change_scene"):
				OS.alert("La restauración se ha completado. El juego se reiniciará para aplicar los cambios.", "Restauración completada")
				scene_manager.change_scene("res://Scenes/MainMenu.tscn")
				return
		
		# Aplicar los cambios en el gestor de packs
		if has_node("/root/PacksManager"):
			var packs_manager = get_node("/root/PacksManager")
			if packs_manager.has_method("reload_packs"):
				packs_manager.reload_packs()
			elif packs_manager.has_method("load_packs"):
				packs_manager.load_packs()
			
			# Intentar forzar la actualización de UI si existe un método para ello
			if packs_manager.has_method("update_ui"):
				packs_manager.update_ui()
		
		# Mostrar mensaje final
		OS.alert("Se han desbloqueado y habilitado para jugar los dos primeros packs (Fruits y Numbers). Por favor, reinicia completamente el juego para asegurar que los cambios se apliquen correctamente.", "Restauración completada")
	else:
		print("ERROR: No se encontró el nodo GLOBAL")
		OS.alert("No se pudo restaurar el acceso a los puzzles.", "Error")
