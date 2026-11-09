-- Reversa de 2026-11-10_h1_rls_legacy.sql: restaura exactamente los permisos y el
-- estado de RLS guardados por la migración en legacy.cx_h1_respaldo_*.
-- Solo usar si algo deja de funcionar.

begin;

drop trigger if exists cx_tickets_columnas on legacy.tickets;
drop function if exists legacy.cx_tickets_columnas();

drop policy if exists cx_tk_leer on legacy.tickets;
drop policy if exists cx_tk_editar on legacy.tickets;
drop policy if exists cx_tk_borrar on legacy.tickets;
drop policy if exists cx_bg_leer on legacy.base_general;
drop policy if exists cx_bg_editar on legacy.base_general;
drop policy if exists cx_bg_borrar on legacy.base_general;

do $$
declare t text; r record;
begin
  if to_regclass('legacy.envios_plantillas') is not null then
    drop policy if exists cx_envios_leer_admin on legacy.envios_plantillas;
  end if;
  foreach t in array array['tickets', 'base_general', 'envios_plantillas', 'mensajes', 'agentes',
                           'bot_sessions', 'estado_conv', 'knowledge_base', 'alertas',
                           'respuestas_rapidas'] loop
    if to_regclass('legacy.' || t) is not null then
      execute format('revoke all on legacy.%I from anon, authenticated', t);
      for r in select privilege_type, grantee from legacy.cx_h1_respaldo_permisos
               where table_name = t loop
        execute format('grant %s on legacy.%I to %I', r.privilege_type, t, r.grantee);
      end loop;
      if coalesce((select rls from legacy.cx_h1_respaldo_rls where table_name = t), false) then
        execute format('alter table legacy.%I enable row level security', t);
      else
        execute format('alter table legacy.%I disable row level security', t);
      end if;
    end if;
  end loop;
end $$;

drop function if exists legacy.cx_rol();
drop table if exists legacy.cx_dashboard_roles;
-- Los respaldos se conservan; borrarlos a mano cuando ya no se necesiten:
-- drop table legacy.cx_h1_respaldo_permisos, legacy.cx_h1_respaldo_rls;

commit;
