# Customer Experience Dashboard 📊

Dashboard para monitoreo de incidencias y solicitudes de servicio. Permite consultar, analizar y filtrar registros por año, mes, tipo de servicio, zona, status y más.

## Características

✨ **Dashboard Interactivo**
- KPIs en tiempo real (Total, Resueltas, Pendientes, Cancelaciones, Tiempo de Respuesta)
- Gráficos dinámicos (10 visualizaciones)
- Filtros por año, mes, servicio, zona, status, tipo de incidencia y ejecutivo

🔍 **Consulta de Status**
- Búsqueda avanzada por folio, cliente, propiedad, tipo de incidencia
- Resultados paginados
- Información detallada por registro

📋 **Base General**
- Vista completa de todos los registros
- Búsqueda y filtrado
- Información organizada en columnas

🔐 **Autenticación**
- Integración con Supabase Auth
- Login seguro
- Datos protegidos

## Instalación Local

### Requisitos
- Node.js 14+
- npm o yarn
- Credenciales de Supabase

### Pasos

1. **Clonar el repositorio**
```bash
git clone https://github.com/diegovsalas/cx-dashboard.git
cd cx-dashboard
```

2. **Instalar dependencias**
```bash
npm install
```

3. **Configurar variables de entorno**
```bash
cp .env.example .env
```

Edita `.env` con tus credenciales:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
PORT=3000
NODE_ENV=development
```

4. **Iniciar en desarrollo**
```bash
npm run dev
```

El dashboard estará disponible en `http://localhost:3000`

## Despliegue en Render

### Opción 1: Usando Render Dashboard

1. **Ir a [Render.com](https://render.com)**
2. **Crear una nueva cuenta o iniciar sesión**
3. **Conectar tu repositorio de GitHub**
4. **Crear nuevo servicio web:**
   - Elegir "Web Service"
   - Conectar tu repositorio `cx-dashboard`
   - Configurar:
     - **Name:** `cx-dashboard`
     - **Environment:** Node
     - **Build Command:** `npm install`
     - **Start Command:** `npm start`
     - **Plan:** Free (o pagado según necesidades)

5. **Agregar variables de entorno:**
   - En la sección "Environment"
   - Agregar:
     - `SUPABASE_URL`: Tu URL de Supabase
     - `SUPABASE_ANON_KEY`: Tu anon key de Supabase
     - `NODE_ENV`: `production`

6. **Deploy**
   - Render realizará el deploy automáticamente
   - Tu dashboard estará disponible en: `https://cx-dashboard.onrender.com`

### Opción 2: Usar render.yaml (Infraestructura como Código)

Ya existe un archivo `render.yaml` configurado. Solo necesitas:

1. Commitear los cambios:
```bash
git add .
git commit -m "Setup para deploy en Render"
git push origin main
```

2. En Render dashboard, conectar el repositorio y crear el servicio
3. Las variables de entorno deben configurarse en la UI de Render

## Estructura del Proyecto

```
.
├── public/
│   └── index.html          # Dashboard HTML
├── server.js               # Servidor Express
├── package.json            # Dependencias
├── .env.example            # Variables de ejemplo
├── .gitignore              # Archivos ignorados
├── render.yaml             # Config de Render
└── README.md               # Este archivo
```

## Configuración de Supabase

### Requisitos en Supabase

1. **Tabla `base_general`** con campos:
   - `id` (int)
   - `folio_ticket` (text)
   - `fecha_de_la_solicitud` (date/timestamp)
   - `mes` (text)
   - `nombre_del_cliente_nuevo` (text)
   - `propiedad` (text)
   - `tipo_de_solicitud` (text)
   - `tipo_de_incidencia` (text)
   - `submotvio` (text)
   - `status` (text)
   - `ejecutivo_asignado` (text)
   - `zona` (text)
   - `tipo_de_servicio` (text)
   - `tiempo_de_respuesta` (numeric)
   - `fecha_de_solucion` (date/timestamp)
   - Y otros campos según necesites

2. **Autenticación habilitada** en Supabase

3. **Políticas de seguridad (RLS)** configuradas

## Variables de Entorno

```env
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here

# Server
PORT=3000
NODE_ENV=production
```

## API Endpoints

- **GET /** - Sirve el dashboard HTML
- **GET /health** - Health check para Render
- **GET /api/config** - Info de configuración (versión, ambiente)

## Monitoreo

En Render, puedes monitorear:
- **Logs**: En el dashboard de Render
- **CPU y Memoria**: Métricas en tiempo real
- **Redeploys**: Historial de deployments

## Solución de Problemas

### El dashboard no carga
1. Verifica que las credenciales de Supabase sean correctas
2. Revisa la consola del navegador (F12) para errores
3. Verifica los logs en Render

### Error de autenticación
1. Verifica que `SUPABASE_URL` y `SUPABASE_ANON_KEY` sean correctas
2. Comprueba que la autenticación esté habilitada en Supabase
3. Verifica las políticas RLS en la tabla

### Los gráficos no se cargan
1. Verifica que los datos tengan los campos correctos
2. Revisa la consola del navegador para errores de Chart.js
3. Comprueba que haya datos para mostrar

## Soporte

Para reportar problemas o sugerencias:
- Crear un issue en GitHub
- Contactar al equipo de desarrollo

## Licencia

MIT

---

**Última actualización:** 27 de marzo de 2026
