# Ejemplos de Uso de Módulos

Este archivo contiene ejemplos prácticos de cómo usar todos los módulos juntos en un proyecto real.

## Configuración Inicial del Proyecto

### 1. Configurar Autoloads
En `Project > Project Settings > Autoload`, añade en este orden:
```
SettingsService
AudioService
IAPService
EntitlementsService
DLCService
```

### 2. Configurar Buses de Audio
En `Project > Audio > Audio Buses`:
```
Master
├── Music
└── SFX
```

### 3. Configurar Project Settings
```
dlc/base_url = "https://tu-servidor.com/api"
commerce/sku_mapping_path = "res://Modules/commerce/config/sku_mapping.json"
```

## Ejemplo: Sistema de Tienda Completo

### Scene Principal
```gdscript
# MainMenu.gd
extends Control

@onready var music_volume_slider = $VBoxContainer/MusicVolumeSlider
@onready var sfx_volume_slider = $VBoxContainer/SFXVolumeSlider
@onready var shop_button = $VBoxContainer/ShopButton
@onready var play_button = $VBoxContainer/PlayButton

func _ready():
    setup_audio_controls()
    connect_signals()
    load_user_settings()

func setup_audio_controls():
    var audio_service = get_node("/root/AudioService")
    music_volume_slider.value = audio_service.get_music_volume()
    sfx_volume_slider.value = audio_service.get_sfx_volume()

func connect_signals():
    music_volume_slider.value_changed.connect(_on_music_volume_changed)
    sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
    shop_button.pressed.connect(_on_shop_button_pressed)
    play_button.pressed.connect(_on_play_button_pressed)

func load_user_settings():
    var settings_service = get_node("/root/SettingsService")
    var language = settings_service.get_language("es")
    TranslationServer.set_locale(language)

func _on_music_volume_changed(value: float):
    var audio_service = get_node("/root/AudioService")
    audio_service.set_music_volume(value)

func _on_sfx_volume_changed(value: float):
    var audio_service = get_node("/root/AudioService")
    audio_service.set_sfx_volume(value)

func _on_shop_button_pressed():
    var audio_service = get_node("/root/AudioService")
    audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
    get_tree().change_scene_to_file("res://Scenes/Shop.tscn")

func _on_play_button_pressed():
    var audio_service = get_node("/root/AudioService")
    audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
    get_tree().change_scene_to_file("res://Scenes/Game.tscn")
```

### Scene de Tienda
```gdscript
# Shop.gd
extends Control

@onready var product_list = $VBoxContainer/ProductList
@onready var purchase_button = $VBoxContainer/PurchaseButton
@onready var back_button = $VBoxContainer/BackButton
@onready var status_label = $VBoxContainer/StatusLabel

var available_products = []
var selected_product = null

func _ready():
    connect_signals()
    load_products()

func connect_signals():
    purchase_button.pressed.connect(_on_purchase_button_pressed)
    back_button.pressed.connect(_on_back_button_pressed)
    product_list.item_selected.connect(_on_product_selected)
    
    # Conectar señales de IAP
    var iap_service = get_node("/root/IAPService")
    iap_service.connected.connect(_on_iap_connected)
    iap_service.sku_details.connect(_on_products_loaded)
    iap_service.purchase_error.connect(_on_purchase_error)
    iap_service.purchases_updated.connect(_on_purchases_updated)
    
    # Conectar señales de DLC
    var dlc_service = get_node("/root/DLCService")
    dlc_service.pack_installed.connect(_on_pack_installed)
    dlc_service.download_progress.connect(_on_download_progress)

func load_products():
    var iap_service = get_node("/root/IAPService")
    var skus = ["pack_animals", "pack_cities", "pack_numbers", "full_game_unlock"]
    iap_service.query_products(skus)

func _on_iap_connected():
    status_label.text = "Conectado a la tienda"
    load_products()

func _on_products_loaded(products: Array):
    available_products = products
    update_product_list()

func update_product_list():
    product_list.clear()
    for product in available_products:
        var item_text = "%s - %s" % [product.title, product.price]
        product_list.add_item(item_text)

func _on_product_selected(index: int):
    selected_product = available_products[index]
    purchase_button.disabled = false

func _on_purchase_button_pressed():
    if selected_product:
        var audio_service = get_node("/root/AudioService")
        audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
        
        var iap_service = get_node("/root/IAPService")
        iap_service.purchase(selected_product.sku)
        purchase_button.disabled = true
        status_label.text = "Procesando compra..."

func _on_purchase_error(code: int, message: String):
    status_label.text = "Error en compra: %s" % message
    purchase_button.disabled = false

func _on_purchases_updated(purchases: Array):
    status_label.text = "Compra procesada exitosamente"
    purchase_button.disabled = false

func _on_pack_installed(pack_id: String):
    status_label.text = "Pack instalado: %s" % pack_id

func _on_download_progress(pack_id: String, file_path: String, received: int, total: int):
    if total > 0:
        var progress = float(received) / float(total)
        status_label.text = "Descargando %s: %.1f%%" % [pack_id, progress * 100]

func _on_back_button_pressed():
    var audio_service = get_node("/root/AudioService")
    audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
    get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
```

## Ejemplo: Sistema de Configuración Completo

### Scene de Opciones
```gdscript
# Options.gd
extends Control

@onready var language_option = $VBoxContainer/LanguageOption
@onready var general_volume_slider = $VBoxContainer/GeneralVolumeSlider
@onready var music_volume_slider = $VBoxContainer/MusicVolumeSlider
@onready var sfx_volume_slider = $VBoxContainer/SFXVolumeSlider
@onready var fullscreen_checkbox = $VBoxContainer/FullscreenCheckbox
@onready var save_button = $VBoxContainer/SaveButton
@onready var reset_button = $VBoxContainer/ResetButton

func _ready():
    load_current_settings()
    connect_signals()

func load_current_settings():
    var settings_service = get_node("/root/SettingsService")
    var audio_service = get_node("/root/AudioService")
    
    # Cargar configuraciones de audio
    var volumes = audio_service.get_volumes()
    general_volume_slider.value = volumes.general
    music_volume_slider.value = volumes.music
    sfx_volume_slider.value = volumes.sfx
    
    # Cargar configuraciones de juego
    var language = settings_service.get_language("es")
    language_option.selected = get_language_index(language)
    
    var fullscreen = settings_service.get_value("graphics", "fullscreen", false)
    fullscreen_checkbox.button_pressed = fullscreen

func connect_signals():
    general_volume_slider.value_changed.connect(_on_general_volume_changed)
    music_volume_slider.value_changed.connect(_on_music_volume_changed)
    sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
    language_option.item_selected.connect(_on_language_changed)
    fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
    save_button.pressed.connect(_on_save_button_pressed)
    reset_button.pressed.connect(_on_reset_button_pressed)

func _on_general_volume_changed(value: float):
    var audio_service = get_node("/root/AudioService")
    audio_service.set_general_volume(value)

func _on_music_volume_changed(value: float):
    var audio_service = get_node("/root/AudioService")
    audio_service.set_music_volume(value)

func _on_sfx_volume_changed(value: float):
    var audio_service = get_node("/root/AudioService")
    audio_service.set_sfx_volume(value)

func _on_language_changed(index: int):
    var languages = ["es", "en", "ca"]
    var selected_language = languages[index]
    
    var settings_service = get_node("/root/SettingsService")
    settings_service.set_language(selected_language)
    
    # Aplicar cambio de idioma
    TranslationServer.set_locale(selected_language)
    
    # Recargar UI
    reload_ui_for_new_language()

func _on_fullscreen_toggled(pressed: bool):
    var settings_service = get_node("/root/SettingsService")
    settings_service.set_value("graphics", "fullscreen", pressed)
    
    # Aplicar cambio de pantalla
    if pressed:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_save_button_pressed():
    var audio_service = get_node("/root/AudioService")
    audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
    
    var settings_service = get_node("/root/SettingsService")
    settings_service.save_settings()
    
    show_message("Configuraciones guardadas")

func _on_reset_button_pressed():
    var audio_service = get_node("/root/AudioService")
    audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
    
    reset_to_defaults()
    load_current_settings()
    
    show_message("Configuraciones restablecidas")

func reset_to_defaults():
    var settings_service = get_node("/root/SettingsService")
    var audio_service = get_node("/root/AudioService")
    
    # Restablecer volúmenes
    audio_service.set_volumes({"general": 50, "music": 10, "sfx": 80})
    
    # Restablecer configuraciones
    settings_service.set_language("es")
    settings_service.set_value("graphics", "fullscreen", false)
    
    # Aplicar cambios
    TranslationServer.set_locale("es")
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func get_language_index(language: String) -> int:
    var languages = ["es", "en", "ca"]
    return languages.find(language)

func reload_ui_for_new_language():
    # Recargar textos de la UI
    # Esto depende de tu implementación específica
    pass

func show_message(text: String):
    # Mostrar mensaje al usuario
    # Esto depende de tu implementación específica
    print(text)
```

## Ejemplo: Sistema de Progreso con DLC

### Scene de Selección de Packs
```gdscript
# PackSelection.gd
extends Control

@onready var pack_list = $VBoxContainer/PackList
@onready var play_button = $VBoxContainer/PlayButton
@onready var buy_button = $VBoxContainer/BuyButton
@onready var status_label = $VBoxContainer/StatusLabel

var available_packs = []
var selected_pack = null

func _ready():
    load_available_packs()
    connect_signals()

func load_available_packs():
    var dlc_service = get_node("/root/DLCService")
    available_packs = dlc_service.get_available_packs_for_purchase()
    update_pack_list()

func update_pack_list():
    pack_list.clear()
    for pack in available_packs:
        var item_text = "%s - %s" % [pack.name, pack.price]
        pack_list.add_item(item_text)

func connect_signals():
    pack_list.item_selected.connect(_on_pack_selected)
    play_button.pressed.connect(_on_play_button_pressed)
    buy_button.pressed.connect(_on_buy_button_pressed)
    
    # Conectar señales de DLC
    var dlc_service = get_node("/root/DLCService")
    dlc_service.pack_installed.connect(_on_pack_installed)

func _on_pack_selected(index: int):
    selected_pack = available_packs[index]
    play_button.disabled = false
    buy_button.disabled = false

func _on_play_button_pressed():
    if selected_pack:
        var audio_service = get_node("/root/AudioService")
        audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
        
        # Verificar si el pack está disponible
        if is_pack_available(selected_pack.id):
            start_game_with_pack(selected_pack.id)
        else:
            status_label.text = "Pack no disponible. Compra requerida."

func _on_buy_button_pressed():
    if selected_pack:
        var audio_service = get_node("/root/AudioService")
        audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
        
        # Iniciar proceso de compra
        purchase_pack(selected_pack.id)

func is_pack_available(pack_id: String) -> bool:
    var dlc_service = get_node("/root/DLCService")
    var pack_path = "user://dlc/packs/%s.json" % pack_id
    return FileAccess.file_exists(pack_path)

func start_game_with_pack(pack_id: String):
    # Guardar pack seleccionado
    var settings_service = get_node("/root/SettingsService")
    settings_service.set_value("game", "selected_pack", pack_id)
    
    # Cambiar a scene de juego
    get_tree().change_scene_to_file("res://Scenes/Game.tscn")

func purchase_pack(pack_id: String):
    var iap_service = get_node("/root/IAPService")
    var sku = "pack_%s" % pack_id  # Asumiendo mapeo de SKU
    
    iap_service.purchase(sku)
    status_label.text = "Procesando compra..."

func _on_pack_installed(pack_id: String):
    status_label.text = "Pack instalado: %s" % pack_id
    load_available_packs()  # Recargar lista
```

## Ejemplo: Sistema de Logros con Persistencia

### Scene de Logros
```gdscript
# Achievements.gd
extends Control

@onready var achievement_list = $VBoxContainer/AchievementList
@onready var progress_label = $VBoxContainer/ProgressLabel

var achievements = []

func _ready():
    load_achievements()
    connect_signals()

func load_achievements():
    var settings_service = get_node("/root/SettingsService")
    achievements = settings_service.get_value("achievements", "unlocked", [])
    update_achievement_list()

func update_achievement_list():
    achievement_list.clear()
    for achievement in achievements:
        var item_text = "✅ %s" % achievement
        achievement_list.add_item(item_text)

func connect_signals():
    # Conectar señales de otros sistemas
    var dlc_service = get_node("/root/DLCService")
    dlc_service.pack_installed.connect(_on_pack_installed)

func _on_pack_installed(pack_id: String):
    unlock_achievement("pack_%s_unlocked" % pack_id)

func unlock_achievement(achievement_id: String):
    var settings_service = get_node("/root/SettingsService")
    var achievements = settings_service.get_value("achievements", "unlocked", [])
    
    if achievement_id not in achievements:
        achievements.append(achievement_id)
        settings_service.set_value("achievements", "unlocked", achievements)
        settings_service.save_settings()
        
        # Mostrar notificación
        show_achievement_notification(achievement_id)
        
        # Actualizar UI
        update_achievement_list()

func show_achievement_notification(achievement_id: String):
    var audio_service = get_node("/root/AudioService")
    audio_service.play_sfx("res://Assets/Sounds/sfx_achievement.wav")
    
    # Mostrar notificación (implementar según tu UI)
    print("¡Logro desbloqueado: %s!" % achievement_id)
```

## Ejemplo: Sistema de Backup y Restauración

### Scene de Configuración Avanzada
```gdscript
# AdvancedSettings.gd
extends Control

@onready var backup_button = $VBoxContainer/BackupButton
@onready var restore_button = $VBoxContainer/RestoreButton
@onready var export_button = $VBoxContainer/ExportButton
@onready var import_button = $VBoxContainer/ImportButton

func _ready():
    connect_signals()

func connect_signals():
    backup_button.pressed.connect(_on_backup_button_pressed)
    restore_button.pressed.connect(_on_restore_button_pressed)
    export_button.pressed.connect(_on_export_button_pressed)
    import_button.pressed.connect(_on_import_button_pressed)

func _on_backup_button_pressed():
    var audio_service = get_node("/root/AudioService")
    audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
    
    create_backup()

func create_backup():
    var settings_service = get_node("/root/SettingsService")
    var dlc_service = get_node("/root/DLCService")
    
    # Crear backup de configuraciones
    var backup_data = {
        "settings": settings_service.get_section("settings"),
        "audio": settings_service.get_section("audio"),
        "achievements": settings_service.get_section("achievements"),
        "purchases": settings_service.get_section("purchases"),
        "timestamp": Time.get_datetime_string_from_system()
    }
    
    # Guardar backup
    var backup_file = FileAccess.open("user://backup_%s.json" % Time.get_unix_time_from_system(), FileAccess.WRITE)
    if backup_file:
        backup_file.store_string(JSON.stringify(backup_data))
        backup_file.close()
        show_message("Backup creado exitosamente")
    else:
        show_message("Error al crear backup")

func _on_restore_button_pressed():
    var audio_service = get_node("/root/AudioService")
    audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
    
    restore_from_backup()

func restore_from_backup():
    # Implementar selección de archivo de backup
    # y restauración de configuraciones
    show_message("Funcionalidad de restauración en desarrollo")

func _on_export_button_pressed():
    var audio_service = get_node("/root/AudioService")
    audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
    
    export_data()

func export_data():
    var settings_service = get_node("/root/SettingsService")
    var dlc_service = get_node("/root/DLCService")
    
    # Exportar datos del usuario
    var export_data = {
        "settings": settings_service.get_section("settings"),
        "achievements": settings_service.get_section("achievements"),
        "purchases": settings_service.get_section("purchases"),
        "dlc_packs": dlc_service.get_purchased_packs(),
        "export_timestamp": Time.get_datetime_string_from_system()
    }
    
    # Guardar archivo de exportación
    var export_file = FileAccess.open("user://export_%s.json" % Time.get_unix_time_from_system(), FileAccess.WRITE)
    if export_file:
        export_file.store_string(JSON.stringify(export_data))
        export_file.close()
        show_message("Datos exportados exitosamente")
    else:
        show_message("Error al exportar datos")

func _on_import_button_pressed():
    var audio_service = get_node("/root/AudioService")
    audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
    
    import_data()

func import_data():
    # Implementar importación de datos
    show_message("Funcionalidad de importación en desarrollo")

func show_message(text: String):
    # Mostrar mensaje al usuario
    print(text)
```

## Notas de Implementación

### Orden de Inicialización
Los módulos deben inicializarse en este orden:
1. SettingsService
2. AudioService
3. IAPService
4. EntitlementsService
5. DLCService

### Manejo de Errores
Siempre verifica que los servicios estén disponibles antes de usarlos:
```gdscript
var audio_service = get_node_or_null("/root/AudioService")
if audio_service:
    audio_service.play_sfx("sound.wav")
```

### Persistencia de Datos
Los módulos manejan la persistencia automáticamente, pero puedes forzar el guardado:
```gdscript
var settings_service = get_node("/root/SettingsService")
settings_service.save_settings()
```

### Testing
Para testing, usa el proveedor Dummy de IAP:
```gdscript
# El proveedor Dummy se activa automáticamente
# cuando Google Play Billing no está disponible
```

Estos ejemplos muestran cómo integrar todos los módulos en un sistema completo y funcional. Cada módulo mantiene su independencia mientras proporciona funcionalidades específicas que se combinan para crear una experiencia de usuario rica y completa.
