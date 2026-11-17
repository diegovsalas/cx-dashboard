-- Seguridad: el esquema public se podía leer con la llave pública (anon) que viene en la página del dashboard:
-- 44 tablas con facturación, RFC, contactos, contratos, correos de ventas, tokens de encuestas y una api key.
-- Quién usa public: el CRM / Customer Success (leads-manager) lee con DATABASE_URL y la llave de servicio, y el bot con
-- la llave de servicio; ambos pasan por encima de RLS, así que no se afectan. El dashboard de CX solo lee el esquema legacy.
-- Este script: (1) respalda RLS y permisos actuales; (2) activa RLS en todas las tablas de public y retira permisos a
-- anon y authenticated en tablas y vistas; (3) evita que las tablas nuevas nazcan abiertas.
-- Reversa: 2026-11-17_cerrar_public_reversa.sql. Idempotente.
begin;
create table if not exists legacy.cx_seg_respaldo_public_permisos as
  select table_name, grantee, privilege_type, now() as respaldado_at
  from information_schema.role_table_grants
  where table_schema = 'public' and grantee in ('anon', 'authenticated');
create table if not exists legacy.cx_seg_respaldo_public_rls as
  select c.relname as table_name, c.relrowsecurity as rls, now() as respaldado_at
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p');
revoke all on legacy.cx_seg_respaldo_public_permisos, legacy.cx_seg_respaldo_public_rls from anon, authenticated;

do $$
declare r record;
begin
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('r', 'p') loop
    execute format('alter table public.%I enable row level security', r.relname);
    execute format('revoke all on public.%I from anon, authenticated', r.relname);
  end loop;
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('v', 'm') loop
    execute format('revoke all on public.%I from anon, authenticated', r.relname);
  end loop;
end $$;

alter default privileges in schema public revoke all on tables from anon, authenticated;

select count(*) filter (where c.relrowsecurity) as tablas_con_rls, count(*) as tablas
from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind in ('r', 'p');
commit;
