-- Reversa de 2026-11-11_h6_csat_ticket_correcto.sql: regresa csat y comentario al respaldo.
begin;
update legacy.tickets t set csat = r.csat, comentario_csat = r.comentario_csat
  from legacy.cx_h6_respaldo_csat r where t.folio = r.folio;
commit;
-- Después, si ya no se necesita: drop table legacy.cx_h6_respaldo_csat;
