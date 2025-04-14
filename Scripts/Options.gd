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
var buttonClose: Button
var buttonRestore: Button
var sliderVolumeGeneral = HSlider
var sliderVolumeSFX = HSlider
var sliderVolumeMusic = HSlider
# Nuevos sliders para opciones de sensibilidad
var sliderPanSensitivity = HSlider
var sliderTweenDuration = HSlider
var checkTweenEffect = CheckBox
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
	labelGeneral = $%Label_general
	labelMusic = $%LabelMusic
	labelSFX = $%LabelSFX
	labelLanguage = $%LabelIdioma
	labelResolution = $%Label_resolution
	# Inicializar nuevas etiquetas
	labelPanSensitivity = $%LabelPanSensitivity
	labelTweenEffect = $%LabelTweenEffect
	labelTweenDuration = $%LabelTweenDuration
	
	buttonClose = %ButtonClose
	buttonRestore = %RestoreButton
	sliderVolumeGeneral = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/HSlider_Volumen_General
	sliderVolumeMusic = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/HSlider_Volumen_Musica
	sliderVolumeSFX = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/HSlider_Volumen_VFX
	# Inicializar nuevos controles
	sliderPanSensitivity = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/HSlider_Pan_Sensitivity
	checkTweenEffect = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/CheckBox_Tween_Effect
	sliderTweenDuration = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/HSlider_Tween_Duration
	
	selectLanguage = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/LangSelector
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
	
	# Cargar valores actuales
	load_current_values()
	
	# Adaptar la UI para dispositivos móviles
	# adapt_ui_for_device()
	
	# Actualizar textos de la UI
	update_ui_texts()

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
	
	buttonClose.text = tr("common_back")
	buttonRestore.text = tr("options_restore_purchases")
	
	print("Options: Textos actualizados con idioma: ", TranslationServer.get_locale())

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
