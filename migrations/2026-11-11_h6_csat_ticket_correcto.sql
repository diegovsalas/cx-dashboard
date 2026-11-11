-- H6 · Mover 4 calificaciones CSAT al ticket de la encuesta que contestó el cliente.
-- Evidencia (legacy.mensajes): la encuesta enviada «[Encuesta CSAT enviada] · FOLIO» y la respuesta
-- del cliente minutos después. El bot viejo la guardó en otro ticket del mismo teléfono.
--   A0467 ← 5   (respuesta 21-ago; se escribió encima de A0126, que conserva su propio 5 de mayo)
--   A0390 ← 1   (respuesta 25-ago; estaba en D0367, que no recibió encuesta)
--   A0737 ← 3   (respuesta 23-oct; estaba en A0611, que no recibió encuesta)
--   A0790 ← 5   (respuesta 10-nov; estaba en A0739, cuya encuesta del 23-oct no se contestó)
-- Respaldo: legacy.cx_h6_respaldo_csat. Reversa: 2026-11-11_h6_csat_ticket_correcto_reversa.sql.
-- Idempotente: cada cambio solo aplica si el ticket sigue con el valor esperado.
begin;

create table if not exists legacy.cx_h6_respaldo_csat as
  select folio, csat, comentario_csat, now() as respaldado_at
  from legacy.tickets where folio in ('A0126','A0467','D0367','A0390','A0611','A0737','A0739','A0790');
revoke all on legacy.cx_h6_respaldo_csat from anon, authenticated;

-- Destinos: reciben la calificación (y el comentario, si lo hubo) solo si están vacíos
update legacy.tickets d set csat = '5'
  where d.folio = 'A0467' and coalesce(d.csat, '') = '';
update legacy.tickets d set csat = o.csat, comentario_csat = o.comentario_csat
  from legacy.tickets o
  where (d.folio, o.folio) in (('A0390','D0367'), ('A0737','A0611'), ('A0790','A0739'))
    and coalesce(d.csat, '') = '' and coalesce(o.csat, '') <> '';

-- Orígenes: se limpian solo si el destino ya quedó con la misma calificación
update legacy.tickets o set csat = null, comentario_csat = null
  from legacy.tickets d
  where (d.folio, o.folio) in (('A0390','D0367'), ('A0737','A0611'), ('A0790','A0739'))
    and d.csat = o.csat;

select folio, csat, left(coalesce(comentario_csat, ''), 40) as comentario
  from legacy.tickets
  where folio in ('A0126','A0467','D0367','A0390','A0611','A0737','A0739','A0790') order by folio;
commit;
