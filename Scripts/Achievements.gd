extends Control

func _ready():
	# Mostrar en consola todos los logros disponibles
	for achievement_id in AchievementsManager.achievements.keys():
		var achievement = AchievementsManager.achievements[achievement_id]
		print(achievement_id + " : " + achievement["name"] + " - " + achievement["desc"] + " (unlocked: " + str(achievement["unlocked"]) + ")")

	# Aquí se pueden instanciar nodos UI para mostrar cada logro en la interfaz. 
