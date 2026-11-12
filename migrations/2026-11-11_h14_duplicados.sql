-- H14 · Duplicados: se marcan, no se borran ni se modifican los registros.
--   anotado_por_equipo (31): tickets que el propio equipo cerró escribiendo que el caso sigue en otro folio.
--   copia_vacia (8): solicitudes del histórico con mismo cliente, sucursal, fecha y tipo que otra,
--   pero sin resultado, estado ni notas (envío repetido del formulario de Airtable).
-- El dashboard excluye lo marcado de todos los indicadores y lo cuenta aparte.
-- Reversa: drop table legacy.cx_duplicados (o borrar filas). Idempotente.
begin;
create table if not exists legacy.cx_duplicados (
  fuente     text not null check (fuente in ('tickets', 'base_general')),
  registro   text not null,          -- tickets.folio | base_general.id
  principal  text not null,          -- folio / id donde sigue el caso
  nivel      text not null check (nivel in ('anotado_por_equipo', 'copia_vacia')),
  evidencia  text not null,
  marcado_at timestamptz not null default now(),
  primary key (fuente, registro)
);
alter table legacy.cx_duplicados enable row level security;
revoke all on legacy.cx_duplicados from anon, authenticated;
grant select on legacy.cx_duplicados to authenticated, service_role;
drop policy if exists cx_duplicados_leer on legacy.cx_duplicados;
create policy cx_duplicados_leer on legacy.cx_duplicados for select to authenticated using (true);

insert into legacy.cx_duplicados (fuente, registro, principal, nivel, evidencia) values
  ('tickets','A0061','A0062','anotado_por_equipo','«Se cierra ticket ya que es el mismo caso» (mismo que A0062)'),
  ('tickets','A0019','A0018','anotado_por_equipo','A0018: «se toma este folio para seguimiento, está repetido con el A0019»'),
  ('tickets','A0146','A0147','anotado_por_equipo','«Mismo ticket que 147, se lleva seguimiento desde ese folio»'),
  ('tickets','A0184','A0185','anotado_por_equipo','«Se lleva seguimiento en el ticket A0185»'),
  ('tickets','A0196','A0197','anotado_por_equipo','«Se procede a cerrar este ticket y llevar el seguimiento en A0197»'),
  ('tickets','A0208','A0197','anotado_por_equipo','«Llevar el seguimiento en el número A0197»'),
  ('tickets','A0235','A0252','anotado_por_equipo','«Se cierra ticket, es el mismo que el A0252»'),
  ('tickets','A0242','A0243','anotado_por_equipo','«Mismo ticket que A0243, se lleva seguimiento en el otro»'),
  ('tickets','A0262','A0246','anotado_por_equipo','«Se cierra ticket ya que es el mismo que el A0246»'),
  ('tickets','A0275','A0274','anotado_por_equipo','«Seguimiento en folio A0274; se le otorgaron estos 2 folios más»'),
  ('tickets','A0279','A0274','anotado_por_equipo','«Seguimiento en folio A0274; se le otorgaron estos 2 folios más»'),
  ('tickets','A0312','A0318','anotado_por_equipo','«Se cierra ticket ya que el seguimiento está en el A0318»'),
  ('tickets','A0334','D0300','anotado_por_equipo','«Se lleva seguimiento en el ticket D0300»'),
  ('tickets','A0341','A0302','anotado_por_equipo','«Se lleva seguimiento en el ticket A0302»'),
  ('tickets','A0358','A0357','anotado_por_equipo','«Se cierra ticket, ya se está llevando seguimiento en el A0357»'),
  ('tickets','A0361','A0355','anotado_por_equipo','«Se cierra ticket, es el mismo que A0355»'),
  ('tickets','D0367','A0368','anotado_por_equipo','«Se cierra ticket y se continúa seguimiento en el folio A0368»'),
  ('tickets','A0392','A0389','anotado_por_equipo','«Se cierra este folio, el cliente ya cuenta con el A0389»'),
  ('tickets','A0415','A0416','anotado_por_equipo','«Se cierra ticket, se le otorgó doble (A0416)»'),
  ('tickets','A0422','A0418','anotado_por_equipo','«Se cierra ticket, ya tenía asignado el A0418»'),
  ('tickets','D0456','A0435','anotado_por_equipo','«Ya se lleva seguimiento en ticket A0435»'),
  ('tickets','A0469','A0465','anotado_por_equipo','«Se cierra ticket, ya se lleva el seguimiento en el A0465»'),
  ('tickets','A0488','A0481','anotado_por_equipo','«Se cierra ticket, ya cuenta con el A0481»'),
  ('tickets','A0514','A0501','anotado_por_equipo','«Seguimiento en ticket A0501»'),
  ('tickets','A0560','A0561','anotado_por_equipo','«Se cierra ticket, ya tiene seguimiento en el A0561»'),
  ('tickets','A0579','A0568','anotado_por_equipo','«Se llevó ticket con nombre … A0568» (mismas notas, A0568 con resultado)'),
  ('tickets','A0585','A0584','anotado_por_equipo','«Se cierra ticket ya que es el mismo que A0584»'),
  ('tickets','A0625','A0626','anotado_por_equipo','«Se cierra ticket ya que se repite con el 626»'),
  ('tickets','A0630','A0626','anotado_por_equipo','«Se cierra ticket, cliente está duplicando, seguimiento en A0626»'),
  ('tickets','A0635','A0634','anotado_por_equipo','«Se cierra ticket, ya se lleva seguimiento en el A0634»'),
  ('tickets','A0771','A0770','anotado_por_equipo','«Se cierra ticket, ya se lleva seguimiento en folio A0770»'),
  ('base_general','783','62','copia_vacia','Copia sin resultado ni notas de la solicitud 62 · Omnilife Chivas 11-jul-2025'),
  ('base_general','566','71','copia_vacia','Copia sin resultado ni notas de la solicitud 71 · Musa Beauty Salon 15-jul-2025'),
  ('base_general','97','366','copia_vacia','Copia sin resultado ni notas de la solicitud 366 · ITW Safety Components 11-jul-2025'),
  ('base_general','206','581','copia_vacia','Copia sin resultado ni notas de la solicitud 581 · Grupo Neef 10-jul-2025'),
  ('base_general','286','255','copia_vacia','Copia sin resultado ni notas de la solicitud 255 · Happy Laser 1-jul-2025'),
  ('base_general','849','1002','copia_vacia','Copia sin resultado ni notas de la solicitud 1002 · Condominio Sevilla 15, 10-jul-2025'),
  ('base_general','999','900','copia_vacia','Copia sin resultado ni notas de la solicitud 900 · Plaza Balagan 15-jul-2025'),
  ('base_general','1145','900','copia_vacia','Copia sin resultado ni notas de la solicitud 900 · Plaza Balagan 15-jul-2025')
on conflict (fuente, registro) do nothing;

select fuente, nivel, count(*) from legacy.cx_duplicados group by 1, 2 order by 1, 2;
commit;
