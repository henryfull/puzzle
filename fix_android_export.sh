#!/bin/bash

echo "🔧 Configurando entorno para exportación Android..."

# Cerrar cualquier instancia de Godot que esté corriendo
killall Godot 2>/dev/null || true

# Configurar Java 17
export JAVA_HOME="/opt/homebrew/Cellar/openjdk@17/17.0.15/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# Configurar Android SDK
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/34.0.0:$PATH"

# Asegurar que las herramientas básicas estén disponibles
export SHELL="/bin/zsh"
export PATH="/bin:/usr/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

# Configurar variables específicas para Gradle
export GRADLE_OPTS="-Dorg.gradle.daemon=false"
export GRADLE_USER_HOME="$HOME/.gradle"

# Verificar que todo esté configurado
echo "📋 Verificando configuración..."
echo "Java: $(java -version 2>&1 | head -1)"
echo "JAVA_HOME: $JAVA_HOME"
echo "ANDROID_HOME: $ANDROID_HOME"
echo "Gradle build tools: $ANDROID_HOME/build-tools/34.0.0"

# Verificar que las herramientas existan
if [ ! -f "$JAVA_HOME/bin/java" ]; then
    echo "❌ ERROR: Java no encontrado en $JAVA_HOME"
    exit 1
fi

if [ ! -d "$ANDROID_HOME" ]; then
    echo "❌ ERROR: Android SDK no encontrado en $ANDROID_HOME"
    exit 1
fi

if [ ! -f "/bin/sh" ]; then
    echo "❌ ERROR: Shell no encontrado"
    exit 1
fi

echo "✅ Configuración correcta"
echo ""

# Navegar al directorio del proyecto
cd "/Users/lleno/workspace/videogames/puzzle"

# Abrir Godot con el proyecto directamente
echo "🚀 Abriendo Godot con configuración Android..."
/Applications/Godot.app/Contents/MacOS/Godot --path "$(pwd)" --editor &

echo ""
echo "✅ Godot abierto con configuración Android"
echo "📱 Ahora puedes intentar exportar a Android"
echo "💡 Si el error persiste, prueba a exportar desde la terminal con el comando gradle directamente" 