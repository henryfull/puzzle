extends Control

signal value_changed(value)

@onready var label = $VBoxContainer/Label
@onready var icon = $VBoxContainer/HBoxContainer/Icon
@onready var slider = $VBoxContainer/HBoxContainer/Slider

# Valores por defecto
var default_value = 80
var min_value = 0
var max_value = 100

func _ready():
	# Configurar el slider
	slider.min_value = min_value
	slider.max_value = max_value
	slider.value = default_value
	
	# Conectar la señal del slider
	slider.connect("value_changed", Callable(self, "_on_slider_value_changed"))
	
	print("SliderOption: Componente inicializado")

# Método para configurar el componente
func configure(text_label, icon_name, initial_value = null, callback_object = null, callback_method = ""):
	# Configurar el texto
	if label:
		label.text = text_label
	
	# Configurar el icono
	if icon and icon_name:
		var icon_path = "res://Assets/Images/GUID/" + icon_name
		var texture = load(icon_path)
		if texture:
			icon.texture = texture
		else:
			print("SliderOption: No se pudo cargar el icono: ", icon_path)
	
	# Configurar el valor inicial si se proporciona
	if initial_value != null and slider:
		slider.value = initial_value
	
	# Conectar el callback si se proporciona
	if callback_object != null and callback_method != "" and slider:
		# Desconectar cualquier conexión previa para evitar duplicados
		if slider.is_connected("value_changed", Callable(callback_object, callback_method)):
			slider.disconnect("value_changed", Callable(callback_object, callback_method))
		
		# Conectar la nueva señal
		slider.connect("value_changed", Callable(callback_object, callback_method))
	
	print("SliderOption: Configurado con texto='", text_label, "', icono='", icon_name, "'")

# Método para obtener el valor actual
func get_value():
	return slider.value

# Método para establecer el valor
func set_value(value):
	slider.value = value

# Método para configurar los valores mínimo y máximo
func set_range(min_val, max_val):
	min_value = min_val
	max_value = max_val
	
	if slider:
		slider.min_value = min_val
		slider.max_value = max_val

# Callback interno para la señal value_changed
func _on_slider_value_changed(value):
	# Emitir nuestra propia señal
	emit_signal("value_changed", value)
