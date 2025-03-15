@tool
extends EditorScript

func _run():
	# Verificar si el proyecto está abierto en el editor
	if not Engine.is_editor_hint():
		return
	
	# Obtener el ProjectSettings
	var project_settings = ProjectSettings
	
	# Verificar si OptionsManager ya está registrado como autoload
	if not project_settings.has_setting("autoload/OptionsManager"):
		# Registrar OptionsManager como autoload
		project_settings.set_setting("autoload/OptionsManager", "*res://Scripts/Autoload/OptionsManager.gd")
		
		# Guardar los cambios
		project_settings.save()
		
		print("OptionsManager ha sido registrado como autoload.")
	else:
		print("OptionsManager ya está registrado como autoload.") 