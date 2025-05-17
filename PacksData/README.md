# Sistema de DLC para Puzzles

## Estructura

El juego utiliza un sistema de DLC (Contenido Descargable) para manejar diferentes packs de puzzles. La estructura es la siguiente:

### Archivos Base
- `PacksData/sample_packs.json`: Contiene todos los packs y sus puzzles completos (fuente de verdad).
- `dlc/new_base_packs.json`: Índice de los packs disponibles (metadata sin puzzles).

### Carpetas de DLC
- `user://dlc/packs/`: Aquí se almacenan los archivos JSON de cada pack individual cuando son "descargados".
- `user://dlc/dlc_metadata.json`: Contiene información sobre qué packs han sido comprados y están disponibles.

## Funcionamiento

1. **Packs Base**: El juego viene con algunos packs base desbloqueados (fruits, artistic-cities).
2. **Compras**: El jugador puede comprar packs adicionales a través del PackPurchaseManager.
3. **Descargas**: Cuando se compra un pack, se extrae del archivo base y se guarda como un archivo DLC individual.
4. **Carga Dinámica**: El DLCManager carga dinámicamente solo los packs que están disponibles para el jugador.

## Ventajas

- **Eficiencia**: Solo se cargan los packs necesarios.
- **Flexibilidad**: Se pueden añadir nuevos packs sin modificar el juego base.
- **Experiencia de Usuario**: El jugador puede ver claramente qué packs tiene disponibles y cuáles puede comprar.

## Flujo de Trabajo para Desarrolladores

1. Añade nuevos packs al archivo `sample_packs.json` completo.
2. Actualiza `new_base_packs.json` con la metadata del nuevo pack (sin puzzles).
3. Los puzzles se cargarán dinámicamente desde el archivo base cuando sea necesario.

## Notas

- Los archivos DLC se guardan en la carpeta de usuario para persistencia entre sesiones.
- El sistema simula descargas extrayendo contenido del archivo base en lugar de descargarlo de un servidor. 