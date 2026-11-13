-- Recuperación con evidencia de chats y notas de las agentes (13-nov-2026).
-- Solo se llenan datos vacíos o no confiables, con la frase que los respalda. Nada se inventa:
-- donde no hay evidencia el dato se queda vacío. Cada valor anterior y su evidencia quedan en
-- legacy.cx_recuperacion_chat (respaldo + procedencia); la bitácora registra cada cambio.
--   Fechas de cierre (75): nota fechada de la agente («15 JULIO Se realizó», «13 julio se cierra»).
--     Van a cx_calidad_resolucion como 'recuperada' (el ticket no se toca). Día de la nota, 18:00 Monterrey.
--   Fecha efectiva de baja (37): nota «DD MES SE MANDA BAJA (EN SISTEMA)» en bajas Canceladas sin fecha.
--   Motivo de cancelación (11): lo que dijo el cliente o anotó la agente.
--   Sucursal (30): respuesta del cliente a la pregunta del bot.
-- Reversa: 2026-11-13_recuperacion_chats_reversa.sql. Idempotente (solo llena lo que sigue vacío).
begin;
-- La bitácora registra estos cambios con este autor (no como «postgres»):
select set_config('request.jwt.claims', '{"email":"recuperación desde chats (13-nov)"}', true);
create table if not exists legacy.cx_recuperacion_chat (
  fuente text not null, registro text not null, campo text not null,
  valor_anterior text, valor_nuevo text not null, evidencia text not null,
  aplicado_at timestamptz not null default now(), primary key (fuente, registro, campo));
revoke all on legacy.cx_recuperacion_chat from anon, authenticated;
grant select on legacy.cx_recuperacion_chat to authenticated, service_role;
alter table legacy.cx_recuperacion_chat enable row level security;
drop policy if exists cx_recuperacion_leer on legacy.cx_recuperacion_chat;
create policy cx_recuperacion_leer on legacy.cx_recuperacion_chat for select to authenticated using (true);

create temp table r_fecha(fuente text, registro text, fecha timestamptz, evidencia text) on commit drop;
insert into r_fecha values
  ('tickets','A0199','2026-06-26 18:00:00-06','Nota de la agente: «26 JUNIO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0141','2026-05-21 18:00:00-06','Nota de la agente: «21 mayo Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0232','2026-06-22 18:00:00-06','Nota de la agente: «22 JUNIO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0328','2026-07-20 18:00:00-06','Nota de la agente: «20 JULIO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0104','2026-05-08 18:00:00-06','Nota de la agente: «08 Mayo, SE CIERRA» (día anotado; 18:00 por convención)'),
  ('tickets','A0462','2026-08-21 18:00:00-06','Nota de la agente: «21 AGOSTO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0140','2026-06-25 18:00:00-06','Nota de la agente: «25 de junio. ya se realizo» (día anotado; 18:00 por convención)'),
  ('tickets','A0308','2026-07-07 18:00:00-06','Nota de la agente: «07 julio, se hizo cambio de equipo Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0347','2026-07-14 18:00:00-06','Nota de la agente: «14 JULIO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0470','2026-09-15 18:00:00-06','Nota de la agente: «15 sep se manda baja» (día anotado; 18:00 por convención)'),
  ('tickets','A0301','2026-07-22 18:00:00-06','Nota de la agente: «22 JULIO EL SERVICIO DE JULIO YA SE REALIZO» (día anotado; 18:00 por convención)'),
  ('tickets','A0276','2026-07-16 18:00:00-06','Nota de la agente: «16 julio Servicio Eventual se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0427','2026-08-13 18:00:00-06','Nota de la agente: «13 Agosto se agenda cita.Servicio Eventual, se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0118','2026-05-13 18:00:00-06','Nota de la agente: «13 MAYO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0405','2026-08-07 18:00:00-06','Nota de la agente: «07 AGOSTO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0060','2026-04-24 18:00:00-06','Nota de la agente: «24 Abril (cliente decide continuar conel aroma de oriental white relax) Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0033','2026-04-15 18:00:00-06','Nota de la agente: «15 Abril. Se realizo» (día anotado; 18:00 por convención)'),
  ('tickets','A0388','2026-07-30 18:00:00-06','Nota de la agente: «30 JULIO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0066','2026-04-25 18:00:00-06','Nota de la agente: «25 Abril Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0016','2026-04-08 18:00:00-06','Nota de la agente: «08 de abril 08 Abril Servicio Eventual, se cambió el equipo» (día anotado; 18:00 por convención)'),
  ('tickets','A0607','2026-10-07 18:00:00-06','Nota de la agente: «07 octubre Se realizo» (día anotado; 18:00 por convención)'),
  ('tickets','A0077','2026-04-29 18:00:00-06','Nota de la agente: «29 ABRIL Se realiza insistencia el 29/04/26 a las 3:45pm, se realizo» (día anotado; 18:00 por convención)'),
  ('tickets','A0310','2026-07-14 18:00:00-06','Nota de la agente: «14 julio Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0028','2026-04-13 18:00:00-06','Nota de la agente: «13 Abril Incidencias se realizo» (día anotado; 18:00 por convención)'),
  ('tickets','A0265','2026-07-28 18:00:00-06','Nota de la agente: «28 JULIO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0362','2026-07-29 18:00:00-06','Nota de la agente: «29 JULIO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0081','2026-05-04 18:00:00-06','Nota de la agente: «04 Mayo el cambio de aroma se aplicara para el siguiente mes de Junio, ya se realizo» (día anotado; 18:00 por convención)'),
  ('tickets','A0085','2026-05-05 18:00:00-06','Nota de la agente: «05 Mayo Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0123','2026-05-16 18:00:00-06','Nota de la agente: «16 MAYO Servicio Eventual,Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0082','2026-05-05 18:00:00-06','Nota de la agente: «05 Mayo, se hace visita con el cliente y no se encuentra. se cierra» (día anotado; 18:00 por convención)'),
  ('tickets','A0210','2026-06-10 18:00:00-06','Nota de la agente: «10 junio 10 junio Servicio Eventual//// se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0161','2026-05-27 18:00:00-06','Nota de la agente: «27 MAYO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0217','2026-06-12 18:00:00-06','Nota de la agente: «12 de junio. 12 JUNIO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0017','2026-04-17 18:00:00-06','Nota de la agente: «17 Abril Esta es solicitud de Cancelación, se cierra» (día anotado; 18:00 por convención)'),
  ('tickets','A0175','2026-06-26 18:00:00-06','Nota de la agente: «26 junio se manda baja» (día anotado; 18:00 por convención)'),
  ('tickets','A0325','2026-07-28 18:00:00-06','Nota de la agente: «28 JULIO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0233','2026-06-19 18:00:00-06','Nota de la agente: «19 de junio 22 JUNIO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0114','2026-05-12 18:00:00-06','Nota de la agente: «12 Mayo Servicio Eventual el cliente reporta que el aroma no es el mismo , se procedió a realizar cambio de aroma en los» (día anotado; 18:00 por convención)'),
  ('tickets','A0207','2026-06-09 18:00:00-06','Nota de la agente: «09 JUNIO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0093','2026-05-07 18:00:00-06','Nota de la agente: «07 Mayo Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0336','2026-07-28 18:00:00-06','Nota de la agente: «28 JULIO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0311','2026-07-15 18:00:00-06','Nota de la agente: «15 JULIO Se realizo» (día anotado; 18:00 por convención)'),
  ('tickets','A0135','2026-05-20 18:00:00-06','Nota de la agente: «20 MAYO Servicio Eventual, se retiró equipo Advance acrílico folio 4730 por fallo en bomba y se instaló» (día anotado; 18:00 por convención)'),
  ('tickets','D0268','2026-07-03 18:00:00-06','Nota de la agente: «03 JULIO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0253','2026-07-08 18:00:00-06','Nota de la agente: «08 JULIO. 08 julio Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0215','2026-06-12 18:00:00-06','Nota de la agente: «12 de junio. 12 JUNIO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0466','2026-08-25 18:00:00-06','Nota de la agente: «25 AGOATO (se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0371','2026-08-13 18:00:00-06','Nota de la agente: «13 agosto CLIENTE YA ESTA AL CORRIENTE DE LA DEUDA. SE MANDARA BAJA. se manda baja» (día anotado; 18:00 por convención)'),
  ('tickets','A0057','2026-04-22 18:00:00-06','Nota de la agente: «22 ABRIL se cierra» (día anotado; 18:00 por convención)'),
  ('tickets','A0259','2026-07-28 18:00:00-06','Nota de la agente: «28 JULIO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0389','2026-08-20 18:00:00-06','Nota de la agente: «20 de agosto se manda baja» (día anotado; 18:00 por convención)'),
  ('tickets','A0194','2026-06-26 18:00:00-06','Nota de la agente: «26 Junio se manda baja» (día anotado; 18:00 por convención)'),
  ('tickets','A0058','2026-04-22 18:00:00-06','Nota de la agente: «22 Abril Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0203','2026-06-09 18:00:00-06','Nota de la agente: «09 junio Servicio Eventual se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0086','2026-05-27 18:00:00-06','Nota de la agente: «27 DE MAYO SE MANDAN CANCELACIONES DE FACTURAS DE ABRIL Y MAYO, CON RECOLECCION DE EQUIPOS. Y SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0286','2026-07-28 18:00:00-06','Nota de la agente: «28 JULIO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0285','2026-07-27 18:00:00-06','Nota de la agente: «27 JULIO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0014','2026-04-07 18:00:00-06','Nota de la agente: «07 Abril Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0130','2026-05-25 18:00:00-06','Nota de la agente: «25 MAYO Servicio Eventual: Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0419','2026-08-21 18:00:00-06','Nota de la agente: «21 AGOSTO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0304','2026-07-28 18:00:00-06','Nota de la agente: «28 JULIO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0127','2026-05-19 18:00:00-06','Nota de la agente: «19 MAYO, CLIENTE NO LOCALIZADO. SE CIERRA» (día anotado; 18:00 por convención)'),
  ('tickets','A0582','2026-09-29 18:00:00-06','Nota de la agente: «29 SEPTIEMBRE SE REALIZO» (día anotado; 18:00 por convención)'),
  ('tickets','A0324','2026-07-20 18:00:00-06','Nota de la agente: «20 julio. en sistema que el servicio se realizo» (día anotado; 18:00 por convención)'),
  ('tickets','A0293','2026-07-13 18:00:00-06','Nota de la agente: «13 julio se cierra» (día anotado; 18:00 por convención)'),
  ('tickets','A0264','2026-07-02 18:00:00-06','Nota de la agente: «02 JULIO Servicio Eventual se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0363','2026-07-30 18:00:00-06','Nota de la agente: «30 JULIO se manda baja» (día anotado; 18:00 por convención)'),
  ('tickets','A0189','2026-06-26 18:00:00-06','Nota de la agente: «26 JUNIO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0391','2026-08-04 18:00:00-06','Nota de la agente: «04 AGOSTOEL EQUIPO ESTABA TAPADO Y Se realizo» (día anotado; 18:00 por convención)'),
  ('tickets','A0258','2026-06-24 18:00:00-06','Nota de la agente: «24 JUNIO Se realizó» (día anotado; 18:00 por convención)'),
  ('tickets','A0345','2026-08-31 18:00:00-06','Nota de la agente: «31 AGOSTO SE MANDA BAJA» (día anotado; 18:00 por convención)'),
  ('tickets','A0228','2026-06-17 18:00:00-06','Nota de la agente: «17 DE JUNIO. 17 JUNIO Se realizó» (día anotado; 18:00 por convención)'),
  ('base_general','190','2026-01-29 18:00:00-06','Nota de la agente: «29 de enero regresó el técnico y tanto la srita Karla y Ana Gabriela, confirmaron seguir con el servicio y se realizó» (día anotado; 18:00 por convención)'),
  ('base_general','903','2025-06-25 18:00:00-06','Nota de la agente: «25 Jun, Se realizó» (día anotado; 18:00 por convención)'),
  ('base_general','971','2025-10-27 18:00:00-06','Nota de la agente: «27 oct Servicio Eventual se realizó» (día anotado; 18:00 por convención)');
insert into legacy.cx_recuperacion_chat (fuente, registro, campo, valor_anterior, valor_nuevo, evidencia)
  select c.fuente, c.registro, 'fecha_cierre', c.estado||' · '||coalesce(c.evidencia,''), r.fecha::text, r.evidencia
  from legacy.cx_calidad_resolucion c join r_fecha r using (fuente, registro)
  where c.estado in ('sin_fecha','sintetica','inconsistente')
  on conflict do nothing;
update legacy.cx_calidad_resolucion c set estado='recuperada', fecha_recuperada=r.fecha, evidencia=r.evidencia,
       clasificado_por='nota_agente', clasificado_at=now()
  from r_fecha r where c.fuente=r.fuente and c.registro=r.registro and c.estado in ('sin_fecha','sintetica','inconsistente');
create temp table r_campo(registro text, campo text, valor text, evidencia text) on commit drop;
insert into r_campo values
  ('A0684','categoria','Cierre de operación','Comentario de la agente: «CIERRE DE SUCURSAL Centro Oncología Medica y Radioterapia»'),
  ('A0812','categoria','Económico','Comentario de la agente: «Cliente pide su baja de servicio debido a recorte de presupuesto»'),
  ('A0691','categoria','Calidad del aroma','Cliente en el chat: «TENGO MES Y MEDIO REPORTANDO Q EL AROMA NO SE PERCATA CON LA INTENCIDAD»'),
  ('A0816','categoria','Bajo uso','Cliente en el chat: «ya no usamos esas areas»'),
  ('A0671','categoria','Económico','Cliente en el chat: «Por el precio se me está dificultando dar el pago»'),
  ('A0805','categoria','Económico','Cliente en el chat: «Necesito ajustar mis gastos»'),
  ('A0786','categoria','Otro','Cliente en el chat: «A mi esposo le ha generado una alergia»'),
  ('A0722','categoria','Bajo uso','Cliente en el chat: «Ya no se usará en la oficina»'),
  ('A0770','categoria','Otro','Cliente en el chat: «Se cancelara debido a cambios admirativos y la nueva admiración ya no desea continuar con el servicio»'),
  ('A0725','categoria','Fin de contrato','Cliente en el chat: «Mi contrato está vencido»'),
  ('A0723','categoria','Económico','Cliente en el chat: «Falta de presupuesto»'),
  ('A0465','fecha_efectiva_cancelacion','2026-09-03','Nota de la agente: «03 SEPTIEMBRE- se manda baja»'),
  ('A0435','fecha_efectiva_cancelacion','2026-08-28','Nota de la agente: «28 AGOSTO SE MANDA BAJA»'),
  ('A0548','fecha_efectiva_cancelacion','2026-09-24','Nota de la agente: «24 septiembre se manda baja»'),
  ('A0519','fecha_efectiva_cancelacion','2026-09-24','Nota de la agente: «24 sept se manda baja»'),
  ('A0386','fecha_efectiva_cancelacion','2026-08-27','Nota de la agente: «27 AGOSTO SE MANDA BAJA»'),
  ('A0454','fecha_efectiva_cancelacion','2026-08-27','Nota de la agente: «27 AGOSTO SE MANDA BAJA»'),
  ('A0490','fecha_efectiva_cancelacion','2026-09-21','Nota de la agente: «21 sep se manda baja»'),
  ('A0459','fecha_efectiva_cancelacion','2026-08-28','Nota de la agente: «28 AGOSTO SE MANDA BAJA»'),
  ('A0407','fecha_efectiva_cancelacion','2026-08-27','Nota de la agente: «27 AGOSTO SE MANDA BAJA»'),
  ('A0406','fecha_efectiva_cancelacion','2026-08-28','Nota de la agente: «28 AGOSTO SE MANDA BAJA»'),
  ('A0424','fecha_efectiva_cancelacion','2026-08-27','Nota de la agente: «27 AGOSTO SE MANDA BAJA»'),
  ('A0388','fecha_efectiva_cancelacion','2026-07-30','Nota de la agente: «30 JULIO SE MANDA BAJA»'),
  ('A0447','fecha_efectiva_cancelacion','2026-08-28','Nota de la agente: «28 AGOSTO SE MANDA BAJA»'),
  ('A0546','fecha_efectiva_cancelacion','2026-09-24','Nota de la agente: «24 SEPTIEMBRE SE MANDA BAJA»'),
  ('A0502','fecha_efectiva_cancelacion','2026-09-08','Nota de la agente: «08 septiembre se manda baja»'),
  ('A0362','fecha_efectiva_cancelacion','2026-07-29','Nota de la agente: «29 JULIO SE MANDA BAJA»'),
  ('A0598','fecha_efectiva_cancelacion','2026-09-29','Nota de la agente: «29 SEPTIEMBRE SE MANDA BAJA»'),
  ('A0431','fecha_efectiva_cancelacion','2026-08-28','Nota de la agente: «28 AGOSTO SE MANDA BAJA»'),
  ('A0438','fecha_efectiva_cancelacion','2026-08-28','Nota de la agente: «28 AGOSTO SE MANDA BAJA»'),
  ('A0522','fecha_efectiva_cancelacion','2026-09-24','Nota de la agente: «24 sept se manda baja»'),
  ('D0425','fecha_efectiva_cancelacion','2026-08-27','Nota de la agente: «27 AGOSTO SE MANDA BAJA»'),
  ('A0553','fecha_efectiva_cancelacion','2026-09-24','Nota de la agente: «24 SEPT, SE MANDA BAJA»'),
  ('A0439','fecha_efectiva_cancelacion','2026-08-28','Nota de la agente: «28 AGOSTO SE MANDA BAJA»'),
  ('A0445','fecha_efectiva_cancelacion','2026-09-03','Nota de la agente: «03 septiembre se manda baja»'),
  ('A0414','fecha_efectiva_cancelacion','2026-08-27','Nota de la agente: «27 AGOSTO, SE MANDA BAJA»'),
  ('A0389','fecha_efectiva_cancelacion','2026-08-20','Nota de la agente: «20 de agosto se manda baja»'),
  ('A0521','fecha_efectiva_cancelacion','2026-09-24','Nota de la agente: «24 SEPTIEMBRE: SE MANDA BAJA»'),
  ('A0448','fecha_efectiva_cancelacion','2026-08-28','Nota de la agente: «28 AGOSTO SE MANDA BAJA»'),
  ('A0593','fecha_efectiva_cancelacion','2026-09-29','Nota de la agente: «29 sep se manda baja»'),
  ('A0444','fecha_efectiva_cancelacion','2026-08-28','Nota de la agente: «28 agosto se manda baja»'),
  ('A0536','fecha_efectiva_cancelacion','2026-09-24','Nota de la agente: «24 SEPTIEMBRE SE MANDA BAJA»'),
  ('A0394','fecha_efectiva_cancelacion','2026-08-27','Nota de la agente: «27 AGOSTO SE MANDA BAJA»'),
  ('A0568','fecha_efectiva_cancelacion','2026-09-25','Nota de la agente: «25 septiembre se manda baja»'),
  ('A0436','fecha_efectiva_cancelacion','2026-08-28','Nota de la agente: «28 AGOSTO SE MANDA BAJA»'),
  ('A0189','fecha_efectiva_cancelacion','2026-06-26','Nota de la agente: «26 JUNIO SE MANDA BAJA»'),
  ('A0395','fecha_efectiva_cancelacion','2026-08-27','Nota de la agente: «27 AGOSTO SE MANDA BAJA»'),
  ('A0345','fecha_efectiva_cancelacion','2026-08-31','Nota de la agente: «31 AGOSTO SE MANDA BAJA»'),
  ('A0157','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0386','empresa','Faja de Oro 316, Col. Lomas de Rosales (spa)','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «faja de oro 316 Colonia lomas de Rosales Es un spa! (Negocio) Aromatex»'),
  ('A0169','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0328','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0370','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «casa»'),
  ('A0198','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0583','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0256','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0383','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0532','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0626','empresa','Paseo Triunfo de la República 197 B, San Lorenzo, Ciudad Juárez','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Paseo Triunfo de la Republica 197 B, San Lorenzo, Ciudad Juarez. c.p 32320»'),
  ('A0502','empresa','Hyundai Solana Camelinas','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Hyundai Solana camelinas (razón social proveedora SKY)»'),
  ('A0244','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa 🏠»'),
  ('A0609','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «casa»'),
  ('A0733','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0062','empresa','Única','Bot: «…e, Oficina 3, etc._ Si es la única ubicación escribe *única*» · cliente: «unica»'),
  ('A0240','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0330','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('B0403','empresa','Haagen-Dazs El Dorado, Veracruz','Bot: «…e, Oficina 3, etc._ Si es la única ubicación escribe *única*» · cliente: «En haagen dazs el dorado Veracruz»'),
  ('A0542','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0499','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0226','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «CASa»'),
  ('B0195','empresa','Casa Andares','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa andares»'),
  ('A0211','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0419','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0694','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0304','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa»'),
  ('A0266','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «casa»'),
  ('A0319','empresa','Casa, León Gto.','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «Casa, en leon gto»'),
  ('A0228','empresa','Casa','Bot: «…re del lugar) 🏠 ¿O es servicio en tu casa? (escribe: *casa*)» · cliente: «casa»');
insert into legacy.cx_recuperacion_chat (fuente, registro, campo, valor_anterior, valor_nuevo, evidencia)
  select 'tickets', t.folio, r.campo,
         case r.campo when 'categoria' then t.categoria when 'empresa' then t.empresa else t.fecha_efectiva_cancelacion::text end,
         r.valor, r.evidencia
  from legacy.tickets t join r_campo r on r.registro=t.folio
  where (r.campo='categoria' and lower(btrim(coalesce(t.categoria,''))) in ('','cancelación de servicio','solicitud operativa','pendiente de clasificación'))
     or (r.campo='empresa' and btrim(coalesce(t.empresa,''))='')
     or (r.campo='fecha_efectiva_cancelacion' and t.fecha_efectiva_cancelacion is null and t.status_cancelacion='Cancelada')
  on conflict do nothing;
update legacy.tickets t set categoria=r.valor from r_campo r
  where r.registro=t.folio and r.campo='categoria'
    and lower(btrim(coalesce(t.categoria,''))) in ('','cancelación de servicio','solicitud operativa','pendiente de clasificación');
update legacy.tickets t set fecha_efectiva_cancelacion=r.valor::date from r_campo r
  where r.registro=t.folio and r.campo='fecha_efectiva_cancelacion' and t.fecha_efectiva_cancelacion is null and t.status_cancelacion='Cancelada';
update legacy.tickets t set empresa=r.valor from r_campo r
  where r.registro=t.folio and r.campo='empresa' and btrim(coalesce(t.empresa,''))='';

select campo, count(*) as aplicados from legacy.cx_recuperacion_chat group by campo order by campo;
commit;
