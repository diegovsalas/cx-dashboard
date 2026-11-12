-- Motivo obligatorio al cerrar una cancelación del bot (amplía la regla del H8).
-- Una cancelación de tickets solo se cierra con motivo del catálogo; «Cancelación de servicio»,
-- «Solicitud operativa» o vacío no cuentan como motivo. Solo al cerrar o al cambiar resultado,
-- fecha, tipo o motivo estando cerrada: los cerrados históricos no se bloquean para otras ediciones.
-- Reversa: volver a correr 2026-11-11_h8_regla_cierre_cancelacion.sql (función anterior).
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
     and (o ->> c_tipo) is not distinct from (n ->> c_tipo)
     and (o ->> 'categoria') is not distinct from (n ->> 'categoria') then
    return new;   -- ya estaba cerrado y no cambió nada de la regla
  end if;
  if resultado not in ('retenida','cancelada','downgrade','migracion','cancelado por morosidad') then
    raise exception 'Para cerrar una cancelación selecciona un resultado definitivo.'
      using errcode = 'check_violation';
  end if;
  -- Motivo obligatorio (solo tickets del bot: el histórico guarda el motivo en otros campos de Airtable)
  if c_estatus = 'estatus'
     and translate(lower(btrim(coalesce(n ->> 'categoria', ''))), 'áéíóú', 'aeiou')
         in ('', 'cancelacion de servicio', 'solicitud operativa', 'pendiente de clasificacion') then
    raise exception 'Selecciona el motivo de cancelación antes de cerrar.'
      using errcode = 'check_violation';
  end if;
  if resultado in ('cancelada','cancelado por morosidad') and new.fecha_efectiva_cancelacion is null then
    raise exception 'Indica la fecha efectiva de la cancelación (AAAA-MM-DD).'
      using errcode = 'check_violation';
  end if;
  return new;
end $$;

commit;
