-- ============================================================================
-- Migration: Diagnóstico previo de cancelaciones
-- Fecha: 2026-05-08 (segunda migración del día)
-- Ejecutar en: Supabase Studio → SQL Editor → New Query → pegar → Run
-- ============================================================================

ALTER TABLE tickets ADD COLUMN IF NOT EXISTS diagnostico_previo_cancelacion TEXT;
ALTER TABLE base_general ADD COLUMN IF NOT EXISTS diagnostico_previo_cancelacion TEXT;

-- Verificar
SELECT column_name, data_type
FROM information_schema.columns
WHERE column_name = 'diagnostico_previo_cancelacion'
  AND table_name IN ('tickets','base_general');
