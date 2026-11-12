-- Reversa de 2026-11-11_h8_regla_cierre_cancelacion.sql
begin;
drop trigger if exists cx_regla_cierre_cancelacion on legacy.tickets;
drop trigger if exists cx_regla_cierre_cancelacion on legacy.base_general;
drop function if exists legacy.cx_validar_cierre_cancelacion();
commit;
