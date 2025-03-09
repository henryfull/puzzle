# Script para habilitar la emulación táctil desde el ratón
# Este script debe ejecutarse una vez para configurar el proyecto

@tool
extends EditorScript

func _run():
	print("Habilitando emulación táctil desde el ratón...")
	
	# Obtener la configuración del proyecto
	var config = ConfigFile.new()
	var err = config.load("res://project.godot")
	
	if err != OK:
		print("Error al cargar la configuración del proyecto: ", err)
		return
	
	# Verificar si la sección de entrada existe
	if not config.has_section("input_devices"):
		config.set_value("input_devices", "pointing/emulate_touch_from_mouse", true)
	else:
		# Actualizar la configuración
		config.set_value("input_devices", "pointing/emulate_touch_from_mouse", true)
	
	# Guardar la configuración
	err = config.save("res://project.godot")
	
	if err != OK:
		print("Error al guardar la configuración del proyecto: ", err)
		return
	
	print("Emulación táctil habilitada correctamente.")
	print("Por favor, reinicia el editor para aplicar los cambios.") 