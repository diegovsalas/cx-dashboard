-- H2 · Fechas de resolución: regla única hacia adelante + calidad del histórico.
-- No modifica ninguna fecha existente. Reversa: 2026-11-10_h2_fechas_resolucion_reversa.sql
-- Idempotente: reclasifica desde cero las filas generadas por regla cada vez que se ejecuta.

begin;

-- 1. Calidad de fechas de resolución del histórico. Solo guarda excepciones:
--    un registro cerrado que NO aparece aquí tiene una fecha confiable.
create table if not exists legacy.cx_calidad_resolucion (
  fuente           text not null check (fuente in ('tickets', 'base_general')),
  registro         text not null,          -- tickets.folio | base_general.id
  estado           text not null check (estado in ('sintetica', 'sin_fecha', 'inconsistente', 'recuperada')),
  fecha_original   text,                   -- valor tal como estaba (no se modifica en la tabla origen)
  fecha_recuperada timestamptz,            -- solo estado = 'recuperada'
  evidencia        text not null,
  clasificado_por  text not null default 'regla',
  clasificado_at   timestamptz not null default now(),
  primary key (fuente, registro)
);
alter table legacy.cx_calidad_resolucion enable row level security;
revoke all on legacy.cx_calidad_resolucion from anon, authenticated;
grant select on legacy.cx_calidad_resolucion to authenticated, service_role;
drop policy if exists cx_calidad_res_leer on legacy.cx_calidad_resolucion;
create policy cx_calidad_res_leer on legacy.cx_calidad_resolucion
  for select to authenticated using (true);

delete from legacy.cx_calidad_resolucion where clasificado_por = 'regla';

-- 1a. tickets. Evidencia de cierre: la marca que el bot registra 2-3 s después de cerrar
--     ("[Encuesta CSAT enviada] · <folio>"); validada contra 60 cierres con fecha real.
with marca as (
  select substring(m.texto from '·\s*([A-Z][0-9]{3,5})') as folio, min(m.created_at) as at
  from legacy.mensajes m
  where m.texto like '[Encuesta CSAT enviada]%'
  group by 1
), base as (
  select t.folio, t.created_at, t.resolved_at, mc.at as marca_at
  from legacy.tickets t
  left join marca mc on mc.folio = t.folio and mc.at >= t.created_at
  where t.estatus in ('Resuelto', 'Cerrado')
), clasif as (
  select folio, resolved_at, marca_at,
    case
      when resolved_at is not null and resolved_at < created_at then 'inconsistente'
      when resolved_at is null and marca_at is not null then 'recuperada'
      when resolved_at is null then 'sin_fecha'
      when resolved_at - created_at = interval '24 hours' and created_at < '2026-05-20'
           and marca_at is not null then 'recuperada'
      when resolved_at - created_at = interval '24 hours' and created_at < '2026-05-20' then 'sintetica'
    end as estado,
    (resolved_at - created_at = interval '24 hours' and created_at < '2026-05-20') as era_sintetica
  from base
)
insert into legacy.cx_calidad_resolucion (fuente, registro, estado, fecha_original, fecha_recuperada, evidencia)
select 'tickets', folio, estado, to_json(resolved_at) #>> '{}',
       case when estado = 'recuperada' then marca_at end,
       case estado
         when 'inconsistente' then 'Cierre anterior a la apertura'
         when 'sin_fecha'     then 'Cerrado sin fecha de resolución y sin marca de encuesta CSAT'
         when 'sintetica'     then 'Fecha = apertura + 24 h exactas, rellenada antes del 2026-05-20 (inicio del registro automático)'
         when 'recuperada'    then case when era_sintetica
                                     then 'Fecha rellenada; se usa la marca de encuesta CSAT enviada al cerrar'
                                     else 'Sin fecha; se usa la marca de encuesta CSAT enviada al cerrar' end
       end
from clasif where estado is not null;

-- 1b. base_general (histórico de Airtable, congelado).
insert into legacy.cx_calidad_resolucion (fuente, registro, estado, fecha_original, evidencia)
select 'base_general', b.id::text,
       case when b.fecha_de_solucion is null then 'sin_fecha' else 'inconsistente' end,
       b.fecha_de_solucion::text,
       case when b.fecha_de_solucion is null then 'Cerrado sin fecha de solución en Airtable'
            else 'Solución anterior a la solicitud' end
from legacy.base_general b
where b.status in ('Resuelta', 'Resuelto', 'Cerrado')
  and (b.fecha_de_solucion is null or b.fecha_de_solucion < b.fecha_de_la_solicitud);

-- 2. Regla única para tickets nuevos o modificados (bot, dashboard o SQL):
--    abierto -> cerrado: hora real del cambio; cerrado -> abierto: se borra;
--    cerrado -> cerrado (Resuelto -> Cerrado): se conserva la primera;
--    sin cambio de estatus: no se reescribe; el bot solo puede llenar una fecha vacía.
create or replace function legacy.cx_tickets_resolved_at() returns trigger
  language plpgsql set search_path = ''
as $$
declare
  cerrado_nuevo boolean := new.estatus in ('Resuelto', 'Cerrado');
  cerrado_antes boolean := tg_op = 'UPDATE' and old.estatus in ('Resuelto', 'Cerrado');
begin
  if tg_op = 'INSERT' then
    new.resolved_at := case when cerrado_nuevo then coalesce(new.resolved_at, now()) end;
  elsif new.estatus is distinct from old.estatus then
    if cerrado_nuevo and not cerrado_antes then new.resolved_at := now();
    elsif cerrado_nuevo and cerrado_antes then new.resolved_at := coalesce(old.resolved_at, now());
    else new.resolved_at := null;
    end if;
  elsif coalesce(auth.role(), '') = 'authenticated' or old.resolved_at is not null then
    -- Sin cambio de estatus la fecha no se reescribe (p. ej. el barrido CSAT del bot
    -- la sellaba de nuevo minutos después). El bot solo puede llenar una fecha vacía.
    new.resolved_at := old.resolved_at;
  end if;
  return new;
end $$;
revoke execute on function legacy.cx_tickets_resolved_at() from public, anon, authenticated;
drop trigger if exists cx_tickets_resolved_at on legacy.tickets;
create trigger cx_tickets_resolved_at before insert or update on legacy.tickets
  for each row execute function legacy.cx_tickets_resolved_at();

commit;

-- Resumen para verificar después de ejecutar:
-- select fuente, estado, count(*) from legacy.cx_calidad_resolucion group by 1, 2 order by 1, 2;
