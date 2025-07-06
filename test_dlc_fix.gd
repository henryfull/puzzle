extends Node

# Script simple para verificar que los DLCs están funcionando correctamente
# Ejecutar desde el menú principal o desde donde sea necesario

func _ready():
	print("=== TEST DLC FIX ===")
	test_dlc_loading()

func test_dlc_loading():
	print("Verificando carga de DLCs...")
	
	# Verificar que ProgressManager existe
	if not has_node("/root/ProgressManager"):
		print("ERROR: ProgressManager no encontrado")
		return
	
	var progress_manager = get_node("/root/ProgressManager")
	
	# Obtener todos los packs
	var packs = progress_manager.get_all_packs_with_progress()
	print("Packs cargados: ", packs.size())
	
	# Verificar cada pack
	for pack in packs:
		print("Pack: ", pack.name, " (ID: ", pack.id, ")")
		print("  - Desbloqueado: ", pack.get("unlocked", false))
		print("  - Comprado: ", pack.get("purchased", false))
		print("  - Puzzles: ", pack.puzzles.size() if pack.has("puzzles") else 0)
		
		# Verificar que está disponible
		if progress_manager.is_pack_available(pack.id):
			print("  - ✓ DISPONIBLE")
		else:
			print("  - ✗ NO DISPONIBLE")
	
	print("=== FIN TEST ===")

# Función para forzar reset y recarga
func force_reset_and_reload():
	print("Forzando reset y recarga de DLCs...")
	
	if has_node("/root/ProgressManager"):
		var progress_manager = get_node("/root/ProgressManager")
		progress_manager.force_load_all_dlcs()
		print("DLCs recargados forzosamente")
	else:
		print("ERROR: ProgressManager no encontrado") 