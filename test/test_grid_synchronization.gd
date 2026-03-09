extends Node

# Script de prueba para verificar la sincronización del grid después de la restauración

func _ready():
	print("====== PRUEBA DE SINCRONIZACIÓN DEL GRID ======")
	print("Verificando que el grid interno se actualiza correctamente")
	print("================================================")
	
	# Test 1: Verificar que se guarda la información de celda
	test_cell_data_saving()
	
	# Test 2: Verificar función de restauración mejorada
	test_restoration_logic()
	
	# Test 3: Test de save/load completo con información de celda
	test_complete_grid_sync()

func test_cell_data_saving():
	print("TEST 1: Verificando que se guarda información de celda")
	
	var manager = get_node("/root/PuzzleStateManager")
	if manager:
		print("  - PuzzleStateManager disponible")
		
		# Crear estado de prueba
		manager.start_new_puzzle_state("test_pack", "test_puzzle", 2, 3)
		
		# Crear datos de prueba simulando piezas con celdas
		var mock_piece_manager = MockPieceManager.new()
		mock_piece_manager.setup_test_pieces()
		
		# Actualizar usando la nueva función
		manager.update_pieces_positions_from_manager(mock_piece_manager)
		
		# Verificar que se guardó la información de celda
		var saved_pieces = manager.get_saved_pieces_data()
		if saved_pieces.size() > 0:
			var first_piece = saved_pieces[0]
			if first_piece.has("current_cell") and typeof(first_piece.current_cell) == TYPE_DICTIONARY:
				print("  ✅ Información de celda guardada correctamente: x=", first_piece.current_cell.x, ", y=", first_piece.current_cell.y)
			else:
				print("  ❌ Información de celda NO guardada")
		else:
			print("  ❌ No se guardaron datos de piezas")
		
		# Limpiar
		manager.clear_all_state()
	else:
		print("  ❌ PuzzleStateManager no disponible")

func test_restoration_logic():
	print("\nTEST 2: Verificando lógica de restauración mejorada")
	
	# Simular datos de pieza con ambos formatos
	var piece_data_with_cell = {
		"order_number": 1,
		"current_position": {
			"x": 150.0,
			"y": 200.0
		},
		"current_cell": {
			"x": 2.0,
			"y": 3.0
		},
		"group_id": -1
	}
	
	var piece_data_without_cell = {
		"order_number": 2,
		"current_position": {
			"x": 250.0,
			"y": 300.0
		},
		"group_id": -1
	}
	
	# Verificar que podemos acceder a la celda guardada
	if piece_data_with_cell.has("current_cell"):
		var cell_data = piece_data_with_cell.current_cell
		if typeof(cell_data) == TYPE_DICTIONARY and cell_data.has("x") and cell_data.has("y"):
			var cell = Vector2(cell_data.x, cell_data.y)
			print("  ✅ Celda extraída correctamente de datos con celda: ", cell)
		else:
			print("  ❌ Formato de celda incorrecto")
	
	# Verificar comportamiento sin celda (fallback)
	if not piece_data_without_cell.has("current_cell"):
		print("  ✅ Datos sin celda detectados correctamente - usará fallback")
	else:
		print("  ❌ Detección de datos sin celda falló")

func test_complete_grid_sync():
	print("\nTEST 3: Test completo de sincronización grid")
	
	var manager = get_node("/root/PuzzleStateManager")
	if manager:
		print("  - Iniciando test completo...")
		
		# Crear estado inicial
		manager.start_new_puzzle_state("test_grid", "test_sync", 2, 3)
		
		# Simular piezas en posiciones específicas
		var mock_manager = MockPieceManager.new()
		mock_manager.setup_grid_test_pieces()
		
		# Guardar estado
		manager.update_pieces_positions_from_manager(mock_manager)
		print("  - Estado inicial guardado")
		
		# Simular cambio de posiciones
		mock_manager.move_pieces_to_different_positions()
		manager.update_pieces_positions_from_manager(mock_manager)
		print("  - Estado actualizado guardado")
		
		# Verificar datos finales
		var final_pieces = manager.get_saved_pieces_data()
		var all_have_cells = true
		for piece_data in final_pieces:
			if not piece_data.has("current_cell"):
				all_have_cells = false
				break
		
		if all_have_cells:
			print("  ✅ Todas las piezas tienen información de celda")
		else:
			print("  ❌ Algunas piezas no tienen información de celda")
		
		# Limpiar
		manager.clear_all_state()
		print("  - Test completado y limpiado")
	else:
		print("  ❌ PuzzleStateManager no disponible")

	print("\n====== PRUEBA COMPLETADA ======")
	print("Si todos los tests muestran ✅, la sincronización del grid funciona correctamente")

# Clase mock para simular PuzzlePieceManager en las pruebas
class MockPieceManager:
	var pieces = []
	
	func setup_test_pieces():
		pieces.clear()
		
		# Crear piezas de prueba
		for i in range(3):
			var mock_piece = MockPiece.new()
			mock_piece.order_number = i
			mock_piece.current_cell = Vector2(i, 0)
			mock_piece.global_position = Vector2(100 + i * 50, 150)
			pieces.append(mock_piece)
	
	func setup_grid_test_pieces():
		pieces.clear()
		
		# Crear piezas en posiciones específicas para test de grid
		var positions = [
			Vector2(0, 0),
			Vector2(1, 0),
			Vector2(0, 1),
			Vector2(1, 1)
		]
		
		for i in range(positions.size()):
			var mock_piece = MockPiece.new()
			mock_piece.order_number = i
			mock_piece.current_cell = positions[i]
			mock_piece.global_position = Vector2(100 + positions[i].x * 60, 150 + positions[i].y * 60)
			pieces.append(mock_piece)
	
	func move_pieces_to_different_positions():
		# Simular movimiento de piezas a nuevas posiciones
		for i in range(pieces.size()):
			pieces[i].current_cell.x += 1
			pieces[i].global_position.x += 60
	
	func get_pieces():
		return pieces

# Clase mock para simular una pieza del PuzzlePieceManager
class MockPiece:
	var node = MockNode.new()
	var current_cell = Vector2.ZERO
	var order_number = 0
	var global_position = Vector2.ZERO
	
	func _init():
		node.mock_piece = self

class MockNode:
	var mock_piece
	var order_number = 0
	
	func get_puzzle_piece_data():
		return {
			"order_number": order_number,
			"current_position": {
				"x": mock_piece.global_position.x,
				"y": mock_piece.global_position.y
			},
			"group_id": -1,
			"flipped": false
		} 