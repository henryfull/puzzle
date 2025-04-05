extends ScrollContainer

# Propiedades exportadas
@export var columns: int = 3
@export var cell_size: Vector2 = Vector2(100, 100)
@export var spacing: Vector2 = Vector2(10, 10)

# Variables internas
var grid: GridContainer = null
var selected_item: Control = null
var items: Array = []

func _ready():
	setup_grid()
	setup_touch_scroll()

func setup_grid():
	# Crear el contenedor de la cuadrícula
	grid = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", int(spacing.x))
	grid.add_theme_constant_override("v_separation", int(spacing.y))
	add_child(grid)
	
	# Configurar el tamaño mínimo
	custom_minimum_size = Vector2(
		columns * (cell_size.x + spacing.x) - spacing.x,
		cell_size.y + spacing.y
	)

func setup_touch_scroll():
	# Configurar el desplazamiento táctil
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

func add_item(item: Control):
	items.append(item)
	grid.add_child(item)
	item.custom_minimum_size = cell_size
	
	# Conectar señales para la selección
	if not item.gui_input.is_connected(_on_item_gui_input):
		item.gui_input.connect(_on_item_gui_input.bind(item))

func _on_item_gui_input(event: InputEvent, item: Control):
	if event is InputEventScreenTouch:
		if event.pressed:
			select_item(item)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select_item(item)

func select_item(item: Control):
	if selected_item:
		# Deseleccionar el item anterior
		selected_item.modulate = Color.WHITE
	
	# Seleccionar el nuevo item
	selected_item = item
	item.modulate = Color(0.8, 0.8, 1.0)  # Color azul claro para indicar selección
	
	# Emitir señal de selección
	item_selected.emit(item)

func clear():
	for item in items:
		if is_instance_valid(item):
			item.queue_free()
	items.clear()
	selected_item = null

func set_columns(new_columns: int):
	columns = new_columns
	if grid:
		grid.columns = columns
		# Recalcular tamaño mínimo
		custom_minimum_size.x = columns * (cell_size.x + spacing.x) - spacing.x

# Señales
signal item_selected(item: Control) 
