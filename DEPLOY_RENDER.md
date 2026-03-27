# GUÍA RÁPIDA DE DEPLOY EN RENDER 🚀

## Pasos para desplegar tu Dashboard en Render

### 1️⃣ Prepara tu Repositorio (Local)
```bash
cd /Users/diego/migracion-supabase

# Inicializa git si no lo has hecho
git init

# Agrega todos los archivos
git add .

# Primer commit
git commit -m "Setup inicial del dashboard para Render"

# Agrega tu repositorio remoto de GitHub
git remote add origin https://github.com/tu-usuario/cx-dashboard.git

# Push al main
git push -u origin main
```

### 2️⃣ Configurar Render

#### Opción A: Desde el Dashboard de Render (MÁS FÁCIL)

1. Ve a https://dashboard.render.com
2. Haz clic en **"New +"** → **"Web Service"**
3. Conecta tu repositorio de GitHub (cx-dashboard)
4. Llena los campos:
   - **Name:** `cx-dashboard`
   - **Environment:** `Node`
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
   - **Plan:** Free (gratis, con limitaciones)
5. Haz clic en **"Create Web Service"**

#### Opción B: Variables de Entorno (Importante)

Una vez creado el servicio:

1. Ve a **Settings** del servicio
2. Baja hasta **Environment**
3. Agrega estas variables:
   ```
   SUPABASE_URL: https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY: tu-anon-key-aqui
   NODE_ENV: production
   ```
4. Haz clic en **Save**

### 3️⃣ Tu Dashboard Estará En:
```
https://cx-dashboard.onrender.com
```

---

## ⚙️ Archivos Creados/Modificados

✅ `package.json` - Dependencias Node
✅ `server.js` - Servidor Express
✅ `.env.example` - Template de variables
✅ `.gitignore` - Archivos a ignorar en git
✅ `render.yaml` - Config de Render (opcional)
✅ `README.md` - Documentación completa
✅ `public/index.html` - Dashboard HTML

---

## 📋 Checklist Antes de Deploy

- [ ] Tu repositorio está en GitHub
- [ ] Has configurado las variables de Supabase en Render
- [ ] El archivo `package.json` existe con las dependencias
- [ ] El archivo `server.js` existe y es válido
- [ ] La carpeta `public/` existe con `index.html`

---

## 🔧 Troubleshooting

### ❌ "Cannot find module 'express'"
- Render debería instalar automáticamente con `npm install`
- Si falla, revisa los logs en el dashboard de Render

### ❌ "SUPABASE_URL is undefined"
- Ve a Settings → Environment
- Verifica que las variables estén configuradas
- Haz clic en "Save" después de cambios

### ❌ El dashboard carga pero no muestra datos
- Verifica que `SUPABASE_ANON_KEY` es correcta
- Revisa que la tabla `base_general` exista en Supabase
- Abre la consola del navegador (F12) para ver errores

---

## 📞 Información Adicional

**Tiempo de Deploy:** 1-3 minutos
**Uptime:** 99.9% en plan pagado, 0.5 horas/mes en free
**Escalabilidad:** Automática con plan pagado

---

Cualquier duda, consulta: https://docs.render.com
