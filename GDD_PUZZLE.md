# Game Design Document: Puzzle

## 1. Información General

### 1.1 Concepto del Juego
Puzzle es un juego de rompecabezas para dispositivos móviles y PC donde los jugadores deben reconstruir imágenes divididas en piezas. El juego ofrece varios packs temáticos con múltiples puzzles en cada uno, diferentes niveles de dificultad y varios modos de juego para adaptarse a diferentes estilos de jugadores.

### 1.2 Plataformas
- Dispositivos móviles (iOS, Android)
- PC (Windows, macOS)

### 1.3 Público Objetivo
- Jugadores casuales de todas las edades
- Aficionados a los juegos de rompecabezas
- Personas que buscan un entretenimiento relajante o un desafío mental

## 2. Gameplay

### 2.1 Mecánicas Básicas
- **Arrastrar y Soltar**: Los jugadores pueden arrastrar las piezas y soltarlas en su posición.
- **Unión de Piezas**: Las piezas que encajan correctamente se unen automáticamente formando grupos.
- **Paneo del Tablero**: Los jugadores pueden desplazarse por el tablero de juego para ver todas las piezas disponibles.
- **Volteo de Piezas**: Los jugadores pueden voltear las piezas para ver el diseño trasero como ayuda adicional.

### 2.2 Modos de Juego
1. **Modo Principiante (Learner)**: Tutorial y puzles muy simples (1x4) para familiarizarse con el juego.
2. **Modo Relax**: Sin límites de tiempo ni movimientos, permite disfrutar del juego sin presión.
3. **Modo Normal**: Contabiliza el tiempo y los movimientos, pero sin límites estrictos.
4. **Modo Contrarreloj (Time Trial)**: Los jugadores deben completar el puzzle antes de que se acabe el tiempo.
5. **Modo Desafío (Challenge)**: Límite de movimientos y de volteos de piezas, ofreciendo un mayor reto.

### 2.3 Niveles de Dificultad
La dificultad se ajusta mediante el número de piezas en el tablero:
- El tamaño del puzzle puede variar desde configuraciones sencillas (p.ej., 1x4 para el modo principiante)
- Hasta configuraciones más complejas (por defecto 6x8)
- El juego permite ajustar el número de columnas y filas según preferencia

### 2.4 Progresión del Juego
- Packs de puzzles temáticos con múltiples imágenes dentro de cada pack
- Sistema de desbloqueo progresivo: completar un puzzle desbloquea el siguiente
- Algunos packs están bloqueados inicialmente y pueden requerir compra o ser desbloqueados por progresión

## 3. Contenido del Juego

### 3.1 Packs de Puzzles
El juego incluye varios packs temáticos, cada uno con múltiples puzzles:
1. **Fruits**: Colección de imágenes relacionadas con frutas. (Desbloqueado por defecto)
2. **Numbers**: Colección de imágenes relacionadas con números. (Requiere desbloqueo)
3. **Wild Animals**: Colección de imágenes de animales salvajes. (Requiere desbloqueo)
4. **Farm Animals**: Colección de imágenes de animales de granja. (Requiere desbloqueo)

Cada pack contiene entre 7-10 puzzles relacionados con su temática.

### 3.2 Elementos de Interfaz
- **Menú Principal**: Acceso a jugar, opciones, logros y estadísticas
- **Selección de Pack**: Muestra los packs disponibles y su estado (bloqueado/desbloqueado)
- **Selección de Puzzle**: Muestra los puzzles dentro de un pack y su estado (completado/pendiente)
- **Pantalla de Juego**: Incluye el tablero de juego, botones de acción y contadores
- **Pantalla de Victoria**: Muestra estadísticas de la partida y opciones para continuar

## 4. Características Técnicas

### 4.1 Estructura del Proyecto
El proyecto está organizado en varios directorios principales:
- **Scenes**: Contiene todas las escenas del juego
- **Scripts**: Contiene toda la lógica de programación
- **Resources**: Contiene recursos como materiales y configuraciones
- **Assets**: Contiene activos como audio, fuentes e imágenes
- **Data**: Contiene datos y esquemas para el juego
- **Addons**: Contiene plugins adicionales como godotsteam

### 4.2 Adaptación para Dispositivos Móviles
- Interfaz escalable que se adapta a diferentes tamaños de pantalla
- Botones más grandes y espaciados en dispositivos móviles
- Sistema de desplazamiento táctil mejorado para facilitar el uso en pantallas táctiles
- Optimizaciones para diferentes resoluciones y orientaciones de pantalla

### 4.3 Elementos Especiales
- **Sistema de Z-Index**: Gestión de capas visuales para asegurar que los elementos se muestren correctamente
- **Contenedor Táctil Personalizado**: Mejora la experiencia de desplazamiento en dispositivos táctiles
- **Viewport para Texturas**: Generación dinámica de texturas para el lado trasero de las piezas
- **Sistema de Pausa**: Permite pausar el juego y acceder a opciones sin perder progreso

## 5. Sistema de Progresión y Logros

### 5.1 Guardado de Progreso
- El juego guarda automáticamente el progreso de los jugadores
- Se registran los packs y puzzles completados
- Se almacenan estadísticas como tiempo total jugado y puzzles resueltos

### 5.2 Estadísticas
El juego registra y muestra varias estadísticas:
- Número total de puzzles completados
- Tiempo total de juego
- Movimientos promedio por puzzle
- Logros desbloqueados

### 5.3 Logros
El juego incluye un sistema de logros que recompensa diferentes hitos:
- Completar puzzles en diferentes niveles de dificultad
- Utilizar (o no) la función de volteo
- Resolver puzzles en un tiempo determinado o con un número limitado de movimientos

## 6. Características Adicionales

### 6.1 Opciones y Configuración
- Ajustes de volumen separados para música, efectos y voces
- Selección de idioma
- Opciones de accesibilidad como tamaño de fuente
- Sensibilidad de desplazamiento del tablero
- Efectos visuales (activar/desactivar)

### 6.2 Efectos y Respuesta Visual
- Animaciones para la unión de piezas
- Efectos para indicar victoria o acciones incorrectas
- Notificaciones de logros desbloqueados
- Efectos de transición entre pantallas

### 6.3 Audio
- Efectos de sonido para mover piezas, unir piezas y completar puzzles
- Efectos de sonido para voltear piezas
- Música de fondo ambiental

## 7. Modelo de Negocio
El juego puede seguir diferentes modelos:
- Gratuito con packs adicionales de pago
- Sistema de desbloqueo progresivo con opción de compra anticipada
- Sistema de consejos o ayudas adicionales mediante compras in-app

## 8. Particularidades y Ventajas Competitivas
- Interfaz intuitiva y accesible para jugadores de todas las edades
- Sistema de volteo de piezas que añade una capa adicional de estrategia
- Adaptación optimizada para dispositivos móviles
- Variedad de modos de juego que ofrecen diferentes experiencias
- Sistema progresivo de dificultad que mantiene el interés a largo plazo 