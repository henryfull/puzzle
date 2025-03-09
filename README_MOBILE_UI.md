# Adaptación de UI para Dispositivos Móviles

Este documento explica cómo implementar la adaptación de la interfaz de usuario para dispositivos móviles en el juego de puzzle.

## Archivos Creados

Se han creado los siguientes archivos para adaptar la UI a dispositivos móviles:

1. `Scripts/UIScaler.gd` - Utilidad para escalar elementos de la UI según el dispositivo
2. `Scripts/MobileTheme.gd` - Generador de tema adaptado para dispositivos móviles
3. `Scripts/UIInitializer.gd` - Script de inicialización para adaptar la UI en todas las escenas
4. `Scripts/Autoload/ThemeManager.gd` - Gestor de temas para aplicar automáticamente el tema móvil

## Modificaciones Realizadas

Se han modificado los siguientes archivos para adaptarlos a dispositivos móviles:

1. `Scripts/GLOBAL.gd` - Añadida configuración de escala de UI y detección de dispositivos móviles
2. `Scripts/MainMenu.gd` - Adaptación de botones para dispositivos móviles
3. `Scripts/VictoryScreen.gd` - Adaptación de la pantalla de victoria para dispositivos móviles
4. `Scripts/PuzzleGame.gd` - Adaptación del botón de verificación y mensajes para dispositivos móviles
5. `Scripts/Options.gd` - Adaptación de la pantalla de opciones para dispositivos móviles

## Pasos para Implementar

Para implementar estos cambios en el proyecto, sigue estos pasos:

### 1. Configurar Autoloads

Añade los siguientes scripts como autoloads en el proyecto:

1. Abre el proyecto en Godot
2. Ve a Proyecto > Configuración del Proyecto > Autoload
3. Añade los siguientes autoloads:
   - `UIInitializer` - Ruta: `res://Scripts/UIInitializer.gd`
   - `ThemeManager` - Ruta: `res://Scripts/Autoload/ThemeManager.gd`

### 2. Verificar Exportación para Móviles

Asegúrate de que la configuración de exportación para dispositivos móviles esté correctamente configurada:

1. Ve a Proyecto > Exportar
2. Configura una plantilla para Android y/o iOS
3. En la sección "Pantalla", asegúrate de que:
   - "Orientación" esté configurada según las necesidades del juego (normalmente "Landscape")
   - "Permitir redimensionar" esté activado
   - "Mantener relación de aspecto" esté activado

### 3. Probar en Dispositivos Reales o Emuladores

Es importante probar la UI en dispositivos reales o emuladores para asegurarse de que:

1. Los botones son lo suficientemente grandes para interactuar con ellos cómodamente
2. Los textos son legibles en diferentes tamaños de pantalla
3. La disposición de los elementos se adapta correctamente a diferentes resoluciones

## Funcionamiento

El sistema de adaptación de UI funciona de la siguiente manera:

1. `UIScaler.gd` detecta si el juego se está ejecutando en un dispositivo móvil y calcula un factor de escala adecuado.
2. `ThemeManager.gd` aplica automáticamente un tema adaptado a dispositivos móviles cuando se detecta que el juego se está ejecutando en uno.
3. Cada escena utiliza el factor de escala para ajustar el tamaño de sus elementos de UI.
4. Los botones y elementos interactivos se hacen más grandes en dispositivos móviles para facilitar la interacción táctil.

## Personalización

Si necesitas personalizar la adaptación para una escena específica, puedes:

1. Acceder al factor de escala actual a través de `UIScaler.get_scale_factor()`
2. Aplicar manualmente el escalado a elementos específicos
3. Modificar `MobileTheme.gd` para ajustar el aspecto visual del tema móvil

## Resolución de Problemas

Si encuentras problemas con la adaptación de la UI:

1. Verifica que los autoloads estén correctamente configurados
2. Comprueba que los nodos de la UI estén utilizando contenedores (Container) y anclajes (anchors) adecuadamente
3. Asegúrate de que los elementos interactivos tengan un tamaño mínimo adecuado para la interacción táctil (al menos 44x44 píxeles)
4. Utiliza la herramienta de vista remota de Godot para depurar la UI en dispositivos reales

## Notas Adicionales

- Los factores de escala se ajustan automáticamente según el tamaño de la pantalla del dispositivo
- Se ha añadido padding adicional a los botones para mejorar la experiencia táctil
- Los tamaños de fuente se aumentan proporcionalmente en dispositivos móviles para mejorar la legibilidad 