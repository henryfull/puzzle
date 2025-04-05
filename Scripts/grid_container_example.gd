extends Control

# Número inicial de elementos a crear
const INITIAL_ITEMS = 20

func _ready():
	# Conectar el slider para cambiar el número de columnas
	%ColumnSlider.value_changed.connect(_on_column_slider_changed)
	
	# Conectar la señal de selección
	%GridContainerList.item_selected.connect(_on_item_selected)
	
	# Crear elementos iniciales
	create_sample_items(INITIAL_ITEMS)

func _on_column_slider_changed(value: float):
	var columns = int(value)
	%ColumnValue.text = str(columns)
	%GridContainerList.set_columns(columns)

func _on_item_selected(item: Control):
	%SelectedLabel.text = "Seleccionado: " + item.name

func create_sample_items(count: int):
	# Limpiar elementos existentes
	%GridContainerList.clear()
	
	# Crear nuevos elementos
	for i in range(count):
		var item = create_item(i)
		%GridContainerList.add_item(item)

func create_item(index: int) -> Control:
	# Crear un panel con un número
	var panel = Panel.new()
	panel.name = "Item_" + str(index)
	
	# Agregar un número
	var label = Label.new()
	label.text = str(index)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Configurar el panel
	var container = VBoxContainer.new()
	container.add_child(label)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	panel.add_child(container)
	
	# Asignar un color aleatorio de fondo
	var color = Color(
		randf_range(0.3, 0.9),
		randf_range(0.3, 0.9),
		randf_range(0.3, 0.9)
	)
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	
	return panel 