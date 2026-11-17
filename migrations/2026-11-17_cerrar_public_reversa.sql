-- Reversa de 2026-11-17_cerrar_public.sql: regresa RLS y permisos de anon/authenticated tal como estaban.
begin;
do $$
declare r record;
begin
  for r in select * from legacy.cx_seg_respaldo_public_rls where not rls loop
    execute format('alter table public.%I disable row level security', r.table_name);
  end loop;
  for r in select * from legacy.cx_seg_respaldo_public_permisos loop
    execute format('grant %s on public.%I to %I', r.privilege_type, r.table_name, r.grantee);
  end loop;
end $$;
alter default privileges in schema public grant all on tables to anon, authenticated;
commit;
