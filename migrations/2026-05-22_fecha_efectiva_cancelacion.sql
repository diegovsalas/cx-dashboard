-- ============================================================================
-- Migration: Fecha efectiva de cancelación
-- Fecha: 2026-05-22
-- Propósito: que el monto cancelado afecte el mes correcto en los KPIs,
--            no el mes en que se creó el ticket.
-- ============================================================================

ALTER TABLE tickets ADD COLUMN IF NOT EXISTS fecha_efectiva_cancelacion DATE;
ALTER TABLE base_general ADD COLUMN IF NOT EXISTS fecha_efectiva_cancelacion DATE;

-- Verificar
SELECT column_name, data_type
FROM information_schema.columns
WHERE column_name = 'fecha_efectiva_cancelacion'
  AND table_name IN ('tickets','base_general');
