extends Node

# Script de prueba para verificar el formato de serialización de posiciones

func _ready():
	print("====== PRUEBA DE FORMATO DE SERIALIZACIÓN ======")
	print("Verificando que las posiciones se serialicen correctamente como diccionarios")
	print("==================================================")
	
	# Test 1: Crear datos de prueba que simulen un estado guardado
	test_position_serialization()
	
	# Test 2: Verificar el formato JSON resultante
	test_json_format()
	
	# Test 3: Test completo de save/load
	test_complete_save_load()

func test_position_serialization():
	print("TEST 1: Verificando serialización de posiciones")
	
	# Simular datos de una pieza
	var test_piece_data = {
		"order_number": 5,
		"original_grid_position": {
			"x": 2.0,
			"y": 3.0
		},
		"current_position": {
			"x": 150.5,
			"y": 225.8
		},
		"local_position": {
			"x": 100.0,
			"y": 200.0
		},
		"flipped": false,
		"group_id": 12345
	}
	
	print("  - Datos de pieza creados correctamente")
	print("  - Posición original: (", test_piece_data.original_grid_position.x, ", ", test_piece_data.original_grid_position.y, ")")
	print("  - Posición actual: (", test_piece_data.current_position.x, ", ", test_piece_data.current_position.y, ")")
	
	# Verificar que podemos acceder a las propiedades sin error
	var pos_x = test_piece_data.current_position.x
	var pos_y = test_piece_data.current_position.y
	print("  ✅ Acceso a propiedades x,y exitoso: (", pos_x, ", ", pos_y, ")")

func test_json_format():
	print("\nTEST 2: Verificando formato JSON")
	
	# Crear estructura de estado completa
	var puzzle_state = {
		"has_saved_state": true,
		"pack_id": "test_pack",
		"puzzle_id": "test_puzzle",
		"pieces_data": [
			{
				"order_number": 0,
				"current_position": {
					"x": 100.0,
					"y": 150.0
				},
				"group_id": -1,
				"flipped": false
			},
			{
				"order_number": 1,
				"current_position": {
					"x": 200.0,
					"y": 250.0
				},
				"group_id": 123,
				"flipped": true
			}
		]
	}
	
	# Convertir a JSON y volver a parsear
	var json_string = JSON.stringify(puzzle_state, "\t")
	print("  - JSON generado exitosamente")
	print("  - Longitud: ", json_string.length(), " caracteres")
	
	# Parsear de vuelta
	var parsed_data = JSON.parse_string(json_string)
	if parsed_data:
		print("  ✅ JSON parseado exitosamente")
		
		# Verificar estructura de posiciones
		var first_piece = parsed_data.pieces_data[0]
		if first_piece.has("current_position") and first_piece.current_position.has("x"):
			print("  ✅ Estructura de posición correcta: x=", first_piece.current_position.x, ", y=", first_piece.current_position.y)
		else:
			print("  ❌ Estructura de posición incorrecta")
	else:
		print("  ❌ Error al parsear JSON")

func test_complete_save_load():
	print("\nTEST 3: Test completo de save/load")
	
	var manager = get_node("/root/PuzzleStateManager")
	if manager:
		print("  - PuzzleStateManager disponible")
		
		# Crear estado de prueba
		manager.start_new_puzzle_state("test_pack", "test_puzzle", 2, 3)
		
		# Simular actualización de posiciones de piezas
		var test_pieces_data = [
			{
				"order_number": 0,
				"current_position": {
					"x": 120.5,
					"y": 180.7
				},
				"group_id": -1,
				"flipped": false
			},
			{
				"order_number": 1,
				"current_position": {
					"x": 250.3,
					"y": 320.9
				},
				"group_id": 456,
				"flipped": true
			}
		]
		
		# Actualizar el estado con los datos de prueba
		manager.puzzle_state.pieces_data = test_pieces_data
		
		# Guardar estado
		manager.save_puzzle_state()
		print("  ✅ Estado guardado")
		
		# Limpiar y cargar de nuevo
		manager.reset_puzzle_state()
		manager.load_puzzle_state()
		
		# Verificar que se cargó correctamente
		var loaded_pieces = manager.get_saved_pieces_data()
		if loaded_pieces.size() > 0:
			var first_piece = loaded_pieces[0]
			if first_piece.has("current_position") and typeof(first_piece.current_position) == TYPE_DICTIONARY:
				print("  ✅ Posición cargada correctamente: x=", first_piece.current_position.x, ", y=", first_piece.current_position.y)
			else:
				print("  ❌ Formato de posición incorrecto después de cargar")
		else:
			print("  ❌ No se cargaron datos de piezas")
		
		# Limpiar estado de prueba
		manager.clear_all_state()
		print("  - Estado de prueba limpiado")
	else:
		print("  ❌ PuzzleStateManager no disponible")

	print("\n====== PRUEBA COMPLETADA ======")
	print("Si todos los tests muestran ✅, el formato está funcionando correctamente") 