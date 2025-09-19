# Módulo de Audio

## Descripción

El módulo de audio proporciona una gestión centralizada y reutilizable del sistema de audio del juego, incluyendo música de fondo, efectos de sonido y control de volúmenes persistente.

## Archivos

- `AudioService.gd` - Servicio principal de audio

## Características

- ✅ Reproducción automática de música de fondo
- ✅ Control de volúmenes por categorías (General, Música, SFX)
- ✅ Persistencia de configuraciones de volumen
- ✅ Reproducción de efectos de sonido con limpieza automática
- ✅ Integración automática con SettingsService
- ✅ Configuración de buses de audio automática

## Requisitos

### Buses de Audio
El servicio requiere que existan los siguientes buses de audio en tu proyecto:
- `Master` - Bus principal
- `Music` - Para música de fondo
- `SFX` - Para efectos de sonido

### Dependencias
- **SettingsService** (opcional, pero recomendado para persistencia)

## Configuración

### 1. Configurar Buses de Audio
En tu proyecto, ve a `Project > Audio > Audio Buses` y crea:
```
Master
├── Music
└── SFX
```

### 2. Añadir como Autoload
En `Project > Project Settings > Autoload`, añade:
- `SettingsService` (si no está ya)
- `AudioService`

### 3. Configurar Ruta de Música por Defecto
Por defecto usa `res://Assets/Sounds/Music/bg_sunset.mp3`. Puedes cambiar esto editando la constante `DEFAULT_MUSIC_PATH` en el script.

## API

### Métodos Públicos

#### Control de Volumen
```gdscript
# Obtener volúmenes actuales
var volumes = audio_service.get_volumes()
# Retorna: {"general": 50, "music": 10, "sfx": 80}

# Establecer volúmenes individuales
audio_service.set_general_volume(75.0)  # 0-100
audio_service.set_music_volume(25.0)    # 0-100
audio_service.set_sfx_volume(90.0)      # 0-100

# Obtener volúmenes individuales
var general_vol = audio_service.get_general_volume()
var music_vol = audio_service.get_music_volume()
var sfx_vol = audio_service.get_sfx_volume()
```

#### Reproducción de Audio
```gdscript
# Reproducir efecto de sonido
audio_service.play_sfx("res://Assets/Sounds/sfx_click.wav")

# Reproducir música (cambia la música actual)
audio_service.play_music("res://Assets/Sounds/Music/new_track.mp3")

# Reproducir música por defecto
audio_service.play_music()  # Usa DEFAULT_MUSIC_PATH
```

#### Control de Volúmenes
```gdscript
# Actualizar volúmenes (útil después de cambios en SettingsService)
audio_service.update_volumes()
```

## Ejemplos de Uso

### Configuración Básica
```gdscript
# En tu scene principal
extends Node

func _ready():
    # El AudioService se inicializa automáticamente
    # La música de fondo comienza a reproducirse automáticamente
    pass
```

### Control de Volumen desde UI
```gdscript
# En un slider de volumen general
func _on_general_volume_slider_value_changed(value: float):
    var audio_service = get_node("/root/AudioService")
    audio_service.set_general_volume(value)

# En un slider de volumen de música
func _on_music_volume_slider_value_changed(value: float):
    var audio_service = get_node("/root/AudioService")
    audio_service.set_music_volume(value)
```

### Reproducir Efectos de Sonido
```gdscript
# Al hacer clic en un botón
func _on_button_pressed():
    var audio_service = get_node("/root/AudioService")
    audio_service.play_sfx("res://Assets/Sounds/sfx_button_click.wav")
```

### Cambiar Música de Fondo
```gdscript
# Al cambiar de nivel
func _on_level_changed(new_level: int):
    var audio_service = get_node("/root/AudioService")
    var music_path = "res://Assets/Sounds/Music/level_%d.mp3" % new_level
    audio_service.play_music(music_path)
```

## Integración con SettingsService

El AudioService se integra automáticamente con SettingsService para persistir las configuraciones de volumen:

```gdscript
# El AudioService lee automáticamente los volúmenes guardados
# y los aplica al inicializarse

# Cuando cambias un volumen, se guarda automáticamente
audio_service.set_music_volume(30.0)  # Se guarda en SettingsService
```

## Notas Técnicas

### Conversión de Porcentaje a dB
El servicio convierte automáticamente los valores de porcentaje (0-100) a decibelios:
- 0% = -80 dB (silencio)
- 50% = -6 dB
- 100% = 0 dB (volumen máximo)

### Limpieza Automática de SFX
Los efectos de sonido se limpian automáticamente después de reproducirse para evitar acumulación de nodos.

### Fallback de SettingsService
Si SettingsService no está disponible, el AudioService usa valores por defecto:
- General: 50%
- Música: 10%
- SFX: 80%

## Migración a Otros Proyectos

1. Copia `AudioService.gd` a tu proyecto
2. Configura los buses de audio requeridos
3. Añade como autoload
4. Ajusta `DEFAULT_MUSIC_PATH` si es necesario
5. El servicio funcionará inmediatamente

## Solución de Problemas

### La música no se reproduce
- Verifica que el archivo de música existe en la ruta especificada
- Comprueba que el bus "Music" está configurado
- Revisa que el archivo de audio es compatible con Godot

### Los volúmenes no se guardan
- Asegúrate de que SettingsService está configurado como autoload
- Verifica que tienes permisos de escritura en `user://`

### Los efectos de sonido no se escuchan
- Verifica que el bus "SFX" está configurado
- Comprueba que la ruta del archivo de sonido es correcta
- Asegúrate de que el volumen de SFX no está en 0
