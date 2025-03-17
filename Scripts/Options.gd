extends Node2D

# Variable para detectar si estamos en un dispositivo móvil
var is_mobile = false
var labelGeneral: Label
var labelMusic: Label
var labelSFX: Label
var labelLanguage: Label
var labelResolution: Label
var buttonClose: Button
var sliderVolumeGeneral = HSlider
var sliderVolumeSFX = HSlider
var sliderVolumeMusic = HSlider
var selectLanguage = OptionButton
var selectResolution = OptionButton
var sliderOptionGeneral = null
var sliderOptionMusic = null
var sliderOptionSFX = null

func _ready():
	print("Options: Inicializando...")
	labelGeneral = $%Label_general
	labelMusic = $%LabelMusic
	labelSFX = $%LabelSFX
	labelLanguage = $%LabelIdioma
	labelResolution = $%Label_resolution
	buttonClose = %ButtonClose
	sliderVolumeGeneral = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/HSlider_Volumen_General
	sliderVolumeMusic = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/HSlider_Volumen_Musica
	sliderVolumeSFX = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/HSlider_Volumen_VFX
	selectLanguage = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/LangSelector
	selectResolution = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/GridContainer/ResolutionButton
	
	# Obtener referencia al componente SliderOption
	sliderOptionGeneral = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/Sliders/SliderOptionGeneral
	sliderOptionMusic = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/Sliders/SliderOptionMusic
	sliderOptionSFX = $CanvasLayer/PanelContainer/VBoxContainer/MarginContainer/Sliders/SliderOptionSFX
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
	adapt_ui_for_device()
	
	# Actualizar textos de la UI
	update_ui_texts()

	print("Options: Inicialización completada")

# Función para actualizar los textos de la UI según el idioma actual
func update_ui_texts():
	# Configurar SliderOption para volumen general
	if sliderOptionGeneral:
		print("Options: Configurando SliderOptionGeneral")
		var global_volume = 80
		if has_node("/root/GLOBAL"):
			global_volume = GLOBAL.settings.volume.general
		
		# Configurar el SliderOption con texto, icono, valor inicial y callback
		sliderOptionGeneral.configure(
			tr("common_general"),
			"icon_volume.svg",
			global_volume,
			self,
			"_on_HSlider_Volumen_General_value_changed"
		)
	else:
		print("Options: ERROR - No se encontró SliderOptionGeneral")
	
	# Configurar SliderOption para volumen de música
	if sliderOptionMusic:
		print("Options: Configurando SliderOptionMusic")
		var music_volume = 80
		if has_node("/root/GLOBAL"):
			music_volume = GLOBAL.settings.volume.music
		
		# Configurar el SliderOption con texto, icono, valor inicial y callback
		sliderOptionMusic.configure(
			tr("common_music"),
			"icon_music.svg",
			music_volume,
			self,
			"_on_HSlider_Volumen_Musica_value_changed"
		)
	else:
		print("Options: ERROR - No se encontró SliderOptionMusic")
	
	# Configurar SliderOption para volumen de efectos
	if sliderOptionSFX:
		print("Options: Configurando SliderOptionSFX")
		var sfx_volume = 80
		if has_node("/root/GLOBAL"):
			sfx_volume = GLOBAL.settings.volume.sfx
		
		# Configurar el SliderOption con texto, icono, valor inicial y callback
		sliderOptionSFX.configure(
			tr("common_sfx"),
			"icon_sfx.svg",
			sfx_volume,
			self,
			"_on_HSlider_Volumen_VFX_value_changed"
		)
	else:
		print("Options: ERROR - No se encontró SliderOptionSFX")

	labelResolution.text = tr("common_resolution")
	labelLanguage.text = tr("common_language")
	labelGeneral.text = tr("common_general")
	labelMusic.text = tr("common_music")
	labelSFX.text = tr("common_sfx")
	buttonClose.text = tr("common_back")
	
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
		
		# Idioma
		var lang_selector = selectLanguage
		if lang_selector:
			# Seleccionar el idioma actual
			for i in range(lang_selector.get_item_count()):
				if lang_selector.get_item_text(i) == global.settings.language:
					lang_selector.select(i)
					break

# Función para adaptar la UI según el dispositivo
func adapt_ui_for_device():
	print("Options: Adaptando UI para dispositivo")
	
	# Verificar que el CanvasLayer exista
	if has_node("CanvasLayer"):
		print("Options: CanvasLayer encontrado para adaptar")
		var canvas_layer = get_node("CanvasLayer")
		
		# Verificar la posición actual del CanvasLayer
		print("Options: Posición actual del CanvasLayer: ", canvas_layer.offset)
		
		# Asegurarnos de que el CanvasLayer tenga la propiedad layer configurada correctamente
		canvas_layer.layer = 100  # Usar un valor alto para asegurarnos de que esté por encima de todo
		print("Options: Layer del CanvasLayer configurado a: ", canvas_layer.layer)
	else:
		print("Options: ERROR - CanvasLayer no encontrado para adaptar")
	
	# Usar UIScaler si está disponible
	if ResourceLoader.exists("res://Scripts/UIScaler.gd"):
		var UIScaler = load("res://Scripts/UIScaler.gd")
		
		# Escalar botones
		var button = %ButtonClose
		if button:
			UIScaler.scale_button(button)
		
		# Escalar etiquetas
		var labels = [
			%Label_resolution,
			$LabelIdioma,
			$Label_general,
			$LabelMusic,
			$LabelSFX
		]
		
		for label in labels:
			if label:
				UIScaler.scale_label(label)
		
		# Escalar controles de opciones
		var option_controls = [
			selectResolution,
			selectLanguage,
			sliderVolumeGeneral, 
			sliderVolumeMusic,
			sliderVolumeSFX
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
			var back_button = %ButtonClose
			if back_button:
				back_button.custom_minimum_size = Vector2(200, 70)
				back_button.add_theme_font_size_override("font_size", 24)
			
			# Ajustar etiquetas
			var labels = [
				%Label_resolution,
				$LabelIdioma,
				$Label_general,
				$LabelMusic,
				$LabelSFX
			]
			
			for label in labels:
				if label:
					label.add_theme_font_size_override("font_size", 20)
			
			# Ajustar controles de opciones
			var option_buttons = [
				selectResolution, selectLanguage
			]
			
			for option_button in option_buttons:
				if option_button:
					option_button.custom_minimum_size = Vector2(150, 50)
					option_button.add_theme_font_size_override("font_size", 20)
			
			# Ajustar sliders
			var sliders = [
				sliderVolumeGeneral, 
				sliderVolumeMusic,
				sliderVolumeSFX
			]
			
			for slider in sliders:
				if slider:
					slider.custom_minimum_size = Vector2(200, 30)
			
			# Ajustar espaciado

	# Añadir un fondo semitransparente para el panel de opciones
	var panel_bg = ColorRect.new()
	panel_bg.name = "PanelBackground"
	panel_bg.color = Color(0, 0, 0, 0.7)  # Negro semitransparente
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)  # Cubrir toda la pantalla
	
	# Insertar el fondo antes de los otros elementos
	$CanvasLayer.add_child(panel_bg)
	$CanvasLayer.move_child(panel_bg, 0)  # Mover al fondo
	
	print("Options: UI adaptada para dispositivo")

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


func _on_button_close_pressed() -> void:
	OptionsManager.hide_options()
