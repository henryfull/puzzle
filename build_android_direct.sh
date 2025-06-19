#!/bin/bash

echo "🔨 Construyendo proyecto Android directamente..."

# Configurar Java 17
export JAVA_HOME="/opt/homebrew/Cellar/openjdk@17/17.0.15/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# Configurar Android SDK
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/34.0.0:$PATH"

# Configurar Gradle
export GRADLE_OPTS="-Dorg.gradle.daemon=false"
export GRADLE_USER_HOME="$HOME/.gradle"

# Navegar al directorio de Android
cd android/build

echo "📋 Verificando herramientas..."
echo "Java: $(java -version 2>&1 | head -1)"
echo "Android SDK: $ANDROID_HOME"
echo "Directorio actual: $(pwd)"

# Limpiar construcciones anteriores
echo "🧹 Limpiando construcciones anteriores..."
./gradlew clean || echo "Nota: Limpieza completada"

# Construir el proyecto
echo "🔨 Iniciando construcción..."
./gradlew assembleDebug

if [ $? -eq 0 ]; then
    echo "✅ ¡Construcción exitosa!"
    echo "📱 APK generado en: build/outputs/apk/debug/"
    ls -la build/outputs/apk/debug/*.apk 2>/dev/null || echo "Buscando APK..."
else
    echo "❌ Error en la construcción"
    echo "💡 Revisa los errores arriba para más detalles"
fi 