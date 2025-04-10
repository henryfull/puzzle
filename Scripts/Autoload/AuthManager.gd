extends Node

signal login_success(provider, user_info)
signal login_failed(provider, error_message)
signal logout_completed()
signal account_linked(provider)

# Constante para el archivo de datos de usuario
const USER_DATA_FILE = "user://user_data.json"

# Datos del usuario
var user_data = {
	"logged_in": false,
	"provider": "",  # "google", "apple", etc.
	"user_id": "",
	"display_name": "",
	"email": "",
	"avatar_url": "",
	"last_sync": 0  # Timestamp del último sincronizado
}

# Estados
var is_logging_in = false
var is_linking_account = false
var is_syncing = false

# Variables para detectar la plataforma
var is_android = false
var is_ios = false

func _ready():
	# Detectar plataforma
	is_android = OS.has_feature("android")
	is_ios = OS.has_feature("ios")
	
	print("AuthManager: Sistema de autenticación inicializado")
	print("AuthManager: Plataforma - Android: ", is_android, ", iOS: ", is_ios)
	
	# Cargar datos del usuario
	load_user_data()

# Cargar datos del usuario del almacenamiento local
func load_user_data():
	var file = FileAccess.open(USER_DATA_FILE, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		var json_result = JSON.parse_string(json_text)
		if json_result:
			user_data = json_result
			print("AuthManager: Datos de usuario cargados correctamente")
		else:
			print("AuthManager: Error al analizar el JSON de datos de usuario")
	else:
		print("AuthManager: No se encontró archivo de datos de usuario, usando valores por defecto")

# Guardar datos del usuario en el almacenamiento local
func save_user_data():
	var file = FileAccess.open(USER_DATA_FILE, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(user_data, "\t")
		file.store_string(json_text)
		file.close()
		print("AuthManager: Datos de usuario guardados correctamente")
	else:
		print("AuthManager: Error al guardar los datos de usuario")

# Iniciar sesión con Google
func login_with_google():
	if is_logging_in:
		print("AuthManager: Ya hay un proceso de inicio de sesión en marcha")
		return
	
	is_logging_in = true
	print("AuthManager: Iniciando sesión con Google...")
	
	if is_android and Engine.has_singleton("GooglePlay"):
		var google_play = Engine.get_singleton("GooglePlay")
		google_play.connect("google_sign_in_success", Callable(self, "_on_google_sign_in_success"))
		google_play.connect("google_sign_in_failed", Callable(self, "_on_google_sign_in_failed"))
		google_play.sign_in()
	elif is_ios and Engine.has_singleton("GoogleSignIn"):
		var google_sign_in = Engine.get_singleton("GoogleSignIn")
		google_sign_in.connect("google_sign_in_success", Callable(self, "_on_google_sign_in_success"))
		google_sign_in.connect("google_sign_in_failed", Callable(self, "_on_google_sign_in_failed"))
		google_sign_in.sign_in()
	else:
		is_logging_in = false
		emit_signal("login_failed", "google", "Plataforma no soportada o singleton no disponible")

# Iniciar sesión con Apple
func login_with_apple():
	if is_logging_in:
		print("AuthManager: Ya hay un proceso de inicio de sesión en marcha")
		return
	
	is_logging_in = true
	print("AuthManager: Iniciando sesión con Apple...")
	
	if is_ios and Engine.has_singleton("AppleSignIn"):
		var apple_sign_in = Engine.get_singleton("AppleSignIn")
		apple_sign_in.connect("apple_sign_in_success", Callable(self, "_on_apple_sign_in_success"))
		apple_sign_in.connect("apple_sign_in_failed", Callable(self, "_on_apple_sign_in_failed"))
		apple_sign_in.sign_in()
	else:
		is_logging_in = false
		emit_signal("login_failed", "apple", "Plataforma no soportada o singleton no disponible")

# Cerrar sesión
func logout():
	print("AuthManager: Cerrando sesión...")
	
	if user_data.logged_in:
		if user_data.provider == "google":
			_logout_google()
		elif user_data.provider == "apple":
			_logout_apple()
		
		# Reiniciar datos de usuario
		user_data = {
			"logged_in": false,
			"provider": "",
			"user_id": "",
			"display_name": "",
			"email": "",
			"avatar_url": "",
			"last_sync": 0
		}
		
		save_user_data()
		emit_signal("logout_completed")
	else:
		print("AuthManager: No hay una sesión activa para cerrar")

# Función interna para cerrar sesión en Google
func _logout_google():
	if is_android and Engine.has_singleton("GooglePlay"):
		var google_play = Engine.get_singleton("GooglePlay")
		google_play.sign_out()
	elif is_ios and Engine.has_singleton("GoogleSignIn"):
		var google_sign_in = Engine.get_singleton("GoogleSignIn")
		google_sign_in.sign_out()

# Función interna para cerrar sesión en Apple
func _logout_apple():
	# Apple no proporciona un método de cierre de sesión a nivel de API
	# Simplemente limpiamos los datos locales
	pass

# Sincronizar datos con la nube
func sync_data():
	if is_syncing:
		print("AuthManager: Ya hay un proceso de sincronización en marcha")
		return
	
	if not user_data.logged_in:
		print("AuthManager: No se puede sincronizar, el usuario no ha iniciado sesión")
		return
	
	is_syncing = true
	print("AuthManager: Sincronizando datos con la nube...")
	
	# Aquí iría el código para sincronizar con tu backend
	# Por ejemplo, usando HTTPRequest para comunicarte con tu servidor
	
	# Simulamos un proceso exitoso
	await get_tree().create_timer(1.0).timeout
	
	user_data.last_sync = Time.get_unix_time_from_system()
	save_user_data()
	
	is_syncing = false
	print("AuthManager: Sincronización completada")

# Callback para inicio de sesión exitoso con Google
func _on_google_sign_in_success(auth_code, display_name, email, id_token, photo_url):
	is_logging_in = false
	
	user_data = {
		"logged_in": true,
		"provider": "google",
		"user_id": id_token,  # En un entorno real, deberías validar este token en tu servidor
		"display_name": display_name,
		"email": email,
		"avatar_url": photo_url,
		"last_sync": Time.get_unix_time_from_system()
	}
	
	save_user_data()
	
	emit_signal("login_success", "google", user_data)
	print("AuthManager: Inicio de sesión con Google exitoso para: ", display_name)

# Callback para inicio de sesión fallido con Google
func _on_google_sign_in_failed(error_code, error_message):
	is_logging_in = false
	emit_signal("login_failed", "google", error_message)
	print("AuthManager: Error al iniciar sesión con Google: ", error_message)

# Callback para inicio de sesión exitoso con Apple
func _on_apple_sign_in_success(auth_code, display_name, email, id_token):
	is_logging_in = false
	
	user_data = {
		"logged_in": true,
		"provider": "apple",
		"user_id": id_token,  # En un entorno real, deberías validar este token en tu servidor
		"display_name": display_name,
		"email": email,
		"avatar_url": "",  # Apple no proporciona URL de avatar
		"last_sync": Time.get_unix_time_from_system()
	}
	
	save_user_data()
	
	emit_signal("login_success", "apple", user_data)
	print("AuthManager: Inicio de sesión con Apple exitoso para: ", display_name)

# Callback para inicio de sesión fallido con Apple
func _on_apple_sign_in_failed(error_code, error_message):
	is_logging_in = false
	emit_signal("login_failed", "apple", error_message)
	print("AuthManager: Error al iniciar sesión con Apple: ", error_message)

# Verificar si el usuario está conectado
func is_logged_in():
	return user_data.logged_in

# Obtener información del usuario
func get_user_info():
	return user_data if user_data.logged_in else null

# Obtener el nombre de usuario
func get_display_name():
	return user_data.display_name if user_data.logged_in else ""

# Obtener el email del usuario
func get_email():
	return user_data.email if user_data.logged_in else ""

# Obtener la URL del avatar
func get_avatar_url():
	return user_data.avatar_url if user_data.logged_in else ""

# Obtener el proveedor de autenticación
func get_provider():
	return user_data.provider if user_data.logged_in else "" 