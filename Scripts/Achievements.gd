extends Node2D

# Referencias a componentes de la UI
@onready var achievements_list = $CanvasLayer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/AchievementsList
@onready var no_achievements_label = $CanvasLayer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/NoAchievementsLabel
@onready var total_value = $CanvasLayer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/StatsPanel/HBoxContainer/StatsTotal/StatsTotal/Value
@onready var unlocked_value = $CanvasLayer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/StatsPanel/HBoxContainer/StatsUnlocked/StatsUnlocked/Value
@onready var percentage_value = $CanvasLayer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/StatsPanel/HBoxContainer/StatsPercentage/StatsPercentage/Value

# Referencias a las pestañas
@onready var all_tab = $CanvasLayer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/TabsContainer/AllTab
@onready var unlocked_tab = $CanvasLayer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/TabsContainer/UnlockedTab
@onready var locked_tab = $CanvasLayer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/TabsContainer/LockedTab

# Estilos para las pestañas activas/inactivas
var active_tab_style: StyleBoxFlat
var inactive_tab_style: StyleBoxFlat

# Variable para rastrear pestaña actual
var current_tab: String = "all"

# Elemento de logro
var achievement_item_scene = preload("res://Scenes/Components/AchievementItem/AchievementItem.tscn")

# Llamada cuando la escena está lista
func _ready():
	# Mostrar en consola todos los logros disponibles
	for achievement_id in AchievementsManager.get_all_achievements().keys():
		var achievement = AchievementsManager.get_achievement(achievement_id)
		print(achievement_id + " : " + achievement["name"] + " - " + achievement["desc"] + " (unlocked: " + str(achievement["unlocked"]) + ")")
	

	
	# Configurar las pestañas
	all_tab.add_theme_stylebox_override("normal", active_tab_style)
	unlocked_tab.add_theme_stylebox_override("normal", inactive_tab_style)
	locked_tab.add_theme_stylebox_override("normal", inactive_tab_style)
	
	# Cargar los logros
	load_achievements("all")
	
	# Actualizar las estadísticas
	update_statistics()

# Función para cargar los logros según el filtro
func load_achievements(filter: String = "all") -> void:
	# Limpiar la lista actual
	for child in achievements_list.get_children():
		child.queue_free()
	
	current_tab = filter
	update_tabs()
	
	# Obtener todos los logros
	var achievements = AchievementsManager.get_all_achievements()
	var filtered_achievements = []
	
	# Filtrar según la pestaña seleccionada
	for achievement_id in achievements.keys():
		var achievement = achievements[achievement_id]
		
		# Aplicar filtro
		match filter:
			"all":
				filtered_achievements.append({"id": achievement_id, "data": achievement})
			"unlocked":
				if achievement.unlocked:
					filtered_achievements.append({"id": achievement_id, "data": achievement})
			"locked":
				if not achievement.unlocked:
					filtered_achievements.append({"id": achievement_id, "data": achievement})
	
	# Si no hay logros, mostrar mensaje
	if filtered_achievements.is_empty():
		no_achievements_label.visible = true
		return
	
	no_achievements_label.visible = false
	
	# Ordenar logros (desbloqueados primero, luego por ID)
	filtered_achievements.sort_custom(func(a, b): 
		if a.data.unlocked != b.data.unlocked:
			return not a.data.unlocked
		return a.id < b.id
	)
	
	# Crear elementos para cada logro
	for achievement in filtered_achievements:
		var item = achievement_item_scene.instantiate()
		achievements_list.add_child(item)
		item.setup(achievement.id, achievement.data)

# Actualizar las estadísticas de logros
func update_statistics() -> void:
	var achievements = AchievementsManager.get_all_achievements()
	var total = achievements.size()
	var unlocked = 0
	
	for achievement_id in achievements.keys():
		if achievements[achievement_id].unlocked:
			unlocked += 1
	
	var percentage = 0
	if total > 0:
		percentage = (unlocked * 100) / total
	
	total_value.text = str(total)
	unlocked_value.text = str(unlocked)
	percentage_value.text = str(int(percentage)) + "%"

# Actualizar la apariencia de las pestañas
func update_tabs() -> void:
	match current_tab:
		"all":
			all_tab.add_theme_stylebox_override("normal", active_tab_style)
			unlocked_tab.add_theme_stylebox_override("normal", inactive_tab_style)
			locked_tab.add_theme_stylebox_override("normal", inactive_tab_style)
		"unlocked":
			all_tab.add_theme_stylebox_override("normal", inactive_tab_style)
			unlocked_tab.add_theme_stylebox_override("normal", active_tab_style)
			locked_tab.add_theme_stylebox_override("normal", inactive_tab_style)
		"locked":
			all_tab.add_theme_stylebox_override("normal", inactive_tab_style)
			unlocked_tab.add_theme_stylebox_override("normal", inactive_tab_style)
			locked_tab.add_theme_stylebox_override("normal", active_tab_style)

# Callbacks de los botones
func _on_all_tab_pressed() -> void:
	load_achievements("all")

func _on_unlocked_tab_pressed() -> void:
	load_achievements("unlocked")

func _on_locked_tab_pressed() -> void:
	load_achievements("locked")
