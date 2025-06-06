# 🔲 Sistema de Bordes de Grupo - Documentación

## ✨ Descripción

Se ha implementado un nuevo sistema de **bordes visuales** que muestra un contorno alrededor de los grupos de piezas conectadas. Esto facilita enormemente la identificación visual de qué piezas pertenecen al mismo grupo.

## 🎨 Características Principales

### Visual del Sistema
- **Bordes Solo para Grupos**: Solo las piezas agrupadas (2+ piezas) muestran bordes
- **Piezas Individuales**: Las piezas sueltas no tienen borde para mantener claridad visual
- **Colores Dinámicos**: Cada grupo tiene un color de borde único basado en su ID
- **Contorno de Área Completa**: El borde sigue la forma exterior del grupo completo
- **Bordes Inteligentes**: Solo se dibuja el perímetro exterior, no líneas internas entre piezas del grupo

### Configuración Visual
- **Color por Defecto**: Amarillo sutil (`Color(1.0, 1.0, 0.0, 0.7)`)
- **Grosor por Defecto**: 2.0 píxeles (optimizado para contornos de área)
- **Opacidad por Defecto**: 70% (equilibrio entre visibilidad y sutileza)
- **Sistema Centralizado**: Un solo borde por grupo, dibujado alrededor del área completa

## 🛠️ Configuración desde el Editor

### En la Escena PuzzlePiece.tscn:

1. **Selecciona el nodo raíz** "PuzzlePiece"
2. **En el Inspector**, busca la sección **"Bordes de Grupo"**
3. **Variables configurables**:

```
enable_group_border_display: bool = true      # Activar/desactivar
group_border_thickness: float = 2.0          # Grosor del borde (contorno de área)
group_border_opacity: float = 0.7            # Opacidad (0.1 - 1.0) 
group_border_color_override: Color           # Color personalizado
```

## 📋 Funciones de Control Programático

### Desde PuzzleGame:

```gdscript
# Activar/desactivar bordes globalmente
puzzle_game.toggle_group_borders(true)  # o false

# Cambiar grosor de todos los bordes
puzzle_game.set_group_border_thickness(5.0)  # 5 píxeles

# Cambiar opacidad de todos los bordes
puzzle_game.set_group_border_opacity(0.6)  # 60% opacidad

# Refrescar todos los bordes (útil después de cambios)
puzzle_game.refresh_group_borders()

# Mostrar/ocultar temporalmente
puzzle_game.toggle_group_borders_visibility(false)
```

### Desde PuzzlePieceManager:

```gdscript
# Control más granular
piece_manager.set_group_borders_enabled(true)
piece_manager.set_group_border_thickness(4.0)
piece_manager.set_group_border_opacity(0.7)
piece_manager.refresh_all_group_borders()
piece_manager.toggle_group_borders_visibility(true)
```

### Desde PuzzlePiece individual:

```gdscript
# Controlar borde de una pieza específica
piece.create_group_border()
piece.remove_group_border()
piece.update_group_border()
piece.set_group_border_color(Color.RED)
piece.set_group_border_visible(false)
```

## 🌈 Sistema de Colores Automático

El sistema asigna automáticamente colores únicos a cada grupo basándose en el `group_id`:

1. **Rojo** - `Color(0.95, 0.3, 0.3, 1.0)`
2. **Verde** - `Color(0.3, 0.8, 0.3, 1.0)`
3. **Azul** - `Color(0.3, 0.3, 0.95, 1.0)`
4. **Amarillo** - `Color(0.95, 0.95, 0.3, 1.0)`
5. **Naranja** - `Color(0.95, 0.6, 0.3, 1.0)`
6. **Púrpura** - `Color(0.7, 0.3, 0.95, 1.0)`
7. **Cian** - `Color(0.3, 0.95, 0.95, 1.0)`
8. **Rosa** - `Color(0.95, 0.3, 0.6, 1.0)`
9. **Verde Lima** - `Color(0.5, 0.8, 0.2, 1.0)`
10. **Violeta** - `Color(0.5, 0.2, 0.8, 1.0)`

Los colores se reciclan para grupos adicionales.

## 🔄 Funcionamiento Automático

### Cuándo se Actualizan los Bordes:

1. **Al formar un grupo** - Se crean bordes automáticamente
2. **Al separar piezas** - Se eliminan bordes de piezas individuales
3. **Al mover grupos** - Los bordes se mantienen
4. **Al cambiar de grupo** - Los colores se actualizan automáticamente

### Eventos que Disparan Actualización:

- `update_pieces_group()` - Cuando cambia la composición del grupo
- `set_group_id()` - Cuando se asigna nuevo ID de grupo
- `_update_edge_pieces_in_group()` - Al finalizar operaciones de grupo

## 🎯 Casos de Uso

### 1. Activar Bordes Temporalmente para Debug:
```gdscript
# Al inicio del puzzle para ver grupos claramente
await get_tree().create_timer(2.0).timeout
puzzle_game.toggle_group_borders(true)
```

### 2. Cambiar Configuración Durante el Juego:
```gdscript
# Para puzzles más complejos, usar bordes más gruesos
if GLOBAL.rows > 8:
    puzzle_game.set_group_border_thickness(4.0)
    puzzle_game.set_group_border_opacity(0.9)
```

### 3. Modo de Ayuda Visual:
```gdscript
# Botón para mostrar/ocultar bordes como ayuda
func _on_help_button_pressed():
    var visible = !piece_manager.pieces[0].node.group_border_line.visible
    puzzle_game.toggle_group_borders_visibility(visible)
```

## 🔧 Personalización Avanzada

### Cambiar Colores Globalmente:
```gdscript
# Modificar la paleta de colores en PuzzlePiece.gd
var group_colors: Array = [
    Color(1.0, 0.0, 0.0, 1.0),    # Rojo brillante
    Color(0.0, 1.0, 0.0, 1.0),    # Verde brillante
    Color(0.0, 0.0, 1.0, 1.0),    # Azul brillante
    # ... más colores personalizados
]
```

### Ajustar Offset del Borde:
```gdscript
# En PuzzlePiece.gd, cambiar:
var border_offset: float = 8.0  # Mayor separación del sprite
```

### Bordes Redondeados (Avanzado):
```gdscript
# Modificar _update_border_outline() para usar curvas
# Requiere cálculos más complejos con Bezier curves
```

## 🚨 Solución de Problemas

### Bordes No Aparecen:
1. **Verificar** `enable_group_border_display = true`
2. **Asegurar** que hay grupos formados (2+ piezas)
3. **Llamar** `refresh_group_borders()` manualmente

### Bordes Muy Gruesos/Delgados:
```gdscript
# Ajustar grosor
puzzle_game.set_group_border_thickness(2.0)  # Más delgado
# o
puzzle_game.set_group_border_thickness(5.0)  # Más grueso
```

### Colores Muy Intensos/Apagados:
```gdscript
# Ajustar opacidad
puzzle_game.set_group_border_opacity(0.5)   # Más sutil
# o
puzzle_game.set_group_border_opacity(1.0)   # Más intenso
```

### Rendimiento:
- Los bordes usan `Line2D` que es eficiente
- Se crean/destruyen dinámicamente según sea necesario
- No afectan significativamente el rendimiento

## 📊 Configuraciones Recomendadas

### Para Puzzles Pequeños (3x3, 4x4):
```
thickness: 1.5
opacity: 0.6
color: Amarillo suave (contorno de área sutil)
```

### Para Puzzles Medianos (5x5, 6x6):
```
thickness: 2.0
opacity: 0.7
color: Automático (contorno de área equilibrado)
```

### Para Puzzles Grandes (8x8+):
```
thickness: 2.5
opacity: 0.8
color: Automático con buena visibilidad del contorno
```

### Para Dispositivos Móviles:
```
thickness: 2.0
opacity: 0.75
color: Contorno claro sin interferir con la imagen
```

## ✅ Beneficios del Sistema

1. **Claridad Visual**: Fácil identificación de grupos
2. **Retroalimentación Inmediata**: Ver grupos al formarse
3. **Accesibilidad**: Ayuda a usuarios con dificultades visuales
4. **Configurabilidad**: Adaptable a diferentes necesidades
5. **Rendimiento**: Implementación eficiente sin impacto notable

¡El sistema de bordes de grupo está listo y funcional! 🎉 