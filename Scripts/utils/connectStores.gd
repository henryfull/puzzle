extends Node

# Variables para la detección de plataforma
var is_ios = false
var is_android = false

# Variable para controlar que solo se muestre una vez
var connection_initialized = false

# Señales para notificar el estado de conexión
signal connected_to_service(service_name)
signal connection_failed(service_name, error_message)

# Referencia a la notificación visual
var notification_scene = preload("res://Scenes/Components/ConnectionNotification/ConnectionNotification.tscn")
var current_notification = null

func _ready():
	# Ya no inicializamos conexión aquí, ahora el menú principal
	# llamará a initialize_connection cuando sea apropiado
	print("ConnectStores: Gestor de conexiones inicializado y listo para usar")
	
	# Detectar plataforma automáticamente
	detect_platform()
	
	# Añadir un breve retraso para dar tiempo a que los singletons se registren
	get_tree().create_timer(0.5).timeout.connect(func():
		var is_game_center_available = Engine.has_singleton("GameCenter")
		var is_google_play_available = Engine.has_singleton("GooglePlay") or Engine.has_singleton("GodotPlayGames")
		print("ConnectStores: Después de espera, Game Center disponible: " + str(is_game_center_available))
		print("ConnectStores: Después de espera, Google Play disponible: " + str(is_google_play_available))
	)

# Función para inicializar la conexión a los servicios
func initialize_connection():
	# Solo inicializamos si no se ha hecho antes
	if connection_initialized:
		print("ConnectStores: La conexión ya se ha inicializado antes")
		return
	
	# Asegurarnos de que la plataforma se ha detectado correctamente
	detect_platform()
	
	print("ConnectStores: Iniciando conexión. iOS=" + str(is_ios) + ", Android=" + str(is_android))
	
	if is_ios:
		init_game_center()
	elif is_android:
		init_google_play()
	else:
		# En plataformas de escritorio o web, simular una conexión exitosa
		print("ConnectStores: Plataforma de escritorio detectada, simulando conexión")
		# Retrasar un poco para simular el tiempo de conexión
		await get_tree().create_timer(1.0).timeout
		show_connection_notification("Servicios de juego", true)

	load_achievements_data()
	initialize_notification_system()
	connection_initialized = true
	print("ConnectStores: Sistema de logros inicializado")

# Detecta la plataforma en la que se está ejecutando el juego
func detect_platform():
	var platform = OS.get_name().to_lower()
	print("ConnectStores: Plataforma detectada: " + platform)
	
	# Verificar iOS con múltiples enfoques
	is_ios = platform == "ios" or OS.has_feature("iOS") or OS.has_feature("ios")
	is_android = platform == "android" or OS.has_feature("android")
	
	print("ConnectStores: is_ios=" + str(is_ios) + ", is_android=" + str(is_android))

# Función para verificar si hay servicios disponibles según la plataforma
func are_services_available():
	if is_ios:
		return Engine.has_singleton("GameCenter")
	elif is_android:
		return Engine.has_singleton("GooglePlay") or Engine.has_singleton("GodotPlayGames")
	return false

# Función para verificar el estado de autenticación actual
func is_authenticated():
	if is_ios and Engine.has_singleton("GameCenter"):
		var game_center = Engine.get_singleton("GameCenter")
		return game_center.isAuthenticated()
	elif is_android:
		# Intentar primero con GooglePlay
		if Engine.has_singleton("GooglePlay"):
			var play_services = Engine.get_singleton("GooglePlay")
			return play_services.isSignedIn()
		# Luego con GodotPlayGames si está disponible
		elif Engine.has_singleton("GodotPlayGames"):
			var play_games = Engine.get_singleton("GodotPlayGames")
			return play_games.isSignedIn()
	return false

# Función para obtener el nombre del servicio actual
func get_service_name():
	if is_ios and Engine.has_singleton("GameCenter"):
		return "Apple Game Center"
	elif is_android:
		if Engine.has_singleton("GooglePlay") or Engine.has_singleton("GodotPlayGames"):
			return "Google Play Games"
	return ""

# Inicializa los servicios de Game Center en iOS
func init_game_center():
	print("ConnectStores: Verificando disponibilidad de Game Center...")
	
	var has_game_center = Engine.has_singleton("GameCenter")
	print("ConnectStores: Engine.has_singleton('GameCenter') = " + str(has_game_center))
	
	# Si no tenemos el plugin, crear una implementación dummy para pruebas
	if not has_game_center:
		print("ConnectStores: Creando implementación dummy de Game Center para pruebas")
		
		# Esperar un momento y simular autenticación exitosa
		await get_tree().create_timer(1.5).timeout
		connected_to_service.emit("Game Center (Simulado)")
		show_connection_notification("Game Center (Simulado)", true)
		return
	
	var game_center = Engine.get_singleton("GameCenter")
	
	# Listar métodos disponibles para diagnóstico
	print("ConnectStores: Métodos disponibles en Game Center:")
	var methods = []
	for method in game_center.get_method_list():
		methods.append(method.name)
	print(methods)
	
	# Verificar señales disponibles
	print("ConnectStores: authentication_changed signal exists: " + 
		  str(game_center.has_signal("authentication_changed")))
	
	# Conectar señales de Game Center
	if game_center.has_signal("authentication_changed"):
		game_center.authentication_changed.connect(_on_gamecenter_authentication_changed)
	game_center.authenticate()
	print("ConnectStores: Autenticando con Game Center")

# Callback para eventos de autenticación de Game Center
func _on_gamecenter_authentication_changed(authenticated):
	if authenticated:
		print("ConnectStores: Autenticado con Game Center exitosamente")
		connected_to_service.emit("Game Center")
		show_connection_notification("Game Center", true)
	else:
		print("ConnectStores: Error al autenticar con Game Center")
		connection_failed.emit("Game Center", "Error de autenticación")
		show_connection_notification("Game Center", false, "Error de autenticación")

# Inicializa los servicios de Google Play en Android
func init_google_play():
	print("ConnectStores: Verificando disponibilidad de servicios Google Play...")
	
	# Primero intentamos con la API de Google Play Games
	if Engine.has_singleton("GooglePlay"):
		var play_services = Engine.get_singleton("GooglePlay")
		# Usamos la sintaxis correcta para conectar señales en Godot 4
		if play_services.has_signal("signed_in"):
			play_services.signed_in.connect(_on_google_signed_in)
		if play_services.has_signal("sign_in_failed"):
			play_services.sign_in_failed.connect(_on_google_sign_in_failed)
		play_services.sign_in()
		print("ConnectStores: Iniciando sesión con Google Play")
	# Si no está disponible, intentamos con GodotPlayGames
	elif Engine.has_singleton("GodotPlayGames"):
		var play_games = Engine.get_singleton("GodotPlayGames")
		if play_games.has_method("signIn"):
			play_games.signIn()
			# Esperar un momento y verificar el estado
			await get_tree().create_timer(2.0).timeout
			if play_games.isSignedIn():
				_on_google_signed_in()
			else:
				_on_google_sign_in_failed(0)
		print("ConnectStores: Iniciando sesión con Google Play Games (plugin alternativo)")
	else:
		print("ConnectStores: Google Play no disponible, usando implementación dummy")
		# Implementación dummy para casos donde no está disponible
		await get_tree().create_timer(1.5).timeout
		connected_to_service.emit("Google Play Games (Simulado)")
		show_connection_notification("Google Play Games (Simulado)", true)

# Callback cuando el inicio de sesión en Google Play es exitoso
func _on_google_signed_in():
	print("ConnectStores: Sesión iniciada con Google Play")
	connected_to_service.emit("Google Play")
	show_connection_notification("Google Play", true)

# Callback cuando el inicio de sesión en Google Play falla
func _on_google_sign_in_failed(error_code = 0):
	print("ConnectStores: Error al iniciar sesión con Google Play. Código: " + str(error_code))
	connection_failed.emit("Google Play", "Error " + str(error_code))
	show_connection_notification("Google Play", false, "Error " + str(error_code))

# Carga los datos de logros del juego
func load_achievements_data():
	# Aquí debes implementar la carga de tus datos de logros específicos
	print("ConnectStores: Cargando datos de logros")

# Inicializa el sistema de notificaciones
func initialize_notification_system():
	# Aquí debes implementar la inicialización de tu sistema de notificaciones
	print("ConnectStores: Sistema de notificaciones inicializado")

# Muestra una notificación visual de la conexión
func show_connection_notification(service_name, success, error_message = ""):
	# Eliminar notificación anterior si existe
	if current_notification != null and is_instance_valid(current_notification):
		current_notification.queue_free()
	
	# Crear nueva notificación
	current_notification = notification_scene.instantiate()
	get_tree().root.add_child(current_notification)
	
	# Configurar la notificación
	if success:
		current_notification.show_success(service_name)
	else:
		current_notification.show_error(service_name, error_message)
