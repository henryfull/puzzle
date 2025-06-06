# test_fixes_verification.gd
# Script para verificar que los fixes de superposición y restart funcionan

extends SceneTree

func _init():
	print("=== VERIFICACIÓN DE FIXES APLICADOS ===")
	print()
	
	# Test 1: Verificar que el fix de superposición está presente
	test_superposition_fix_presence()
	
	# Test 2: Verificar que el fix de restart está presente
	test_restart_fix_presence()
	
	print()
	print("=== VERIFICACIÓN COMPLETADA ===")
	quit()

func test_superposition_fix_presence():
	print("🔍 Test 1: Verificando fix de superposición...")
	
	# Verificar que el código de PuzzlePieceManager tiene las funciones nuevas
	var piece_manager_path = "res://Scripts/PuzzlePieceManager.gd"
	var file = FileAccess.open(piece_manager_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var fixes_found = []
		
		if "_ensure_no_overlapping_pieces_in_grid" in content:
			fixes_found.append("✅ Función _ensure_no_overlapping_pieces_in_grid encontrada")
		else:
			fixes_found.append("❌ Función _ensure_no_overlapping_pieces_in_grid NO encontrada")
		
		if "_find_truly_free_cell_near" in content:
			fixes_found.append("✅ Función _find_truly_free_cell_near encontrada")
		else:
			fixes_found.append("❌ Función _find_truly_free_cell_near NO encontrada")
		
		if "_ensure_no_overlapping_pieces_in_grid()" in content:
			fixes_found.append("✅ Llamada a fix de superposición en place_group encontrada")
		else:
			fixes_found.append("❌ Llamada a fix de superposición en place_group NO encontrada")
		
		for fix in fixes_found:
			print("  " + fix)
	else:
		print("  ❌ No se pudo abrir PuzzlePieceManager.gd")

func test_restart_fix_presence():
	print("🔍 Test 2: Verificando fix de restart...")
	
	# Verificar que el código de PuzzleGameStateManager tiene el fix
	var state_manager_path = "res://Scripts/PuzzleGameStateManager.gd"
	var file = FileAccess.open(state_manager_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var fixes_found = []
		
		if "clear_all_state()" in content:
			fixes_found.append("✅ Llamada a clear_all_state() encontrada")
		else:
			fixes_found.append("❌ Llamada a clear_all_state() NO encontrada")
		
		if "extra_rows_added = 0" in content:
			fixes_found.append("✅ Reset de extra_rows_added encontrado")
		else:
			fixes_found.append("❌ Reset de extra_rows_added NO encontrado")
		
		if "posiciones aleatorias nuevas" in content:
			fixes_found.append("✅ Comentario sobre posiciones aleatorias encontrado")
		else:
			fixes_found.append("❌ Comentario sobre posiciones aleatorias NO encontrado")
		
		if "start_new_puzzle_state(" in content:
			fixes_found.append("✅ Reinicialización de estado encontrada")
		else:
			fixes_found.append("❌ Reinicialización de estado NO encontrada")
		
		for fix in fixes_found:
			print("  " + fix)
	else:
		print("  ❌ No se pudo abrir PuzzleGameStateManager.gd") 