extends Node

const SAVEFILE = "user://SAVEFILE.save"
const prefix = "user://"
const ext = ".save"

var game_data = {
	"score": 0,
	"game": {},
	"lastConnect": ""
}
# Called when the node enters the scene tree for the first time.
func _ready():
	load_data()
	pass # Replace with function body.



func load_data():
	loadGame("settings")
	loadGame("progress")

func save(savefile: String):
	var saved: String = prefix + savefile + ext
	var file = FileAccess.open(saved, FileAccess.WRITE)
	file.store_var(game_data)
	file = null

func loadGame(savefile: String):
	var saver: String = prefix + savefile + ext
	var file = FileAccess.open(saver, FileAccess.READ)

	if file != null:
		var content = file.get_var()
		GLOBAL[savefile] = content
		print("load", savefile, content)
		game_data = content
