-- Reversa de 2026-11-14_primer_mes_sin_cobro.sql
begin;
alter table legacy.tickets disable trigger cx_regla_cierre_cancelacion;
update legacy.tickets t set fecha_efectiva_cancelacion = a.valor_anterior::date from legacy.cx_ajuste_primer_mes a where a.campo='fecha_efectiva_cancelacion' and a.registro=t.folio;
update legacy.tickets t set status_cancelacion = a.valor_anterior from legacy.cx_ajuste_primer_mes a where a.campo='status_cancelacion' and a.registro=t.folio;
update legacy.tickets t set tipo = a.valor_anterior from legacy.cx_ajuste_primer_mes a where a.campo='tipo' and a.registro=t.folio;
update legacy.tickets t set descripcion_downgrade = a.valor_anterior from legacy.cx_ajuste_primer_mes a where a.campo='descripcion_downgrade' and a.registro=t.folio;
delete from legacy.cx_ajuste_primer_mes;
alter table legacy.tickets enable trigger cx_regla_cierre_cancelacion;
commit;
