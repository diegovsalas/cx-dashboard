begin;
create temp table r(caso text, ok boolean, msg text);
create or replace function pg_temp.probar(caso text, sql text) returns void language plpgsql as $$
begin execute sql; insert into r values (caso, true, '');
exception when check_violation then insert into r values (caso, false, sqlerrm); end $$;
insert into legacy.tickets (folio, telefono, nombre, servicio, tipo, estatus, canal_origen) values
  ('ZI001','5200000000','P','Aromatex','Falla','En proceso','cx'),
  ('ZI002','5200000000','P','Aromatex','Falla','En proceso','aromatex');
select pg_temp.probar('1 cerrar CX sin zona ni sucursal (falla)', $q$update legacy.tickets set estatus='Cerrado' where folio='ZI001'$q$);
select pg_temp.probar('2 cerrar CX con zona inválida (falla)', $q$update legacy.tickets set estatus='Cerrado', zona='Marte', empresa='Única' where folio='ZI001'$q$);
select pg_temp.probar('3 cerrar CX con zona y sucursal (pasa)', $q$update legacy.tickets set estatus='Resuelto', zona='Bajío', empresa='Única' where folio='ZI001'$q$);
select pg_temp.probar('4 ya cerrado: borrar sucursal y pasar a Cerrado (pasa)', $q$update legacy.tickets set empresa=null, estatus='Cerrado' where folio='ZI001'$q$);
select pg_temp.probar('5 Aromatex sin datos (pasa)', $q$update legacy.tickets set estatus='Cerrado' where folio='ZI002'$q$);
select pg_temp.probar('6 histórico cerrado sin zona: editar otro campo (pasa)', $q$update legacy.tickets set prioridad=prioridad where folio=(select folio from legacy.tickets where estatus='Cerrado' and coalesce(zona,'')='' and coalesce(canal_origen,'cx')='cx' limit 1)$q$);
select * from r; rollback;
