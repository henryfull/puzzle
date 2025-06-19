#!/bin/bash

# Script para lanzar Godot con configuración completa para Android
echo "Configurando entorno para exportación Android..."

# Configurar Java 17
export JAVA_HOME="/opt/homebrew/Cellar/openjdk@17/17.0.15/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# Configurar Android SDK (ajusta la ruta según tu instalación)
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$PATH"

# Asegurar que el shell esté disponible
export SHELL="/bin/zsh"
export PATH="/bin:/usr/bin:/usr/local/bin:$PATH"

# Verificar configuración
echo "=== VERIFICACIÓN DE CONFIGURACIÓN ==="
echo "Java versión:"
java -version
echo ""
echo "JAVA_HOME: $JAVA_HOME"
echo "ANDROID_HOME: $ANDROID_HOME"
echo "Shell: $SHELL"
echo "PATH configurado correctamente"
echo ""

# Lanzar Godot con las variables de entorno
echo "Lanzando Godot con configuración completa..."
/Applications/Godot.app/Contents/MacOS/Godot

echo "¡Godot debería abrirse ahora con la configuración correcta para Android!" 