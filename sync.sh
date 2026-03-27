#!/bin/bash

# Script para sincronizar cambios a GitHub y Render
# Uso: ./sync.sh "Tu mensaje de commit"

if [ -z "$1" ]; then
  MSG="Actualizar dashboard y dependencias"
else
  MSG="$1"
fi

echo "🔄 Sincronizando cambios..."

# Verificar que estamos en el directorio correcto
if [ ! -f "package.json" ]; then
  echo "❌ Error: Debes ejecutar este script desde la raíz del proyecto"
  exit 1
fi

# Stage archivos
echo "📦 Agregando archivos..."
git add .

# Crear commit
echo "💾 Creando commit..."
git commit -m "$MSG"

# Push a GitHub
echo "🚀 Subiendo a GitHub..."
git push origin main

echo ""
echo "✅ ¡Sincronización completada!"
echo "📊 Render recibirá los cambios en 1-2 minutos"
echo "🔗 Monitorea en: https://dashboard.render.com"
