# test_forced_close.gd
# Script para probar el problema del cierre forzado del juego

extends Node

func _ready():
	print("=== PRUEBA DEL PROBLEMA DE CIERRE FORZADO ===")
	
	# Simular el flujo de juego
	await get_tree().process_frame
	test_forced_close_scenario()

func test_forced_close_scenario():
	print("\n1. Simulando inicio de partida...")
	
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if not puzzle_state_manager:
		print("❌ ERROR: PuzzleStateManager no encontrado")
		return
	
	# Simular inicio de nuevo puzzle
	puzzle_state_manager.start_new_puzzle_state("pack_test", "puzzle_test", 2, 3)
	print("✅ Estado inicial creado")
	
	# Simular algunos movimientos y posiciones de piezas
	print("\n2. Simulando movimientos y posiciones...")
	
	# Simular datos de piezas en posiciones específicas
	var mock_pieces_data = [
		{
			"order_number": 0,
			"original_grid_position": Vector2(0, 0),
			"current_position": Vector2(100, 150),
			"flipped": false,
			"group_id": 1,
			"is_correct_position": false
		},
		{
			"order_number": 1,
			"original_grid_position": Vector2(1, 0),
			"current_position": Vector2(250, 300),
			"flipped": true,
			"group_id": 2,
			"is_correct_position": false
		}
	]
	
	# Forzar datos de piezas directamente
	puzzle_state_manager.puzzle_state.pieces_data = mock_pieces_data
	
	# Simular contadores actualizados
	puzzle_state_manager.update_counters(120.5, 25, 3, 8, 200.0)
	
	print("✅ Datos simulados - 2 piezas en posiciones específicas")
	print("   Pieza 0 en: ", mock_pieces_data[0].current_position)
	print("   Pieza 1 en: ", mock_pieces_data[1].current_position)
	
	# Forzar guardado
	puzzle_state_manager.save_puzzle_state()
	print("✅ Estado guardado con posiciones específicas")
	
	print("\n3. Simulando cierre forzado y reinicio...")
	
	# Limpiar estado en memoria (simular cierre forzado)
	puzzle_state_manager.reset_puzzle_state()
	print("✅ Estado en memoria limpiado (simula cierre forzado)")
	
	# Cargar desde archivo (simular reinicio)
	puzzle_state_manager.load_puzzle_state()
	
	if puzzle_state_manager.has_saved_state():
		print("✅ Estado cargado desde archivo")
		
		var saved_pieces = puzzle_state_manager.get_saved_pieces_data()
		var saved_counters = puzzle_state_manager.get_saved_counters()
		
		print("\n4. Verificando datos restaurados...")
		print("   Contadores - Tiempo: ", saved_counters.elapsed_time, ", Movimientos: ", saved_counters.total_moves)
		print("   Piezas guardadas: ", saved_pieces.size())
		
		for i in range(saved_pieces.size()):
			var piece = saved_pieces[i]
			print("   Pieza ", piece.order_number, " en posición: ", piece.current_position)
		
		# Verificar si las posiciones se mantuvieron
		var positions_correct = true
		for i in range(min(saved_pieces.size(), mock_pieces_data.size())):
			var saved_pos = saved_pieces[i].current_position
			var expected_pos = mock_pieces_data[i].current_position
			if saved_pos != expected_pos:
				positions_correct = false
				print("❌ ERROR: Posición incorrecta para pieza ", i)
				print("   Esperada: ", expected_pos, ", Encontrada: ", saved_pos)
		
		if positions_correct:
			print("✅ ÉXITO: Todas las posiciones se mantuvieron correctamente")
		else:
			print("❌ FALLO: Las posiciones no se mantuvieron correctamente")
	else:
		print("❌ ERROR: No se pudo cargar el estado desde archivo")
	
	print("\n=== PRUEBA COMPLETADA ===")
	
	# Limpiar datos de prueba
	puzzle_state_manager.clear_all_state() 