-- Reversa de 2026-11-17_retencion_fase1.sql
-- ATENCIÓN: borra los casos de retención registrados. Respaldar antes si ya hay datos reales:
--   create table legacy.cx_retencion_casos_respaldo as select * from legacy.cx_retencion_casos;
-- Los tickets que ya se cerraron con status «Pausa» se quedan como están.
begin;
drop trigger if exists cx_retencion_una_puerta on legacy.tickets;
drop function if exists legacy.cx_retencion_bloquear_cierre_externo();
drop view if exists legacy.cx_retencion_bandeja;
drop function if exists legacy.cx_retencion_editar_regla(text,text,jsonb);
drop function if exists legacy.cx_retencion_reabrir(text);
drop function if exists legacy.cx_retencion_cerrar(text);
drop function if exists legacy.cx_retencion_autorizar(text);
drop function if exists legacy.cx_retencion_registrar(text,text,text,text,text,text);
drop function if exists legacy.cx_retencion_tomar(text);
drop table if exists legacy.cx_retencion_eventos;
drop table if exists legacy.cx_retencion_acciones;
drop table if exists legacy.cx_retencion_casos;
drop table if exists legacy.cx_retencion_config_log;
drop table if exists legacy.cx_retencion_config;
drop function if exists legacy.cx_retencion_acciones_guardia();
drop function if exists legacy.cx_retencion_casos_guardia();
drop function if exists legacy.cx_ret_motivo_sugerido(text);
drop function if exists legacy.cx_ret_marca(text);
drop function if exists legacy.cx_ret_puede_tomar();
drop function if exists legacy.cx_ret_permiso(text);
drop function if exists legacy.cx_ret_email();
drop table if exists legacy.cx_retencion_permisos;
-- Regla de cierre sin «pausa» (versión 2026-11-11_h8_regla_cierre_cancelacion.sql)
create or replace function legacy.cx_validar_cierre_cancelacion() returns trigger
  language plpgsql set search_path = ''
as $$
declare
  c_estatus text := tg_argv[0];   -- 'estatus' (tickets) | 'status' (base_general)
  c_tipo    text := tg_argv[1];   -- 'tipo' (tickets)    | 'tipo_de_solicitud' (base_general)
  n jsonb := to_jsonb(new);
  o jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) end;
  norm_estatus text := lower(coalesce(n ->> c_estatus, ''));
  resultado text := translate(lower(btrim(coalesce(n ->> 'status_cancelacion', ''))), 'áéíóú', 'aeiou');
  cerrado_antes boolean := o is not null and lower(coalesce(o ->> c_estatus, '')) in ('cerrado','resuelto','resuelta','cancelado');
begin
  if lower(coalesce(n ->> c_tipo, '')) not like '%cancelac%'
     or norm_estatus not in ('cerrado','resuelto','resuelta','cancelado') then
    return new;
  end if;
  if cerrado_antes
     and (o ->> 'status_cancelacion') is not distinct from (n ->> 'status_cancelacion')
     and (o ->> 'fecha_efectiva_cancelacion') is not distinct from (n ->> 'fecha_efectiva_cancelacion')
     and (o ->> c_tipo) is not distinct from (n ->> c_tipo) then
    return new;   -- ya estaba cerrado y no cambió nada de la regla
  end if;
  if resultado not in ('retenida','cancelada','downgrade','migracion','cancelado por morosidad') then
    raise exception 'Para cerrar una cancelación selecciona un resultado definitivo.'
      using errcode = 'check_violation';
  end if;
  if resultado in ('cancelada','cancelado por morosidad') and new.fecha_efectiva_cancelacion is null then
    raise exception 'Indica la fecha efectiva de la cancelación (AAAA-MM-DD).'
      using errcode = 'check_violation';
  end if;
  return new;
end $$;
commit;
