extends Node

# Script de prueba para verificar que las mejoras en la continuación de puzzles funcionen correctamente
# Coloca este archivo en la raíz del proyecto y ejecuta desde la escena principal

func _ready():
	print("====== PRUEBA DE CONTINUACIÓN DE PUZZLES MEJORADA ======")
	print("Este script verifica que los problemas de sincronización estén resueltos")
	print("=========================================================")
	print()
	
	# Esperar a que todos los autoloads estén listos
	await get_tree().process_frame
	
	# Test 1: Verificar que PuzzleStateManager funciona correctamente
	test_puzzle_state_manager()
	print()
	
	# Test 2: Verificar sistema de validación de datos
	test_data_validation()
	print()
	
	print("====== INSTRUCCIONES DE PRUEBA MANUAL ======")
	print("1. Inicia un puzzle y mueve algunas piezas")
	print("2. Forma algunos grupos moviendo piezas adyacentes")
	print("3. Sal del puzzle usando el menú de pausa")
	print("4. Vuelve a entrar al mismo puzzle")
	print("5. Verifica que:")
	print("   - Las piezas están exactamente donde las dejaste")
	print("   - Los grupos se mantienen intactos")
	print("   - Al arrastrar una pieza, solo se mueve esa pieza (no duplicados)")
	print("   - Las piezas no se juntan aleatoriamente al soltarlas")
	print("   - El comportamiento es igual a un puzzle nuevo")
	print("============================================")

func test_puzzle_state_manager():
	print("TEST 1: Verificando PuzzleStateManager mejorado...")
	
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if not puzzle_state_manager:
		print("❌ ERROR: PuzzleStateManager no encontrado")
		return
	
	print("✅ PuzzleStateManager encontrado")
	
	# Verificar que tiene las nuevas funciones de validación
	if puzzle_state_manager.has_method("_validate_piece_data"):
		print("✅ Nueva función de validación de datos disponible")
	else:
		print("❌ ERROR: Función de validación no encontrada")
	
	# Simular datos de pieza válidos
	var valid_piece_data = {
		"order_number": 1,
		"current_position": {"x": 100.0, "y": 200.0},
		"current_cell": {"x": 2, "y": 3},
		"group_id": -1,
		"flipped": false
	}
	
	# Crear un objeto de pieza simulado
	var mock_piece = Node.new()
	mock_piece.order_number = 1
	
	# Simular validación
	print("   Probando validación de datos...")
	var is_valid = puzzle_state_manager._validate_piece_data(valid_piece_data, mock_piece)
	if is_valid:
		print("✅ Validación de datos funciona correctamente")
	else:
		print("❌ ERROR: Validación de datos falló")
	
	# Limpiar
	mock_piece.queue_free()

func test_data_validation():
	print("TEST 2: Verificando validación de datos de piezas...")
	
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if not puzzle_state_manager:
		print("❌ ERROR: PuzzleStateManager no disponible")
		return
	
	# Crear mock piece object
	var mock_piece = Node.new()
	mock_piece.order_number = 5
	
	# Test 1: Datos válidos
	var valid_data = {
		"order_number": 5,
		"current_position": {"x": 150.0, "y": 300.0},
		"current_cell": {"x": 1, "y": 2},
		"group_id": 123,
		"flipped": true
	}
	
	if puzzle_state_manager._validate_piece_data(valid_data, mock_piece):
		print("✅ Datos válidos: APROBADO")
	else:
		print("❌ Datos válidos: FALLO")
	
	# Test 2: Datos inválidos (sin current_cell)
	var invalid_data = {
		"order_number": 5,
		"current_position": {"x": 150.0, "y": 300.0},
		"flipped": false
	}
	
	if not puzzle_state_manager._validate_piece_data(invalid_data, mock_piece):
		print("✅ Rechazo de datos inválidos: APROBADO")
	else:
		print("❌ Rechazo de datos inválidos: FALLO")
	
	# Test 3: Datos con group_id faltante (debería añadirse automáticamente)
	var data_no_group = {
		"order_number": 5,
		"current_position": {"x": 150.0, "y": 300.0},
		"current_cell": {"x": 1, "y": 2},
		"flipped": false
	}
	
	if puzzle_state_manager._validate_piece_data(data_no_group, mock_piece):
		if data_no_group.has("group_id") and data_no_group.group_id == -1:
			print("✅ Auto-corrección de group_id faltante: APROBADO")
		else:
			print("❌ Auto-corrección de group_id faltante: FALLO")
	else:
		print("❌ Validación con group_id faltante: FALLO")
	
	# Limpiar
	mock_piece.queue_free()

func _exit_tree():
	print("====== PRUEBA COMPLETADA ======")
	print("Si todos los tests muestran ✅, las mejoras están funcionando correctamente")
	print("Ahora prueba manualmente continuando un puzzle guardado") 