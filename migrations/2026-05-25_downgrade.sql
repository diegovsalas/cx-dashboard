-- ============================================================================
-- Migration: Soporte de Downgrade en cancelaciones (retención parcial)
-- Fecha: 2026-05-25
-- ============================================================================

ALTER TABLE tickets ADD COLUMN IF NOT EXISTS monto_nuevo_downgrade NUMERIC;
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS descripcion_downgrade TEXT;
ALTER TABLE base_general ADD COLUMN IF NOT EXISTS monto_nuevo_downgrade NUMERIC;
ALTER TABLE base_general ADD COLUMN IF NOT EXISTS descripcion_downgrade TEXT;

-- Verificar
SELECT column_name, data_type
FROM information_schema.columns
WHERE column_name IN ('monto_nuevo_downgrade','descripcion_downgrade')
  AND table_name IN ('tickets','base_general')
ORDER BY table_name, column_name;
