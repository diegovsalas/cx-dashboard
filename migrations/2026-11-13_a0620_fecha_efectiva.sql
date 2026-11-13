-- A0620: fecha efectiva capturada con año 0226; se corrige a 2026-12-12 (aprobado por Diego Velázquez, 13-nov-2026).
-- Solo cambia si sigue con el valor erróneo. Respaldo y evidencia en legacy.cx_recuperacion_chat;
-- la bitácora registra el cambio. Reversa: update ... set fecha_efectiva_cancelacion='0226-12-12' where folio='A0620'.
begin;
select set_config('request.jwt.claims', '{"email":"corrección de captura (13-nov)"}', true);
insert into legacy.cx_recuperacion_chat (fuente, registro, campo, valor_anterior, valor_nuevo, evidencia)
  select 'tickets', folio, 'fecha_efectiva_cancelacion', fecha_efectiva_cancelacion::text, '2026-12-12',
         'Error de captura en el año (0226 → 2026); solicitud creada el 28-sep-2026. Corrección aprobada por Diego Velázquez el 13-nov-2026.'
  from legacy.tickets where folio = 'A0620' and fecha_efectiva_cancelacion = '0226-12-12'
  on conflict do nothing;
update legacy.tickets set fecha_efectiva_cancelacion = '2026-12-12'
  where folio = 'A0620' and fecha_efectiva_cancelacion = '0226-12-12';
select folio, fecha_efectiva_cancelacion from legacy.tickets where folio = 'A0620';
commit;
