extends Node2D

var btn_play: Button
var btn_options : Button
var btn_stats : Button
var btn_achievements : Button
var btn_exit : Button
var label_version: Label
var confirm_dialog_scene = preload("res://Scenes/Components/ConfirmExitDialog/ConfirmExitDialog.tscn")

func _ready():
	# Esperar un frame para asegurarnos de que GLOBAL y TranslationLoader estén inicializados
	btn_options = $CanvasLayer/MarginContainer/VBoxContainer/BTN_gameoptions
	btn_play = $CanvasLayer/MarginContainer/VBoxContainer/BTN_play
	btn_stats = $CanvasLayer/MarginContainer/VBoxContainer/BTN_stats
	btn_achievements = $CanvasLayer/MarginContainer/VBoxContainer/BTN_achievements
	btn_exit = $CanvasLayer/MarginContainer/VBoxContainer/BTN_exit
	label_version = $CanvasLayer/LabelVersion

	if OS.has_feature("ios"):
		btn_exit.visible = false
	
	# Mostrar la versión del juego
	update_version_label()
	
	await get_tree().process_frame
	
	# Inicializar ConnectStores para los servicios de plataforma
	if has_node("/root/ConnectStores"):
		var connect_stores = get_node("/root/ConnectStores")
		if not connect_stores.connection_initialized:
			print("MainMenu: Inicializando servicios de plataforma...")
			connect_stores.initialize_connection()
	
	# Actualizar los textos según el idioma actual
	update_ui_texts()
	
	
	# Conectar señal de cambio de idioma
	if has_node("/root/TranslationLoader"):
		get_node("/root/TranslationLoader").connect("language_changed", Callable(self, "_on_language_changed"))
	

# Función para actualizar la etiqueta de versión
func update_version_label():
	# Obtener la versión del juego desde ProjectSettings
	var version = ProjectSettings.get_setting("application/config/version", "0.0.0")
	
	# Mostrar la versión en el LabelVersion
	if label_version:
		label_version.text = "v. " + version
		print("MainMenu: Versión del juego: ", version)

# Función para actualizar los textos de la UI
func update_ui_texts():
	btn_options.text = tr("common_modes").to_upper()
	btn_play.text = tr("common_play").to_upper()
	btn_exit.text = tr("common_exit").to_upper()
	print("MainMenu: Textos actualizados con idioma: ", TranslationServer.get_locale())



# Función para manejar cambios de idioma
func _on_language_changed(_locale_code):
	update_ui_texts()
	
	# Actualizar textos del menú de opciones si está visible
	if has_node("/root/OptionsManager"):
		get_node("/root/OptionsManager").update_texts_if_visible()

func _on_PlayButton_pressed():
	# Si el menú de opciones está visible, ocultarlo primero
	if has_node("/root/OptionsManager") and get_node("/root/OptionsManager").is_visible():
		get_node("/root/OptionsManager").hide_options()
		await get_tree().create_timer(0.3).timeout  # Esperar a que termine la animación
	
	# Verificar si hay un estado guardado para continuar
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if puzzle_state_manager and puzzle_state_manager.has_saved_state():
		print("MainMenu: Detectado estado guardado, continuando partida...")
		if puzzle_state_manager.setup_continue_game():
			# Ir directamente al puzzle guardado
			GLOBAL.change_scene_with_loading("res://Scenes/PuzzleGame.tscn")
			return
		else:
			print("MainMenu: No se pudo configurar la continuación, yendo a selección de packs")
	
	# Si no hay estado guardado o hay un pack/puzzle guardado, ir a la selección apropiada
	if puzzle_state_manager:
		var saved_pack_id = puzzle_state_manager.get_saved_pack_id()
		var saved_puzzle_id = puzzle_state_manager.get_saved_puzzle_id()
		
		if not saved_pack_id.is_empty():
			# Hay un pack guardado, configurar GLOBAL y ir a selección de puzzles
			_setup_saved_pack_and_go_to_puzzles(saved_pack_id)
			return
	
	# No hay estado guardado, ir a selección de packs normalmente
	GLOBAL.change_scene_with_loading("res://Scenes/PackSelection.tscn")

func _on_OptionsButton_pressed():
	OptionsManager.show_options(self)

func _on_AchievementsButton_pressed():
	GLOBAL.change_scene_with_loading("res://Scenes/Achievements.tscn")

# Mostrar el diálogo de confirmación para salir directamente
func show_exit_dialog():
	# Eliminar diálogos anteriores si existen
	for child in get_children():
		if child.is_in_group("exit_dialog"):
			child.queue_free()
	
	# Instanciar nuevo diálogo
	var dialog = confirm_dialog_scene.instantiate()
	
	# Conectar señales
	dialog.exit_confirmed.connect(func(): get_tree().quit())
	dialog.exit_canceled.connect(func(): dialog.queue_free())
	
	# Añadir a la escena actual
	add_child(dialog)
	
	# Mostrar el diálogo
	dialog.show_dialog()

func _on_ExitButton_pressed():
	# Mostrar diálogo de confirmación para salir
	show_exit_dialog()

func _on_btn_exit_pressed() -> void:
	# Mostrar diálogo de confirmación para salir
	show_exit_dialog()

func _on_StatsButton_pressed():
	GLOBAL.change_scene_with_loading("res://Scenes/StatsScreen.tscn")

func _on_show_gameModes() -> void:
	$GameMode.get_child(0).visible = true

# Función para configurar el pack guardado y ir a la selección de puzzles
func _setup_saved_pack_and_go_to_puzzles(pack_id: String):
	print("MainMenu: Configurando pack guardado: ", pack_id)
	
	# Buscar el pack en ProgressManager
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("MainMenu: Error - No se encontró ProgressManager")
		GLOBAL.change_scene_with_loading("res://Scenes/PackSelection.tscn")
		return
	
	# Buscar el pack por ID
	var found_pack = null
	for pack in progress_manager.packs_data.packs:
		if pack.id == pack_id:
			found_pack = pack
			break
	
	if found_pack:
		# Configurar GLOBAL con el pack encontrado
		GLOBAL.selected_pack = found_pack
		print("MainMenu: Pack configurado: ", found_pack.name)
		
		# Ir a la selección de puzzles del pack
		GLOBAL.change_scene_with_loading("res://Scenes/PuzzleSelection.tscn")
	else:
		print("MainMenu: No se encontró el pack guardado, yendo a selección de packs")
		GLOBAL.change_scene_with_loading("res://Scenes/PackSelection.tscn")
