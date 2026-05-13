-- ============================================================================
-- Migration: Columnas para Retención de Cancelaciones
-- Fecha: 2026-05-08
-- Ejecutar en: Supabase Studio → SQL Editor → New Query → pegar → Run
-- ============================================================================

-- Tickets WhatsApp tipo "Solicitud de Cancelación"
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS oferta_retencion TEXT;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS causa_raiz_cancelacion TEXT;

-- Cancelaciones legacy (base_general)
-- Nota: base_general ya tiene `anlisis_de_causa_raz` para causa raíz,
--       solo agregamos `oferta_retencion`
ALTER TABLE base_general ADD COLUMN IF NOT EXISTS oferta_retencion TEXT;

-- Verificar
SELECT
  column_name, data_type
FROM information_schema.columns
WHERE (table_name = 'tickets' AND column_name IN ('oferta_retencion','causa_raiz_cancelacion'))
   OR (table_name = 'base_general' AND column_name = 'oferta_retencion');
