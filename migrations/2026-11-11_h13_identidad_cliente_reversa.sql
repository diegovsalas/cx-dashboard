-- Reversa de 2026-11-11_h13_identidad_cliente.sql
begin;
drop trigger if exists cx_regla_identidad_cierre on legacy.tickets;
drop function if exists legacy.cx_validar_identidad_cierre();
update legacy.tickets t set telefono = r.telefono from legacy.cx_h13_respaldo_telefono r where r.tabla = 'tickets' and t.folio = r.fila;
update legacy.mensajes m set telefono = r.telefono from legacy.cx_h13_respaldo_telefono r where r.tabla = 'mensajes' and m.id::text = r.fila;
delete from legacy.cx_h13_respaldo_telefono;   -- ya restaurado; deja la tabla lista para volver a aplicar
commit;
