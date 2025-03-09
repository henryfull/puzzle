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
		
		# Configurar opciones de gestos táctiles
		if ProjectSettings.has_setting("input_devices/pointing/ios/touch_delay"):
			ProjectSettings.set_setting("input_devices/pointing/ios/touch_delay", 0.0)
			print("Retardo táctil en iOS configurado a 0.")
		
		if ProjectSettings.has_setting("input_devices/pointing/android/touch_delay"):
			ProjectSettings.set_setting("input_devices/pointing/android/touch_delay", 0.0)
			print("Retardo táctil en Android configurado a 0.")
			
		# Configurar opciones adicionales para mejorar la experiencia táctil
		if ProjectSettings.has_setting("input_devices/pointing/emulate_touch_from_mouse"):
			ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", false)
			print("Emulación táctil desde ratón deshabilitada en dispositivos móviles.")
			
		# Configurar opciones de gestos
		if ProjectSettings.has_setting("input_devices/pointing/ios/enable_long_press"):
			ProjectSettings.set_setting("input_devices/pointing/ios/enable_long_press", false)
			print("Pulsación larga en iOS deshabilitada para evitar conflictos.")
			
		if ProjectSettings.has_setting("input_devices/pointing/android/enable_long_press"):
			ProjectSettings.set_setting("input_devices/pointing/android/enable_long_press", false)
			print("Pulsación larga en Android deshabilitada para evitar conflictos.")
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