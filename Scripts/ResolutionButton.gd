extends OptionButton

# Lista de resoluciones predefinidas
var resolutions = [
	Vector2(800, 600),
	Vector2(1024, 768),
	Vector2(1280, 720),
	Vector2(1920, 1080)
]
var current_index := 0

func _ready():
	# Solo se muestra en entornos de escritorio
	if OS.has_feature("mobile"):
		hide()
	else:
		populate_resolutions()
		load_resolution()  # Cargar la resolución guardada, si existe.
		connect("item_selected", Callable(self, "_on_resolution_selected"))

# Llena el OptionButton con las resoluciones disponibles.
func populate_resolutions():
	clear()
	for res in resolutions:
		add_item(str(res.x) + "x" + str(res.y))

# Se llama al seleccionar una resolución en el desplegable.
func _on_resolution_selected(index):
	current_index = index
	var new_resolution = resolutions[current_index]
	DisplayServer.window_set_size(new_resolution)  # Cambia la resolución
	save_resolution(new_resolution)  # Guarda la configuración
	print("Resolución cambiada a: ", new_resolution)

# Guarda la resolución en un archivo de configuración.
func save_resolution(res: Vector2):
	var config = ConfigFile.new()  # Crear nueva instancia de ConfigFile
	config.set_value("display", "resolution_x", res.x)
	config.set_value("display", "resolution_y", res.y)
	config.save("user://settings.cfg")

# Carga la resolución guardada (si existe) y la aplica.
func load_resolution():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		var rx = config.get_value("display", "resolution_x", resolutions[0].x)
		var ry = config.get_value("display", "resolution_y", resolutions[0].y)
		var saved_res = Vector2(rx, ry)
		# Buscar el índice que coincida con la resolución guardada
		for i in range(resolutions.size()):
			if resolutions[i] == saved_res:
				current_index = i
				break
		# Aplicar la resolución guardada
		DisplayServer.window_set_size(saved_res)
		# Seleccionar el elemento correspondiente en el OptionButton
		select(current_index)
	else:
		# Si no existe la configuración, usar la resolución por defecto.
		select(0)
		DisplayServer.window_set_size(resolutions[0])
