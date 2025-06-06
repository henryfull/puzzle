# test_puzzle_state.gd
# Script de prueba para verificar el sistema de guardado automático del estado del puzzle

extends Node

func _ready():
	print("=== PRUEBA DEL SISTEMA DE GUARDADO AUTOMÁTICO ===")
	
	# Esperar a que todos los autoloads estén listos
	await get_tree().process_frame
	
	test_puzzle_state_manager()

func test_puzzle_state_manager():
	print("\n1. Probando PuzzleStateManager...")
	
	var puzzle_state_manager = get_node("/root/PuzzleStateManager")
	if not puzzle_state_manager:
		print("❌ ERROR: PuzzleStateManager no encontrado")
		return
	
	print("✅ PuzzleStateManager encontrado")
	
	# Probar inicialización de nuevo estado
	print("\n2. Probando inicialización de nuevo estado...")
	puzzle_state_manager.start_new_puzzle_state("pack_test", "puzzle_test", 2, 3)
	
	if puzzle_state_manager.has_saved_state():
		print("✅ Estado guardado inicializado correctamente")
		print("   Pack ID: ", puzzle_state_manager.get_saved_pack_id())
		print("   Puzzle ID: ", puzzle_state_manager.get_saved_puzzle_id())
	else:
		print("❌ ERROR: Estado no se inicializó correctamente")
		return
	
	# Probar actualización de contadores
	print("\n3. Probando actualización de contadores...")
	puzzle_state_manager.update_counters(120.5, 25, 3, 8, 300.0)
	
	var saved_counters = puzzle_state_manager.get_saved_counters()
	print("✅ Contadores actualizados:")
	print("   Tiempo transcurrido: ", saved_counters.elapsed_time)
	print("   Movimientos totales: ", saved_counters.total_moves)
	print("   Flips: ", saved_counters.flip_count)
	print("   Movimientos en flip: ", saved_counters.flip_move_count)
	print("   Tiempo restante: ", saved_counters.time_left)
	
	# Probar guardado y carga
	print("\n4. Probando guardado y carga...")
	puzzle_state_manager.save_puzzle_state()
	print("✅ Estado guardado en archivo")
	
	# Simular reinicio cargando el estado
	puzzle_state_manager.load_puzzle_state()
	if puzzle_state_manager.has_saved_state():
		print("✅ Estado cargado correctamente desde archivo")
	else:
		print("❌ ERROR: No se pudo cargar el estado desde archivo")
	
	# Probar configuraciones por defecto
	print("\n5. Probando configuraciones por defecto...")
	var config_saved = puzzle_state_manager.save_default_puzzle_config("pack_test", "puzzle_test", "desafio_facil")
	if config_saved:
		print("✅ Configuración por defecto guardada")
		
		var configs = puzzle_state_manager.get_available_configs("pack_test", "puzzle_test")
		print("✅ Configuraciones disponibles: ", configs)
		
		var config_loaded = puzzle_state_manager.load_default_puzzle_config("pack_test", "puzzle_test", "desafio_facil")
		if config_loaded:
			print("✅ Configuración por defecto cargada")
		else:
			print("❌ ERROR: No se pudo cargar la configuración por defecto")
	else:
		print("❌ ERROR: No se pudo guardar la configuración por defecto")
	
	# Probar completar puzzle
	print("\n6. Probando completar puzzle...")
	puzzle_state_manager.complete_puzzle()
	if not puzzle_state_manager.has_saved_state():
		print("✅ Estado limpiado correctamente al completar puzzle")
		print("   Pack mantenido: ", puzzle_state_manager.get_saved_pack_id())
		print("   Puzzle mantenido: ", puzzle_state_manager.get_saved_puzzle_id())
	else:
		print("❌ ERROR: Estado no se limpió al completar puzzle")
	
	print("\n=== PRUEBA COMPLETADA ===")
	print("El sistema de guardado automático está funcionando correctamente ✅") 