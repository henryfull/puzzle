extends Node
@onready var progress_manager = get_node("/root/ProgressManager")




func setup_result_panels(panels_data):

	# Configurar cada panel
	for panel_data in panels_data:
		var panel = panel_data.panel
		if panel:
			var current_value = panel_data.current_value
			var is_time = panel_data.is_time
			# Determinar el mejor valor
			var best_value = current_value  # Por defecto, valor actual
			# Configurar el panel
			configure_result_panel(
				panel, 
				panel_data.title, 
				current_value, 
				best_value, 
				false, 
				is_time, 
				panel_data.color
			)

# Función genérica para configurar un panel de resultados
func configure_result_panel(panel: PanelContainer, title_text: String, current_value, best_value, is_new_record: bool, is_time: bool = false, panel_color: Color = Color(0.1, 0.7, 0.3, 1)):
	if panel:
		# Establecer el título
		panel.titleLabel.text = tr(title_text)

		# Formatear y establecer el valor actual
		var value_text = ""
		if is_time:
			var minutes = int(current_value) / 60
			var seconds = int(current_value) % 60
			value_text = "%02d:%02d" % [minutes, seconds]
		else:
			value_text = str(current_value)
		
		panel.value.text = value_text
		panel.bestValue.visible = false
		var panel_style = panel.get("theme_override_styles/panel")
		if panel_style is StyleBoxFlat:
			# Guardar el color original para la animación
			var original_color = panel_style.bg_color
			
			# Establecer un color más brillante
			panel_style.bg_color = panel_color
			
			# Crear una animación sencilla de pulso
			var tween = create_tween().set_loops(3)
			var highlight_color = panel_color.lightened(0.2)
			tween.tween_property(panel_style, "bg_color", highlight_color, 0.5)
			tween.tween_property(panel_style, "bg_color", original_color, 0.5)
