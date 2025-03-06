# Script para actualizar la escena VictoryScreen.tscn
# Este script debe ejecutarse desde el editor de Godot

@tool
extends EditorScript

func _run():
	print("Actualizando la escena VictoryScreen.tscn...")
	
	# Cargar la escena
	var scene_path = "res://Scenes/VictoryScreen.tscn"
	var scene = load(scene_path)
	if not scene:
		print("Error: No se pudo cargar la escena " + scene_path)
		return
	
	var victory_scene = scene.instantiate()
	
	# Obtener el nodo principal
	var vbox_container = victory_scene.get_node("CanvasLayer/VBoxContainer")
	if not vbox_container:
		print("Error: No se encontró el VBoxContainer")
		return
	
	# Configurar el contenedor principal para que ocupe toda la pantalla
	vbox_container.anchor_right = 1.0
	vbox_container.anchor_bottom = 1.0
	vbox_container.offset_left = 0
	vbox_container.offset_top = 0
	vbox_container.offset_right = 0
	vbox_container.offset_bottom = 0
	vbox_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Añadir un título
	var title = Label.new()
	title.text = "PUZZLE COMPLETADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0, 0, 0))
	vbox_container.add_child(title)
	vbox_container.move_child(title, 0)  # Mover al principio
	
	# Añadir información sobre el puzzle completado
	var info = Label.new()
	info.name = "InfoLabel"
	info.text = "Has completado el puzzle"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	vbox_container.add_child(info)
	vbox_container.move_child(info, 1)  # Mover después del título
	
	# Crear un contenedor para el contenido (imagen o texto)
	var content_container = PanelContainer.new()
	content_container.name = "ContentContainer"
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.custom_minimum_size = Vector2(350, 350)
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color(1, 1, 1, 1.0) # Fondo blanco
	content_style.corner_radius_top_left = 5
	content_style.corner_radius_top_right = 5
	content_style.corner_radius_bottom_left = 5
	content_style.corner_radius_bottom_right = 5
	content_container.add_theme_stylebox_override("panel", content_style)
	vbox_container.add_child(content_container)
	
	# Mover el Sprite2D existente al contenedor de contenido
	var sprite = vbox_container.get_node("Sprite2D")
	if sprite:
		vbox_container.remove_child(sprite)
		content_container.add_child(sprite)
		sprite.position = Vector2(175, 175)  # Centrar en el contenedor
		sprite.scale = Vector2(0.5, 0.5)  # Ajustar escala
	
	# Crear la vista de texto
	var text_view = RichTextLabel.new()
	text_view.name = "TextView"
	text_view.visible = false
	text_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_view.bbcode_enabled = true
	text_view.scroll_active = true
	text_view.add_theme_font_size_override("normal_font_size", 16)
	text_view.add_theme_color_override("default_color", Color(0, 0, 0))
	content_container.add_child(text_view)
	
	# Añadir un contenedor para el botón de alternancia
	var toggle_container = HBoxContainer.new()
	toggle_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_container.alignment = BoxContainer.ALIGNMENT_CENTER
	toggle_container.add_theme_constant_override("separation", 20)
	vbox_container.add_child(toggle_container)
	
	# Botón para alternar entre imagen y texto
	var toggle_btn = Button.new()
	toggle_btn.text = "Texto"
	toggle_btn.custom_minimum_size = Vector2(150, 40)
	toggle_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	toggle_container.add_child(toggle_btn)
	
	# Guardar la escena actualizada
	var packed_scene = PackedScene.new()
	packed_scene.pack(victory_scene)
	ResourceSaver.save(packed_scene, scene_path)
	
	print("Escena VictoryScreen.tscn actualizada correctamente.") 