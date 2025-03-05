extends Node2D

func _ready():
	# Inicialización de la selección de pack.
	# Aquí se pueden cargar los datos de PacksData, por ejemplo, leyendo archivos JSON o YAML.
	print("PackSelection: inicialización de los packs disponibles")
	load_packs()

func load_packs():
	var packs = load_json("res://PacksData/sample_packs.json") # Cargar el JSON
	print("Packs cargados: ", packs.size())
	
	if packs.size() == 0:
		print("ERROR: No se encontraron packs en el archivo JSON")
		var error_label = Label.new()
		error_label.text = "Error: No se encontraron packs disponibles"
		$CanvasLayer/VBoxContainer.add_child(error_label)
		return
	
	for pack in packs:
		print("Procesando pack: ", pack["name"])
		var button = Button.new() # Crear un nuevo botón
		button.text = pack["name"] # Asignar el nombre del pack al botón
		button.pressed.connect(Callable(self, "_on_PackSelected").bind(pack))
		$CanvasLayer/VBoxContainer.add_child(button) # Añadir el botón al VBoxContainer
		print("Botón añadido para pack: ", pack["name"])

func load_json(path: String) -> Array:
	print("Cargando archivo JSON: ", path)
	var data = AchievementsManager.loadFile(path)
	
	if data.is_empty():
		print("ERROR: No se pudo cargar el archivo JSON o está vacío")
		return []
	
	var parsed_data = JSON.parse_string(data)
	if parsed_data == null:
		print("ERROR: Error al analizar el JSON")
		return []
	
	if not parsed_data.has("packs"):
		print("ERROR: El JSON no tiene la clave 'packs'")
		return []
	
	var packs = parsed_data.packs
	if packs == null or not (packs is Array):
		print("ERROR: La clave 'packs' no es un array válido")
		return []
	
	print("Packs encontrados en el JSON: ", packs.size())
	return packs

func _on_PackSelected(pack):
	print("Pack seleccionado: ", pack)
	
	# Verificar que el pack tenga la estructura correcta
	if not pack.has("puzzles"):
		print("ERROR: El pack seleccionado no tiene la clave 'puzzles'")
		# Añadir una clave puzzles vacía para evitar errores
		pack["puzzles"] = []
	
	GLOBAL.selected_pack = pack	
	# Función llamada al seleccionar un pack
	print("Pack seleccionado: " + pack["name"] + " con " + str(pack["puzzles"].size()) + " puzzles")
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn") 

func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
