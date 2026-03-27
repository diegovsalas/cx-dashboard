#!/bin/bash

# COMANDOS ÚTILES PARA GITHUB Y RENDER
# Copia y pega según sea necesario

echo "═══════════════════════════════════════════════════════════"
echo "📋 COMANDOS ÚTILES - CX-DASHBOARD"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. SINCRONIZAR CON GITHUB
echo "1️⃣  SINCRONIZAR CON GITHUB"
echo "   cd /Users/diego/migracion-supabase"
echo "   git add ."
echo "   git commit -m 'Tu mensaje aquí'"
echo "   git push origin main"
echo ""

# 2. VERIFICAR STATUS
echo "2️⃣  VERIFICAR STATUS"
echo "   git status"
echo "   git log --oneline -5"
echo ""

# 3. VER CAMBIOS
echo "3️⃣  VER CAMBIOS"
echo "   git diff              # Cambios sin hacer stage"
echo "   git diff --staged     # Cambios ya en stage"
echo ""

# 4. DESHACER CAMBIOS
echo "4️⃣  DESHACER CAMBIOS"
echo "   git checkout -- archivo.txt           # Deshacer un archivo"
echo "   git reset --hard HEAD                 # Deshacer TODO (cuidado!)"
echo ""

# 5. RAMAS
echo "5️⃣  TRABAJAR CON RAMAS"
echo "   git branch                            # Ver ramas locales"
echo "   git branch nueva-rama                 # Crear rama"
echo "   git checkout nueva-rama               # Cambiar a rama"
echo "   git push origin nueva-rama            # Subir nueva rama"
echo ""

# 6. ACTUALIZAR DESDE GITHUB
echo "6️⃣  ACTUALIZAR DESDE GITHUB"
echo "   git fetch origin                      # Traer cambios (sin aplicar)"
echo "   git pull origin main                  # Traer y aplicar cambios"
echo ""

# 7. MONITOREAR RENDER
echo "7️⃣  MONITOREAR RENDER"
echo "   Dashboard: https://dashboard.render.com"
echo "   Tu servicio: https://dashboard.render.com → cx-dashboard"
echo "   Logs en vivo: Panel de Render → Logs"
echo ""

# 8. PROBAR LOCALMENTE
echo "8️⃣  PROBAR LOCALMENTE"
echo "   npm install                           # Instalar dependencias"
echo "   npm start                             # Iniciar servidor (puerto 3000)"
echo "   Luego: http://localhost:3000"
echo ""

# 9. VARIABLES DE ENTORNO
echo "9️⃣  CONFIGURAR VARIABLES"
echo "   cp .env.example .env"
echo "   # Edita .env con tus credenciales"
echo ""

# 10. TROUBLESHOOTING
echo "🔟 TROUBLESHOOTING"
echo "   Error de npm: rm -rf node_modules && npm install"
echo "   Error de git: git status (para diagnosticar)"
echo "   Error en Render: Ver logs en dashboard.render.com"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "💡 NOTAS:"
echo "   • Siempre haz commit antes de cambiar de rama"
echo "   • Escribe mensajes de commit claros"
echo "   • Pushea regularmente a GitHub"
echo "   • Render redeploya automáticamente al hacer push"
echo "═══════════════════════════════════════════════════════════"
