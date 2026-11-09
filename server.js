const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
// index:false para que '/' lo sirva nuestra ruta (index.html de la raíz), no public/index.html
app.use(express.static(path.join(__dirname, 'public'), { index: false }));
app.use(express.json());

// Servir el dashboard (index.html de la RAÍZ = app real)
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Assets locales que usa el dashboard (sin exponer scripts .py/.sql del repo)
app.get('/favicon.png', (req, res) => {
  res.sendFile(path.join(__dirname, 'favicon.png'));
});
app.get('/guia.html', (req, res) => {
  res.sendFile(path.join(__dirname, 'guia.html'));
});

// Configuración pública por ambiente (solo URL y anon key, nunca service key).
// APP_ENV=staging exige un proyecto Supabase distinto al de producción.
const PROD_SUPABASE_REF = 'cyntwgxryfbrboehcdex';
const APP_ENV = process.env.APP_ENV || 'production';
if (APP_ENV === 'staging') {
  const url = process.env.SUPABASE_URL || '';
  if (!url || !process.env.SUPABASE_ANON_KEY || url.includes(PROD_SUPABASE_REF)) {
    console.error('APP_ENV=staging requiere SUPABASE_URL y SUPABASE_ANON_KEY de un proyecto distinto a producción.');
    process.exit(1);
  }
}
app.get('/env.js', (req, res) => {
  res.type('application/javascript').set('Cache-Control', 'no-store');
  if (APP_ENV !== 'staging') return res.send('window.CX_ENV={name:"production"};');
  res.send('window.CX_ENV=' + JSON.stringify({
    name: 'staging',
    supabaseUrl: process.env.SUPABASE_URL,
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY,
  }) + ';');
});

// Health check para Render
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API para obtener configuración (sin exponer credenciales)
app.get('/api/config', (req, res) => {
  res.json({
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'production'
  });
});

// Manejo de errores 404
app.use((req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

// Iniciar servidor
app.listen(PORT, () => {
  console.log(`🚀 Dashboard Customer Experience corriendo en puerto ${PORT}`);
  console.log(`📊 Accede en: http://localhost:${PORT}`);
});
