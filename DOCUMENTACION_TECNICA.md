# 📚 Documentación Técnica - Puzzle Tiki Tiki

Este documento centraliza toda la documentación técnica, soluciones implementadas y guías del sistema del juego.

---

## 🔲 Sistema de Bordes de Grupo

### ✨ Descripción
Se ha implementado un nuevo sistema de **bordes visuales** que muestra un contorno alrededor de los grupos de piezas conectadas. Esto facilita enormemente la identificación visual de qué piezas pertenecen al mismo grupo.

### 🎨 Características Principales
- **Bordes Solo para Grupos**: Solo las piezas agrupadas (2+ piezas) muestran bordes
- **Piezas Individuales**: Las piezas sueltas no tienen borde para mantener claridad visual
- **Colores Dinámicos**: Cada grupo tiene un color de borde único basado en su ID
- **Contorno de Área Completa**: El borde sigue la forma exterior del grupo completo

### 🛠️ Configuración desde el Editor
En la escena PuzzlePiece.tscn:
1. **Selecciona el nodo raíz** "PuzzlePiece"
2. **En el Inspector**, busca la sección **"Bordes de Grupo"**
3. **Variables configurables**:
```
enable_group_border_display: bool = true      # Activar/desactivar
group_border_thickness: float = 2.0          # Grosor del borde
group_border_opacity: float = 0.7            # Opacidad (0.1 - 1.0) 
```

---

## 🏆 Sistema de Puntuaciones

### Objetivo
Desarrollar un sistema de puntuación por puzzle que premie la precisión, la estrategia y el rendimiento del jugador.

### Acciones que SUMAN puntos
| Acción | Descripción | Puntos |
|--------|-------------|--------|
| Pieza colocada correctamente | Se une al grupo principal | +2 puntos |
| Unión de dos grupos | Conecta dos grupos existentes | +5 puntos |
| Racha de aciertos | Racha de 3: +1, de 5: +2, de 10+: +3 | Acumulativo |
| Puzzle completado | Todas las piezas completas | +20 puntos |
| Sin errores | No movimientos inválidos | +15 puntos extra |
| Sin usar flip | No usó pistas | +10 puntos extra |

### Acciones que RESTAN puntos
| Acción | Descripción | Penalización |
|--------|-------------|--------------|
| Movimiento inválido | Pieza no se agrupa | -1 punto |
| Uso de flip/ayuda | Usar pistas visuales | -5 puntos |
| Deshacer acción | Opción de "undo" | -2 puntos |

---

## 🔧 Solución para Bordes Blancos

### 🚨 Problema
Bordes blancos visibles entre las piezas causados por gaps microscópicos.

### ✅ Soluciones Implementadas

#### 1. Factor de Solapamiento
```gdscript
var overlap_factor = 1.001  # 0.1% de solapamiento
var scale_x = (cell_size.x / piece_orig_w) * overlap_factor
var scale_y = (cell_size.y / piece_orig_h) * overlap_factor
```

#### 2. Compensación de Posición
```gdscript
var offset_compensation = Vector2(
    (cell_size.x * (overlap_factor - 1.0)) * -0.5,
    (cell_size.y * (overlap_factor - 1.0)) * -0.5
)
```

#### 3. Filtrado de Textura Desactivado
```gdscript
sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
```

---

## 💾 Sistema de Guardado Automático

### Características
- **Guardado automático** tras cada acción significativa
- **Persistencia de progreso** entre sesiones
- **Recuperación de estado** en caso de cierre forzado
- **Formato JSON** para compatibilidad

### Implementación
```gdscript
# Guardado automático después de:
- Completar un puzzle
- Unir piezas en grupo
- Cambios en configuración
- Pausar/salir del juego
```

---

## 📱 Interfaz Móvil Optimizada

### Características Touch
- **Gestos táctiles** optimizados para móviles
- **Botones escalables** según tamaño de pantalla
- **Zoom y paneo** fluidos
- **Orientación adaptable** (portrait/landscape)

### Elementos UI
- **Scroll táctil** en listas de puzzles/packs
- **Botones de navegación** optimizados para dedos
- **Indicadores visuales** de estado
- **Notificaciones** no intrusivas

---

## 🎨 Efectos Visuales

### Sistema de Partículas
- **Efectos de fusión** al unir piezas
- **Animaciones de victoria** al completar puzzle
- **Transiciones suaves** entre pantallas
- **Feedback visual** en interacciones

### Configuración
```gdscript
# Activar/desactivar efectos
enable_visual_effects: bool = true
particle_intensity: float = 1.0  # 0.0 - 2.0
animation_speed: float = 1.0     # 0.5 - 2.0
```

---

## ⚙️ Gestión de Z-Index

### Problema Resuelto
Superposición incorrecta de elementos UI y piezas del puzzle.

### Solución
```gdscript
# Jerarquía de Z-Index:
# 100+: Menús y diálogos
# 50-99: UI del juego
# 10-49: Piezas seleccionadas
# 1-9: Piezas normales
# 0: Fondo
```

---

## 🔒 Prevención de Cierre Forzado

### Problemas Identificados
- **Estados no guardados** al salir abruptamente
- **Pérdida de progreso** en puzzles largos
- **Corrupción de datos** de guardado

### Soluciones
```gdscript
# Guardado preventivo cada 30 segundos
# Validación de integridad de datos
# Recuperación automática de estado
# Notificaciones antes de salir
```

---

## 🔄 Corrección de Bordes y Flip

### Sistema de Volteo Mejorado
- **Animación suave** de rotación 3D
- **Conservación de posición** durante flip
- **Sincronización** de estado visual
- **Feedback audio-visual**

### Correcciones Implementadas
```gdscript
# Eliminación de gaps durante flip
# Mantenimiento de grupos al voltear
# Animación optimizada para móviles
# Prevención de double-flip accidental
```

---

## 🎯 Modo de Aprendizaje

### Características Especiales
- **Puntuación desactivada** para enfoque en aprendizaje
- **Pistas visuales** mejoradas
- **Sin penalizaciones** por errores
- **Progresión guiada** paso a paso

### Tutorial Interactivo
- **Introducción gradual** de mecánicas
- **Tooltips contextuales**
- **Validación de acciones** antes de continuar
- **Celebración de logros** pequeños

---

## 🛠️ Herramientas de Desarrollo

### Scripts de Build (.sh)
- `build_android_direct.sh`: Build directo para Android
- `setup_android_env.sh`: Configuración de entorno Android
- `launch_godot_java17.sh`: Lanzar Godot con Java 17
- `switch_java.sh`: Cambiar versión de Java
- `fix_android_export.sh`: Reparar configuración de exportación

### Testing y Debug
```gdscript
# Archivos de test disponibles:
- test_puzzle_state.gd
- test_grid_synchronization.gd  
- test_forced_close.gd
- test_serialization_format.gd
```

---

## 📊 Optimización de Rendimiento

### Mejoras Implementadas
- **Pool de objetos** para piezas reutilizables
- **Carga asíncrona** de texturas grandes
- **Culling automático** de elementos fuera de pantalla
- **Compresión de texturas** optimizada

### Configuración por Dispositivo
```gdscript
# Detección automática de capacidades
if device_performance == "LOW":
    disable_particles()
    reduce_texture_quality()
    limit_simultaneous_animations()
```

---

## 🌐 Localización

### Idiomas Soportados
- **Español** (es)
- **Inglés** (en) 
- **Catalán** (ca)

### Sistema de Traducción
```gdscript
# Archivos de localización:
data/localization/translation.es.translation
data/localization/translation.en.translation
data/localization/translation.ca.translation
```

---

## 🔧 Configuración Avanzada

### Variables de Proyecto
```gdscript
# En project.godot:
rendering/textures/canvas_textures/default_texture_filter=0
input_devices/pointing/emulate_touch_from_mouse=true
application/config/use_custom_user_dir=true
```

### Opciones del Usuario
- **Volumen**: música, efectos, voces
- **Idioma**: cambio dinámico
- **Accesibilidad**: contraste, tamaño de texto
- **Rendimiento**: calidad gráfica adaptable

---

## 📝 Notas de Desarrollo

### Refactorización Reciente
- **Modularización** del sistema de piezas
- **Separación de responsabilidades** en managers
- **Mejora de arquitectura** MVC
- **Documentación** de APIs internas

### Próximas Mejoras
- [ ] Sistema de logros
- [ ] Integración con servicios en la nube
- [ ] Modo multijugador cooperativo
- [ ] Editor de puzzles personalizado

---

## 📦 Sistema DLC y Packs

### Estructura de DLC
El juego utiliza un sistema de DLC (Contenido Descargable) para manejar diferentes packs de puzzles:

- `PacksData/sample_packs.json`: Contiene todos los packs y sus puzzles completos (fuente de verdad)
- `dlc/new_base_packs.json`: Índice de los packs disponibles (metadata sin puzzles)
- `user://dlc/packs/`: Archivos JSON de cada pack individual cuando son "descargados"
- `user://dlc/dlc_metadata.json`: Información sobre qué packs han sido comprados

### Funcionamiento
1. **Packs Base**: Algunos packs vienen desbloqueados (fruits, artistic-cities)
2. **Compras**: El jugador puede comprar packs adicionales via PackPurchaseManager
3. **Descargas**: Al comprar, se extrae del archivo base y se guarda como DLC individual
4. **Carga Dinámica**: El DLCManager carga solo los packs disponibles para el jugador

---

## 🎬 Componente LoadingPuzzle

### ✨ Descripción
Componente de animación tipo Tetris donde las piezas de una imagen caen y se ensamblan para formar el puzzle completo.

### 🎮 Características
- Selección aleatoria de imágenes de una lista predefinida
- Descomposición automática de imagen en piezas según filas y columnas
- Animación de caída tipo Tetris con efectos de gravedad
- Efectos visuales al aterrizar las piezas
- Sistema de reinicio de animación

### 📊 Propiedades Exportadas
```gdscript
@export var cols : int = 8        # Número de columnas del puzzle
@export var rows : int = 15       # Número de filas del puzzle
@export var duration: float = 1.5 # Duración total de la animación
```

### 🔄 Uso Básico
```gdscript
var loading_puzzle = preload("res://Scenes/Components/loadingPuzzle/loading_puzzle.tscn").instantiate()
add_child(loading_puzzle)
loading_puzzle.puzzle_completed.connect(_on_puzzle_completed)
```

---

*Documento actualizado: $(date)*
*Versión del juego: 1.0*
*Engine: Godot 4.4* 