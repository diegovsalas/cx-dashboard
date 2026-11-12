-- Reversa de 2026-11-11_h15_prioridad_abiertos.sql
begin;
update legacy.tickets t set prioridad = r.prioridad from legacy.cx_h15_respaldo_prioridad r where t.folio = r.folio;
commit;
