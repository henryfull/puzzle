extends Node

# Diccionario que contiene los logros del juego
var languagesAvaibles = [{'field': 'es', 'label': 'Español'}, {'field': 'en', 'label': 'English'},{'field': 'ca', 'label': 'Catala'}]
var achievements = {
	"primer_paso": {
		"name": "Primer Paso",
		"desc": "Completa tu primer puzle.",
		"unlocked": false
	},
	"velocidad_relampago": {
		"name": "Velocidad Relámpago",
		"desc": "Completa un puzle en Modo Contrarreloj con tiempo sobrante ≥ 30s.",
		"unlocked": false
	},
	"el_coleccionista": {
		"name": "El Coleccionista",
		"desc": "Completa 10 puzles diferentes.",
		"unlocked": false
	},
	"sin_mirar_atras": {
		"name": "Sin Mirar Atrás",
		"desc": "Completa un puzle sin usar la función de Flip.",
		"unlocked": false
	},
	"eficiencia_maxima": {
		"name": "Eficiencia Máxima",
		"desc": "Termina un puzle realizando menos de X movimientos.",
		"unlocked": false
	},
	"maestro_de_la_noche": {
		"name": "Maestro de la Noche",
		"desc": "Completa 3 puzles en Modo Contrarreloj en máxima dificultad.",
		"unlocked": false
	},
	"perfecto_en_todo_sentido": {
		"name": "Perfecto en Todo Sentido",
		"desc": "Obtén la máxima puntuación posible en un puzle.",
		"unlocked": false
	}
}

# Función para desbloquear un logro
func unlock_achievement(achievement_id: String) -> void:
	if achievements.has(achievement_id) and not achievements[achievement_id]["unlocked"]:
		achievements[achievement_id]["unlocked"] = true
		print("Logro desbloqueado: " + achievements[achievement_id]["name"])
		# Aquí se puede integrar la lógica para reportar el logro a plataformas externas como Steam, Google Play o Game Center.

# Función para obtener la información de un logro
func get_achievement(achievement_id: String) -> Dictionary:
	if achievements.has(achievement_id):
		return achievements[achievement_id]
	return {} 
	
func loadFile(path) -> String:
	var file = FileAccess.open(path, FileAccess.READ)

	if file != null:
		var content = file.get_as_text()
		return content
	else: 
		return ''

func _on_BackButton_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn") 
	
func updateVolume(field, value):
	GLOBAL.settings.volume[field] = value
