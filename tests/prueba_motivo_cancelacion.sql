begin;
create temp table r(caso text, ok boolean, msg text);
create or replace function pg_temp.probar(caso text, sql text) returns void language plpgsql as $$
begin execute sql; insert into r values (caso, true, '');
exception when check_violation then insert into r values (caso, false, sqlerrm); end $$;
insert into legacy.tickets (folio, telefono, nombre, servicio, tipo, estatus, categoria, zona, empresa) values
  ('ZM001','5200000000','P','Aromatex','Solicitud de Cancelación','En proceso','Cancelación de servicio','Matriz','Única');
select pg_temp.probar('1 cerrar Retenida sin motivo (falla)', $q$update legacy.tickets set estatus='Cerrado', status_cancelacion='Retenida' where folio='ZM001'$q$);
select pg_temp.probar('2 cerrar Retenida con motivo (pasa)', $q$update legacy.tickets set estatus='Cerrado', status_cancelacion='Retenida', categoria='Económico' where folio='ZM001'$q$);
select pg_temp.probar('3 quitar motivo a una cerrada (falla)', $q$update legacy.tickets set categoria='Cancelación de servicio' where folio='ZM001'$q$);
select pg_temp.probar('4 histórico base_general sin motivo sigue igual que H8 (pasa)', $q$update legacy.base_general set status='Resuelta', status_cancelacion='Retenida' where id=(select id from legacy.base_general where tipo_de_solicitud ilike '%cancelac%' and status='Sin atender' limit 1)$q$);
select pg_temp.probar('5 cerrada histórica sin motivo: editar comentario (pasa)', $q$update legacy.tickets set comentarios_de_seguimiento=coalesce(comentarios_de_seguimiento,'')||'' where folio=(select folio from legacy.tickets where tipo ilike '%cancelac%' and estatus='Cerrado' and categoria='Cancelación de servicio' limit 1)$q$);
select * from r; rollback;
