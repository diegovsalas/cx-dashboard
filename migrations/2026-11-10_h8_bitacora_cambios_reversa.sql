-- Reversa de 2026-11-10_h8_bitacora_cambios.sql. Quita los triggers; conserva la tabla con lo registrado.
begin;
drop trigger if exists cx_bitacora on legacy.tickets;
drop trigger if exists cx_bitacora on legacy.base_general;
drop function if exists legacy.cx_bitacora_registrar();
-- Para borrar también el historial registrado: drop table legacy.cx_bitacora_cambios;
commit;
