extends Node2D

# Variable para detectar si estamos en un dispositivo móvil
var is_mobile = false

func _ready():
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Cargar valores actuales
	load_current_values()
	
	# Adaptar la UI para dispositivos móviles
	adapt_ui_for_device()

# Función para actualizar los textos de la UI según el idioma actual
func update_ui_texts():
	$"CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerResolución/Label_resolution".text = tr("common_resolution")
	$"CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer4/Label_general".text = tr("common_general")
	$"CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer2/label music".text = tr("common_music")
	$"CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer3/label sfx".text = tr("common_sfx")
	$"CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerIdioma/Label idioma".text = tr("common_language")
	
	print("Options: Textos actualizados con idioma: ", TranslationServer.get_locale())

# Función para cargar los valores actuales
func load_current_values():
	# Cargar volúmenes desde GLOBAL
	if has_node("/root/GLOBAL"):
		var global = get_node("/root/GLOBAL")
		
		# Volumen general
		var slider_general = $CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer4/HSlider_Volumen_General
		if slider_general:
			slider_general.value = global.settings.volume.general
		
		# Volumen música
		var slider_music = $CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer2/HSlider_Volumen_Musica
		if slider_music:
			slider_music.value = global.settings.volume.music
		
		# Volumen efectos
		var slider_sfx = $CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer3/HSlider_Volumen_VFX
		if slider_sfx:
			slider_sfx.value = global.settings.volume.sfx
		
		# Idioma
		var lang_selector = $CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerIdioma/LangSelector
		if lang_selector:
			# Seleccionar el idioma actual
			for i in range(lang_selector.get_item_count()):
				if lang_selector.get_item_text(i) == global.settings.language:
					lang_selector.select(i)
					break

# Función para adaptar la UI según el dispositivo
func adapt_ui_for_device():
	# Usar UIScaler si está disponible
	if ResourceLoader.exists("res://Scripts/UIScaler.gd"):
		var UIScaler = load("res://Scripts/UIScaler.gd")
		
		# Escalar botones
		var button = $CanvasLayer/BoxContainer/VBoxContainer3/Button
		if button:
			UIScaler.scale_button(button)
		
		# Escalar etiquetas
		var labels = [
			$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerResolución/Label_resolution,
			$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerIdioma/"Label idioma",
			$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer4/Label_general,
			$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer2/"label music",
			$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer3/"label sfx"
		]
		
		for label in labels:
			if label:
				UIScaler.scale_label(label)
		
		# Escalar controles de opciones
		var option_controls = [
			$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerResolución/ResolutionButton,
			$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerIdioma/LangSelector,
			$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer4/HSlider_Volumen_General,
			$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer2/HSlider_Volumen_Musica,
			$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer3/HSlider_Volumen_VFX
		]
		
		for control in option_controls:
			if control:
				if control is OptionButton:
					UIScaler.scale_button(control)
				elif control is HSlider:
					var scale = UIScaler.get_scale_factor()
					control.custom_minimum_size = Vector2(100 * scale, 0)
	else:
		# Si no está disponible UIScaler, usar ajustes manuales
		if is_mobile:
			# Ajustar botón de volver
			var back_button = $CanvasLayer/BoxContainer/VBoxContainer3/Button
			if back_button:
				back_button.custom_minimum_size = Vector2(200, 70)
				back_button.add_theme_font_size_override("font_size", 24)
			
			# Ajustar etiquetas
			var labels = [
				$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerResolución/Label_resolution,
				$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerIdioma/"Label idioma",
				$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer4/Label_general,
				$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer2/"label music",
				$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer3/"label sfx"
			]
			
			for label in labels:
				if label:
					label.add_theme_font_size_override("font_size", 20)
			
			# Ajustar controles de opciones
			var option_buttons = [
				$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerResolución/ResolutionButton,
				$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainerIdioma/LangSelector
			]
			
			for option_button in option_buttons:
				if option_button:
					option_button.custom_minimum_size = Vector2(150, 50)
					option_button.add_theme_font_size_override("font_size", 20)
			
			# Ajustar sliders
			var sliders = [
				$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer4/HSlider_Volumen_General,
				$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer2/HSlider_Volumen_Musica,
				$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer/BoxContainer3/HSlider_Volumen_VFX
			]
			
			for slider in sliders:
				if slider:
					slider.custom_minimum_size = Vector2(200, 30)
			
			# Ajustar espaciado
			$CanvasLayer/BoxContainer/VBoxContainer3.add_theme_constant_override("separation", 20)
			$CanvasLayer/BoxContainer/VBoxContainer3/HBoxContainer/VBoxContainer.add_theme_constant_override("separation", 15)

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

func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
