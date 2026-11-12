-- Bitácora: también registra lo que demuestra la gestión (comentarios, diagnóstico, oferta, causa raíz,
-- motivo, sucursal), además de lo que ya registraba desde el H8 (estatus, resultado, fechas, responsable,
-- tipo, prioridad, zona). Solo cambia la lista de columnas vigiladas; la función y la tabla son las mismas.
-- Reversa: volver a correr 2026-11-10_h8_bitacora_cambios.sql. Idempotente.
begin;
drop trigger if exists cx_bitacora on legacy.tickets;
create trigger cx_bitacora after insert or update on legacy.tickets
  for each row execute function legacy.cx_bitacora_registrar(
    'estatus', 'resolved_at', 'status_cancelacion', 'agente', 'tipo', 'prioridad', 'zona', 'fecha_efectiva_cancelacion',
    'empresa', 'categoria', 'comentarios_de_seguimiento', 'diagnostico', 'causa_raiz',
    'diagnostico_previo_cancelacion', 'oferta_retencion', 'causa_raiz_cancelacion');

drop trigger if exists cx_bitacora on legacy.base_general;
create trigger cx_bitacora after update on legacy.base_general
  for each row execute function legacy.cx_bitacora_registrar(
    'status', 'fecha_de_solucion', 'status_cancelacion', 'ejecutivo_asignado', 'tipo_de_solicitud', 'fecha_efectiva_cancelacion',
    'zona', 'comentarios_de_seguimiento', 'diagnostico', 'anlisis_de_causa_raz',
    'diagnostico_previo_cancelacion', 'oferta_retencion');
commit;
