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
