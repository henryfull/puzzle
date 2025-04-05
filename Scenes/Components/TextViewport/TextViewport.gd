extends Viewport

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var text_viewport = load("res://Scenes/Components/TextViewport/TextViewport.tscn").instantiate()
	add_child(text_viewport)
	# Esperar un frame para que se dibuje el Viewport:
	await get_tree().process_frame

	var viewport_image = text_viewport.get_texture().get_image()
	var puzzle_back = ImageTexture.new()
	puzzle_back.create_from_image(viewport_image)

	# Luego quitas el viewport de la escena si no quieres verlo:
	text_viewport.queue_free()

	# puzzle_back es la textura con tu texto dibujado
	# A partir de aquí, la usas en set_piece_data(front_tex, puzzle_back, region)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
