-- Reversa de 2026-11-11_h11_reclasificar_sin_clasificar.sql
begin;
update legacy.tickets t set tipo = r.tipo from legacy.cx_h11_respaldo_tipo r where t.folio = r.folio;
commit;
