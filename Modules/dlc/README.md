# Módulo DLC

## Descripción

El módulo DLC proporciona una solución completa para la gestión de contenido descargable (Downloadable Content). Incluye descarga, instalación y gestión de packs de contenido, tanto desde fuentes locales como remotas.

## Archivos

### Servicios Principales
- `DLCService.gd` - Servicio principal de gestión de DLC
- `downloadService.gd` - Servicio de descarga e instalación de contenido

## Características

- ✅ Descarga de contenido desde servidor remoto
- ✅ Instalación de contenido desde fuentes locales
- ✅ Gestión de packs de contenido JSON
- ✅ Descarga de assets (imágenes, sonidos, etc.)
- ✅ Persistencia de metadata de compras
- ✅ Integración con sistema de compras
- ✅ Carga de texturas desde múltiples fuentes
- ✅ Sistema de señales para progreso y estado

## Requisitos

### Dependencias
- **SettingsService** (para persistencia)
- **IAPService** (opcional, para compras)

### Configuración de Proyecto
- Directorio `res://dlc/packs/` para contenido base
- Directorio `user://dlc/packs/` para contenido descargado
- Archivo `res://dlc/new_base_packs.json` con índice de packs

## Configuración

### 1. Configurar Autoloads
En `Project > Project Settings > Autoload`, añade:
- `SettingsService`
- `DLCService`

### 2. Configurar Directorios
Crea la siguiente estructura de directorios:
```
res://dlc/
├── packs/
│   ├── pack1.json
│   ├── pack2.json
│   └── ...
└── new_base_packs.json

user://dlc/
└── packs/
    ├── pack1.json
    ├── pack2.json
    └── ...
```

### 3. Configurar URL Base (Opcional)
Para descarga remota, configura en `Project Settings`:
- `dlc/base_url` = "https://tu-servidor.com/api"

## API

### DLCService

#### Señales
```gdscript
# Instalación de packs
DLCService.pack_installed(pack_id: String)

# Progreso de descarga
DLCService.download_progress(pack_id: String, file_path: String, received: int, total: int)

# Finalización de descarga
DLCService.download_finished(pack_id: String, success: bool)
```

#### Métodos Principales
```gdscript
# Obtener packs para un SKU
var packs = DLCService.get_packs_for_sku("pack_animals")

# Verificar soporte de descarga
var has_download = DLCService.has_download_support()

# Marcar packs como comprados
DLCService.mark_packs_purchased(["pack1", "pack2"])

# Instalar packs desde base local
var installed = DLCService.install_packs_from_base(["pack1", "pack2"])

# Descargar e instalar packs
var result = await DLCService.download_and_install_packs(["pack1", "pack2"])

# Cargar textura desde cualquier fuente
var texture = DLCService.load_texture_any("user://dlc/packs/pack1/image.png")
```

### downloadService

#### Señales
```gdscript
# Progreso de compra e instalación
downloadService.purchase_started(pack_id: String)
downloadService.purchase_completed(pack_id: String, success: bool)
downloadService.download_started(pack_id: String)
downloadService.download_progress(pack_id: String, progress: float)
downloadService.download_completed(pack_id: String, success: bool)
downloadService.installation_completed(pack_id: String, success: bool)
```

#### Métodos Principales
```gdscript
# Obtener entitlements desde backend
var entitlements = await downloadService.fetch_entitlements()

# Verificar compra
var verified = await downloadService.verify_purchase("android", "pack_animals", "token")

# Descargar pack
var success = await downloadService.download_pack("pack_animals")

# Compra e instalación completa
var success = await downloadService.purchase_and_install_pack("pack_animals")

# Obtener packs disponibles
var available = downloadService.get_available_packs_for_purchase()
```

## Ejemplos de Uso

### Configuración Básica
```gdscript
# En tu scene principal
extends Node

func _ready():
    # Los servicios se inicializan automáticamente
    _connect_dlc_signals()

func _connect_dlc_signals():
    var dlc_service = get_node("/root/DLCService")
    dlc_service.pack_installed.connect(_on_pack_installed)
    dlc_service.download_progress.connect(_on_download_progress)
    dlc_service.download_finished.connect(_on_download_finished)
```

### Instalar Contenido Local
```gdscript
# Instalar packs desde contenido base
func install_local_packs():
    var dlc_service = get_node("/root/DLCService")
    var packs_to_install = ["animals", "cities", "numbers"]
    
    var installed_count = dlc_service.install_packs_from_base(packs_to_install)
    print("Packs instalados: %d de %d" % [installed_count, packs_to_install.size()])

func _on_pack_installed(pack_id: String):
    print("Pack instalado: %s" % pack_id)
    # Actualizar UI o cargar contenido
```

### Descargar Contenido Remoto
```gdscript
# Descargar packs desde servidor
func download_remote_packs():
    var dlc_service = get_node("/root/DLCService")
    
    if not dlc_service.has_download_support():
        print("Descarga remota no disponible")
        return
    
    var packs_to_download = ["new_pack1", "new_pack2"]
    var result = await dlc_service.download_and_install_packs(packs_to_download)
    
    if result.ok:
        print("Descarga exitosa: %d packs" % result.success_count)
    else:
        print("Error en descarga")

func _on_download_progress(pack_id: String, file_path: String, received: int, total: int):
    var progress = float(received) / float(total) if total > 0 else 0.0
    print("Descargando %s: %.1f%%" % [pack_id, progress * 100])
    # Actualizar barra de progreso
```

### Cargar Contenido DLC
```gdscript
# Cargar textura desde DLC
func load_dlc_texture(pack_id: String, image_path: String):
    var dlc_service = get_node("/root/DLCService")
    var full_path = "user://dlc/packs/%s/%s" % [pack_id, image_path]
    var texture = dlc_service.load_texture_any(full_path)
    
    if texture:
        # Usar textura en UI
        texture_rect.texture = texture
    else:
        print("No se pudo cargar textura: %s" % full_path)

# Cargar datos de pack
func load_pack_data(pack_id: String):
    var pack_path = "user://dlc/packs/%s.json" % pack_id
    if FileAccess.file_exists(pack_path):
        var file = FileAccess.open(pack_path, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var pack_data = JSON.parse_string(content)
        if pack_data:
            return pack_data
    
    return null
```

### Verificar Contenido Disponible
```gdscript
# Verificar qué packs están disponibles
func check_available_packs():
    var dlc_service = get_node("/root/DLCService")
    
    # Packs desde SKU
    var animal_packs = dlc_service.get_packs_for_sku("pack_animals")
    print("Packs de animales: %s" % str(animal_packs))
    
    # Verificar si tiene soporte de descarga
    if dlc_service.has_download_support():
        print("Descarga remota disponible")
    else:
        print("Solo contenido local disponible")
```

### Integración con Sistema de Compras
```gdscript
# Cuando se completa una compra
func _on_purchase_completed(sku: String):
    var dlc_service = get_node("/root/DLCService")
    var packs = dlc_service.get_packs_for_sku(sku)
    
    if packs.size() > 0:
        # Marcar como comprado
        dlc_service.mark_packs_purchased(packs)
        
        # Instalar contenido
        if dlc_service.has_download_support():
            await dlc_service.download_and_install_packs(packs)
        else:
            dlc_service.install_packs_from_base(packs)
```

### UI de Gestión de DLC
```gdscript
# Ejemplo de UI para gestionar DLC
extends Control

@onready var pack_list = $PackList
@onready var download_button = $DownloadButton
@onready var progress_bar = $ProgressBar

var available_packs = []

func _ready():
    var dlc_service = get_node("/root/DLCService")
    dlc_service.download_progress.connect(_on_download_progress)
    dlc_service.download_finished.connect(_on_download_finished)
    
    load_available_packs()

func load_available_packs():
    var dlc_service = get_node("/root/DLCService")
    available_packs = dlc_service.get_available_packs_for_purchase()
    update_pack_list()

func update_pack_list():
    pack_list.clear()
    for pack in available_packs:
        var item_text = "%s - %s" % [pack.name, pack.price]
        pack_list.add_item(item_text)

func _on_download_button_pressed():
    var selected_index = pack_list.get_selected_items()
    if selected_index.size() > 0:
        var pack = available_packs[selected_index[0]]
        download_pack(pack.id)

func download_pack(pack_id: String):
    var dlc_service = get_node("/root/DLCService")
    download_button.disabled = true
    progress_bar.visible = true
    
    var result = await dlc_service.download_and_install_pack(pack_id)
    
    if result.ok:
        print("Pack descargado exitosamente: %s" % pack_id)
    else:
        print("Error al descargar pack: %s" % pack_id)
    
    download_button.disabled = false
    progress_bar.visible = false

func _on_download_progress(pack_id: String, file_path: String, received: int, total: int):
    if total > 0:
        var progress = float(received) / float(total)
        progress_bar.value = progress * 100

func _on_download_finished(pack_id: String, success: bool):
    if success:
        print("Descarga completada: %s" % pack_id)
    else:
        print("Error en descarga: %s" % pack_id)
```

## Estructura de Packs

### Archivo JSON de Pack
```json
{
  "id": "animals",
  "name": "Animales",
  "description": "Pack de puzzles de animales",
  "image_path": "user://dlc/packs/animals/thumbnail.jpg",
  "puzzles": [
    {
      "id": "puzzle_1",
      "name": "León",
      "image": "user://dlc/packs/animals/lion.jpg",
      "difficulty": "easy"
    }
  ]
}
```

### Estructura de Directorios
```
user://dlc/packs/animals/
├── animals.json
├── thumbnail.jpg
├── lion.jpg
└── ...
```

## Configuración de Servidor

### Endpoint de Descarga
```
GET /packs/{pack_id}.json
GET /packs/{pack_id}/{filename}
```

### Respuesta de Pack
```json
{
  "id": "animals",
  "name": "Animales",
  "description": "Pack de puzzles de animales",
  "image_path": "animals/thumbnail.jpg",
  "puzzles": [...]
}
```

## Notas Técnicas

### Gestión de Archivos
- Los archivos se descargan a memoria y luego se guardan
- Se crean directorios automáticamente si no existen
- Los archivos se validan antes de guardar

### Persistencia
- Los packs comprados se guardan en metadata
- La información se persiste en `user://dlc/dlc_metadata.json`
- Los cambios se reflejan inmediatamente

### Carga de Texturas
- Soporte para rutas `res://` y `user://`
- Carga automática desde imágenes
- Fallback a textura nula si falla la carga

## Migración a Otros Proyectos

1. Copia la carpeta `dlc` completa
2. Configura los autoloads necesarios
3. Crea la estructura de directorios requerida
4. Ajusta las rutas de configuración
5. Los servicios funcionarán automáticamente

## Solución de Problemas

### Los packs no se instalan
- Verifica que los directorios existen
- Comprueba que los archivos JSON son válidos
- Revisa los permisos de escritura

### La descarga falla
- Verifica que la URL base está configurada
- Comprueba la conexión a internet
- Revisa que el servidor responde correctamente

### Las texturas no se cargan
- Verifica que las rutas son correctas
- Comprueba que los archivos de imagen existen
- Revisa que los formatos son compatibles con Godot
