Sistema de Puntuaciones – Requisitos Funcionales

Objetivo

Desarrollar un sistema de puntuación por puzzle que premie la precisión, la estrategia y el rendimiento del jugador, permitiendo además generar un ranking global con las mejores puntuaciones.

⸻

1. PUNTUACIÓN POR PUZZLE

1.1 Inicio de partida
	•	Al iniciar un puzzle, la puntuación del jugador se inicializa en 0 puntos.

1.2 Acciones que SUMAN puntos`

Acción	Descripción	Puntos otorgados
Pieza colocada correctamente en grupo	Se une al grupo principal o crea uno nuevo	+2 puntos
Unión de dos grupos mediante una pieza	Se colocan piezas que conectan dos grupos existentes	+5 puntos
Racha de aciertos	Racha de 3: +1 por pieza\nRacha de 5: +2\nRacha de 10+: +3	Acumulativo por pieza durante la racha
Puzzle completado	El jugador ha completado todas las piezas del puzzle	+20 puntos base
Puzzle sin errores	No ha habido movimientos inválidos	+15 puntos extra
Puzzle sin usar flip	El jugador no ha usado pistas	+10 puntos extra

1.3 Acciones que RESTAN puntos

Acción	Descripción	Penalización
Movimiento inválido	La pieza movida no se agrupa con nada	–1 punto
Uso de flip o ayuda visual	Visualiza el reverso o usa pista	–5 puntos por uso
Deshacer acción (opcional)	Si se permite una opción de “undo”	–2 puntos
Piezas flotantes (opcional)	Piezas no unidas tras X movimientos	–3 puntos cada X turnos


⸻

2. GESTIÓN DE RACHAS
	•	Contador interno de aciertos consecutivos.
	•	Colocar pieza correctamente: +1 al contador.
	•	Error o uso de flip: resetear contador a 0.
	•	Bonus según la racha activa se aplica automáticamente.

⸻

3. REGISTRO Y PERSISTENCIA DE PUNTUACIONES

3.1 Registro por puzzle
	•	Se guarda la puntuación obtenida al completar cada puzzle.
	•	Al repetir el puzzle, se guarda la mejor puntuación alcanzada.

3.2 Ranking global
	•	Suma de las mejores puntuaciones por puzzle.
	•	Opcional: múltiples intentos con mejor resultado almacenado.

3.3 Almacenamiento
	•	Guardado local y sincronización con base de datos del ranking.
	•	Soporte para almacenamiento en la nube (Google/Apple/Steam).

⸻

4. INTERFAZ DE USUARIO

4.1 Durante el puzzle
	•	Mostrar:
	•	Puntuación actual
	•	Indicador de racha activa (si hay)
	•	Penalizaciones (opcional)

4.2 Al finalizar el puzzle
	•	Pantalla resumen:
	•	Puntuación total
	•	Detalle de puntos ganados y perdidos
	•	Bonus obtenidos
	•	Botón para repetir o volver

4.3 Ranking global
	•	Lista ordenada de jugadores:
	•	Alias
	•	Puntuación total
	•	Posición en ranking
	•	Opcional: filtros por amigos, país o global

⸻

5. REQUISITOS TÉCNICOS Y LÓGICOS
	•	Sistema modular con constantes configurables.
	•	Opción para desactivarlo en modo “relax” o “aprendizaje”.
	•	Desacoplado del sistema visual (independiente del renderizado).