-- H15 · Recalcular la prioridad de los 10 tickets abiertos de CX que cambian con la regla nueva
-- (calidad_datos.prioridad_regla): Alta = sin servicio o riesgo (apagado, derrame, urgente,
-- incumplimiento de visita, plagas, falla del servicio) y cancelaciones; lo demás Normal.
-- Los cerrados conservan la prioridad que tuvieron. Solo cambia si sigue con el valor anterior.
-- Respaldo: legacy.cx_h15_respaldo_prioridad. Reversa: ..._reversa.sql.
begin;
create table if not exists legacy.cx_h15_respaldo_prioridad as
  select folio, prioridad, now() as respaldado_at from legacy.tickets where folio in ('A0822','A0746','A0805','A0716','A0787','B0762','A0818','A0776','A0735','A0816');
revoke all on legacy.cx_h15_respaldo_prioridad from anon, authenticated;

update legacy.tickets t set prioridad = v.nueva
  from (values
  ('A0822','Alta','Normal'),
  ('A0746','Normal','Alta'),
  ('A0805','Normal','Alta'),
  ('A0716','Normal','Alta'),
  ('A0787','Alta','Normal'),
  ('B0762','Normal','Alta'),
  ('A0818','Alta','Normal'),
  ('A0776','Alta','Normal'),
  ('A0735','Normal','Alta'),
  ('A0816','Normal','Alta')) as v(folio, anterior, nueva)
  where t.folio = v.folio and t.prioridad = v.anterior and t.estatus not in ('Cerrado', 'Resuelto');

select folio, tipo, prioridad from legacy.tickets where folio in ('A0822','A0746','A0805','A0716','A0787','B0762','A0818','A0776','A0735','A0816') order by prioridad, folio;
commit;
