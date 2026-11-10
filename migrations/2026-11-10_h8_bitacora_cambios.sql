-- Bitácora automática de cambios en tickets y base_general (quién, qué, cuándo).
-- La escribe la base en cada cambio, desde el bot, el dashboard o SQL; nadie la llena a mano.
-- Reversa: 2026-11-10_h8_bitacora_cambios_reversa.sql. Idempotente.

begin;

create table if not exists legacy.cx_bitacora_cambios (
  id             bigint generated always as identity primary key,
  fuente         text not null check (fuente in ('tickets', 'base_general')),
  registro       text not null,          -- tickets.folio | base_general.id
  campo          text not null,
  valor_anterior text,
  valor_nuevo    text,
  cambiado_por   text not null,          -- correo de la sesión, 'bot (service_role)' o el rol de SQL
  cambiado_at    timestamptz not null default now()
);
create index if not exists cx_bitacora_registro on legacy.cx_bitacora_cambios (fuente, registro, cambiado_at);
alter table legacy.cx_bitacora_cambios enable row level security;
revoke all on legacy.cx_bitacora_cambios from anon, authenticated;
grant select on legacy.cx_bitacora_cambios to authenticated, service_role;
drop policy if exists cx_bitacora_leer on legacy.cx_bitacora_cambios;
create policy cx_bitacora_leer on legacy.cx_bitacora_cambios
  for select to authenticated using (true);

create or replace function legacy.cx_bitacora_registrar() returns trigger
  language plpgsql security definer set search_path = ''
as $$
declare
  campos text[] := tg_argv;          -- columnas a vigilar, pasadas por el trigger
  c text; antes text; despues text;
  quien text := coalesce(nullif(auth.jwt() ->> 'email', ''),
                         case when auth.role() = 'service_role' then 'bot (service_role)' end,
                         session_user);
  reg text := case tg_table_name when 'tickets' then new.folio::text else new.id::text end;
begin
  foreach c in array campos loop
    antes   := case when tg_op = 'UPDATE' then to_jsonb(old) ->> c end;
    despues := to_jsonb(new) ->> c;
    if (tg_op = 'INSERT' and despues is not null) or (tg_op = 'UPDATE' and antes is distinct from despues) then
      insert into legacy.cx_bitacora_cambios (fuente, registro, campo, valor_anterior, valor_nuevo, cambiado_por)
      values (tg_table_name, reg, c, antes, despues, quien);
    end if;
  end loop;
  return new;
end $$;
revoke execute on function legacy.cx_bitacora_registrar() from public, anon, authenticated;

-- AFTER: registra el valor final, ya ajustado por los demás triggers (p. ej. resolved_at).
drop trigger if exists cx_bitacora on legacy.tickets;
create trigger cx_bitacora after insert or update on legacy.tickets
  for each row execute function legacy.cx_bitacora_registrar(
    'estatus', 'resolved_at', 'status_cancelacion', 'agente', 'tipo', 'prioridad', 'zona', 'fecha_efectiva_cancelacion');

drop trigger if exists cx_bitacora on legacy.base_general;
create trigger cx_bitacora after update on legacy.base_general
  for each row execute function legacy.cx_bitacora_registrar(
    'status', 'fecha_de_solucion', 'status_cancelacion', 'ejecutivo_asignado', 'tipo_de_solicitud', 'fecha_efectiva_cancelacion');

commit;
