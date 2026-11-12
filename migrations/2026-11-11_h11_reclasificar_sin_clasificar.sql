-- H11 · Reclasificar 7 tickets «Otro» con lo que el cliente pidió en la conversación (legacy.mensajes).
--   B0403, B0404  plagas de ratones y cucarachas (Pestex)            → Incidencia: Plagas
--   C0720         «No recibimos el servicio a partir del 1 de octubre» → Falla del servicio
--   D0268         cambio de domicilio, se reubicaron los equipos      → Solicitud operativa: Reubicación o cambio de domicilio
--   D0192         pausar el servicio 2-3 meses                        → Solicitud operativa: Suspensión temporal
--   B0472         certificado de fumigación                           → Solicitud operativa: Certificado de fumigación
--   C0493         cotizar servicio de limpieza                        → Consulta
-- No se tocan D0103 ni D0367 (cancelaciones que requieren decisión del equipo) ni A0177/A0180 (pruebas).
-- Respaldo: legacy.cx_h11_respaldo_tipo. Reversa: ..._reversa.sql. Idempotente: solo cambia si sigue en «Otro».
begin;
create table if not exists legacy.cx_h11_respaldo_tipo as
  select folio, tipo, now() as respaldado_at from legacy.tickets
  where folio in ('B0403','B0404','C0720','D0268','D0192','B0472','C0493');
revoke all on legacy.cx_h11_respaldo_tipo from anon, authenticated;

update legacy.tickets t set tipo = v.nuevo
  from (values ('B0403','Incidencia: Plagas'),
               ('B0404','Incidencia: Plagas'),
               ('C0720','Falla del servicio'),
               ('D0268','Solicitud operativa: Reubicación o cambio de domicilio'),
               ('D0192','Solicitud operativa: Suspensión temporal'),
               ('B0472','Solicitud operativa: Certificado de fumigación'),
               ('C0493','Consulta')) as v(folio, nuevo)
  where t.folio = v.folio and t.tipo = 'Otro';

select folio, tipo from legacy.tickets
  where folio in ('B0403','B0404','C0720','D0268','D0192','B0472','C0493') order by folio;
commit;
