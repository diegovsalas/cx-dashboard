-- H13 · Identidad del cliente.
-- 1) Regla: un ticket de CX (no Aromatex) solo pasa a Cerrado/Resuelto con zona del catálogo y sucursal.
--    Solo al cerrarse; los ya cerrados no se bloquean para otras ediciones. Misma regla que el bot
--    (calidad_datos.validar_identidad_cierre) y que los formularios del Kanban y del dashboard.
-- 2) Teléfonos: 10 dígitos o 521+10 → 52+10 (formato con el que escribe Meta), en tickets y en sus
--    mensajes, para que el bot reconozca el historial de esos clientes. No toca números extranjeros
--    (p. ej. +1) ni identificadores web_. Respaldo: legacy.cx_h13_respaldo_telefono.
-- Reversa: 2026-11-11_h13_identidad_cliente_reversa.sql. Idempotente.
begin;

create or replace function legacy.cx_validar_identidad_cierre() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  if coalesce(new.canal_origen, 'cx') <> 'cx'
     or lower(coalesce(new.estatus, '')) not in ('cerrado', 'resuelto', 'resuelta')
     or (tg_op = 'UPDATE' and lower(coalesce(old.estatus, '')) in ('cerrado', 'resuelto', 'resuelta')) then
    return new;
  end if;
  if btrim(coalesce(new.zona, '')) = '' or btrim(coalesce(new.empresa, '')) = '' then
    raise exception 'Para cerrar indica la zona y la sucursal del cliente.' using errcode = 'check_violation';
  end if;
  if new.zona not in ('Matriz', 'Centro', 'Sur', 'Bajío', 'Noreste', 'Noroeste', 'Pacífico') then
    raise exception 'Zona no válida: elige Matriz, Centro, Sur, Bajío, Noreste, Noroeste o Pacífico.' using errcode = 'check_violation';
  end if;
  return new;
end $$;

drop trigger if exists cx_regla_identidad_cierre on legacy.tickets;
create trigger cx_regla_identidad_cierre before insert or update on legacy.tickets
  for each row execute function legacy.cx_validar_identidad_cierre();

-- Teléfonos
create table if not exists legacy.cx_h13_respaldo_telefono (tabla text, fila text, telefono text, respaldado_at timestamptz default now());
revoke all on legacy.cx_h13_respaldo_telefono from anon, authenticated;

create temp table h13_tel on commit drop as
  select distinct telefono as viejo,
         case when telefono ~ '^\d{10}$' then '52' || telefono else '52' || substr(telefono, 4) end as nuevo
  from legacy.tickets where telefono ~ '^\d{10}$' or telefono ~ '^521\d{10}$';

insert into legacy.cx_h13_respaldo_telefono (tabla, fila, telefono)
  select 'tickets', t.folio, t.telefono from legacy.tickets t join h13_tel h on h.viejo = t.telefono
  union all
  select 'mensajes', m.id::text, m.telefono from legacy.mensajes m join h13_tel h on h.viejo = m.telefono;

update legacy.tickets t set telefono = h.nuevo from h13_tel h where t.telefono = h.viejo;
update legacy.mensajes m set telefono = h.nuevo from h13_tel h where m.telefono = h.viejo;

select (select count(*) from legacy.tickets where telefono ~ '^\d{10}$' or telefono ~ '^521\d{10}$') as tickets_sin_unificar,
       (select count(*) from legacy.cx_h13_respaldo_telefono where tabla = 'tickets') as tickets_respaldados,
       (select count(*) from legacy.cx_h13_respaldo_telefono where tabla = 'mensajes') as mensajes_respaldados;
commit;
