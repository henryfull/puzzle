extends Control

# Señal para notificar al padre que se ha completado una compra
signal purchase_completed

const PACKS_DATA_FILE = "res://PacksData/sample_packs.json"

func registerPurcharse():
	# Verificar si los packs se cargaron correctamente
	# Intentar cargar directamente el archivo JSON
	var file = FileAccess.open(PACKS_DATA_FILE, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json_result = JSON.parse_string(json_text)
		if json_result and json_result.has("dlc_packs_names"):
			GLOBAL.dlc_packs = json_result.dlc_packs_names
			# Guardar la configuración global
			GLOBAL.save_settings()

func _on_buy_button_pressed() -> void:
	# Lista de DLCs disponibles para comprar
	var dlc_to_purchase = ["numbers", "wild-animals", "farm-animals", "artistic-cities", "wild-animals-cartoon"]
	
	# Verificar si tenemos acceso al ProgressManager
	if has_node("/root/ProgressManager"):
		var progress_manager = get_node("/root/ProgressManager")
		
		if dlc_to_purchase.size() > 0:
			print("DialogBuy: Registrando compra de ", dlc_to_purchase.size(), " packs DLC")
			
			# 1. Primero registrar los DLCs como comprados (esto los añade a settings y GLOBAL)
			registerPurcharse()
			
			# 2. Ahora que están registrados como comprados, cargarlos
			var loaded_dlc_packs = progress_manager.load_dlc_packs()
			print("DialogBuy: Se han cargado ", loaded_dlc_packs.size(), " packs DLC después de la compra")
			
			# 3. Refrescar los datos de DLCs para asegurar que todo está actualizado
			progress_manager.refresh_dlc_packs()
			
			# Emitir la señal para que el padre recargue los packs
			emit_signal("purchase_completed")
			
			# Cerrar el diálogo
			self.queue_free()
		else:
			print("DialogBuy: No hay DLCs para comprar")
			self.queue_free()
	else:
		print("DialogBuy: ERROR - No se encontró el ProgressManager")
		self.queue_free()


func _on_cancel_button_pressed() -> void:
	self.queue_free()
