extends Control

@onready var progress: Array
@onready var scene_load_status : int

func _ready() :
	get_tree().paused = false # Esto pueden omitirlo, yo lo pongo porque lo requiere MI proyecto.
	ResourceLoader. load_threaded_request (GLOBAL.change_scene)
#ResourceLoader. load_threaded_request("res://assets/levels/00/Level.tscn")
func _process(_delta):
	scene_load_status = ResourceLoader.load_threaded_get_status(GLOBAL.change_scene, progress)
# if scene_load_status == ResourceLoader. THREAD_LOAD_LOADED:
# get_tree.call_deferred("change_scene_to_packed", ResourceLoader. Load_threaded_get(GLOBAL change_scene))
	%ProgressBar.value = progress [0] * 100

func _on_progress_bar_value_changed(value):
	if value == 100 and scene_load_status == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().call_deferred ("change_scene_to_packed", ResourceLoader.load_threaded_get (GLOBAL.change_scene))
