extends Control

const FLIP_DURATION := 0.42
const FLIP_COLLAPSE_SCALE := Vector2(0.06, 0.94)
const FLIP_TILT_DEGREES := 2.4
const FLIP_SHADE_ALPHA := 0.24
const SWIPE_DIRECTION_RATIO := 1.2
const MIN_SWIPE_THRESHOLD := 56.0
const MAX_SWIPE_THRESHOLD := 108.0
const HINT_BUTTON_PULSE_SCALE := Vector2(1.12, 1.12)
const HINT_CARD_NUDGE_SCALE := Vector2(0.96, 0.985)
const HINT_CARD_NUDGE_TILT_DEGREES := 1.35
const HINT_CYCLE_DELAY := 3.8
const HINT_INTRO_DELAY := 0.9
const HINT_SWIPE_DURATION := 0.95
const HINT_HAND_ATLAS_PATH := "res://Assets/Images/GUID/tile_tikitiki_puzzle.png"
const HINT_HAND_ATLAS_REGION := Rect2(272, 474, 101, 101)
const HINT_TRAIL_COLOR := Color(1.0, 0.95, 0.77, 0.78)
const HINT_HAND_COLOR := Color(1.0, 1.0, 1.0, 0.96)

@export var labelNamePuzzle: Label
@export var labelInfo: Label
@export var statsLabel: Label
@export var puzzleImage2D: TextureRect
@export var textFace: Control
@export var flipCard: Control
@export var flipShade: ColorRect
@export var textView: RichTextLabel
@export var labelTitle : Label
@export var expanseImagePanel : Panel
@export var time_label: Label
@export var moves_label: Label
@export var score_label: Label
@export var new_time_label: Label
@export var new_moves_label: Label
@export var new_score_label: Label

# Variables para almacenar los datos del puzzle
var puzzle_data = null
var pack_data = null
var total_moves = 0
var elapsed_time = 0.0  # Nueva variable para el tiempo transcurrido
var difficulty = {"columns": 0, "rows": 0}  # Nueva variable para la dificultad
var current_pack_id = ""
var current_puzzle_id = ""
var progress_manager = null
var flip_count = 0      # Número de flips realizados
var flip_move_count = 0  # Movimientos durante flips

# Variables para datos de puntuación
var score_data = {}     # Datos de puntuación del sistema de scoring

# Referencias a nodos de la interfaz
var image_view = null
var text_view = null
var toggle_button = null
var flip_button_container = null
var showing_image = true

# Variable para detectar si estamos en un dispositivo móvil
var is_mobile = false
var _flip_tween: Tween
var _is_flipping := false
var _is_tracking_swipe := false
var _tracking_pointer_id := -1
var _swipe_start_position := Vector2.ZERO
var _swipe_current_position := Vector2.ZERO
var _rest_card_scale := Vector2.ONE
var _rest_flip_button_scale := Vector2.ONE
var _rest_flip_button_modulate := Color.WHITE
var _has_seen_flip_hint := false
var _hint_button_tween: Tween
var _hint_cycle_tween: Tween
var _hint_swipe_tween: Tween
var _hint_card_tween: Tween
var _hint_overlay: Control
var _hint_hand: TextureRect
var _hint_trail: Line2D
var _hint_swipe_start := Vector2.ZERO
var _hint_swipe_end := Vector2.ZERO

func _ready():
	# Reproducir sonido de victoria
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx("res://Assets/Sounds/SFX/win.wav")
	
	# Detectar si estamos en un dispositivo móvil
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	
	# Obtener referencia al ProgressManager
	progress_manager = get_node("/root/ProgressManager")
	setup_ui()
	
	# Obtener los datos de victoria desde GLOBAL
	if GLOBAL.has_method("get") and GLOBAL.get("victory_data") != null:
		var victory_data = GLOBAL.victory_data
		
		# Cargar los datos del puzzle
		if victory_data.has("puzzle"):
			puzzle_data = victory_data.puzzle
		
		# Cargar los datos del pack
		if victory_data.has("pack"):
			pack_data = victory_data.pack
		
		# Cargar el número de movimientos
		if victory_data.has("total_moves"):
			total_moves = victory_data.total_moves
		
		# Cargar el tiempo transcurrido
		if victory_data.has("elapsed_time"):
			elapsed_time = victory_data.elapsed_time
			
		# Cargar información de dificultad
		if victory_data.has("difficulty"):
			difficulty = victory_data.difficulty
		
		# Cargar los IDs para la navegación
		if victory_data.has("pack_id"):
			current_pack_id = victory_data.pack_id

		# Cargar datos de flips
		if victory_data.has("flip_count"):
			flip_count = victory_data.flip_count

		if victory_data.has("flip_move_count"):
			flip_move_count = victory_data.flip_move_count

		if victory_data.has("puzzle_id"):
			current_puzzle_id = victory_data.puzzle_id
		
		# Cargar datos de puntuación
		if victory_data.has("score_data"):
			score_data = victory_data.score_data
			print("VictoryScreen: Datos de puntuación cargados: ", score_data)
		
		# Limpiar los datos de victoria para evitar problemas si se vuelve a esta escena

	
	# Si tenemos datos del puzzle, mostrarlos
	if puzzle_data != null:
		update_ui_with_puzzle_data()
	else:
		# Si no hay datos, intentar usar GLOBAL.selected_puzzle como respaldo
		if GLOBAL.selected_puzzle != null:
			puzzle_data = GLOBAL.selected_puzzle
			update_ui_with_puzzle_data()
	
	# Mostrar logros desbloqueados si hay alguno
	show_unlocked_achievements()
	
	# Verificar si la dificultad progresiva está habilitada y aumentarla si es el caso
	if GLOBAL.progresive_difficulty == true:
		if GLOBAL.rows < 22:
			GLOBAL.rows += 1
		elif GLOBAL.columns < 10:
			GLOBAL.columns += 1
		# Guardar la configuración actualizada
		GLOBAL.save_settings()
	
	# Configurar todos los paneles de resultados
	setup_result_panels()
	
	# Adaptar la UI para dispositivos móviles
	# adapt_ui_for_device()
	if GLOBAL.has_method("get") and GLOBAL.get("victory_data") != null:
		# Guardar las estadísticas en el ProgressManager
		save_stats_to_progress_manager(GLOBAL.victory_data)
		

# Función para configurar la interfaz básica
func setup_ui():
	image_view = puzzleImage2D
	text_view = textView
	toggle_button = get_node_or_null("CanvasLayer/PanelFlip/MarginContainer/TextureButton")
	flip_button_container = get_node_or_null("CanvasLayer/PanelFlip")

	if flipCard:
		_rest_card_scale = flipCard.scale
		call_deferred("_sync_flip_card_transform")
		call_deferred("_ensure_flip_hint_nodes")

	if flip_button_container:
		_rest_flip_button_scale = flip_button_container.scale
		_rest_flip_button_modulate = flip_button_container.modulate
		call_deferred("_sync_flip_button_transform")

	if image_view:
		image_view.texture = null
		image_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_view.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if textFace:
		textFace.visible = false
		textFace.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if text_view:
		text_view.text = ""
		text_view.bbcode_enabled = true
		text_view.scroll_active = false
		text_view.fit_content = true
		text_view.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		text_view.add_theme_font_size_override("normal_font_size", 20)
		text_view.add_theme_color_override("default_color", Color(0, 0, 0))
		text_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Configurar márgenes para el texto
		text_view.add_theme_constant_override("margin_left", 40)
		text_view.add_theme_constant_override("margin_right", 40)
		text_view.add_theme_constant_override("margin_top", 40)
		text_view.add_theme_constant_override("margin_bottom", 40)
		
		# Configurar el espaciado entre líneas
		text_view.add_theme_constant_override("line_separation", 10)

	if flipShade:
		flipShade.color = Color(0.03, 0.02, 0.08, 1.0)
		flipShade.modulate = Color(1, 1, 1, 0.0)
		flipShade.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_set_card_face_visibility(true)
	_update_flip_availability()

	_refresh_toggle_button_text()

func update_ui_texts():
	if labelTitle:
		labelTitle.text = TranslationServer.translate("common_completed").to_upper()

	update_ui_with_puzzle_data()
	_refresh_toggle_button_text()

func _notification(what):
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		update_ui_texts()
	elif what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_sync_flip_card_transform")
		call_deferred("_sync_flip_button_transform")

func _refresh_toggle_button_text():
	if toggle_button:
		toggle_button.tooltip_text = TranslationServer.translate("common_text") if showing_image else TranslationServer.translate("common_image")

func _input(event):
	if _is_flipping or not flipCard:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_swipe_tracking(event.index, event.position)
		elif _is_tracking_swipe and event.index == _tracking_pointer_id:
			_swipe_current_position = event.position
			_try_flip_from_swipe()
			_reset_swipe_tracking()
	elif event is InputEventScreenDrag and _is_tracking_swipe and event.index == _tracking_pointer_id:
		_swipe_current_position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_swipe_tracking(0, event.position)
		elif _is_tracking_swipe:
			_swipe_current_position = event.position
			_try_flip_from_swipe()
			_reset_swipe_tracking()
	elif event is InputEventMouseMotion and _is_tracking_swipe:
		_swipe_current_position = event.position

func _begin_swipe_tracking(pointer_id: int, position: Vector2) -> void:
	if not _can_flip_card() or not _is_point_inside_flip_card(position):
		return

	_is_tracking_swipe = true
	_tracking_pointer_id = pointer_id
	_swipe_start_position = position
	_swipe_current_position = position

func _reset_swipe_tracking() -> void:
	_is_tracking_swipe = false
	_tracking_pointer_id = -1
	_swipe_start_position = Vector2.ZERO
	_swipe_current_position = Vector2.ZERO

func _try_flip_from_swipe() -> void:
	var drag_delta := _swipe_current_position - _swipe_start_position
	if abs(drag_delta.x) < _get_swipe_threshold():
		return
	if abs(drag_delta.x) <= abs(drag_delta.y) * SWIPE_DIRECTION_RATIO:
		return

	if drag_delta.x < 0.0 and showing_image:
		_flip_card_to(false, -1.0)
	elif drag_delta.x > 0.0 and not showing_image:
		_flip_card_to(true, 1.0)

func _get_swipe_threshold() -> float:
	if not flipCard:
		return MIN_SWIPE_THRESHOLD

	return clamp(flipCard.size.x * 0.18, MIN_SWIPE_THRESHOLD, MAX_SWIPE_THRESHOLD)

func _is_point_inside_flip_card(point: Vector2) -> bool:
	return flipCard.get_global_rect().has_point(point)

# Función para actualizar la interfaz con los datos del puzzle
func update_ui_with_puzzle_data():
	# Actualizar la información de movimientos y tiempo
	var info_label = labelInfo
	if info_label:
		info_label.text = TranslationServer.translate("victory_completed_in_prefix") + " " + str(total_moves) + TranslationServer.translate("victory_moves_suffix") + "\n" + TranslationServer.translate("victory_time_prefix") + " " + _format_time_value(elapsed_time)
	
	# Actualizar la información de estadísticas
	var stats_label = statsLabel
	if stats_label and progress_manager:
		# Obtener las estadísticas del puzzle actual
		var puzzle_stats = progress_manager.get_puzzle_stats(current_pack_id, current_puzzle_id)
		var difficulty_key = _get_difficulty_key()
		
		if puzzle_stats.has(difficulty_key):
			var stats = puzzle_stats[difficulty_key]
			
			var stats_text = "%s: %s\n" % [TranslationServer.translate("stats_best_time"), _format_time_value(stats.best_time)]
			stats_text += "%s: %s\n" % [TranslationServer.translate("stats_best_moves"), str(stats.best_moves)]
			stats_text += "%s: %s" % [TranslationServer.translate("stats_completions"), str(stats.completions)]
			
			stats_label.text = stats_text
		else:
			stats_label.text = TranslationServer.translate("stats_no_previous")
	
	# Actualizar todos los paneles de resultados
	setup_result_panels()
	
	# Actualizar la imagen
	if puzzle_data and puzzle_data.has("image"):
		var image_texture = load(puzzle_data.image)
		if image_texture:
			$CanvasLayer/ExpanseImage/PanelContainer/ImageExpanse.texture = image_texture
			if image_view:
				image_view.texture = image_texture
	
	# Actualizar el nombre del puzzle
	if puzzle_data and puzzle_data.has("name"):
		var name_label = labelNamePuzzle
		if name_label:
			name_label.text = TranslationServer.translate(puzzle_data.name).to_upper()
			name_label.visible = true
	
	# Actualizar el texto descriptivo
	if puzzle_data and puzzle_data.has("description") and text_view:
		var description = puzzle_data.description
		var localized_description = TranslationServer.translate(description).strip_edges()
		text_view.text = _format_description_text(localized_description)
	
	# Verificar si hay un siguiente puzzle disponible
	var next_button: BaseButton = get_node_or_null("CanvasLayer/Footer/HBoxContainer/PanelNextButton/MarginContainer/TextureButton")
	var legacy_next_button: BaseButton = get_node_or_null("CanvasLayer/Footer/HBoxContainer/Siguiente")
	if progress_manager:
		var next_puzzle = progress_manager.get_next_unlocked_puzzle(current_pack_id, current_puzzle_id)
		var has_next_puzzle := next_puzzle != null
		if next_button:
			next_button.disabled = not has_next_puzzle
			next_button.modulate = Color.WHITE if has_next_puzzle else Color(1, 1, 1, 0.35)
		if legacy_next_button:
			legacy_next_button.disabled = not has_next_puzzle
			legacy_next_button.modulate = Color.WHITE if has_next_puzzle else Color(1, 1, 1, 0.35)

	_update_flip_availability()

# Función para alternar entre la vista de imagen y texto
func _on_toggle_view_pressed():
	_flip_card_to(not showing_image)

func _sync_flip_card_transform() -> void:
	if not flipCard:
		return

	flipCard.pivot_offset = flipCard.size * 0.5
	_update_flip_hint_layout()
	if not _is_flipping:
		flipCard.scale = _rest_card_scale
		flipCard.rotation = 0.0

func _sync_flip_button_transform() -> void:
	if not flip_button_container:
		return

	flip_button_container.pivot_offset = flip_button_container.size * 0.5
	if not _hint_button_tween:
		flip_button_container.scale = _rest_flip_button_scale
		flip_button_container.modulate = _rest_flip_button_modulate

func _ensure_flip_hint_nodes() -> void:
	if not flipCard or _hint_overlay:
		return

	_hint_overlay = Control.new()
	_hint_overlay.name = "SwipeHintOverlay"
	_hint_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_overlay.clip_contents = true
	_hint_overlay.visible = false
	flipCard.add_child(_hint_overlay)

	_hint_trail = Line2D.new()
	_hint_trail.name = "SwipeHintTrail"
	_hint_trail.width = 14.0
	_hint_trail.default_color = HINT_TRAIL_COLOR
	_hint_trail.antialiased = true
	_hint_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_hint_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_hint_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_hint_trail.modulate = Color(1, 1, 1, 0.0)
	_hint_trail.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	_hint_overlay.add_child(_hint_trail)

	var hand_texture := AtlasTexture.new()
	hand_texture.atlas = load(HINT_HAND_ATLAS_PATH)
	hand_texture.region = HINT_HAND_ATLAS_REGION

	_hint_hand = TextureRect.new()
	_hint_hand.name = "SwipeHintHand"
	_hint_hand.texture = hand_texture
	_hint_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hint_hand.modulate = Color(1, 1, 1, 0.0)
	_hint_overlay.add_child(_hint_hand)

	_update_flip_hint_layout()
	_hide_swipe_hint()

func _update_flip_hint_layout() -> void:
	if not flipCard or not _hint_overlay or not _hint_hand or not _hint_trail:
		return

	var card_size := flipCard.size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		return

	var hand_size = min(card_size.x * 0.16, 68.0)
	var hint_y = clamp(card_size.y * 0.78, hand_size * 0.65, card_size.y - hand_size * 0.65)
	_hint_hand.size = Vector2(hand_size, hand_size)
	_hint_trail.width = max(10.0, card_size.x * 0.024)
	_hint_swipe_start = Vector2(card_size.x * 0.80, hint_y)
	_hint_swipe_end = Vector2(card_size.x * 0.28, hint_y)
	_set_swipe_hint_progress(0.0)

func _set_swipe_hint_progress(progress: float) -> void:
	if not _hint_hand or not _hint_trail:
		return

	var hand_center := _hint_swipe_start.lerp(_hint_swipe_end, progress)
	var hand_size := _hint_hand.size
	_hint_hand.position = hand_center - hand_size * 0.5

	var trail_head := hand_center + Vector2(hand_size.x * 0.1, 0.0)
	var trail_tail := _hint_swipe_start + Vector2(hand_size.x * 0.08, 0.0)
	var trail_arch = -min(flipCard.size.y * 0.03, 12.0) * sin(progress * PI)
	var trail_mid := trail_head.lerp(trail_tail, 0.45) + Vector2(0.0, trail_arch)
	if progress <= 0.03:
		trail_mid = trail_tail
		trail_head = trail_tail
	_hint_trail.points = PackedVector2Array([trail_head, trail_mid, trail_tail])

func _hide_swipe_hint() -> void:
	if _hint_overlay:
		_hint_overlay.visible = false
	if _hint_hand:
		_hint_hand.modulate = Color(1, 1, 1, 0.0)
	if _hint_trail:
		_hint_trail.modulate = Color(1, 1, 1, 0.0)
	_set_swipe_hint_progress(0.0)

func _start_flip_button_pulse() -> void:
	if not flip_button_container or _hint_button_tween:
		return

	_sync_flip_button_transform()
	_hint_button_tween = create_tween()
	_hint_button_tween.set_loops()
	_hint_button_tween.tween_interval(0.55)
	_hint_button_tween.tween_property(flip_button_container, "scale", _rest_flip_button_scale * HINT_BUTTON_PULSE_SCALE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hint_button_tween.tween_property(flip_button_container, "scale", _rest_flip_button_scale, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hint_button_tween.tween_interval(1.2)

func _stop_flip_button_pulse() -> void:
	if _hint_button_tween:
		_hint_button_tween.kill()
		_hint_button_tween = null
	_sync_flip_button_transform()

func _play_flip_hint_once() -> void:
	if _has_seen_flip_hint or not _can_flip_card() or _is_flipping:
		return

	_ensure_flip_hint_nodes()
	_update_flip_hint_layout()
	_play_flip_card_nudge()

	if not _hint_overlay or not _hint_hand or not _hint_trail:
		return

	if _hint_swipe_tween:
		_hint_swipe_tween.kill()

	_hint_overlay.visible = true
	_hint_hand.modulate = Color(1, 1, 1, 0.0)
	_hint_trail.modulate = Color(1, 1, 1, 0.0)
	_set_swipe_hint_progress(0.0)

	_hint_swipe_tween = create_tween()
	_hint_swipe_tween.parallel().tween_property(_hint_hand, "modulate", HINT_HAND_COLOR, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hint_swipe_tween.parallel().tween_property(_hint_trail, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hint_swipe_tween.parallel().tween_method(Callable(self, "_set_swipe_hint_progress"), 0.0, 1.0, HINT_SWIPE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hint_swipe_tween.tween_property(_hint_hand, "modulate", Color(1, 1, 1, 0.0), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hint_swipe_tween.parallel().tween_property(_hint_trail, "modulate", Color(1, 1, 1, 0.0), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hint_swipe_tween.tween_callback(Callable(self, "_hide_swipe_hint"))

func _play_flip_card_nudge() -> void:
	if not flipCard:
		return

	if _hint_card_tween:
		_hint_card_tween.kill()

	_sync_flip_card_transform()
	_hint_card_tween = create_tween()
	_hint_card_tween.tween_property(flipCard, "scale", Vector2(_rest_card_scale.x * HINT_CARD_NUDGE_SCALE.x, _rest_card_scale.y * HINT_CARD_NUDGE_SCALE.y), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hint_card_tween.parallel().tween_property(flipCard, "rotation", deg_to_rad(-HINT_CARD_NUDGE_TILT_DEGREES), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hint_card_tween.tween_property(flipCard, "scale", _rest_card_scale, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hint_card_tween.parallel().tween_property(flipCard, "rotation", 0.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _refresh_flip_hints_state() -> void:
	var should_show_hints := _can_flip_card() and not _has_seen_flip_hint and not _is_flipping
	if should_show_hints:
		_start_flip_button_pulse()
		if not _hint_cycle_tween:
			_hint_cycle_tween = create_tween()
			_hint_cycle_tween.set_loops()
			_hint_cycle_tween.tween_interval(HINT_INTRO_DELAY)
			_hint_cycle_tween.tween_callback(Callable(self, "_play_flip_hint_once"))
			_hint_cycle_tween.tween_interval(HINT_CYCLE_DELAY)
	else:
		_stop_flip_hints()

func _stop_flip_hints() -> void:
	if _hint_cycle_tween:
		_hint_cycle_tween.kill()
		_hint_cycle_tween = null
	if _hint_swipe_tween:
		_hint_swipe_tween.kill()
		_hint_swipe_tween = null
	if _hint_card_tween:
		_hint_card_tween.kill()
		_hint_card_tween = null
	_stop_flip_button_pulse()
	_hide_swipe_hint()
	_sync_flip_card_transform()

func _mark_flip_hint_completed() -> void:
	if _has_seen_flip_hint:
		return

	_has_seen_flip_hint = true
	_stop_flip_hints()

func _set_card_face_visibility(show_image_face: bool) -> void:
	showing_image = show_image_face

	if image_view:
		image_view.visible = showing_image

	if textFace:
		textFace.visible = not showing_image
		textFace.mouse_filter = Control.MOUSE_FILTER_IGNORE if showing_image else Control.MOUSE_FILTER_PASS

	if text_view:
		text_view.scroll_active = not showing_image

	_refresh_toggle_button_text()

func _flip_card_to(target_show_image: bool, direction_hint: float = 0.0) -> void:
	if _is_flipping or not _can_flip_card() or target_show_image == showing_image:
		return

	_mark_flip_hint_completed()
	_is_flipping = true
	_reset_swipe_tracking()
	_sync_flip_card_transform()

	if _flip_tween:
		_flip_tween.kill()

	var direction := direction_hint
	if is_zero_approx(direction):
		direction = 1.0 if target_show_image else -1.0

	if flipShade:
		flipShade.modulate = Color(1, 1, 1, 0.0)

	var half_duration := FLIP_DURATION * 0.5
	_flip_tween = create_tween()
	_flip_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	_flip_tween.tween_property(flipCard, "scale", Vector2(FLIP_COLLAPSE_SCALE.x, FLIP_COLLAPSE_SCALE.y), half_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_flip_tween.parallel().tween_property(flipCard, "rotation", deg_to_rad(FLIP_TILT_DEGREES * direction), half_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if flipShade:
		_flip_tween.parallel().tween_property(flipShade, "modulate", Color(1, 1, 1, FLIP_SHADE_ALPHA), half_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	_flip_tween.tween_callback(Callable(self, "_set_card_face_visibility").bind(target_show_image))
	_flip_tween.tween_property(flipCard, "scale", _rest_card_scale, half_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flip_tween.parallel().tween_property(flipCard, "rotation", 0.0, half_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if flipShade:
		_flip_tween.parallel().tween_property(flipShade, "modulate", Color(1, 1, 1, 0.0), half_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_flip_tween.finished.connect(Callable(self, "_finish_flip_animation"))

func _finish_flip_animation() -> void:
	_is_flipping = false
	_sync_flip_card_transform()

func _can_flip_card() -> bool:
	return image_view != null and image_view.texture != null and text_view != null and not text_view.text.strip_edges().is_empty()

func _update_flip_availability() -> void:
	var can_flip := _can_flip_card()

	if toggle_button:
		toggle_button.disabled = not can_flip
		toggle_button.modulate = Color.WHITE if can_flip else Color(1, 1, 1, 0.35)

	_refresh_flip_hints_state()

func _format_description_text(localized_description: String) -> String:
	var clean_paragraphs: PackedStringArray = []
	for paragraph in localized_description.split("\n", false):
		var clean_paragraph := paragraph.strip_edges()
		if not clean_paragraph.is_empty():
			clean_paragraphs.append(clean_paragraph)

	var formatted_text := "\n\n".join(clean_paragraphs)
	var scientific_name_regex := RegEx.new()
	scientific_name_regex.compile("([A-Z][a-z]+ [a-z]+)")
	var scientific_name_match := scientific_name_regex.search(formatted_text)
	if scientific_name_match:
		var scientific_name := scientific_name_match.get_string()
		formatted_text = formatted_text.replace(scientific_name, "[color=#8B2E2E][i]%s[/i][/color]" % scientific_name)

	return "[font_size=20]%s[/font_size]" % formatted_text

# Funciones existentes para los botones
func _on_RepeatButton_pressed():
	GLOBAL.change_scene_with_loading("res://Scenes/PuzzleGame.tscn")

func _on_NextPuzzleButton_pressed():
	# Obtener el siguiente puzzle del pack actual
	var next_puzzle = progress_manager.get_next_unlocked_puzzle(current_pack_id, current_puzzle_id)
	
	if next_puzzle != null:
		# Si hay un siguiente puzzle, lo cargamos directamente
		GLOBAL.selected_puzzle = next_puzzle
		# Reiniciar la escena actual con el nuevo puzzle
		GLOBAL.change_scene_with_loading("res://Scenes/PuzzleGame.tscn")
	else:
		# Si no hay siguiente puzzle, volvemos a la selección
		GLOBAL.change_scene_with_loading("res://Scenes/PuzzleSelection.tscn")

func _on_MainMenuButton_pressed():
	GLOBAL.change_scene_with_loading("res://Scenes/PuzzleSelection.tscn")

# Función para mostrar logros desbloqueados en esta partida
func show_unlocked_achievements():
	# Verificar si tenemos acceso al AchievementsManager
	if not has_node("/root/AchievementsManager"):
		return
	
	var achievements_manager = get_node("/root/AchievementsManager")
	var unlocked_achievements = achievements_manager.get_achievements_unlocked_this_session()
	
	# Si no hay logros desbloqueados, no hacer nada
	if unlocked_achievements.size() == 0:
		return
	
	# Encontrar la sección de estadísticas para añadir información de logros
	var stats_label = statsLabel
	if stats_label:
		var achievement_text = TranslationServer.translate("common_achievements") + "\n"
		
		for achievement_id in unlocked_achievements:
			var achievement_data = achievements_manager.get_achievement(achievement_id)
			if achievement_data.size() > 0:
				achievement_text += "- " + TranslationServer.translate(achievement_data.name) + "\n"
		
		stats_label.text = achievement_text
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stats_label.add_theme_font_size_override("font_size", 18)
		stats_label.add_theme_color_override("font_color", Color(0.1, 0.3, 0.8))
	
	# También añadir información a la vista de texto
	if text_view and text_view.bbcode_enabled:
		var current_text = text_view.text
		var achievement_bbcode = "\n\n[center][color=#003399][font_size=22]" + TranslationServer.translate("common_achievements").to_upper() + "[/font_size][/color][/center]\n\n"
		
		for achievement_id in unlocked_achievements:
			var achievement_data = achievements_manager.get_achievement(achievement_id)
			if achievement_data.size() > 0:
				achievement_bbcode += "[center][color=#0055AA][font_size=20]" + TranslationServer.translate(achievement_data.name) + "[/font_size][/color]\n"
				achievement_bbcode += "[font_size=18]" + TranslationServer.translate(achievement_data.desc) + "[/font_size][/center]\n\n"
		
		text_view.text = current_text + achievement_bbcode
	
	# Limpiar la lista de logros desbloqueados después de mostrarlos
	achievements_manager.clear_achievements_unlocked_this_session()
	
	# Hacer visible la sección de logros
	if stats_label:
		stats_label.visible = true

	_update_flip_availability()

# Función para configurar los valores mostrados en la pantalla de victoria
func setup_result_panels():
	var difficulty_stats := _get_current_difficulty_stats()
	var final_score = score_data.get("final_score", 0) if score_data and score_data.size() > 0 else 0

	time_label.text = _format_time_value(elapsed_time)
	moves_label.text = str(total_moves)
	score_label.text = str(final_score)
	_set_new_record_state(new_time_label, _is_better_result(difficulty_stats, "best_time", elapsed_time, true, 99999.0))
	_set_new_record_state(new_moves_label, _is_better_result(difficulty_stats, "best_moves", total_moves, true, 99999))
	_set_new_record_state(new_score_label, _is_better_result(difficulty_stats, "best_score", final_score, false, 0))

func _get_current_difficulty_stats() -> Dictionary:
	if not progress_manager:
		return {}

	var puzzle_stats: Dictionary = progress_manager.get_puzzle_stats(current_pack_id, current_puzzle_id)
	var difficulty_key := _get_difficulty_key()

	if puzzle_stats.has(difficulty_key):
		return puzzle_stats[difficulty_key]

	return {}

func _get_difficulty_key() -> String:
	return str(difficulty.columns) + "x" + str(difficulty.rows)

func _format_time_value(time_in_seconds: float) -> String:
	var minutes = int(time_in_seconds) / 60
	var seconds = int(time_in_seconds) % 60
	return "%02d:%02d" % [minutes, seconds]

func _is_better_result(difficulty_stats: Dictionary, stat_key: String, current_value, compare_less: bool, default_value) -> bool:
	if difficulty_stats.is_empty():
		return true

	var best_value = difficulty_stats.get(stat_key, default_value)
	if compare_less:
		return current_value < best_value

	return current_value > best_value

func _set_new_record_state(target_label: Label, is_new_record: bool) -> void:
	if target_label:
		target_label.visible = is_new_record

# Nueva función para guardar todas las estadísticas en el ProgressManager
func save_stats_to_progress_manager(victory_data):
	if not progress_manager:
		return
		
	# Preparar la estructura de estadísticas
	var stats = {
		"time": elapsed_time,
		"moves": total_moves,
		"columns": difficulty.columns,
		"rows": difficulty.rows,
		"flips": victory_data.get("flip_count", 0),  # Nuevo - número de flips
		"flip_moves": victory_data.get("flip_move_count", 0),  # Nuevo - movimientos durante flips
		"gamemode": victory_data.get("gamemode", 0),  # Nuevo - modalidad de juego
		"score": score_data.get("final_score", 0),  # Nuevo - puntuación obtenida
		"date": Time.get_datetime_string_from_system()
	}
	var difficulty_key = _get_difficulty_key()
	# Crear la clave de dificultad basada en las dimensiones del puzzle
	# Guardar las estadísticas con los 4 parámetros en el orden correcto
	progress_manager.save_puzzle_stats(stats, current_pack_id, current_puzzle_id, difficulty_key)
	GLOBAL.victory_data = null


func showExpaneseImage():
	# Primero se muestra el fondo negro del expanseImage
	expanseImagePanel.visible = true
	


func _on_texture_button_exit_pressed() -> void:
	pass # Replace with function body.
