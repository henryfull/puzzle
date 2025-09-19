# Documentación de Módulos

Esta carpeta contiene la documentación completa de todos los módulos reutilizables del proyecto. Los módulos están diseñados para ser portables entre diferentes proyectos de Godot.

## Índice de Módulos

### 🎵 [Audio](./audio/README.md)
- **AudioService**: Gestión centralizada de audio con soporte para música de fondo y efectos de sonido
- Control de volúmenes persistente
- Integración automática con SettingsService

### 💰 [Commerce](./commerce/README.md)
- **IAPService**: Servicio principal de compras in-app
- **EntitlementsService**: Gestión de derechos de compra
- **Proveedores**: Google Play Billing y Dummy para testing
- **Configuración**: Mapeo de SKUs a contenido

### ⚙️ [Core](./core/README.md)
- **SettingsService**: Gestión de configuraciones persistentes
- Utilidades para volúmenes, idioma y configuraciones generales

### 📦 [DLC](./dlc/README.md)
- **DLCService**: Gestión de contenido descargable
- **downloadService**: Descarga e instalación de packs de contenido
- Soporte para contenido local y remoto

## Cómo Usar los Módulos

### Instalación
1. Copia la carpeta `Modules` completa a tu nuevo proyecto
2. Asegúrate de que los buses de audio estén configurados (Master, Music, SFX)
3. Configura las rutas en ProjectSettings si es necesario

### Dependencias
- **AudioService** requiere **SettingsService**
- **EntitlementsService** requiere **IAPService** y **DLCService**
- **DLCService** puede usar **IAPService** para compras

### Configuración Inicial
```gdscript
# En tu scene principal o autoload
# SettingsService se inicializa automáticamente
# AudioService se inicializa automáticamente
# IAPService se inicializa automáticamente
# DLCService se inicializa automáticamente
```

## Estructura de Archivos

```
Modules/
├── audio/
│   └── AudioService.gd
├── commerce/
│   ├── IAPService.gd
│   ├── EntitlementsService.gd
│   ├── providers/
│   │   ├── GooglePlayBillingProvider.gd
│   │   └── DummyIAPProvider.gd
│   └── config/
│       └── sku_mapping.json
├── core/
│   └── SettingsService.gd
├── dlc/
│   ├── DLCService.gd
│   └── downloadService.gd
└── documentation/
    ├── README.md (este archivo)
    ├── audio/
    ├── commerce/
    ├── core/
    └── dlc/
```

## Notas de Desarrollo

- Todos los módulos están diseñados para ser autónomos
- Usan señales para comunicación entre módulos
- Persisten datos en `user://settings.cfg` o archivos específicos
- Incluyen fallbacks para cuando las dependencias no están disponibles
- Son compatibles con Godot 4.x

## Migración Entre Proyectos

1. Copia la carpeta `Modules` completa
2. Añade los archivos como autoloads en Project Settings
3. Configura los buses de audio necesarios
4. Ajusta las rutas de configuración si es necesario
5. Los módulos se inicializarán automáticamente

Para más detalles sobre cada módulo, consulta su documentación específica en las subcarpetas correspondientes.
