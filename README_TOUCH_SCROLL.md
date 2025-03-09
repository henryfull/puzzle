# Configuración de Desplazamiento Táctil

Este documento explica cómo configurar correctamente el desplazamiento táctil en el proyecto para dispositivos móviles como iPhone.

## Problema

El desplazamiento táctil en los ScrollContainer no funciona correctamente en dispositivos táctiles. Específicamente:
1. No se puede desplazar cuando se toca sobre elementos clicables (botones, etc.)
2. Solo funciona cuando se toca en los espacios vacíos entre elementos

## Solución Implementada

Se han implementado varias mejoras para solucionar este problema:

1. **Sistema de detección de gestos**: Se ha implementado un sistema que diferencia entre desplazamiento y clic basado en:
   - Distancia recorrida desde el inicio del toque
   - Tiempo que se mantiene el toque
   - Velocidad del movimiento

2. **ScrollContainer personalizado**: Se ha creado un ScrollContainer personalizado (`TouchScrollContainer`) que:
   - Captura todos los eventos táctiles
   - Determina si el gesto es un desplazamiento o un clic
   - Propaga los clics a los elementos correspondientes cuando es necesario

3. **Configuración de filtros de ratón**: 
   - El ScrollContainer tiene `mouse_filter = MOUSE_FILTER_STOP` para capturar todos los eventos táctiles
   - Los contenedores dentro del ScrollContainer tienen `mouse_filter = MOUSE_FILTER_IGNORE`
   - Los botones y elementos interactivos tienen `mouse_filter = MOUSE_FILTER_STOP`

4. **Inercia de desplazamiento**: Se ha implementado inercia para proporcionar una experiencia de desplazamiento más natural y fluida.

## Cómo Funciona

1. **Detección de gestos**:
   - Cuando se inicia un toque, se registra la posición inicial y se inicia un temporizador
   - Si el toque se mueve más allá de una zona muerta (10 píxeles por defecto), se considera un desplazamiento
   - Si el toque se mantiene sin moverse durante un tiempo (0.2 segundos por defecto), se considera un toque mantenido
   - Si el toque se libera rápidamente sin moverse mucho, se considera un clic

2. **Manejo de desplazamiento**:
   - Durante el desplazamiento, los eventos táctiles son capturados por el ScrollContainer
   - El ScrollContainer aplica el desplazamiento según la dirección y velocidad del gesto
   - Al finalizar el desplazamiento, se aplica inercia para un efecto más natural

3. **Manejo de clics**:
   - Si se detecta un clic (toque corto sin mucho movimiento), el evento se propaga al elemento correspondiente
   - Esto permite interactuar con botones y otros elementos clicables incluso dentro del ScrollContainer

## Archivos Implementados

- **TouchScrollContainer.gd**: ScrollContainer personalizado con sistema de detección de gestos
- **TouchScrollHandler.gd**: Script que se puede adjuntar a cualquier ScrollContainer existente
- **TouchScrollFix.gd**: Script que configura automáticamente todos los nodos
- **ProjectSettings.gd**: Script para configurar opciones de entrada táctil en tiempo de ejecución
- **EnableTouchEmulation.gd**: Script para habilitar la emulación táctil desde el ratón

## Cómo Usar el ScrollContainer Personalizado

### Opción 1: Usar la escena TouchScrollContainer

```gdscript
var touch_scroll_scene = load("res://Scenes/Components/TouchScrollContainer.tscn")
var scroll_container = touch_scroll_scene.instantiate()
```

### Opción 2: Adjuntar el script TouchScrollHandler a un ScrollContainer existente

```gdscript
var scroll_container = $ScrollContainer
var touch_handler_script = load("res://Scripts/TouchScrollHandler.gd")
scroll_container.set_script(touch_handler_script)
```

### Opción 3: Usar TouchScrollFix para configurar automáticamente

```gdscript
var TouchScrollFix = load("res://Scripts/TouchScrollFix.gd")
TouchScrollFix.configure_touch_scroll(self)
```

## Parámetros Configurables

Puedes ajustar los siguientes parámetros en los scripts `TouchScrollContainer.gd` y `TouchScrollHandler.gd`:

- `touch_scroll_speed`: Velocidad de desplazamiento (por defecto: 1.0)
- `touch_scroll_inertia`: Factor de inercia (0-1, por defecto: 0.9)
- `touch_scroll_deadzone`: Zona muerta en píxeles (por defecto: 10)
- `touch_hold_delay`: Tiempo para considerar un toque como mantenido (por defecto: 0.2 segundos)

## Solución de Problemas

Si el desplazamiento táctil sigue sin funcionar correctamente:

1. **Problema**: No se puede desplazar sobre elementos clicables
   - **Solución**: Asegúrate de que el script `TouchScrollContainer.gd` o `TouchScrollHandler.gd` esté adjunto al ScrollContainer

2. **Problema**: Los clics no funcionan después de desplazarse
   - **Solución**: Aumenta el valor de `touch_scroll_deadzone` para que sea más fácil detectar clics

3. **Problema**: El desplazamiento es demasiado sensible
   - **Solución**: Aumenta el valor de `touch_scroll_deadzone` y reduce el valor de `touch_scroll_speed`

4. **Problema**: El desplazamiento es demasiado lento
   - **Solución**: Aumenta el valor de `touch_scroll_speed`

5. **Problema**: La inercia es demasiado fuerte o débil
   - **Solución**: Ajusta el valor de `touch_scroll_inertia` (más cercano a 1 = más inercia)

## Configuración del Proyecto

Asegúrate de que el script `ProjectSettings.gd` esté configurado como autoload para habilitar automáticamente todas las opciones necesarias para el desplazamiento táctil. 