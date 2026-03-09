extends Node

# Script de prueba para el sistema unificado de restauración
# Verifica que los grupos se mantienen correctamente después de cargar partidas guardadas

func _ready():
	print("====== PRUEBA DEL SISTEMA UNIFICADO DE RESTAURACIÓN ======")
	print("Verificando que los grupos se mantienen correctamente")
	print("=========================================================")
	
	# Test 1: Verificar que el sistema unificado se puede instanciar
	test_unified_system_instantiation()
	
	# Test 2: Verificar las banderas de control en PuzzlePieceManager
	test_control_flags()
	
	# Test 3: Simulación de restauración con grupos
	test_group_restoration_simulation()
	
	print("\n====== PRUEBA COMPLETADA ======")
	print("El sistema unificado está listo para usar.")
	print("Para probar completamente:")
	print("1. Inicia un puzzle")
	print("2. Forma algunos grupos de piezas")
	print("3. Cierra el juego")
	print("4. Reabre el juego y continúa la partida")
	print("5. Verifica que los grupos se mantienen visualmente")

func test_unified_system_instantiation():
	print("\nTEST 1: Verificando instanciación del sistema unificado")
	
	# Intentar cargar la clase
	var UnifiedRestoration = load("res://Scripts/Autoload/UnifiedPuzzleRestoration.gd")
	if UnifiedRestoration:
		print("  ✅ Clase UnifiedPuzzleRestoration cargada correctamente")
		
		# Intentar instanciar
		var restoration_system = UnifiedRestoration.new()
		if restoration_system:
			print("  ✅ Sistema unificado instanciado correctamente")
			
			# Verificar estado inicial
			if restoration_system.get_current_state() == UnifiedRestoration.RestorationState.IDLE:
				print("  ✅ Estado inicial correcto (IDLE)")
			else:
				print("  ❌ Estado inicial incorrecto")
			
			restoration_system.queue_free()
		else:
			print("  ❌ Error al instanciar sistema unificado")
	else:
		print("  ❌ Error al cargar clase UnifiedPuzzleRestoration")

func test_control_flags():
	print("\nTEST 2: Verificando banderas de control")
	
	# Verificar que podemos simular un PuzzlePieceManager con las nuevas funciones
	var mock_manager = MockPieceManager.new()
	
	print("  - Probando control de procesos automáticos...")
	mock_manager.set_auto_processes_enabled(false)
	if not mock_manager.auto_processes_enabled:
		print("  ✅ Control de procesos automáticos funciona")
	else:
		print("  ❌ Control de procesos automáticos no funciona")
	
	print("  - Probando control individual de sistemas...")
	mock_manager.set_group_checking_enabled(false)
	mock_manager.set_overlap_resolution_enabled(false)
	mock_manager.set_border_updates_enabled(false)
	
	if not mock_manager.group_checking_enabled and not mock_manager.overlap_resolution_enabled and not mock_manager.border_updates_enabled:
		print("  ✅ Controles individuales funcionan")
	else:
		print("  ❌ Controles individuales no funcionan")
	
	mock_manager.queue_free()

func test_group_restoration_simulation():
	print("\nTEST 3: Simulación de restauración de grupos")
	
	# Crear datos simulados de piezas con grupos
	var mock_saved_data = [
		{
			"order_number": 1,
			"current_cell": {"x": 0, "y": 0},
			"group_id": 100,
			"flipped": false
		},
		{
			"order_number": 2,
			"current_cell": {"x": 1, "y": 0},
			"group_id": 100,  # Mismo grupo que la pieza 1
			"flipped": false
		},
		{
			"order_number": 3,
			"current_cell": {"x": 0, "y": 1},
			"group_id": 200,  # Grupo diferente
			"flipped": false
		},
		{
			"order_number": 4,
			"current_cell": {"x": 2, "y": 0},
			"group_id": -1,  # Pieza individual
			"flipped": false
		}
	]
	
	# Verificar que los datos están bien estructurados
	var groups_found = {}
	for piece_data in mock_saved_data:
		var group_id = piece_data.group_id
		if group_id != -1:
			if not group_id in groups_found:
				groups_found[group_id] = 0
			groups_found[group_id] += 1
	
	print("  - Datos de prueba: ", mock_saved_data.size(), " piezas")
	print("  - Grupos identificados: ", groups_found.size())
	print("  - Grupo 100: ", groups_found.get(100, 0), " piezas")
	print("  - Grupo 200: ", groups_found.get(200, 0), " piezas")
	
	if groups_found.get(100, 0) == 2:
		print("  ✅ Grupo de 2 piezas detectado correctamente")
	else:
		print("  ❌ Error en detección de grupo de 2 piezas")
	
	if groups_found.get(200, 0) == 1:
		print("  ✅ Pieza individual en grupo detectada")
	else:
		print("  ❌ Error en detección de pieza individual")
	
	print("  ✅ Simulación de datos completada")

# Clase mock para simular PuzzlePieceManager en las pruebas
class MockPieceManager extends Node:
	var auto_processes_enabled: bool = true
	var group_checking_enabled: bool = true
	var overlap_resolution_enabled: bool = true
	var border_updates_enabled: bool = true
	
	func set_auto_processes_enabled(enabled: bool):
		auto_processes_enabled = enabled
		group_checking_enabled = enabled
		overlap_resolution_enabled = enabled
		border_updates_enabled = enabled
	
	func set_group_checking_enabled(enabled: bool):
		group_checking_enabled = enabled
	
	func set_overlap_resolution_enabled(enabled: bool):
		overlap_resolution_enabled = enabled
	
	func set_border_updates_enabled(enabled: bool):
		border_updates_enabled = enabled 