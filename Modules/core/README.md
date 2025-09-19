# Módulo Core

## Descripción

El módulo core proporciona servicios fundamentales para la gestión de configuraciones persistentes del juego. Es la base sobre la cual otros módulos construyen sus funcionalidades de persistencia.

## Archivos

- `SettingsService.gd` - Servicio principal de configuraciones

## Características

- ✅ Gestión de configuraciones persistentes en `user://settings.cfg`
- ✅ API simple para get/set de valores por secciones
- ✅ Utilidades específicas para volúmenes de audio
- ✅ Gestión de idioma del juego
- ✅ Carga y guardado automático de configuraciones
- ✅ Fallbacks para valores por defecto

## Requisitos

- Ninguno (es un módulo base)

## Configuración

### 1. Añadir como Autoload
En `Project > Project Settings > Autoload`, añade:
- `SettingsService`

### 2. Configuración Automática
El servicio se inicializa automáticamente y carga las configuraciones existentes.

## API

### Métodos Públicos

#### Gestión Básica de Configuraciones
```gdscript
# Obtener un valor específico
var value = settings_service.get_value("seccion", "clave", valor_por_defecto)

# Establecer un valor específico
settings_service.set_value("seccion", "clave", valor)

# Obtener toda una sección
var section_data = settings_service.get_section("seccion")
# Retorna: Dictionary con todas las claves de la sección

# Establecer toda una sección
var new_section = {"clave1": "valor1", "clave2": "valor2"}
settings_service.set_section("seccion", new_section)
```

#### Gestión de Archivos
```gdscript
# Cargar configuraciones desde disco
var error_code = settings_service.load_settings()

# Guardar configuraciones a disco
var error_code = settings_service.save_settings()
```

#### Utilidades de Audio
```gdscript
# Obtener volúmenes actuales
var volumes = settings_service.get_volumes()
# Retorna: {"general": 50, "music": 10, "sfx": 80}

# Establecer volúmenes
var new_volumes = {"general": 75, "music": 25, "sfx": 90}
settings_service.set_volumes(new_volumes)

# Establecer volúmenes individuales
settings_service.set_value("audio", "general_volume", 75)
settings_service.set_value("audio", "music_volume", 25)
settings_service.set_value("audio", "sfx_volume", 90)
```

#### Gestión de Idioma
```gdscript
# Obtener idioma actual
var current_lang = settings_service.get_language("es")  # "es" es el valor por defecto

# Establecer idioma
settings_service.set_language("en")
```

## Ejemplos de Uso

### Configuración Básica
```gdscript
# En tu scene principal
extends Node

func _ready():
    # SettingsService se inicializa automáticamente
    # Las configuraciones se cargan automáticamente
    pass
```

### Guardar Configuración de Usuario
```gdscript
# Guardar configuración de gráficos
func save_graphics_settings():
    var settings_service = get_node("/root/SettingsService")
    settings_service.set_value("graphics", "fullscreen", true)
    settings_service.set_value("graphics", "resolution", "1920x1080")
    settings_service.set_value("graphics", "quality", "high")
    settings_service.save_settings()
```

### Cargar Configuración de Usuario
```gdscript
# Cargar configuración de gráficos
func load_graphics_settings():
    var settings_service = get_node("/root/SettingsService")
    var fullscreen = settings_service.get_value("graphics", "fullscreen", false)
    var resolution = settings_service.get_value("graphics", "resolution", "1280x720")
    var quality = settings_service.get_value("graphics", "quality", "medium")
    
    # Aplicar configuraciones
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
    # ... aplicar resolución y calidad
```

### Gestión de Progreso del Juego
```gdscript
# Guardar progreso del jugador
func save_game_progress():
    var settings_service = get_node("/root/SettingsService")
    var progress = {
        "current_level": 5,
        "score": 12500,
        "unlocked_achievements": ["first_win", "score_10000"],
        "last_save_time": Time.get_datetime_string_from_system()
    }
    settings_service.set_section("progress", progress)
    settings_service.save_settings()

# Cargar progreso del jugador
func load_game_progress():
    var settings_service = get_node("/root/SettingsService")
    var progress = settings_service.get_section("progress")
    
    if progress.is_empty():
        # Primera vez jugando
        return initialize_new_game()
    
    var current_level = progress.get("current_level", 1)
    var score = progress.get("score", 0)
    var achievements = progress.get("unlocked_achievements", [])
    
    # Aplicar progreso cargado
    apply_loaded_progress(current_level, score, achievements)
```

### Configuración de Audio
```gdscript
# Configurar volúmenes desde UI
func setup_audio_ui():
    var settings_service = get_node("/root/SettingsService")
    var volumes = settings_service.get_volumes()
    
    # Configurar sliders de volumen
    general_volume_slider.value = volumes.general
    music_volume_slider.value = volumes.music
    sfx_volume_slider.value = volumes.sfx

# Aplicar cambios de volumen
func _on_volume_changed():
    var settings_service = get_node("/root/SettingsService")
    var new_volumes = {
        "general": general_volume_slider.value,
        "music": music_volume_slider.value,
        "sfx": sfx_volume_slider.value
    }
    settings_service.set_volumes(new_volumes)
```

### Gestión de Idioma
```gdscript
# Cambiar idioma del juego
func change_language(new_lang: String):
    var settings_service = get_node("/root/SettingsService")
    settings_service.set_language(new_lang)
    
    # Aplicar cambio de idioma
    TranslationServer.set_locale(new_lang)
    
    # Recargar UI si es necesario
    reload_ui_for_new_language()

# Obtener idioma actual
func get_current_language() -> String:
    var settings_service = get_node("/root/SettingsService")
    return settings_service.get_language("es")
```

## Estructura del Archivo de Configuración

El archivo `user://settings.cfg` se estructura de la siguiente manera:

```ini
[audio]
general_volume=50
music_volume=10
sfx_volume=80

[settings]
language=es

[graphics]
fullscreen=false
resolution=1920x1080
quality=high

[progress]
current_level=5
score=12500
unlocked_achievements=["first_win", "score_10000"]
last_save_time="2024-01-15T10:30:00"
```

## Integración con Otros Módulos

### AudioService
```gdscript
# AudioService lee automáticamente los volúmenes
var volumes = settings_service.get_volumes()
```

### Otros Servicios
```gdscript
# Cualquier servicio puede usar SettingsService
var user_preferences = settings_service.get_section("user_preferences")
var game_settings = settings_service.get_section("game_settings")
```

## Notas Técnicas

### Formato de Archivo
- Usa `ConfigFile` de Godot para persistencia
- Formato INI estándar
- Codificación UTF-8

### Valores por Defecto
- Siempre proporciona valores por defecto en `get_value()`
- Los valores por defecto se usan si la clave no existe
- Los valores por defecto se usan si el archivo no existe

### Carga Automática
- Las configuraciones se cargan automáticamente al inicializar
- Se recargan si se llama a `load_settings()`
- Los cambios se guardan automáticamente en `set_volumes()`

## Migración a Otros Proyectos

1. Copia `SettingsService.gd` a tu proyecto
2. Añade como autoload
3. El servicio funcionará inmediatamente
4. Personaliza las utilidades específicas según tus necesidades

## Solución de Problemas

### Las configuraciones no se guardan
- Verifica que tienes permisos de escritura en `user://`
- Comprueba que llamas a `save_settings()` después de los cambios
- Revisa los logs de error de Godot

### Las configuraciones no se cargan
- Verifica que el archivo `user://settings.cfg` existe
- Comprueba que el archivo no está corrupto
- Revisa que usas las claves correctas en `get_value()`

### Valores inesperados
- Siempre proporciona valores por defecto en `get_value()`
- Verifica que las claves existen antes de usarlas
- Comprueba la estructura del archivo de configuración
