extends Node

# Script de diagnóstico avanzado para identificar problemas en la continuación de puzzles
# Ejecutar desde la consola del debugger con: debug_puzzle_continuation.run_full_diagnosis()

var diagnosis_results = {}

func _ready():
	print("=== DIAGNÓSTICO AVANZADO DE CONTINUACIÓN DE PUZZLES ===")
	print("Usa debug_puzzle_continuation.run_full_diagnosis() desde la consola")
	print("O permite que se ejecute automáticamente en 3 segundos...")
	
	# Auto-ejecutar después de 3 segundos si no se hace manualmente
	await get_tree().create_timer(3.0).timeout
	run_full_diagnosis()

func run_full_diagnosis():
	print("\n🔍 INICIANDO DIAGNÓSTICO COMPLETO...")
	diagnosis_results.clear()
	
	# Paso 1: Verificar managers principales
	verify_managers()
	
	# Paso 2: Verificar estado del guardado
	verify_save_state()
	
	# Paso 3: Simular proceso de guardado
	simulate_save_process()
	
	# Paso 4: Verificar integridad de datos
	verify_data_integrity()
	
	# Paso 5: Verificar sistema de entrada
	verify_input_system()
	
	# Mostrar resultados finales
	show_diagnosis_results()

func verify_managers():
	print("\n📋 VERIFICANDO MANAGERS PRINCIPALES...")
	diagnosis_results["managers"] = {}
	
	# Verificar PuzzleStateManager
	var state_manager = get_node("/root/PuzzleStateManager")
	if state_manager:
		diagnosis_results["managers"]["state_manager"] = "✅ Disponible"
		
		# Verificar métodos críticos
		if state_manager.has_method("_validate_piece_data"):
			diagnosis_results["managers"]["validation_method"] = "✅ Método de validación disponible"
		else:
			diagnosis_results["managers"]["validation_method"] = "❌ Método de validación faltante"
	else:
		diagnosis_results["managers"]["state_manager"] = "❌ No disponible"
	
	# Verificar si hay un puzzle game activo
	var puzzle_games = get_tree().get_nodes_in_group("puzzle_game")
	if puzzle_games.size() > 0:
		var puzzle_game = puzzle_games[0]
		diagnosis_results["managers"]["puzzle_game"] = "✅ PuzzleGame activo encontrado"
		
		# Verificar PuzzlePieceManager
		if puzzle_game.has_method("get_pieces_data"):
			diagnosis_results["managers"]["piece_manager"] = "✅ PieceManager disponible"
		else:
			diagnosis_results["managers"]["piece_manager"] = "❌ PieceManager no disponible"
		
		# Verificar InputHandler
		if puzzle_game.get("input_handler"):
			diagnosis_results["managers"]["input_handler"] = "✅ InputHandler disponible"
		else:
			diagnosis_results["managers"]["input_handler"] = "❌ InputHandler no disponible"
	else:
		diagnosis_results["managers"]["puzzle_game"] = "❌ No hay PuzzleGame activo"

func verify_save_state():
	print("\n💾 VERIFICANDO ESTADO DE GUARDADO...")
	diagnosis_results["save_state"] = {}
	
	var state_manager = get_node("/root/PuzzleStateManager")
	if not state_manager:
		diagnosis_results["save_state"]["status"] = "❌ StateManager no disponible"
		return
	
	# Verificar si hay estado guardado
	if state_manager.has_saved_state():
		diagnosis_results["save_state"]["has_state"] = "✅ Hay estado guardado"
		
		# Verificar datos específicos
		var saved_pieces = state_manager.get_saved_pieces_data()
		diagnosis_results["save_state"]["pieces_count"] = str(saved_pieces.size()) + " piezas guardadas"
		
		# Verificar estructura de la primera pieza
		if saved_pieces.size() > 0:
			var first_piece = saved_pieces[0]
			var required_fields = ["order_number", "current_position", "current_cell", "group_id"]
			var missing_fields = []
			
			for field in required_fields:
				if not first_piece.has(field):
					missing_fields.append(field)
			
			if missing_fields.is_empty():
				diagnosis_results["save_state"]["data_structure"] = "✅ Estructura de datos correcta"
			else:
				diagnosis_results["save_state"]["data_structure"] = "❌ Campos faltantes: " + str(missing_fields)
		
		# Verificar información de current_cell específicamente
		var pieces_with_cell_data = 0
		var pieces_with_valid_cell = 0
		
		for piece_data in saved_pieces:
			if piece_data.has("current_cell") and piece_data.current_cell != null:
				pieces_with_cell_data += 1
				if piece_data.current_cell.has("x") and piece_data.current_cell.has("y"):
					pieces_with_valid_cell += 1
		
		diagnosis_results["save_state"]["cell_data_status"] = str(pieces_with_valid_cell) + "/" + str(saved_pieces.size()) + " piezas con current_cell válido"
		
	else:
		diagnosis_results["save_state"]["has_state"] = "❌ No hay estado guardado"

func simulate_save_process():
	print("\n🔄 SIMULANDO PROCESO DE GUARDADO...")
	diagnosis_results["save_simulation"] = {}
	
	var puzzle_games = get_tree().get_nodes_in_group("puzzle_game")
	if puzzle_games.size() == 0:
		diagnosis_results["save_simulation"]["status"] = "❌ No hay PuzzleGame para simular"
		return
	
	var puzzle_game = puzzle_games[0]
	var piece_manager = puzzle_game.get("piece_manager")
	
	if not piece_manager:
		diagnosis_results["save_simulation"]["piece_manager"] = "❌ PieceManager no disponible"
		return
	
	# Simular obtención de datos de piezas
	var pieces = piece_manager.get_pieces()
	diagnosis_results["save_simulation"]["pieces_found"] = str(pieces.size()) + " piezas encontradas"
	
	if pieces.size() > 0:
		var first_piece = pieces[0]
		
		# Verificar datos de la pieza individual
		if first_piece.node and first_piece.node.has_method("get_puzzle_piece_data"):
			var piece_data = first_piece.node.get_puzzle_piece_data()
			
			# Verificar si get_puzzle_piece_data incluye current_cell
			if piece_data.has("current_cell") and piece_data.current_cell != null:
				diagnosis_results["save_simulation"]["piece_data_cell"] = "✅ get_puzzle_piece_data incluye current_cell"
			else:
				diagnosis_results["save_simulation"]["piece_data_cell"] = "❌ get_puzzle_piece_data NO incluye current_cell válido"
			
			# Verificar diferencia entre current_cell del manager vs del nodo
			var manager_cell = first_piece.current_cell
			var node_cell_data = piece_data.get("current_cell", null)
			
			if node_cell_data:
				var node_cell = Vector2(node_cell_data.x, node_cell_data.y)
				if manager_cell == node_cell:
					diagnosis_results["save_simulation"]["cell_sync"] = "✅ current_cell sincronizado entre manager y nodo"
				else:
					diagnosis_results["save_simulation"]["cell_sync"] = "❌ DESINCRONIZACIÓN: Manager=" + str(manager_cell) + ", Nodo=" + str(node_cell)
			else:
				diagnosis_results["save_simulation"]["cell_sync"] = "❌ No hay current_cell en datos del nodo"

func verify_data_integrity():
	print("\n🔍 VERIFICANDO INTEGRIDAD DE DATOS...")
	diagnosis_results["data_integrity"] = {}
	
	var puzzle_games = get_tree().get_nodes_in_group("puzzle_game")
	if puzzle_games.size() == 0:
		diagnosis_results["data_integrity"]["status"] = "❌ No hay PuzzleGame activo"
		return
	
	var puzzle_game = puzzle_games[0]
	var piece_manager = puzzle_game.get("piece_manager")
	
	if not piece_manager:
		diagnosis_results["data_integrity"]["piece_manager"] = "❌ PieceManager no disponible"
		return
	
	var pieces = piece_manager.get_pieces()
	
	# Verificar superposiciones
	var overlaps = _check_for_overlaps(pieces)
	if overlaps == 0:
		diagnosis_results["data_integrity"]["overlaps"] = "✅ Sin superposiciones detectadas"
	else:
		diagnosis_results["data_integrity"]["overlaps"] = "❌ " + str(overlaps) + " superposiciones detectadas"
	
	# Verificar estados de arrastre
	var dragging_pieces = 0
	var invalid_drag_start = 0
	
	for piece_obj in pieces:
		if piece_obj.dragging:
			dragging_pieces += 1
		
		if piece_obj.drag_start_cell != piece_obj.current_cell:
			invalid_drag_start += 1
	
	diagnosis_results["data_integrity"]["dragging_state"] = str(dragging_pieces) + " piezas en estado de arrastre"
	diagnosis_results["data_integrity"]["drag_sync"] = str(invalid_drag_start) + " piezas con drag_start_cell desincronizado"

func verify_input_system():
	print("\n🎮 VERIFICANDO SISTEMA DE ENTRADA...")
	diagnosis_results["input_system"] = {}
	
	var puzzle_games = get_tree().get_nodes_in_group("puzzle_game")
	if puzzle_games.size() == 0:
		diagnosis_results["input_system"]["status"] = "❌ No hay PuzzleGame activo"
		return
	
	var puzzle_game = puzzle_games[0]
	var input_handler = puzzle_game.get("input_handler")
	
	if input_handler:
		# Verificar si el input handler está procesando eventos
		var is_processing_input = input_handler.is_processing_unhandled_input()
		var is_processing_unhandled = input_handler.is_processing_input()
		
		diagnosis_results["input_system"]["processing_state"] = "Input: " + str(is_processing_input) + ", Unhandled: " + str(is_processing_unhandled)
		
		# Verificar si las piezas pueden recibir eventos
		var piece_manager = puzzle_game.get("piece_manager")
		if piece_manager:
			var pieces = piece_manager.get_pieces()
			var pickable_pieces = 0
			
			for piece_obj in pieces:
				if piece_obj.node and piece_obj.node.has_node("Area2D"):
					var area2d = piece_obj.node.get_node("Area2D")
					if area2d.input_pickable:
						pickable_pieces += 1
			
			diagnosis_results["input_system"]["pickable_pieces"] = str(pickable_pieces) + "/" + str(pieces.size()) + " piezas pueden recibir eventos"
	else:
		diagnosis_results["input_system"]["handler"] = "❌ InputHandler no disponible"

func _check_for_overlaps(pieces: Array) -> int:
	var cell_usage = {}
	var overlaps = 0
	
	for piece_obj in pieces:
		if not piece_obj or not piece_obj.node:
			continue
		
		var cell_key = str(piece_obj.current_cell.x) + "_" + str(piece_obj.current_cell.y)
		
		if cell_key in cell_usage:
			overlaps += 1
		else:
			cell_usage[cell_key] = piece_obj
	
	return overlaps

func show_diagnosis_results():
	print("\n📊 RESULTADOS DEL DIAGNÓSTICO:")
	print("═══════════════════════════════")
	
	for category in diagnosis_results.keys():
		print("\n🔹 " + category.to_upper() + ":")
		var results = diagnosis_results[category]
		
		for key in results.keys():
			print("  " + key + ": " + str(results[key]))
	
	print("\n📋 RECOMENDACIONES:")
	print("═══════════════════════")
	
	# Generar recomendaciones basadas en los resultados
	var recommendations = generate_recommendations()
	for rec in recommendations:
		print("• " + rec)
	
	print("\n🔧 ACCIONES SUGERIDAS:")
	print("═══════════════════════")
	print("1. Si hay current_cell faltante: El problema está en get_puzzle_piece_data()")
	print("2. Si hay superposiciones: El problema está en la restauración del grid")
	print("3. Si hay desincronización: El problema está en sync_drag_start_cells()")
	print("4. Si hay piezas arrastrándose: El problema está en disable_input_events()")

func generate_recommendations() -> Array:
	var recommendations = []
	
	# Verificar problemas críticos
	if diagnosis_results.has("save_state") and diagnosis_results.save_state.has("cell_data_status"):
		var cell_status = diagnosis_results.save_state.cell_data_status
		if "0/" in cell_status:
			recommendations.append("CRÍTICO: Ninguna pieza tiene current_cell válido en datos guardados")
	
	if diagnosis_results.has("data_integrity") and diagnosis_results.data_integrity.has("overlaps"):
		var overlaps = diagnosis_results.data_integrity.overlaps
		if "❌" in overlaps:
			recommendations.append("IMPORTANTE: Resolver superposiciones antes de continuar")
	
	if diagnosis_results.has("save_simulation") and diagnosis_results.save_simulation.has("piece_data_cell"):
		var piece_cell = diagnosis_results.save_simulation.piece_data_cell
		if "❌" in piece_cell:
			recommendations.append("CRÍTICO: Reparar get_puzzle_piece_data() para incluir current_cell")
	
	return recommendations

func _exit_tree():
	print("\n🏁 DIAGNÓSTICO COMPLETADO")
	print("Los resultados han sido mostrados arriba") 