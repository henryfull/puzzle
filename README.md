# Juego de Puzzles en Godot 4.4

Este proyecto es un juego de puzzles desarrollado en Godot 4.4, donde los jugadores pueden disfrutar de diferentes packs de puzzles con distintos niveles de dificultad.

## Características

- Múltiples packs de puzzles temáticos
- Sistema de progresión que desbloquea puzzles y packs a medida que se avanza
- Soporte para packs de pago que pueden ser comprados
- Guardado automático del progreso
- Interfaz de usuario intuitiva y atractiva

## Sistema de Progresión

El juego implementa un sistema de progresión que funciona de la siguiente manera:

### Progresión de Puzzles

- Cada pack contiene múltiples puzzles
- Inicialmente, solo el primer puzzle de cada pack está desbloqueado
- Al completar un puzzle, se desbloquea automáticamente el siguiente
- Los puzzles bloqueados aparecen con un icono de candado y no se pueden seleccionar

### Progresión de Packs

- Inicialmente, solo el primer pack está desbloqueado
- Al completar todos los puzzles de un pack, se marca como completado y se desbloquea el siguiente pack
- Los packs bloqueados aparecen con un indicador visual y no se pueden seleccionar

### Packs de Pago

- Algunos packs requieren ser comprados antes de poder jugarlos
- Estos packs aparecen con un botón de "Comprar"
- Una vez comprados, se desbloquea su primer puzzle y se pueden jugar normalmente

## Estructura de Datos

El sistema utiliza un archivo JSON para almacenar la información de los packs y puzzles, y un archivo de guardado para mantener el progreso del jugador:

```json
// Estructura del archivo de progresión (user://progress.json)
{
  "packs": {
    "pack1": {
      "unlocked": true,
      "purchased": true,
      "completed": false,
      "puzzles": {
        "puzzle1": {"completed": true, "unlocked": true},
        "puzzle2": {"completed": false, "unlocked": true},
        "puzzle3": {"completed": false, "unlocked": false}
      }
    },
    "pack2": {
      "unlocked": false,
      "purchased": false,
      "completed": false,
      "puzzles": {}
    }
  }
}
```

## Implementación Técnica

El sistema de progresión se implementa a través de las siguientes clases:

- `ProgressManager`: Singleton que gestiona toda la progresión, carga y guarda los datos
- `PackSelection`: Muestra los packs disponibles y su estado (desbloqueado, comprado, completado)
- `PuzzleSelection`: Muestra los puzzles de un pack y su estado (desbloqueado, completado)
- `PuzzleGame`: El juego en sí, que marca los puzzles como completados al terminarlos

## Cómo Usar

1. Clona este repositorio
2. Abre el proyecto en Godot 4.4
3. Ejecuta el juego desde la escena MainMenu.tscn

## Licencia

Este proyecto está licenciado bajo [tu licencia aquí].

# Mejoras en el Juego de Puzzle

Este documento resume las mejoras implementadas en el juego de puzzle para resolver los problemas de desaparición incorrecta de grupos y separación de piezas.

## Problemas Resueltos

1. **Gestión de Grupos**: Se ha mejorado la función `merge_pieces` para asegurar que los grupos se fusionen correctamente y mantengan sus relaciones espaciales. Ahora, cuando dos piezas se fusionan, todas las piezas del grupo mantienen la misma referencia al grupo.

2. **Prevención de Solapamientos**: Se ha mejorado la función `ensure_no_overlaps` para detectar y resolver solapamientos de piezas. Cuando se detecta un solapamiento, se mueve todo el grupo a una posición libre, expandiendo el tablero si es necesario.

3. **Colocación Inteligente de Piezas**: Se han implementado las funciones `find_best_position_for_group` y `find_random_position_for_group` para encontrar posiciones adecuadas para los grupos sin solapamientos.

4. **Detección de Grupos Completos**: Se ha mejorado la función `check_and_remove_completed_groups` para detectar correctamente cuando un grupo está completo y hacerlo desaparecer con una animación.

5. **Verificación de Victoria**: Se ha mejorado la función `check_victory` para verificar correctamente cuando el puzzle está completo, ya sea porque todas las piezas están en su posición original o porque no quedan piezas.

## Beneficios

- **Prevención de Solapamientos**: Las piezas ya no se solapan incorrectamente.
- **Integridad de Grupos**: Una vez que las piezas forman un grupo, permanecen juntas durante el movimiento.
- **Expansión Automática del Tablero**: El tablero se expande automáticamente cuando es necesario para acomodar grupos grandes.
- **Experiencia de Juego Mejorada**: El juego ahora ofrece una experiencia más fluida y predecible.

## Próximos Pasos

- Implementar niveles de dificultad
- Añadir un sistema de puntuación
- Mejorar la interfaz de usuario
- Añadir efectos de sonido adicionales 