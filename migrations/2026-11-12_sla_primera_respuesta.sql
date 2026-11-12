-- SLA · Primera respuesta por ticket, sin exponer el contenido de los mensajes.
-- legacy.mensajes está cerrada a los usuarios del dashboard (H1). Esta vista corre con los permisos
-- de su dueño y entrega solo folio + hora del primer mensaje de una agente en la misma atención,
-- posterior a la creación del ticket. Requiere atencion_id (el bot lo guarda desde el 12-oct-2026).
-- Reversa: drop view legacy.cx_primera_respuesta; drop index legacy.cx_mensajes_atencion_agente;
begin;
create index if not exists cx_mensajes_atencion_agente
  on legacy.mensajes (atencion_id, created_at) where rol = 'agente';

create or replace view legacy.cx_primera_respuesta as
  select t.folio, min(m.created_at) as primera_respuesta_at
  from legacy.tickets t
  join legacy.mensajes m
    on m.atencion_id = t.atencion_id and m.rol = 'agente' and m.created_at >= t.created_at
  where t.atencion_id is not null
  group by t.folio;

revoke all on legacy.cx_primera_respuesta from anon, authenticated;
grant select on legacy.cx_primera_respuesta to authenticated, service_role;

select count(*) as tickets_con_primera_respuesta from legacy.cx_primera_respuesta;
commit;
