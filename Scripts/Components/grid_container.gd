extends ScrollContainer

class_name GridContainer

# Propiedades exportadas
@export var columns: int = 3
@export var cell_size: Vector2 = Vector2(100, 100)
@export var spacing: Vector2 = Vector2(10, 10)

# Variables internas
var grid_container: GridContainer
var selected_item: Control = null
var items: Array = []

func _ready():
	setup_grid()
	setup_touch_scroll()

func setup_grid():
	# Crear el contenedor de la cuadrícula
	grid_container = GridContainer.new()
	grid_container.columns = columns
	add_child(grid_container)
	
	# Configurar el tamaño mínimo
	custom_minimum_size = Vector2(
		columns * (cell_size.x + spacing.x) - spacing.x,
		cell_size.y + spacing.y
	)

func setup_touch_scroll():
	# Configurar el desplazamiento táctil
	scroll_horizontal_enabled = true
	scroll_vertical_enabled = true
	touch_scroll_enabled = true

func add_item(item: Control):
	items.append(item)
	grid_container.add_child(item)
	item.custom_minimum_size = cell_size
	
	# Conectar señales para la selección
	if item.has_signal("gui_input"):
		item.connect("gui_input", _on_item_gui_input.bind(item))

func _on_item_gui_input(event: InputEvent, item: Control):
	if event is InputEventScreenTouch:
		if event.pressed:
			select_item(item)

func select_item(item: Control):
	if selected_item:
		# Deseleccionar el item anterior
		selected_item.modulate = Color.WHITE
	
	# Seleccionar el nuevo item
	selected_item = item
	item.modulate = Color(0.8, 0.8, 1.0)  # Color azul claro para indicar selección
	
	# Emitir señal de selección
	emit_signal("item_selected", item)

func clear():
	for item in items:
		item.queue_free()
	items.clear()
	selected_item = null

# Señales
signal item_selected(item: Control) 
