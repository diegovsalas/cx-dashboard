-- H8 · La regla de cierre de cancelaciones se aplica en la base, no solo en una pantalla.
-- Misma regla que el bot (calidad_datos.validar_cierre) y que el modal de Casos:
--   una solicitud de cancelación solo puede quedar cerrada con un resultado definitivo
--   (Retenida, Cancelada, Downgrade, Migración, Cancelado por morosidad), y si es
--   Cancelada / Cancelado por morosidad, con fecha efectiva.
-- Solo se revisa cuando el registro se cierra o cambia su resultado, fecha o tipo estando
-- cerrado: los registros históricos que hoy no cumplen no se tocan ni se bloquean
-- para otras ediciones. Vale para el dashboard, el bot y SQL.
-- Reversa: 2026-11-11_h8_regla_cierre_cancelacion_reversa.sql. Idempotente.
begin;

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

drop trigger if exists cx_regla_cierre_cancelacion on legacy.tickets;
create trigger cx_regla_cierre_cancelacion before insert or update on legacy.tickets
  for each row execute function legacy.cx_validar_cierre_cancelacion('estatus', 'tipo');

drop trigger if exists cx_regla_cierre_cancelacion on legacy.base_general;
create trigger cx_regla_cierre_cancelacion before insert or update on legacy.base_general
  for each row execute function legacy.cx_validar_cierre_cancelacion('status', 'tipo_de_solicitud');

commit;
