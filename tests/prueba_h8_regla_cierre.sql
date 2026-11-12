-- Prueba local de la regla de cierre (todo se revierte al final).
begin;
\set ON_ERROR_STOP 0
create temp table r(caso text, ok boolean, msg text);
create or replace function pg_temp.probar(caso text, sql text) returns void language plpgsql as $$
begin
  execute sql; insert into r values (caso, true, '');
exception when check_violation then insert into r values (caso, false, sqlerrm);
end $$;
insert into legacy.tickets (folio, telefono, nombre, servicio, tipo, estatus, status_cancelacion) values
  ('ZT001','5200000000','Prueba','Aromatex','Solicitud de Cancelación','En proceso',null),
  ('ZT002','5200000000','Prueba','Aromatex','Solicitud de Cancelación','En proceso','Cancelada'),
  ('ZT003','5200000000','Prueba','Aromatex','Incidencia / Queja','En proceso',null);
select pg_temp.probar('1 cerrar cancelación sin resultado (debe fallar)', $q$update legacy.tickets set estatus='Cerrado' where folio='ZT001'$q$);
select pg_temp.probar('2 cerrar Cancelada sin fecha (debe fallar)', $q$update legacy.tickets set estatus='Cerrado' where folio='ZT002'$q$);
select pg_temp.probar('3 cerrar Cancelada con fecha (pasa)', $q$update legacy.tickets set estatus='Cerrado', fecha_efectiva_cancelacion='2026-11-30' where folio='ZT002'$q$);
select pg_temp.probar('4 quitar resultado a una cerrada (debe fallar)', $q$update legacy.tickets set status_cancelacion='En proceso' where folio='ZT002'$q$);
select pg_temp.probar('5 cerrar incidencia sin resultado (pasa)', $q$update legacy.tickets set estatus='Cerrado' where folio='ZT003'$q$);
select pg_temp.probar('6 Migración con acento (pasa)', $q$update legacy.tickets set estatus='Cerrado', status_cancelacion='Migración' where folio='ZT001'$q$);
select pg_temp.probar('7 reclasificar cerrada a cancelación sin resultado (debe fallar)', $q$update legacy.tickets set tipo='Solicitud de Cancelación' where folio='ZT003'$q$);
-- históricos que ya incumplen: otras ediciones siguen permitidas
select pg_temp.probar('8 editar zona de cancelación cerrada histórica sin resultado (pasa)',
  $q$update legacy.base_general set zona = zona where id = (select id from legacy.base_general where tipo_de_solicitud ilike '%cancelac%' and lower(status) in ('resuelta','resuelto','cerrado') and coalesce(status_cancelacion,'') not in ('Retenida','Cancelada','Downgrade','Migración','Cancelado por morosidad') limit 1)$q$);
select pg_temp.probar('9 base_general: cerrar cancelación sin resultado (debe fallar)',
  $q$update legacy.base_general set status='Resuelta' where id = (select id from legacy.base_general where tipo_de_solicitud ilike '%cancelac%' and status='Sin atender' and coalesce(status_cancelacion,'') in ('','Negociacion','En proceso') limit 1)$q$);
select * from r;
rollback;
