-- ============================================================================
-- Migration: Tabla de envíos de plantillas WhatsApp (campañas NPS, info, etc.)
-- Fecha: 2026-05-20
-- Ejecutar en: Supabase Studio → SQL Editor → New Query → pegar → Run
-- ============================================================================

CREATE TABLE IF NOT EXISTS envios_plantillas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_name TEXT NOT NULL,
  campania TEXT,                            -- agrupa varios envíos (ej: "NPS-Mayo-2026")
  telefono TEXT NOT NULL,
  nombre_cliente TEXT,
  parametros JSONB,                         -- {customer_name: "Juan", ticket_id: "A0125"}
  estado TEXT DEFAULT 'pendiente',          -- pendiente | enviado | entregado | leido | respondido | fallido
  meta_message_id TEXT,                     -- WAMID que devuelve Meta
  respuesta_cliente TEXT,                   -- texto crudo de la respuesta
  respuesta_score INT,                      -- número extraído (para NPS: 0-10)
  respuesta_categoria TEXT,                 -- promotor | pasivo | detractor (NPS) | otro
  enviado_at TIMESTAMPTZ,
  entregado_at TIMESTAMPTZ,
  leido_at TIMESTAMPTZ,
  respondido_at TIMESTAMPTZ,
  error_mensaje TEXT,
  enviado_por TEXT,                         -- agente que disparó la campaña
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_envios_telefono ON envios_plantillas(telefono);
CREATE INDEX IF NOT EXISTS idx_envios_campania ON envios_plantillas(campania);
CREATE INDEX IF NOT EXISTS idx_envios_template ON envios_plantillas(template_name);
CREATE INDEX IF NOT EXISTS idx_envios_estado ON envios_plantillas(estado);
CREATE INDEX IF NOT EXISTS idx_envios_created ON envios_plantillas(created_at DESC);

-- Verificar
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'envios_plantillas'
ORDER BY ordinal_position;
