# LoadingPuzzle - Componente de Animación Tetris

Este componente crea una animación tipo Tetris donde las piezas de una imagen caen y se ensamblan para formar el puzzle completo.

## Características

- ✅ Selección aleatoria de imágenes de una lista predefinida
- ✅ Descomposición automática de la imagen en piezas según filas y columnas
- ✅ Animación de caída tipo Tetris con efectos de gravedad
- ✅ Efectos visuales al aterrizar las piezas
- ✅ Señal de completado cuando todas las piezas han caído
- ✅ Sistema de reinicio de animación
- ✅ Soporte para imágenes específicas

## Propiedades Exportadas

```gdscript
@export var cols : int = 8        # Número de columnas del puzzle
@export var rows : int = 15       # Número de filas del puzzle
@export var duration: float = 1.5 # Duración total de la animación
```

## Señales

```gdscript
signal puzzle_completed  # Se emite cuando todas las piezas han caído
```

## Métodos Públicos

### `restart_animation()`
Reinicia la animación con una nueva imagen aleatoria.

### `set_specific_image(image_path: String)`
Usa una imagen específica para el puzzle.

### `get_animation_progress() -> float`
Retorna el progreso de la animación (0.0 a 1.0).

## Uso

### Uso Básico
```gdscript
# Instanciar la escena
var loading_puzzle = preload("res://Scenes/Components/loadingPuzzle/loading_puzzle.tscn").instantiate()
add_child(loading_puzzle)

# Conectar la señal de completado
loading_puzzle.puzzle_completed.connect(_on_puzzle_completed)

func _on_puzzle_completed():
    print("¡Puzzle completado!")
```

### Configuración Personalizada
```gdscript
# Cambiar propiedades antes de añadir a la escena
loading_puzzle.cols = 10
loading_puzzle.rows = 8
loading_puzzle.duration = 2.0
```

### Reiniciar Animación
```gdscript
# Reiniciar con una nueva imagen aleatoria
loading_puzzle.restart_animation()
```

### Usar Imagen Específica
```gdscript
# Usar una imagen específica
loading_puzzle.set_specific_image("res://Assets/Images/mi_imagen.jpg")
```

## Lista de Imágenes

Las imágenes se encuentran en la lista `list_images` del script:
- `res://Assets/Images/arte1.jpg`
- `res://Assets/Images/arte2.jpg`
- `res://Assets/Images/paisaje1.jpg`
- `res://Assets/Images/paisaje2.jpg`

Para añadir más imágenes, modifica el array `list_images` en el script.

## Efectos Visuales

### Animación de Caída
- Las piezas caen desde arriba con variación aleatoria en posición inicial
- Aplicación de curva de aceleración (gravedad simulada)
- Rotación sutil durante la caída
- Retrasos aleatorios para efecto más natural

### Efectos de Aterrizaje
- Efecto de impacto cuando las piezas aterrizan (squash and stretch)
- Corrección automática de rotación al aterrizar
- Efecto de brillo al completar el puzzle

## Configuración Técnica

### Estructura del Nodo
```
LoadingPuzzle (Node2D)
├── Container (Node2D)
│   ├── Piece1 (Node2D)
│   │   └── Sprite2D
│   ├── Piece2 (Node2D)
│   │   └── Sprite2D
│   └── ...
```

### Rendimiento
- Las piezas se crean dinámicamente en `_ready()`
- Las texturas se generan a partir de regiones de la imagen original
- Sistema de limpieza automática de piezas anteriores
- Control de animación para evitar superposiciones

## Archivo de Prueba

Se incluye `test_loading_puzzle.tscn` para probar el componente:
- Botón de reinicio
- Etiqueta informativa
- Configuración de ejemplo

## Notas Técnicas

1. **Formato de Imagen**: Compatible con formatos JPG, PNG
2. **Tamaño**: Las piezas se adaptan automáticamente al tamaño de la imagen
3. **Memoria**: Las texturas se liberan automáticamente al cambiar de imagen
4. **Threading**: Toda la animación se ejecuta en el hilo principal
5. **Escalabilidad**: Optimizado para hasta 15x15 piezas (225 piezas)

## Solución de Problemas

### La imagen no se carga
- Verificar que la ruta de la imagen sea correcta
- Asegurarse de que el archivo esté importado en Godot
- Revisar la consola para mensajes de error

### Las piezas no caen correctamente
- Verificar que el nodo padre sea de tipo Node2D
- Asegurar que las propiedades cols y rows sean mayores a 0
- Verificar que la duración sea mayor a 0

### Rendimiento lento
- Reducir el número de filas y columnas
- Optimizar las imágenes (resolución menor)
- Verificar que no haya memory leaks en animaciones anteriores 