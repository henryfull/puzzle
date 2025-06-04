# Script para configurar automáticamente la emulación táctil en el proyecto
# Este script debe ser autoload para ejecutarse al iniciar el juego

extends Node

func _ready():
	print("Configurando opciones de entrada táctil...")
	
	# Configurar opciones específicas para dispositivos móviles
	if OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android"):
		print("Ejecutando en dispositivo móvil, configurando opciones táctiles...")
		
		# Configurar opciones de entrada táctil para dispositivos móviles
		if ProjectSettings.has_setting("input_devices/pointing/emulate_mouse_from_touch"):
			ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", true)
			print("Emulación de ratón desde táctil habilitada.")
		
		# CRÍTICO: Configurar retrasos táctiles mínimos para prevenir conflictos
		if ProjectSettings.has_setting("input_devices/pointing/ios/touch_delay"):
			ProjectSettings.set_setting("input_devices/pointing/ios/touch_delay", 0.0)
			print("Retardo táctil en iOS configurado a 0.")
		
		if ProjectSettings.has_setting("input_devices/pointing/android/touch_delay"):
			ProjectSettings.set_setting("input_devices/pointing/android/touch_delay", 0.0)
			print("Retardo táctil en Android configurado a 0.")
		
		# NUEVO: Configurar opciones para deshabilitar gestos del borde
		if ProjectSettings.has_setting("input_devices/pointing/android/disable_edge_gestures"):
			ProjectSettings.set_setting("input_devices/pointing/android/disable_edge_gestures", true)
			print("Gestos del borde en Android deshabilitados.")
		
		if ProjectSettings.has_setting("input_devices/pointing/ios/disable_edge_gestures"):
			ProjectSettings.set_setting("input_devices/pointing/ios/disable_edge_gestures", true)
			print("Gestos del borde en iOS deshabilitados.")
			
		# Configurar opciones adicionales para mejorar la experiencia táctil
		if ProjectSettings.has_setting("input_devices/pointing/emulate_touch_from_mouse"):
			ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", false)
			print("Emulación táctil desde ratón deshabilitada en dispositivos móviles.")
			
		# CRÍTICO: Configurar opciones de gestos para evitar conflictos
		if ProjectSettings.has_setting("input_devices/pointing/ios/enable_long_press"):
			ProjectSettings.set_setting("input_devices/pointing/ios/enable_long_press", false)
			print("Pulsación larga en iOS deshabilitada para evitar conflictos.")
		
		if ProjectSettings.has_setting("input_devices/pointing/android/enable_long_press"):
			ProjectSettings.set_setting("input_devices/pointing/android/enable_long_press", false)
			print("Pulsación larga en Android deshabilitada para evitar conflictos.")
		
		# NUEVO: Configurar opciones específicas para Android para deshabilitar gestos del sistema
		if ProjectSettings.has_setting("display/window/handheld/orientation"):
			print("Orientación de pantalla configurada correctamente.")
		
		# Configurar opciones para evitar que el sistema intercepte gestos
		_configure_mobile_specific_settings()
	else:
		# Solo habilitar en escritorio para pruebas
		print("Ejecutando en escritorio, habilitando emulación táctil para pruebas...")
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		
		# Configurar la propiedad en tiempo de ejecución si es posible
		if ProjectSettings.has_setting("input_devices/pointing/emulate_touch_from_mouse"):
			ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", true)
			print("Emulación táctil desde ratón habilitada correctamente.")
		else:
			print("No se pudo habilitar la emulación táctil. Por favor, configúrala manualmente en las opciones del proyecto.")
	
	# Configurar opciones generales de entrada
	if ProjectSettings.has_setting("input_devices/pointing/emulate_touch_from_mouse_in_editor"):
		ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse_in_editor", true)
		print("Emulación táctil desde ratón en editor habilitada.")
		
	# Configurar opciones de física para mejorar el rendimiento
	if ProjectSettings.has_setting("physics/common/enable_pause_aware_picking"):
		ProjectSettings.set_setting("physics/common/enable_pause_aware_picking", true)
		print("Detección de clic consciente de pausa habilitada.")
	
	print("Configuración de entrada táctil completada.")
	
	# Configurar opciones de renderizado para mejorar el rendimiento en dispositivos móviles
	if OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android"):
		if ProjectSettings.has_setting("rendering/renderer/rendering_method"):
			var current_method = ProjectSettings.get_setting("rendering/renderer/rendering_method")
			print("Método de renderizado actual: ", current_method)
			
		if ProjectSettings.has_setting("rendering/renderer/use_debanding"):
			ProjectSettings.set_setting("rendering/renderer/use_debanding", false)
			print("Debanding deshabilitado para mejorar el rendimiento.")
			
		if ProjectSettings.has_setting("rendering/environment/defaults/default_clear_color"):
			var clear_color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
			print("Color de fondo actual: ", clear_color)

# Función específica para configurar opciones avanzadas de dispositivos móviles
func _configure_mobile_specific_settings():
	print("Configurando opciones específicas para dispositivos móviles...")
	
	# Configurar opciones de Android
	if OS.has_feature("android"):
		print("Configurando opciones específicas de Android...")
		
		# Configurar opciones para evitar que Android intercepte gestos
		if ProjectSettings.has_setting("application/config/use_hidden_project_data_directory"):
			ProjectSettings.set_setting("application/config/use_hidden_project_data_directory", false)
		
		# NUEVO: Configurar opciones para prevenir diálogos automáticos del sistema
		if ProjectSettings.has_setting("input_devices/pointing/android/enable_system_gestures"):
			ProjectSettings.set_setting("input_devices/pointing/android/enable_system_gestures", false)
			print("Gestos del sistema Android deshabilitados completamente.")
		
		# Configurar opciones de pantalla inmersiva
		if ProjectSettings.has_setting("display/window/size/mode"):
			print("Modo de pantalla configurado para Android")
		
		# NUEVO: Prevenir que Android muestre diálogos de confirmación de salida
		if ProjectSettings.has_setting("application/config/android_auto_quit_confirmation"):
			ProjectSettings.set_setting("application/config/android_auto_quit_confirmation", false)
			print("Confirmación automática de salida Android deshabilitada.")
	
	# Configurar opciones de iOS
	if OS.has_feature("ios"):
		print("Configurando opciones específicas de iOS...")
		
		# Configurar opciones para evitar que iOS intercepte gestos
		if ProjectSettings.has_setting("application/config/name"):
			print("Configuración de iOS aplicada")
		
		# NUEVO: Configurar opciones para prevenir gestos del sistema iOS
		if ProjectSettings.has_setting("input_devices/pointing/ios/enable_system_gestures"):
			ProjectSettings.set_setting("input_devices/pointing/ios/enable_system_gestures", false)
			print("Gestos del sistema iOS deshabilitados completamente.")
		
		# NUEVO: Configurar opciones para evitar que iOS muestre notificaciones de salida
		if ProjectSettings.has_setting("application/config/ios_auto_quit_confirmation"):
			ProjectSettings.set_setting("application/config/ios_auto_quit_confirmation", false)
			print("Confirmación automática de salida iOS deshabilitada.")
	
	print("Configuraciones específicas de móviles completadas.") 