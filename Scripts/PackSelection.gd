extends Node2D

func _ready():
	# Inicialización de la selección de pack.
	# Aquí se pueden cargar los datos de PacksData, por ejemplo, leyendo archivos JSON o YAML.
	print("PackSelection: inicialización de los packs disponibles")
	load_packs()

func load_packs():
	var packs = load_json("res://PacksData/sample_packs.json") # Cargar el JSON
	for pack in packs:
		var button = Button.new() # Crear un nuevo botón
		button.text = pack["name"] # Asignar el nombre del pack al botón
		button.pressed.connect(Callable(self, "_on_PackSelected").bind(pack))
		$CanvasLayer/VBoxContainer.add_child(button) # Añadir el botón al VBoxContainer

func load_json(path: String) -> Array:
	var data = AchievementsManager.loadFile(path)
	var file = JSON.parse_string(data).packs
	if (file != null):
		return file
	else:
		return []

func _on_PackSelected(pack):
	GLOBAL.selected_pack = pack	
	# Función llamada al seleccionar un pack
	print("Pack seleccionado: " + pack["name"])
	get_tree().change_scene_to_file("res://Scenes/PuzzleSelection.tscn") 

func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
