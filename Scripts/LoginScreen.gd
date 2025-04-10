extends Node2D

# Referencias a nodos UI
var main_container: VBoxContainer
var buttons_container: VBoxContainer
var user_info_container: VBoxContainer
var loading_container: VBoxContainer
var error_container: PanelContainer

var google_login_button: Button
var apple_login_button: Button
var continue_offline_button: Button

var profile_picture: TextureRect
var user_name_label: Label
var user_email_label: Label
var logout_button: Button
var sync_button: Button
var continue_button: Button

var loading_label: Label
var progress_bar: ProgressBar
var cancel_button: Button

var error_title: Label
var error_message: Label
var close_error_button: Button

# Variables de estado
var is_loading: bool = false
var current_operation: String = ""
var profile_image: ImageTexture

# Señal para notificar cuando el usuario ha iniciado sesión
signal login_completed()

func _ready():
	# Obtener referencias a los nodos
	main_container = $CanvasLayer/MainContainer
	buttons_container = $CanvasLayer/MainContainer/ButtonsContainer
	user_info_container = $CanvasLayer/MainContainer/UserInfoContainer
	loading_container = $CanvasLayer/LoadingContainer
	error_container = $CanvasLayer/ErrorContainer
	
	google_login_button = $CanvasLayer/MainContainer/ButtonsContainer/GoogleLoginButton
	apple_login_button = $CanvasLayer/MainContainer/ButtonsContainer/AppleLoginButton
	continue_offline_button = $CanvasLayer/MainContainer/ButtonsContainer/ContinueOfflineButton
	
	profile_picture = $CanvasLayer/MainContainer/UserInfoContainer/ProfilePicture
	user_name_label = $CanvasLayer/MainContainer/UserInfoContainer/UserName
	user_email_label = $CanvasLayer/MainContainer/UserInfoContainer/UserEmail
	logout_button = $CanvasLayer/MainContainer/UserInfoContainer/LogoutButton
	sync_button = $CanvasLayer/MainContainer/UserInfoContainer/SyncButton
	continue_button = $CanvasLayer/MainContainer/UserInfoContainer/ContinueButton
	
	loading_label = $CanvasLayer/LoadingContainer/LoadingLabel
	progress_bar = $CanvasLayer/LoadingContainer/ProgressBar
	cancel_button = $CanvasLayer/LoadingContainer/CancelButton
	
	error_title = $CanvasLayer/ErrorContainer/VBoxContainer/ErrorTitle
	error_message = $CanvasLayer/ErrorContainer/VBoxContainer/ErrorMessage
	close_error_button = $CanvasLayer/ErrorContainer/VBoxContainer/CloseErrorButton
	
	# Configurar la interfaz según el estado de inicio de sesión
	if AuthManager.is_logged_in():
		# El usuario ya tiene sesión iniciada
		_update_user_info()
		show_user_info()
	else:
		# El usuario no ha iniciado sesión
		show_login_buttons()
	
	# Conectar señales del AuthManager
	AuthManager.connect("login_success", Callable(self, "_on_auth_login_success"))
	AuthManager.connect("login_failed", Callable(self, "_on_auth_login_failed"))
	AuthManager.connect("logout_completed", Callable(self, "_on_auth_logout_completed"))
	
	# Conectar señales del CloudSyncManager
	CloudSyncManager.connect("sync_success", Callable(self, "_on_sync_success"))
	CloudSyncManager.connect("sync_failed", Callable(self, "_on_sync_failed"))

# Mostrar botones de inicio de sesión
func show_login_buttons():
	buttons_container.visible = true
	user_info_container.visible = false
	main_container.visible = true
	loading_container.visible = false
	error_container.visible = false

# Mostrar información del usuario
func show_user_info():
	buttons_container.visible = false
	user_info_container.visible = true
	main_container.visible = true
	loading_container.visible = false
	error_container.visible = false

# Mostrar pantalla de carga
func show_loading(message: String = "Conectando..."):
	loading_label.text = message
	progress_bar.value = 0.0
	main_container.visible = false
	loading_container.visible = true
	error_container.visible = false
	
	# Animar la barra de progreso
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", 0.9, 2.0)
	is_loading = true

# Ocultar pantalla de carga
func hide_loading():
	loading_container.visible = false
	is_loading = false

# Mostrar mensaje de error
func show_error(title: String, message: String):
	error_title.text = title
	error_message.text = message
	error_container.visible = true
	
	# Ocultar otras pantallas
	main_container.visible = false
	loading_container.visible = false

# Actualizar la información del usuario en la interfaz
func _update_user_info():
	var user_info = AuthManager.get_user_info()
	
	if user_info:
		user_name_label.text = user_info.display_name
		user_email_label.text = user_info.email
		
		# Cargar la imagen de perfil si hay una URL
		if not user_info.avatar_url.is_empty():
			_load_profile_image(user_info.avatar_url)
		else:
			profile_picture.texture = null  # Sin imagen de perfil

# Cargar imagen de perfil desde URL
func _load_profile_image(url: String):
	if url.is_empty():
		return
		
	# En un entorno real, aquí cargarías la imagen desde la URL
	# Esto requeriría utilizar HTTPRequest para descargar la imagen
	
	# Como ejemplo simulado:
	profile_picture.texture = null
	print("LoginScreen: Cargando imagen de perfil desde URL: ", url)

# Manejadores de señales de botones
func _on_google_login_button_pressed():
	show_loading("Iniciando sesión con Google...")
	current_operation = "login_google"
	AuthManager.login_with_google()

func _on_apple_login_button_pressed():
	show_loading("Iniciando sesión con Apple...")
	current_operation = "login_apple"
	AuthManager.login_with_apple()

func _on_continue_offline_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_logout_button_pressed():
	show_loading("Cerrando sesión...")
	current_operation = "logout"
	AuthManager.logout()

func _on_sync_button_pressed():
	if AuthManager.is_logged_in():
		show_loading("Sincronizando datos...")
		current_operation = "sync"
		CloudSyncManager.sync_all_data()
	else:
		show_error("Error de Sincronización", "Debes iniciar sesión para sincronizar tus datos.")

func _on_continue_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_cancel_button_pressed():
	hide_loading()
	
	if current_operation == "login_google" or current_operation == "login_apple":
		show_login_buttons()
	elif current_operation == "logout" or current_operation == "sync":
		show_user_info()

func _on_close_error_button_pressed():
	error_container.visible = false
	
	if AuthManager.is_logged_in():
		show_user_info()
	else:
		show_login_buttons()

# Manejadores de señales del AuthManager
func _on_auth_login_success(provider, user_info):
	print("LoginScreen: Inicio de sesión exitoso con ", provider)
	hide_loading()
	_update_user_info()
	show_user_info()
	
	# Si es la primera vez que inicia sesión, sincronizar datos
	CloudSyncManager.sync_all_data()
	
	# Emitir señal de que el inicio de sesión se completó
	emit_signal("login_completed")

func _on_auth_login_failed(provider, error_message):
	print("LoginScreen: Error de inicio de sesión con ", provider, ": ", error_message)
	hide_loading()
	show_error("Error de Inicio de Sesión", "No se pudo iniciar sesión con " + provider + ": " + error_message)

func _on_auth_logout_completed():
	print("LoginScreen: Cierre de sesión completado")
	hide_loading()
	show_login_buttons()

# Manejadores de señales del CloudSyncManager
func _on_sync_success():
	print("LoginScreen: Sincronización exitosa")
	hide_loading()
	if is_instance_valid(self) and not is_queued_for_deletion():  # Verificar que la escena sigue activa
		show_user_info()

func _on_sync_failed(error_message):
	print("LoginScreen: Error de sincronización: ", error_message)
	hide_loading()
	if is_instance_valid(self) and not is_queued_for_deletion():  # Verificar que la escena sigue activa
		show_error("Error de Sincronización", "No se pudieron sincronizar los datos: " + error_message) 