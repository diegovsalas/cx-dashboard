-- Reversa de 2026-11-10_h2_fechas_resolucion.sql. Ninguna fecha original se modificó,
-- así que basta con quitar el trigger y la tabla de calidad.
begin;
drop trigger if exists cx_tickets_resolved_at on legacy.tickets;
drop function if exists legacy.cx_tickets_resolved_at();
drop table if exists legacy.cx_calidad_resolucion;
commit;
