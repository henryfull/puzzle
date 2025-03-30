# Estructura de la escena PuzzleGame

Este documento explica cómo estructurar la escena PuzzleGame para que incluya todos los elementos necesarios en la escena en lugar de crearlos dinámicamente en el código.

## Elementos requeridos en la escena

Para que el juego funcione correctamente, la escena debe incluir los siguientes elementos:

### Reproductores de audio
- `AudioMove` (AudioStreamPlayer): Para el sonido al mover una pieza
- `AudioMerge` (AudioStreamPlayer): Para el sonido al fusionar piezas
- `AudioFlip` (AudioStreamPlayer): Para el sonido al voltear las piezas

### Temporizadores
- `VictoryTimer` (Timer): Para comprobar periódicamente si se ha completado el puzzle

### Interfaz de usuario (UI)
- `UILayer` (CanvasLayer): Capa que contiene todos los elementos de UI
  - `OptionsButton` (Button): Botón para mostrar las opciones
  - `SuccessMessage` (Label): Etiqueta para mostrar mensajes de éxito (inicialmente oculta)
  - `ErrorMessage` (Label): Etiqueta para mostrar mensajes de error (inicialmente oculta)
  - `BackButton` (Button): Botón para volver a la selección de puzzles
  - `FlipButton` (Button): Botón para voltear las piezas

## Conexiones de señales

Las siguientes señales deben estar conectadas:

1. `BackButton.pressed` -> `_on_BackButton_pressed()`
2. `FlipButton.pressed` -> `on_flip_button_pressed()`

## Notas adicionales

- No eliminar la función `create_options_button()`, ya que se encarga de configurar el botón de opciones
- Las piezas del puzzle seguirán creándose dinámicamente en el código, ya que su número y disposición dependen de la configuración del puzzle
- Si alguno de estos elementos no existe en la escena, el código tiene un fallback para crearlos dinámicamente, pero se recomienda incluirlos todos en la escena para mejor organización y rendimiento

## Ejemplo de estructura

```
PuzzleGame (Node2D)
├── AudioMove (AudioStreamPlayer)
├── AudioMerge (AudioStreamPlayer)
├── AudioFlip (AudioStreamPlayer)
├── VictoryTimer (Timer)
└── UILayer (CanvasLayer)
    ├── OptionsButton (Button)
    ├── SuccessMessage (Label)
    ├── ErrorMessage (Label)
    ├── BackButton (Button)
    └── FlipButton (Button)
```

Puedes cargar la escena preconfigurada que se encuentra en `Scenes/PuzzleGame.tscn` como punto de partida. 