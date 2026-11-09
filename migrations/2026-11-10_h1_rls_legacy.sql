-- H1 · Cerrar el acceso público a las tablas de legacy.
-- Antes: la anon key (pública, incrustada en index.html) leía 10 tablas sin sesión.
-- Después:
--   anon            -> nada.
--   authenticated   -> lee base_general y tickets; cambia solo `zona` de tickets.
--   editor/admin    -> además edita base_general y tickets.
--   superadmin      -> además borra.
--   admin/superadmin-> lee envios_plantillas (Campañas).
--   service_role    -> sin cambios (bypass de RLS): el bot y las Edge Functions siguen igual.
-- Reversa: 2026-11-10_h1_rls_legacy_reversa.sql
-- Idempotente: puede ejecutarse más de una vez. Omite tablas que no existan.

begin;

-- 0. Respaldo del estado actual (solo la primera vez) para que la reversa sea exacta.
create table if not exists legacy.cx_h1_respaldo_permisos as
  select table_name::text, grantee::text, privilege_type::text, now() as respaldado_at
  from information_schema.role_table_grants
  where table_schema = 'legacy' and grantee in ('anon', 'authenticated');
create table if not exists legacy.cx_h1_respaldo_rls as
  select c.relname::text as table_name, c.relrowsecurity as rls, now() as respaldado_at
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'legacy' and c.relkind = 'r';
revoke all on legacy.cx_h1_respaldo_permisos, legacy.cx_h1_respaldo_rls from anon, authenticated;
alter table legacy.cx_h1_respaldo_permisos enable row level security;
alter table legacy.cx_h1_respaldo_rls enable row level security;

-- 1. Roles del dashboard (fuente de verdad en la base, no en la página).
create table if not exists legacy.cx_dashboard_roles (
  email      text primary key check (email = lower(email)),
  rol        text not null check (rol in ('superadmin', 'admin', 'editor')),
  nota       text,
  created_at timestamptz not null default now()
);
insert into legacy.cx_dashboard_roles (email, rol, nota) values
  ('diegovelazquez@grupoavantex.com',    'superadmin', 'SUPERADMIN_EMAIL en index.html'),
  ('servicioalcliente@grupoavantex.com', 'admin',      'ADMIN_EMAILS en index.html'),
  ('itzelramirez@grupoavantex.com',      'editor',     'EDITOR_EMAILS en index.html'),
  ('johanamartinez@grupoavantex.com',    'editor',     'EDITOR_EMAILS en index.html')
on conflict (email) do update set rol = excluded.rol, nota = excluded.nota;

alter table legacy.cx_dashboard_roles enable row level security;
revoke all on legacy.cx_dashboard_roles from anon, authenticated;
grant select on legacy.cx_dashboard_roles to authenticated;
drop policy if exists cx_roles_ver_propio on legacy.cx_dashboard_roles;
create policy cx_roles_ver_propio on legacy.cx_dashboard_roles
  for select to authenticated
  using (email = lower(coalesce(auth.jwt() ->> 'email', '')));

create or replace function legacy.cx_rol() returns text
  language sql stable security definer set search_path = ''
as $$
  select r.rol from legacy.cx_dashboard_roles r
  where r.email = lower(coalesce(auth.jwt() ->> 'email', ''))
$$;
revoke execute on function legacy.cx_rol() from public, anon;
grant execute on function legacy.cx_rol() to authenticated;

-- 2. Tablas que no usa el dashboard: solo service_role (bot, Edge Functions).
do $$
declare t text;
begin
  foreach t in array array['mensajes', 'agentes', 'bot_sessions', 'estado_conv',
                           'knowledge_base', 'alertas', 'respuestas_rapidas'] loop
    if to_regclass('legacy.' || t) is not null then
      execute format('alter table legacy.%I enable row level security', t);
      execute format('revoke all on legacy.%I from anon, authenticated', t);
    end if;
  end loop;
end $$;

-- 3. Campañas: solo admins.
do $$
begin
  if to_regclass('legacy.envios_plantillas') is not null then
    alter table legacy.envios_plantillas enable row level security;
    revoke all on legacy.envios_plantillas from anon, authenticated;
    grant select on legacy.envios_plantillas to authenticated;
    drop policy if exists cx_envios_leer_admin on legacy.envios_plantillas;
    create policy cx_envios_leer_admin on legacy.envios_plantillas
      for select to authenticated
      using (legacy.cx_rol() in ('superadmin', 'admin'));
  end if;
end $$;

-- 4. base_general: leer con sesión; editar editores/admins; borrar superadmin.
alter table legacy.base_general enable row level security;
revoke all on legacy.base_general from anon, authenticated;
grant select, update, delete on legacy.base_general to authenticated;
drop policy if exists cx_bg_leer on legacy.base_general;
drop policy if exists cx_bg_editar on legacy.base_general;
drop policy if exists cx_bg_borrar on legacy.base_general;
create policy cx_bg_leer on legacy.base_general
  for select to authenticated using (true);
create policy cx_bg_editar on legacy.base_general
  for update to authenticated
  using (legacy.cx_rol() in ('superadmin', 'admin', 'editor'))
  with check (legacy.cx_rol() in ('superadmin', 'admin', 'editor'));
create policy cx_bg_borrar on legacy.base_general
  for delete to authenticated using (legacy.cx_rol() = 'superadmin');

-- 5. tickets: igual, pero cualquier usuario con sesión puede cambiar `zona`
--    (comportamiento actual de la pantalla de Tickets). Un trigger limita las columnas.
alter table legacy.tickets enable row level security;
revoke all on legacy.tickets from anon, authenticated;
grant select, update, delete on legacy.tickets to authenticated;
drop policy if exists cx_tk_leer on legacy.tickets;
drop policy if exists cx_tk_editar on legacy.tickets;
drop policy if exists cx_tk_borrar on legacy.tickets;
create policy cx_tk_leer on legacy.tickets
  for select to authenticated using (true);
create policy cx_tk_editar on legacy.tickets
  for update to authenticated using (true) with check (true);
create policy cx_tk_borrar on legacy.tickets
  for delete to authenticated using (legacy.cx_rol() = 'superadmin');

create or replace function legacy.cx_tickets_columnas() returns trigger
  language plpgsql security definer set search_path = ''
as $$
begin
  -- Solo restringe sesiones del dashboard; service_role (bot) y SQL directo pasan.
  if coalesce(auth.role(), '') <> 'authenticated'
     or legacy.cx_rol() in ('superadmin', 'admin', 'editor') then
    return new;
  end if;
  if (to_jsonb(new) - 'zona') is distinct from (to_jsonb(old) - 'zona') then
    raise exception 'Tu usuario solo puede cambiar la zona de un ticket.'
      using errcode = '42501';
  end if;
  return new;
end $$;
revoke execute on function legacy.cx_tickets_columnas() from public, anon, authenticated;
drop trigger if exists cx_tickets_columnas on legacy.tickets;
create trigger cx_tickets_columnas before update on legacy.tickets
  for each row execute function legacy.cx_tickets_columnas();

commit;
