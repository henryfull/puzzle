# 🎨 Configuración de Efectos Visuales - Guía Rápida

## 📍 Dónde Configurar

Ve a la escena `Scenes/Components/PuzzlePiece/PuzzlePiece.tscn` y selecciona el nodo raíz "PuzzlePiece". En el Inspector verás las siguientes secciones:

## ⚙️ Variables de Configuración

### 🔧 **Efectos Visuales** (Grupo Principal)
- **`enable_visual_effects`**: Activa/desactiva todo el sistema de efectos
  - `true` = Efectos activados
  - `false` = Sin efectos (todas las piezas se ven igual)

### 👻 **Opacidad** (Subgrupo)
- **`single_piece_opacity`**: Transparencia de piezas sueltas
  - Rango: 0.1 (muy transparente) a 1.0 (completamente opaco)
  - **Valor recomendado**: 0.7 (un poco transparente)
  - **Si está muy transparente**: Sube el valor (ej: 0.8)
  - **Si quieres más contraste**: Baja el valor (ej: 0.6)

- **`grouped_piece_opacity`**: Transparencia de piezas agrupadas
  - Rango: 0.1 a 1.0
  - **Valor recomendado**: 1.0 (completamente opaco)
  - **Normalmente no tocar** - las piezas agrupadas deben verse claras

### ✨ **Brillo y Contraste** (Subgrupo)
- **`single_piece_brightness`**: Brillo de piezas sueltas
  - Rango: 0.3 (muy oscuro) a 1.5 (muy brillante)
  - **Valor recomendado**: 0.85 (un poco más oscuro que normal)
  - **Si se ven muy oscuras**: Sube el valor (ej: 0.9 o 0.95)
  - **Si quieres más contraste**: Baja el valor (ej: 0.8 o 0.75)

- **`grouped_piece_brightness`**: Brillo de piezas agrupadas
  - Rango: 0.3 a 1.5
  - **Valor recomendado**: 1.0 (brillo normal)
  - **Si las imágenes se ven muy brillantes**: Baja a 0.95 o 0.9
  - **Si quieres que resalten más**: Sube a 1.05 o 1.1

- **`correct_position_brightness`**: Brillo extra para piezas en posición correcta
  - Rango: 1.0 a 2.0
  - **Valor recomendado**: 1.15 (15% más brillante)
  - **Si el efecto es muy sutil**: Sube a 1.2 o 1.25
  - **Si es muy exagerado**: Baja a 1.1 o 1.05

- **`dragging_brightness`**: Brillo cuando arrastras una pieza
  - Rango: 1.0 a 2.0
  - **Valor recomendado**: 1.1 (10% más brillante)
  - **Si quieres más feedback visual**: Sube a 1.15 o 1.2
  - **Si es muy distractivo**: Baja a 1.05

## 🎯 Configuraciones Recomendadas por Tipo de Imagen

### 📸 **Imágenes Claras/Brillantes** (fotos con mucha luz)
```
single_piece_opacity = 0.75
grouped_piece_opacity = 1.0
single_piece_brightness = 0.8
grouped_piece_brightness = 0.95
correct_position_brightness = 1.1
dragging_brightness = 1.05
```

### 🌙 **Imágenes Oscuras** (fotos nocturnas, arte oscuro)
```
single_piece_opacity = 0.9
grouped_piece_opacity = 1.0
single_piece_brightness = 0.9
grouped_piece_brightness = 1.0
correct_position_brightness = 1
dragging_brightness = 1.10
```

### 🎨 **Imágenes Coloridas** (arte, ilustraciones vibrantes)
```
single_piece_opacity = 0.65
grouped_piece_opacity = 1.0
single_piece_brightness = 0.85
grouped_piece_brightness = 1.0
correct_position_brightness = 1.15
dragging_brightness = 1.1
```

### 📰 **Imágenes con Texto** (documentos, mapas)
```
single_piece_opacity = 0.8
grouped_piece_opacity = 1.0
single_piece_brightness = 0.9
grouped_piece_brightness = 1.0
correct_position_brightness = 1.1
dragging_brightness = 1.05
```

## 🔄 Cómo Aplicar los Cambios

1. **Abre Godot**
2. **Ve a la escena**: `Scenes/Components/PuzzlePiece/PuzzlePiece.tscn`
3. **Selecciona el nodo raíz** "PuzzlePiece"
4. **En el Inspector**, busca la sección "Efectos Visuales"
5. **Ajusta los valores** usando los deslizadores o escribiendo números
6. **Guarda la escena** (Ctrl+S)
7. **Prueba en el juego** para ver los cambios

## 💡 Consejos

- **Empieza con pequeños cambios**: Cambia de 0.05 en 0.05
- **Prueba en diferentes puzzles**: Lo que funciona para una imagen puede no funcionar para otra
- **Guarda configuraciones**: Anota las configuraciones que te gusten para diferentes tipos de imágenes
- **Menos es más**: Efectos sutiles suelen verse mejor que cambios dramáticos

## 🚨 Si Algo Sale Mal

**Valores seguros para volver al estado original**:
```
single_piece_opacity = 0.7
grouped_piece_opacity = 1.0
single_piece_brightness = 0.85
grouped_piece_brightness = 1.0
correct_position_brightness = 1.15
dragging_brightness = 1.1
``` 