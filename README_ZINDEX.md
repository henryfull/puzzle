# Sistema de Ordenamiento Visual y Manejo de Eventos en Godot

Este documento explica cómo funciona el sistema de ordenamiento visual (z-index y CanvasLayer) en Godot, el manejo de eventos de entrada y cómo resolver problemas comunes.

## Entendiendo z-index y CanvasLayer

En Godot, existen dos sistemas principales para controlar qué objetos se dibujan encima de otros:

### 1. Z-Index

- El z-index sólo funciona para ordenar nodos que comparten el mismo padre directo.
- Un z-index mayor hace que un nodo se dibuje por encima de otros nodos con z-index menor.
- Valores de z-index pueden ser positivos o negativos.
- Por defecto, el z-index de un nodo es 0.
- La propiedad `z_as_relative` determina si el z-index es relativo al padre (valor por defecto) o absoluto.

### 2. CanvasLayer

- Los CanvasLayers son capas completas de renderizado.
- Un CanvasLayer con un valor de capa (layer) mayor se dibuja por encima de un CanvasLayer con valor menor.
- **Importante**: Todos los nodos dentro de un CanvasLayer se dibujarán encima o debajo de los nodos de la escena principal, dependiendo del valor de la capa.
- Por defecto, la escena principal está en la capa 0, y cualquier CanvasLayer con valor 1 o mayor se dibujará por encima.

## Manejo de Eventos de Entrada

El manejo de eventos de entrada en Godot sigue estas reglas:

1. Los eventos primero son procesados por los CanvasLayers en orden inverso (del último al primero).
2. Dentro de cada CanvasLayer, los eventos se propagan desde los nodos hijos más recientes a los más antiguos.
3. La propiedad `mouse_filter` en los nodos Control determina si bloquean, procesan o pasan los eventos:
   - `STOP (0)`: Bloquea todos los eventos (comportamiento predeterminado)
   - `PASS (1)`: Procesa el evento y lo pasa al siguiente nodo
   - `IGNORE (2)`: Ignora el evento por completo

### Recomendación para Fondos

Para fondos que no deben bloquear eventos, usa `mouse_filter = 2` (IGNORE) en los nodos ColorRect o TextureRect.

## Estructura recomendada para escenas con fondo y UI

### Opción 1: Fondo como nodo directo (para escenas simples)
```
MiEscena (Node2D o Control)
├── Fondo (ColorRect o TextureRect) [z-index = -10, mouse_filter = 2]
├── ContenidoPrincipal (Node2D) [z-index = 0]
│   └── [Contenido de juego, piezas, personajes, etc.]
└── UILayer (CanvasLayer) [layer = 1]
    └── [Interfaz de usuario, botones, textos, etc.]
```

### Opción 2: Fondo en un CanvasLayer (recomendado para fondos que ocupan toda la pantalla)
```
MiEscena (Node2D o Control)
├── BackgroundLayer (CanvasLayer) [layer = -1]
│   └── Fondo (ColorRect o TextureRect) [mouse_filter = 2]
├── ContenidoPrincipal (Node2D) [z-index = 0]
│   └── [Contenido de juego, piezas, personajes, etc.]
└── UILayer (CanvasLayer) [layer = 1]
    └── [Interfaz de usuario, botones, textos, etc.]
```

## Ejemplo para el puzzle

Para nuestro juego de puzzle, hemos aplicado la Opción 2 con tres capas:

1. El fondo (ColorRect) está en un `BackgroundLayer` (CanvasLayer) con `layer = -1` para que siempre esté detrás de todo.
   - El ColorRect tiene `mouse_filter = 2` para que no bloquee eventos de clic.
2. El contenedor de piezas está como hijo directo del nodo raíz con z-index=5.
3. La UI está en un `UILayer` (CanvasLayer) con `layer = 1` para asegurar que siempre se dibuje por encima de todo.

### Consideraciones importantes

1. **Manejo de eventos táctiles/mouse**: Asegúrate de que los elementos de fondo no bloqueen los eventos estableciendo `mouse_filter = 2`.
2. **Jerarquía de nodos**: Ten en cuenta que los contenedores pueden cambiar cómo se manejan las coordenadas globales y locales.
3. **Diagnóstico**: En caso de problemas, imprime las coordenadas de los clics y la posición de los nodos para detectar discrepancias.

Estructura final:
```
PuzzleGame (Node2D)
├── BackgroundLayer (CanvasLayer) [layer = -1]
│   └── ColorRect [mouse_filter = 2]
├── PiecesContainer (Node2D) [z-index = 5]
│   └── [Piezas del puzzle]
├── UILayer (CanvasLayer) [layer = 1]
│   ├── Botones
│   ├── Etiquetas
│   └── Otros elementos de UI
└── [Otros nodos del juego]
``` 