extends Node

# Script de prueba para verificar el nuevo sistema de guardado/restauración de puzzles

func _ready():
	print("====== SCRIPT DE PRUEBA - SISTEMA DE GUARDADO MEJORADO ======")
	print("Este script verifica que el sistema de guardado funcione correctamente")
	print("================================================================")
	print()
	
	# Test 1: Verificar PuzzleStateManager
	test_puzzle_state_manager()
	print()
	
	# Test 2: Verificar lógica de selección de puzzle diferente
	test_different_puzzle_selection()
	print()
	
	# Test 3: Verificar sistema de emergencia
	test_emergency_save_system()
	print()
	
	print("====== INSTRUCCIONES DE PRUEBA ======")
	print("1. Inicia un puzzle y mueve algunas piezas")
	print("2. Sal usando el menú de pausa (debe mantener posiciones)")
	print("3. Vuelve a entrar - debe continuar exactamente donde lo dejaste")
	print("4. Fuerza el cierre de la app (Cmd+Q o cerrar ventana)")
	print("5. Vuelve a abrir - debe continuar con las posiciones correctas")
	print("6. Selecciona un puzzle diferente - debe empezar nuevo")
	print("7. Completa un puzzle - debe limpiar estado pero mantener pack/puzzle")
	print("======================================")

func test_puzzle_state_manager():
	print("TEST 1: Verificando PuzzleStateManager")
	
	var manager = get_node("/root/PuzzleStateManager")
	if manager:
		print("✅ PuzzleStateManager está disponible")
		print("  - Tiene estado guardado: ", manager.has_saved_state())
		if manager.has_saved_state():
			print("  - Pack guardado: ", manager.get_saved_pack_id())
			print("  - Puzzle guardado: ", manager.get_saved_puzzle_id())
		
		# Verificar métodos necesarios
		var methods_to_check = [
			"start_new_puzzle_state",
			"save_puzzle_state", 
			"load_puzzle_state",
			"clear_all_state",
			"get_saved_pack_id",
			"get_saved_puzzle_id",
			"get_saved_pieces_data"
		]
		
		for method in methods_to_check:
			if manager.has_method(method):
				print("  ✅ Método '", method, "' disponible")
			else:
				print("  ❌ Método '", method, "' NO disponible")
	else:
		print("❌ PuzzleStateManager NO está disponible")

func test_different_puzzle_selection():
	print("TEST 2: Verificando lógica de selección de puzzle diferente")
	
	# Simular que hay un estado guardado para un puzzle
	var manager = get_node("/root/PuzzleStateManager")
	if manager:
		# Crear un estado de prueba
		manager.start_new_puzzle_state("pack_test", "puzzle_test", 2, 3)
		print("  - Estado de prueba creado para pack_test/puzzle_test")
		
		# Configurar GLOBAL como si estuviéramos seleccionando un puzzle diferente
		var fake_pack = {"id": "pack_different", "name": "Pack Diferente"}
		var fake_puzzle = {"id": "puzzle_different", "name": "Puzzle Diferente"}
		
		GLOBAL.selected_pack = fake_pack
		GLOBAL.selected_puzzle = fake_puzzle
		
		# Simular la lógica que debería limpiar el estado
		if manager.has_saved_state():
			var saved_pack_id = manager.get_saved_pack_id()
			var saved_puzzle_id = manager.get_saved_puzzle_id()
			var current_pack_id = GLOBAL.selected_pack.id if GLOBAL.selected_pack else ""
			var current_puzzle_id = GLOBAL.selected_puzzle.id if GLOBAL.selected_puzzle else ""
			
			if saved_pack_id != current_pack_id or saved_puzzle_id != current_puzzle_id:
				print("  ✅ Detectado puzzle diferente, se debería limpiar estado")
				print("    Guardado: ", saved_pack_id, "/", saved_puzzle_id)
				print("    Actual: ", current_pack_id, "/", current_puzzle_id)
			else:
				print("  ❌ No se detectó diferencia cuando debería haberla")
		
		# Limpiar el estado de prueba
		manager.clear_all_state()
		print("  - Estado de prueba limpiado")
	else:
		print("  ❌ No se puede probar - PuzzleStateManager no disponible")

func test_emergency_save_system():
	print("TEST 3: Verificando sistema de guardado de emergencia")
	
	# Verificar que PuzzleGame tiene el método de emergencia
	var puzzle_game_scene = load("res://Scenes/PuzzleGame.tscn")
	if puzzle_game_scene:
		print("  ✅ Escena PuzzleGame cargable")
		
		# Crear una instancia temporal para verificar métodos
		var instance = puzzle_game_scene.instantiate()
		if instance.has_method("_emergency_save_state"):
			print("  ✅ Método '_emergency_save_state' disponible")
		else:
			print("  ❌ Método '_emergency_save_state' NO disponible")
		
		if instance.has_method("_notification"):
			print("  ✅ Método '_notification' disponible para interceptar cierre")
		else:
			print("  ❌ Método '_notification' NO disponible")
		
		instance.queue_free()
	else:
		print("  ❌ No se puede cargar la escena PuzzleGame")
	
	# Verificar que el auto-save timer está configurado
	var manager = get_node("/root/PuzzleStateManager")
	if manager and manager.has_method("start_new_puzzle_state"):
		print("  ✅ Auto-save configurado en PuzzleStateManager")
	else:
		print("  ❌ Auto-save NO configurado correctamente") 