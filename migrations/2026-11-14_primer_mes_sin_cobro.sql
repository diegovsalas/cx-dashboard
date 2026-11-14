-- Regla (14-nov-2026, Diego Velázquez): la fecha efectiva de baja es el PRIMER MES SIN COBRO.
-- 1) Las 37 fechas recuperadas de «DD MES SE MANDA BAJA» pasan al día 1 del mes siguiente
--    (la baja se manda en el mes del último cobro; p. ej. 24-sep → 1-oct).
-- 2) Bajas que afectaron octubre 2026 (lista de Diego): fecha efectiva 2026-10-01.
-- 3) A0470, A0571, A0691 y A0615: bajas parciales → resultado Downgrade, efecto 2026-10-01.
--    A0615 era «Calidad del aroma: No huele» con cambio de equipo en sistema; se reclasifica a cancelación.
--    El nuevo monto mensual de cada downgrade lo captura la agente en la ficha (no se inventa).
-- Respaldo y evidencia: legacy.cx_recuperacion_chat. Reversa: ..._reversa.sql.
begin;
select set_config('request.jwt.claims', '{"email":"regla primer mes sin cobro (14-nov)"}', true);
create table if not exists legacy.cx_ajuste_primer_mes (fuente text, registro text, campo text, valor_anterior text, valor_nuevo text, evidencia text, aplicado_at timestamptz default now(), primary key (fuente, registro, campo));
revoke all on legacy.cx_ajuste_primer_mes from anon, authenticated;
grant select on legacy.cx_ajuste_primer_mes to authenticated, service_role;
alter table legacy.cx_ajuste_primer_mes enable row level security;
drop policy if exists cx_ajuste_leer on legacy.cx_ajuste_primer_mes;
create policy cx_ajuste_leer on legacy.cx_ajuste_primer_mes for select to authenticated using (true);

create table if not exists legacy.cx_tmp_fecha_pm (folio text primary key, fecha date, evidencia text);
truncate legacy.cx_tmp_fecha_pm;
insert into legacy.cx_tmp_fecha_pm values
  ('A0189','2026-07-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «26 JUNIO SE MANDA BAJA»'),
  ('A0345','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «31 AGOSTO SE MANDA BAJA»'),
  ('A0362','2026-08-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «29 JULIO SE MANDA BAJA»'),
  ('A0386','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «27 AGOSTO SE MANDA BAJA»'),
  ('A0388','2026-08-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «30 JULIO SE MANDA BAJA»'),
  ('A0389','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «20 de agosto se manda baja»'),
  ('A0394','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «27 AGOSTO SE MANDA BAJA»'),
  ('A0395','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «27 AGOSTO SE MANDA BAJA»'),
  ('A0406','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «28 AGOSTO SE MANDA BAJA»'),
  ('A0407','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «27 AGOSTO SE MANDA BAJA»'),
  ('A0414','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «27 AGOSTO, SE MANDA BAJA»'),
  ('A0424','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «27 AGOSTO SE MANDA BAJA»'),
  ('A0431','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «28 AGOSTO SE MANDA BAJA»'),
  ('A0435','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «28 AGOSTO SE MANDA BAJA»'),
  ('A0436','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «28 AGOSTO SE MANDA BAJA»'),
  ('A0438','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «28 AGOSTO SE MANDA BAJA»'),
  ('A0439','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «28 AGOSTO SE MANDA BAJA»'),
  ('A0444','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «28 agosto se manda baja»'),
  ('A0445','2026-10-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «03 septiembre se manda baja»'),
  ('A0447','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «28 AGOSTO SE MANDA BAJA»'),
  ('A0448','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «28 AGOSTO SE MANDA BAJA»'),
  ('A0454','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «27 AGOSTO SE MANDA BAJA»'),
  ('A0459','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «28 AGOSTO SE MANDA BAJA»'),
  ('A0465','2026-10-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «03 SEPTIEMBRE- se manda baja»'),
  ('A0470','2026-10-01','Baja parcial con efecto en octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0490','2026-10-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «21 sep se manda baja»'),
  ('A0500','2026-10-01','Primer mes sin cobro octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0501','2026-10-01','Primer mes sin cobro octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0502','2026-10-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «08 septiembre se manda baja»'),
  ('A0519','2026-10-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «24 sept se manda baja»'),
  ('A0521','2026-10-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «24 SEPTIEMBRE: SE MANDA BAJA»'),
  ('A0522','2026-10-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «24 sept se manda baja»'),
  ('A0536','2026-10-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «24 SEPTIEMBRE SE MANDA BAJA»'),
  ('A0546','2026-10-01','Primer mes sin cobro octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0548','2026-10-01','Primer mes sin cobro octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0553','2026-10-01','Primer mes sin cobro octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0568','2026-10-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «25 septiembre se manda baja»'),
  ('A0571','2026-10-01','Baja parcial con efecto en octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0589','2026-10-01','Primer mes sin cobro octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0593','2026-10-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «29 sep se manda baja»'),
  ('A0598','2026-10-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «29 SEPTIEMBRE SE MANDA BAJA»'),
  ('A0600','2026-10-01','Primer mes sin cobro octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0603','2026-10-01','Primer mes sin cobro octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0615','2026-10-01','Baja parcial con efecto en octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0620','2026-10-01','Primer mes sin cobro octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('A0691','2026-10-01','Baja parcial con efecto en octubre 2026, confirmado por Diego Velázquez el 14-nov-2026'),
  ('D0425','2026-09-01','Primer mes sin cobro = mes siguiente a la baja en sistema: «27 AGOSTO SE MANDA BAJA»');
create table if not exists legacy.cx_tmp_dg_pm (folio text primary key, descripcion text);
truncate legacy.cx_tmp_dg_pm;
insert into legacy.cx_tmp_dg_pm values
  ('A0470','Baja de 1 equipo (nota: «15 sep se manda baja de 1 equipo»)'),
  ('A0571','Suspensión de 2 meses (nota: «24 SEPTIEMBRE SE MANDA SUSPENDER»)'),
  ('A0691','Baja parcial confirmada por Diego Velázquez (14-nov-2026)'),
  ('A0615','Cambio de equipo en sistema con ajuste de facturación (nota: «SE HACE CAMBIO EN SISTEMA DEL EQUIPO»)');

-- respaldo de lo que cambia
insert into legacy.cx_ajuste_primer_mes (fuente, registro, campo, valor_anterior, valor_nuevo, evidencia)
  select 'tickets', t.folio, 'fecha_efectiva_cancelacion', t.fecha_efectiva_cancelacion::text, f.fecha::text, f.evidencia
  from legacy.tickets t join legacy.cx_tmp_fecha_pm f using (folio)
  where t.fecha_efectiva_cancelacion is distinct from f.fecha
  on conflict do nothing;
insert into legacy.cx_ajuste_primer_mes (fuente, registro, campo, valor_anterior, valor_nuevo, evidencia)
  select 'tickets', t.folio, x.campo, x.antes, x.despues, d.descripcion
  from legacy.tickets t join legacy.cx_tmp_dg_pm d using (folio)
  cross join lateral (values ('status_cancelacion', t.status_cancelacion, 'Downgrade'),
                             ('tipo', t.tipo, case when t.tipo ilike '%cancelac%' then t.tipo else 'Solicitud de Cancelación' end),
                             ('descripcion_downgrade', t.descripcion_downgrade, coalesce(t.descripcion_downgrade, d.descripcion))) as x(campo, antes, despues)
  where x.antes is distinct from x.despues
  on conflict do nothing;

-- downgrades (tipo y resultado antes de la fecha, para cumplir la regla de cierre)
update legacy.tickets t set tipo = case when t.tipo ilike '%cancelac%' then t.tipo else 'Solicitud de Cancelación' end,
       status_cancelacion = 'Downgrade', descripcion_downgrade = coalesce(t.descripcion_downgrade, d.descripcion)
  from legacy.cx_tmp_dg_pm d where t.folio = d.folio;
-- fechas: primer mes sin cobro
update legacy.tickets t set fecha_efectiva_cancelacion = f.fecha
  from legacy.cx_tmp_fecha_pm f where t.folio = f.folio and t.fecha_efectiva_cancelacion is distinct from f.fecha;

drop table legacy.cx_tmp_fecha_pm;
drop table legacy.cx_tmp_dg_pm;
select campo, count(*) from legacy.cx_ajuste_primer_mes group by campo order by campo;
commit;
