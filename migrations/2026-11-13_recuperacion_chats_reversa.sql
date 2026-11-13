-- Reversa de 2026-11-13_recuperacion_chats.sql: regresa cada valor anterior desde cx_recuperacion_chat.
begin;
-- La bitácora registra estos cambios con este autor (no como «postgres»):
select set_config('request.jwt.claims', '{"email":"recuperación desde chats (13-nov)"}', true);
-- Restaura el estado exacto anterior (motivos vacíos en bajas cerradas): la regla de cierre se
-- desactiva solo dentro de esta transacción y se vuelve a activar al final.
alter table legacy.tickets disable trigger cx_regla_cierre_cancelacion;
update legacy.tickets t set categoria=r.valor_anterior from legacy.cx_recuperacion_chat r where r.fuente='tickets' and r.registro=t.folio and r.campo='categoria';
update legacy.tickets t set empresa=r.valor_anterior from legacy.cx_recuperacion_chat r where r.fuente='tickets' and r.registro=t.folio and r.campo='empresa';
update legacy.tickets t set fecha_efectiva_cancelacion=r.valor_anterior::date from legacy.cx_recuperacion_chat r where r.fuente='tickets' and r.registro=t.folio and r.campo='fecha_efectiva_cancelacion';
update legacy.cx_calidad_resolucion c set estado=split_part(r.valor_anterior,' · ',1), fecha_recuperada=null,
       evidencia=substr(r.valor_anterior, length(split_part(r.valor_anterior,' · ',1))+4), clasificado_por='regla'
  from legacy.cx_recuperacion_chat r where r.campo='fecha_cierre' and c.fuente=r.fuente and c.registro=r.registro;
delete from legacy.cx_recuperacion_chat;
alter table legacy.tickets enable trigger cx_regla_cierre_cancelacion;
commit;
