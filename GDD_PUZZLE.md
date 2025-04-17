# Game Design Document: Puzzle

## 0. Portada del Proyecto
- **Título del juego**: Puzzle  
- **Versión del documento**: v1.0  
- **Fecha**: 17 de abril de 2025  
- **Desarrollador**: Enric Vallribera  
- **Contacto**: [tu email o perfil de contacto]  
- *(Logo o imagen del juego si aplica)*

---

## 1. Información General

### 1.1 Concepto del Juego
Puzzle es un juego de rompecabezas para dispositivos móviles y PC donde los jugadores deben reconstruir imágenes divididas en piezas. El juego ofrece varios packs temáticos, diferentes niveles de dificultad y varios modos de juego adaptados a distintos estilos de jugadores.

### 1.2 Plataformas
- iOS  
- Android  
- Windows  
- macOS  

### 1.3 Público Objetivo
- Jugadores casuales de todas las edades  
- Amantes de rompecabezas y retos mentales  
- Personas que buscan entretenimiento relajante  

---

## 2. Gameplay

### 2.1 Mecánicas Básicas
- **Arrastrar y Soltar**: Para posicionar piezas.
- **Unión de Piezas**: Piezas encajan y se agrupan automáticamente.
- **Paneo del Tablero**: Permite desplazarse por el área de juego.
- **Volteo de Piezas**: Vista alternativa en el reverso de las piezas.

### 2.2 Modos de Juego
1. **Modo Principiante (Learner)**  
2. **Modo Relax**  
3. **Modo Normal**  
4. **Modo Contrarreloj (Time Trial)**  
5. **Modo Desafío (Challenge)**  

### 2.3 Niveles de Dificultad
- Desde configuraciones simples (1x4) hasta complejas (6x8).  
- Ajuste libre del número de filas y columnas.

### 2.4 Progresión del Juego
- Packs temáticos con desbloqueo progresivo.  
- Algunos packs requieren compra o logro.

---

## 3. Contenido del Juego

### 3.1 Packs de Puzzles
- **Fruits** *(desbloqueado)*  
- **Numbers** *(desbloqueo requerido)*  
- **Wild Animals** *(desbloqueo requerido)*  
- **Farm Animals** *(desbloqueo requerido)*  

Cada pack contiene de 7 a 10 puzzles.

### 3.2 Elementos de Interfaz
- Menú Principal  
- Selección de Pack  
- Selección de Puzzle  
- Pantalla de Juego  
- Pantalla de Victoria  

---

## 4. Características Técnicas

### 4.1 Estructura del Proyecto
- `Scenes/`  
- `Scripts/`  
- `Resources/`  
- `Assets/`  
- `Data/`  
- `Addons/`  

### 4.2 Adaptación a Dispositivos Móviles
- Interfaz escalable y táctil.  
- Botones optimizados para pantallas pequeñas.  
- Orientación adaptable.

### 4.3 Elementos Especiales
- Sistema de Z-Index  
- Contenedor Táctil Personalizado  
- Viewport dinámico para texturas  
- Sistema de Pausa

---

## 5. Sistema de Progresión y Logros

### 5.1 Guardado de Progreso
- Guardado automático.  
- Registro de puzzles completados y estadísticas.

### 5.2 Estadísticas
- Tiempo jugado  
- Puzzles resueltos  
- Movimientos promedio  
- Logros alcanzados

### 5.3 Logros
- Resolver en X tiempo o movimientos  
- Uso/no uso del volteo  
- Completar packs

---

## 6. Características Adicionales

### 6.1 Opciones y Configuración
- Volumen: música, efectos, voces  
- Idioma  
- Accesibilidad  
- Sensibilidad de desplazamiento  
- Efectos visuales

### 6.2 Efectos Visuales
- Animaciones suaves  
- Indicadores de acción  
- Transiciones  
- Notificaciones emergentes

### 6.3 Audio
- Efectos para todas las interacciones  
- Música ambiental relajante

---

## 7. Modelo de Negocio

- Gratuito con packs premium  
- Desbloqueo anticipado opcional  
- Compras in-app para ayudas o contenido visual  

---

## 8. Particularidades y Ventajas Competitivas

- Interfaz amigable para todas las edades  
- Sistema de volteo único  
- Modos para relajarse o competir  
- Progresión ajustada al jugador

---

## 9. Narrativa y Estética

### 9.1 Estilo Visual
- Estética cartoon, limpia y minimalista  
- Colores suaves y atractivos  
- Packs con identidad visual coherente  

### 9.2 Ambientación
- No hay narrativa lineal, pero los packs reflejan mundos visuales distintos.  
- Música y arte visual trabajan en conjunto.

---

## 10. UX y Diseño de Jugabilidad

### 10.1 Flujo del Jugador
1. Inicio  
2. Menú Principal  
3. Selección de pack  
4. Selección de puzzle  
5. Modo de juego  
6. Gameplay  
7. Resultados  

### 10.2 Tutorial
- Modo principiante con tutorial interactivo.  
- Ayuda contextual integrada.

---

## 11. IA y Algoritmos

### 11.1 Colocación de Piezas
- Sistema de validación por proximidad  
- Detección de agrupamiento y unión automática

### 11.2 Dificultad Dinámica
- Sugerencias si el jugador se estanca  
- Parámetros ajustables para un reto justo

---

## 12. Localización

- Idiomas disponibles: Español, Inglés, Francés  
- Packs y menús localizados  
- Preparado para internacionalización

---

## 13. Monetización Ética

- Sin anuncios intrusivos  
- Compras solo para contenido visual o acceso temprano  
- El contenido principal es accesible sin pagar

---

## 14. Pruebas y Lanzamiento

### 14.1 Fases de Testeo
- Alpha cerrada  
- Beta abierta (TestFlight / Google Play Beta)  
- Test en múltiples resoluciones

### 14.2 Roadmap de Lanzamiento
- Alpha: Junio 2025  
- Beta: Agosto 2025  
- Lanzamiento: Octubre 2025