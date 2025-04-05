extends Node

signal purchase_confirmed(pack)
signal purchase_canceled()

# Referencia al ProgressManager
var progress_manager

func _ready():
	progress_manager = get_node("/root/ProgressManager")

# Muestra el diálogo de confirmación de compra
func request_purchase(pack):
	print("PackPurchaseManager: Se solicitó la compra del pack: " + pack.name)
	
	# Mostrar un diálogo de confirmación
	var dialog = AcceptDialog.new()
	dialog.title = "Comprar Pack"
	dialog.dialog_text = "¿Quieres comprar el pack '" + pack.name + "'?"
	dialog.add_button("Cancelar", true, "cancel")
	dialog.add_button("Comprar", false, "purchase")
	
	# Conectar señales
	dialog.connect("confirmed", Callable(self, "_on_purchase_confirmed").bind(pack))
	dialog.connect("canceled", Callable(self, "_on_purchase_canceled"))
	
	# Añadir al árbol y mostrar
	var current_scene = get_tree().current_scene
	current_scene.add_child(dialog)
	dialog.popup_centered()

# Lógica para confirmar la compra
func _on_purchase_confirmed(pack):
	print("PackPurchaseManager: Compra confirmada para el pack: " + pack.name)
	
	# Marcar el pack como comprado usando ProgressManager
	if progress_manager.has_method("purchase_pack"):
		progress_manager.purchase_pack(pack.id)
		print("PackPurchaseManager: Pack comprado con éxito: " + pack.name)
		
		# Mostrar mensaje de éxito
		var success_dialog = AcceptDialog.new()
		success_dialog.title = "Compra Exitosa"
		success_dialog.dialog_text = "¡Has comprado el pack '" + pack.name + "'! Ya puedes acceder a sus puzzles."
		
		var current_scene = get_tree().current_scene
		current_scene.add_child(success_dialog)
		success_dialog.popup_centered()
		
		# Emitir señal de compra confirmada
		emit_signal("purchase_confirmed", pack)
	else:
		print("PackPurchaseManager: ERROR - No se pudo comprar el pack - Método purchase_pack no encontrado")
		
		# Mostrar mensaje de error
		var error_dialog = AcceptDialog.new()
		error_dialog.title = "Error de Compra"
		error_dialog.dialog_text = "No se pudo completar la compra. Por favor, inténtalo de nuevo más tarde."
		
		var current_scene = get_tree().current_scene
		current_scene.add_child(error_dialog)
		error_dialog.popup_centered()

# Lógica cuando se cancela la compra
func _on_purchase_canceled():
	print("PackPurchaseManager: Compra cancelada")
	emit_signal("purchase_canceled") 