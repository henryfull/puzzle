extends Control

# Referencias a los controles deslizantes (sliders) en la interfaz
@onready var general_slider = $VBoxContainer/GeneralVolume/HSlider
@onready var music_slider = $VBoxContainer/MusicVolume/HSlider
@onready var sfx_slider = $VBoxContainer/SFXVolume/HSlider
@onready var test_sfx_button = $VBoxContainer/TestSFX/Button

func _ready():
	# Cargar valores actuales
	general_slider.value = AudioManager.get_general_volume()
	music_slider.value = AudioManager.get_music_volume()
	sfx_slider.value = AudioManager.get_sfx_volume()
	
	# Conectar señales
	general_slider.connect("value_changed", Callable(self, "_on_general_volume_changed"))
	music_slider.connect("value_changed", Callable(self, "_on_music_volume_changed"))
	sfx_slider.connect("value_changed", Callable(self, "_on_sfx_volume_changed"))
	
	# Conectar botón de prueba si existe
	if test_sfx_button:
		test_sfx_button.connect("pressed", Callable(self, "_on_test_sfx_button_pressed"))

func _on_general_volume_changed(value):
	AudioManager.set_general_volume(value)
	
func _on_music_volume_changed(value):
	AudioManager.set_music_volume(value)
	
func _on_sfx_volume_changed(value):
	AudioManager.set_sfx_volume(value)
	
func _on_test_sfx_button_pressed():
	# Reproducir un sonido de prueba
	AudioManager.play_sfx("res://Assets/Sounds/SFX/test_sound.wav")
	
func _notification(what):
	# Asegurarse de que la configuración se guarde al cerrar la aplicación
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		AudioManager.save_volume_settings()
		
		# Usar el diálogo de confirmación en lugar de salir directamente
		if has_node("/root/BackGestureHandler"):
			get_node("/root/BackGestureHandler").show_exit_dialog()
			get_viewport().set_input_as_handled()  # Evitar el cierre automático
		else:
			# Si por alguna razón no está el gestor, permitir el cierre normal
			get_tree().quit() 