-- Retención · Fase 1 (árbol de retención en el dashboard CX)
-- Aditiva: crea tablas, vista y funciones nuevas en legacy. Solo modifica
-- legacy.cx_validar_cierre_cancelacion para aceptar el resultado «Pausa».
-- Reversa: 2026-11-17_retencion_fase1_reversa.sql
-- Decisiones (Diego Velázquez, 17-nov-2026):
--   * El caso se crea al TOMAR el ticket desde la bandeja; el bot solo crea el ticket.
--   * Pueden tomar: roles superadmin/admin/editor del dashboard, excepto quien tenga no_toma.
--   * Autoriza todo lo que no decide la ejecutiva: solo Diego Velázquez.
--   * Editan los campos por definir: diegovelazquez@ y alejandrogil@ (con historial).
--   * Multimarca: el proceso es común; el árbol (contenido) es por marca.
begin;

-- ---------------------------------------------------------------- permisos
create table if not exists legacy.cx_retencion_permisos (
  email                text primary key check (email = lower(email)),
  puede_editar_reglas  boolean not null default false,
  puede_autorizar      boolean not null default false,
  no_toma              boolean not null default false,
  nota                 text
);
insert into legacy.cx_retencion_permisos (email, puede_editar_reglas, puede_autorizar, no_toma, nota) values
  ('diegovelazquez@grupoavantex.com', true,  true,  false, 'Gerente de CX: autoriza y edita reglas'),
  ('alejandrogil@grupoavantex.com',   true,  false, false, 'Edita campos por definir; no autoriza casos'),
  ('johanamartinez@grupoavantex.com', false, false, true,  'Decisión 17-nov-2026: no toma solicitudes de la bandeja')
on conflict (email) do update set puede_editar_reglas = excluded.puede_editar_reglas,
  puede_autorizar = excluded.puede_autorizar, no_toma = excluded.no_toma, nota = excluded.nota;

create or replace function legacy.cx_ret_email() returns text
  language sql stable set search_path = ''
as $$ select lower(coalesce(auth.jwt() ->> 'email', '')) $$;

create or replace function legacy.cx_ret_permiso(p text) returns boolean
  language sql stable security definer set search_path = ''
as $$
  select coalesce((select case p when 'editar' then r.puede_editar_reglas
                                 when 'autorizar' then r.puede_autorizar
                                 when 'no_toma' then r.no_toma end
                   from legacy.cx_retencion_permisos r where r.email = legacy.cx_ret_email()), false)
$$;

create or replace function legacy.cx_ret_puede_tomar() returns boolean
  language sql stable security definer set search_path = ''
as $$ select legacy.cx_rol() in ('superadmin','admin','editor') and not legacy.cx_ret_permiso('no_toma') $$;

-- ------------------------------------------------------------ configuración
create table if not exists legacy.cx_retencion_config (
  marca       text primary key,
  activo      boolean not null default true,   -- false: la marca aparece en la bandeja pero sin árbol
  inicio      date not null,                   -- solo entran a la bandeja tickets desde esta fecha
  version     int not null default 1,
  arbol       jsonb,                           -- arbol-retencion.json; null si la marca aún no tiene árbol
  por_definir jsonb not null default '{}'::jsonb,
  updated_by  text,
  updated_at  timestamptz not null default now()
);
create table if not exists legacy.cx_retencion_config_log (
  id        bigserial primary key,
  marca     text not null,
  campo     text not null,
  antes     jsonb,
  despues   jsonb,
  por       text not null,
  at        timestamptz not null default now()
);

-- -------------------------------------------------------------------- casos
create table if not exists legacy.cx_retencion_casos (
  folio                 text primary key,          -- legacy.tickets.folio (sin FK: folio no es único en todas las copias)
  marca                 text not null,
  con_arbol             boolean not null,
  version_arbol         int,
  atiende               text not null,           -- correo de quien tomó el ticket
  tomado_at             timestamptz not null default now(),
  fecha_solicitud       timestamptz not null,    -- llegada del ticket: aquí arranca el reloj
  canal                 text not null default 'WhatsApp',
  contacto              text,
  empresa               text,
  mensualidad           numeric(12,2),
  antiguedad_meses      int,
  vendedor_original     text,
  aroma                 text,
  zona                  text check (zona in ('Matriz','Centro','Sur','Bajío','Noreste','Noroeste','Pacífico')),
  motivo_inicial        text,
  motivo_sugerido       text,
  causa_raiz            text,
  situacion             text,
  primer_contacto_at    timestamptz,
  primer_contacto_via   text check (primer_contacto_via in ('texto','plantilla','manual')),
  primer_contacto_wamid text,
  llamada_at            timestamptz,
  intentos              int not null default 0 check (intentos between 0 and 3),
  notas_llamada         text,
  propuesta_enviada_at  timestamptz,
  resultado             text check (resultado in ('ret','aj','pausa','baja')),
  nueva_mensualidad     numeric(12,2),
  tarifa_compensatoria  text check (tarifa_compensatoria in ('cobra','condona')),
  fecha_efectiva        date,
  fecha_seguimiento     date,
  fecha_reactivacion    date,
  autorizo              text,
  autorizo_email        text,
  autorizo_at           timestamptz,
  resumen_operandium    text,
  resumen_copiado_at    timestamptz,
  estado                text not null default 'abierto' check (estado in ('abierto','cerrado')),
  cerrado_at            timestamptz,
  seguimiento_hecho     boolean not null default false,
  reactivacion_hecha    boolean not null default false,
  recontacto_hecho      boolean not null default false,
  updated_at            timestamptz not null default now()
);
create index if not exists cx_retencion_casos_estado on legacy.cx_retencion_casos (estado, marca);

create table if not exists legacy.cx_retencion_acciones (
  folio       text not null references legacy.cx_retencion_casos(folio) on delete cascade,
  accion      text not null,
  estado      text not null check (estado in ('o','a','r')),
  updated_by  text,
  updated_at  timestamptz not null default now(),
  primary key (folio, accion)
);

create table if not exists legacy.cx_retencion_eventos (
  id      bigserial primary key,
  folio   text not null references legacy.cx_retencion_casos(folio) on delete cascade,
  tipo    text not null,     -- tomado, primer_contacto, boton_cliente, autorizado, cerrado, reabierto
  detalle jsonb not null default '{}'::jsonb,
  por     text,
  at      timestamptz not null default now()
);
create index if not exists cx_retencion_eventos_folio on legacy.cx_retencion_eventos (folio, at);

-- Candado: campos que solo cambian las funciones (autorización, cierre, identidad del caso).
create or replace function legacy.cx_retencion_casos_guardia() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  if coalesce(current_setting('cx.retencion_rpc', true), '') = '1'
     or coalesce(auth.role(), '') <> 'authenticated' then
    new.updated_at := now();
    return new;
  end if;
  if old.estado = 'cerrado' then
    if (to_jsonb(new) - array['seguimiento_hecho','reactivacion_hecha','recontacto_hecho','updated_at'])
       is distinct from (to_jsonb(old) - array['seguimiento_hecho','reactivacion_hecha','recontacto_hecho','updated_at']) then
      raise exception 'El caso está cerrado. Reábrelo para cambiarlo.' using errcode = '42501';
    end if;
  elsif (new.folio, new.marca, new.con_arbol, new.version_arbol, new.atiende, new.tomado_at, new.fecha_solicitud,
         new.autorizo, new.autorizo_email, new.autorizo_at, new.estado, new.cerrado_at, new.primer_contacto_wamid)
     is distinct from
        (old.folio, old.marca, old.con_arbol, old.version_arbol, old.atiende, old.tomado_at, old.fecha_solicitud,
         old.autorizo, old.autorizo_email, old.autorizo_at, old.estado, old.cerrado_at, old.primer_contacto_wamid) then
    raise exception 'Ese dato solo se cambia desde su botón (tomar, autorizar o cerrar).' using errcode = '42501';
  end if;
  -- Cualquier cambio después de copiar el resumen obliga a copiarlo de nuevo.
  if new.resumen_copiado_at is not null and new.resumen_copiado_at is not distinct from old.resumen_copiado_at
     and (to_jsonb(new) - array['resumen_copiado_at','resumen_operandium','updated_at','seguimiento_hecho','reactivacion_hecha','recontacto_hecho'])
         is distinct from (to_jsonb(old) - array['resumen_copiado_at','resumen_operandium','updated_at','seguimiento_hecho','reactivacion_hecha','recontacto_hecho']) then
    new.resumen_copiado_at := null;
  end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists cx_retencion_casos_guardia on legacy.cx_retencion_casos;
create trigger cx_retencion_casos_guardia before update on legacy.cx_retencion_casos
  for each row execute function legacy.cx_retencion_casos_guardia();

-- Cambiar una acción también invalida el resumen copiado.
create or replace function legacy.cx_retencion_acciones_guardia() returns trigger
  language plpgsql security definer set search_path = ''
as $$
declare f text := coalesce(new.folio, old.folio);
begin
  if exists (select 1 from legacy.cx_retencion_casos c where c.folio = f and c.estado = 'cerrado') then
    raise exception 'El caso está cerrado. Reábrelo para cambiarlo.' using errcode = '42501';
  end if;
  perform set_config('cx.retencion_rpc', '1', true);
  update legacy.cx_retencion_casos set resumen_copiado_at = null where folio = f;
  perform set_config('cx.retencion_rpc', '', true);
  if tg_op = 'DELETE' then return old; end if;
  new.updated_by := legacy.cx_ret_email();
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists cx_retencion_acciones_guardia on legacy.cx_retencion_acciones;
create trigger cx_retencion_acciones_guardia before insert or update or delete on legacy.cx_retencion_acciones
  for each row execute function legacy.cx_retencion_acciones_guardia();

-- --------------------------------------------------------------------- RLS
alter table legacy.cx_retencion_permisos    enable row level security;
alter table legacy.cx_retencion_config      enable row level security;
alter table legacy.cx_retencion_config_log  enable row level security;
alter table legacy.cx_retencion_casos       enable row level security;
alter table legacy.cx_retencion_acciones    enable row level security;
alter table legacy.cx_retencion_eventos     enable row level security;
revoke all on legacy.cx_retencion_permisos, legacy.cx_retencion_config, legacy.cx_retencion_config_log,
              legacy.cx_retencion_casos, legacy.cx_retencion_acciones, legacy.cx_retencion_eventos
  from anon, authenticated;
grant select on legacy.cx_retencion_permisos, legacy.cx_retencion_config, legacy.cx_retencion_config_log,
               legacy.cx_retencion_casos, legacy.cx_retencion_eventos to authenticated;
grant update (mensualidad, antiguedad_meses, vendedor_original, aroma, zona, contacto, empresa, canal,
              motivo_inicial, causa_raiz, situacion, primer_contacto_at, primer_contacto_via,
              llamada_at, intentos, notas_llamada, propuesta_enviada_at, resultado, nueva_mensualidad,
              tarifa_compensatoria, fecha_efectiva, fecha_seguimiento, fecha_reactivacion,
              resumen_operandium, resumen_copiado_at, seguimiento_hecho, reactivacion_hecha, recontacto_hecho)
  on legacy.cx_retencion_casos to authenticated;
grant select, insert, update, delete on legacy.cx_retencion_acciones to authenticated;
grant all on legacy.cx_retencion_permisos, legacy.cx_retencion_config, legacy.cx_retencion_config_log,
             legacy.cx_retencion_casos, legacy.cx_retencion_acciones, legacy.cx_retencion_eventos to service_role;
grant usage, select on all sequences in schema legacy to service_role;

drop policy if exists cx_ret_permisos_ver on legacy.cx_retencion_permisos;
create policy cx_ret_permisos_ver on legacy.cx_retencion_permisos for select to authenticated
  using (legacy.cx_rol() is not null or legacy.cx_ret_permiso('editar'));
drop policy if exists cx_ret_config_ver on legacy.cx_retencion_config;
create policy cx_ret_config_ver on legacy.cx_retencion_config for select to authenticated
  using (legacy.cx_rol() is not null or legacy.cx_ret_permiso('editar'));
drop policy if exists cx_ret_log_ver on legacy.cx_retencion_config_log;
create policy cx_ret_log_ver on legacy.cx_retencion_config_log for select to authenticated
  using (legacy.cx_rol() is not null or legacy.cx_ret_permiso('editar'));
drop policy if exists cx_ret_casos_ver on legacy.cx_retencion_casos;
create policy cx_ret_casos_ver on legacy.cx_retencion_casos for select to authenticated
  using (legacy.cx_rol() is not null);
drop policy if exists cx_ret_casos_editar on legacy.cx_retencion_casos;
create policy cx_ret_casos_editar on legacy.cx_retencion_casos for update to authenticated
  using (atiende = legacy.cx_ret_email() or legacy.cx_rol() in ('superadmin','admin'))
  with check (atiende = legacy.cx_ret_email() or legacy.cx_rol() in ('superadmin','admin'));
drop policy if exists cx_ret_eventos_ver on legacy.cx_retencion_eventos;
create policy cx_ret_eventos_ver on legacy.cx_retencion_eventos for select to authenticated
  using (legacy.cx_rol() is not null);
drop policy if exists cx_ret_acciones_ver on legacy.cx_retencion_acciones;
create policy cx_ret_acciones_ver on legacy.cx_retencion_acciones for select to authenticated
  using (legacy.cx_rol() is not null);
drop policy if exists cx_ret_acciones_editar on legacy.cx_retencion_acciones;
create policy cx_ret_acciones_editar on legacy.cx_retencion_acciones for all to authenticated
  using (exists (select 1 from legacy.cx_retencion_casos c where c.folio = cx_retencion_acciones.folio
                 and (c.atiende = legacy.cx_ret_email() or legacy.cx_rol() in ('superadmin','admin'))))
  with check (exists (select 1 from legacy.cx_retencion_casos c where c.folio = cx_retencion_acciones.folio
                 and (c.atiende = legacy.cx_ret_email() or legacy.cx_rol() in ('superadmin','admin'))));

-- ------------------------------------------------------------------ bandeja
create or replace function legacy.cx_ret_marca(servicio text) returns text
  language sql immutable set search_path = ''
as $$ select case when servicio ilike '%aromatex%' then 'Aromatex'
                  when servicio ilike '%pestex%' then 'Pestex'
                  when servicio ilike '%origen%' or servicio ilike '%caf%' then 'Origen Selecto'
                  else coalesce(nullif(btrim(servicio), ''), 'Sin servicio') end $$;

create or replace function legacy.cx_ret_motivo_sugerido(categoria text) returns text
  language sql immutable set search_path = ''
as $$ select case btrim(coalesce(categoria, ''))
  when 'Económico' then 'presupuesto'
  when 'Fallo de servicio' then 'servicio'
  when 'Calidad del aroma' then 'servicio'
  when 'Calidad del servicio' then 'servicio'
  when 'Bajo uso' then 'valor'
  when 'Temporal' then 'valor'
  when 'Fin de contrato' then 'proveedor'
  when 'Cambio de proveedor' then 'proveedor'
  when 'Cierre de operación' then 'cierre'
  when 'Reubicación' then 'cierre'
  else null end $$;   -- «Insatisfacción general» y «Otro» se eligen a mano

create or replace view legacy.cx_retencion_bandeja with (security_invoker = true) as
  select t.folio, t.created_at, t.nombre, t.empresa, t.servicio, t.categoria, t.mensaje,
         t.canal_origen, t.estatus, legacy.cx_ret_marca(t.servicio) as marca,
         coalesce(cfg.activo and cfg.arbol is not null, false) as con_arbol,
         legacy.cx_ret_motivo_sugerido(t.categoria) as motivo_sugerido,
         (coalesce(btrim(t.nombre), '') = '') as sin_contacto
  from legacy.tickets t
  left join legacy.cx_retencion_config cfg on cfg.marca = legacy.cx_ret_marca(t.servicio)
  where t.tipo ilike '%cancelac%'
    and lower(coalesce(t.estatus, '')) not in ('cerrado','resuelto','resuelta','cancelado')
    and t.created_at >= coalesce(cfg.inicio, (select min(c.inicio) from legacy.cx_retencion_config c))
    and not exists (select 1 from legacy.cx_retencion_casos c where c.folio = t.folio);
revoke all on legacy.cx_retencion_bandeja from anon, authenticated;
grant select on legacy.cx_retencion_bandeja to authenticated, service_role;

-- -------------------------------------------------------------------- tomar
create or replace function legacy.cx_retencion_tomar(p_folio text) returns legacy.cx_retencion_casos
  language plpgsql security definer set search_path = ''
as $$
declare t legacy.tickets; cfg legacy.cx_retencion_config; c legacy.cx_retencion_casos; yo text := legacy.cx_ret_email();
begin
  if not legacy.cx_ret_puede_tomar() then
    raise exception 'Tu usuario no puede tomar solicitudes de la bandeja.' using errcode = '42501';
  end if;
  select * into t from legacy.tickets where folio = p_folio for update;
  if t.folio is null then raise exception 'No existe el ticket %.', p_folio; end if;
  if coalesce(t.tipo, '') not ilike '%cancelac%' then
    raise exception 'El ticket % no es una solicitud de cancelación.', p_folio using errcode = 'check_violation';
  end if;
  if exists (select 1 from legacy.cx_retencion_casos x where x.folio = p_folio) then
    raise exception 'Otra persona ya tomó el ticket %.', p_folio using errcode = 'unique_violation';
  end if;
  select * into cfg from legacy.cx_retencion_config where marca = legacy.cx_ret_marca(t.servicio);
  insert into legacy.cx_retencion_casos (folio, marca, con_arbol, version_arbol, atiende, fecha_solicitud, canal,
                                         contacto, empresa, zona, mensualidad, motivo_inicial, motivo_sugerido)
  values (t.folio, legacy.cx_ret_marca(t.servicio), coalesce(cfg.activo and cfg.arbol is not null, false),
          cfg.version, yo, t.created_at,
          case when t.canal_origen ilike '%web%' then 'Chat web' else 'WhatsApp' end,
          nullif(btrim(t.nombre), ''), nullif(btrim(t.empresa), ''),
          case when t.zona in ('Matriz','Centro','Sur','Bajío','Noreste','Noroeste','Pacífico') then t.zona end,
          t.facturacin_sin_iva,
          legacy.cx_ret_motivo_sugerido(t.categoria), legacy.cx_ret_motivo_sugerido(t.categoria))
  returning * into c;
  update legacy.tickets set agente = split_part(yo, '@', 1),
         estatus = case when lower(coalesce(estatus, '')) in ('', 'nuevo') then 'En proceso' else estatus end
   where folio = p_folio;
  insert into legacy.cx_retencion_eventos (folio, tipo, por) values (p_folio, 'tomado', yo);
  return c;
end $$;

-- Solicitud que llegó por otro canal: crea el ticket y lo toma en un paso.
create or replace function legacy.cx_retencion_registrar(p_servicio text, p_canal text, p_nombre text,
                                                         p_empresa text, p_telefono text, p_mensaje text)
  returns legacy.cx_retencion_casos
  language plpgsql security definer set search_path = ''
as $$
declare f text; ini text;
begin
  if not legacy.cx_ret_puede_tomar() then
    raise exception 'Tu usuario no puede registrar solicitudes.' using errcode = '42501';
  end if;
  if coalesce(btrim(p_empresa), '') = '' then raise exception 'Escribe el cliente.' using errcode = 'check_violation'; end if;
  if p_canal not in ('Correo','Llamada','Técnico en sitio','Vendedor','Cobranza','Señal de riesgo') then
    raise exception 'Canal no válido.' using errcode = 'check_violation';
  end if;
  ini := case legacy.cx_ret_marca(p_servicio) when 'Aromatex' then 'A' when 'Pestex' then 'P' when 'Origen Selecto' then 'E' else 'X' end;
  f := public.generar_folio(ini);
  insert into legacy.tickets (folio, telefono, nombre, empresa, servicio, tipo, categoria, mensaje, prioridad, estatus, canal_origen)
  values (f, nullif(regexp_replace(coalesce(p_telefono, ''), '[^0-9]', '', 'g'), ''), btrim(p_nombre), btrim(p_empresa),
          legacy.cx_ret_marca(p_servicio), 'Solicitud de Cancelación', 'Cancelación de servicio',
          left(coalesce(p_mensaje, ''), 500), 'Alta', 'Nuevo', 'dashboard');
  perform legacy.cx_retencion_tomar(f);
  perform set_config('cx.retencion_rpc', '1', true);
  update legacy.cx_retencion_casos set canal = p_canal,
         motivo_inicial = case when p_canal = 'Señal de riesgo' then 'riesgo' else motivo_inicial end
   where folio = f;
  perform set_config('cx.retencion_rpc', '', true);
  return (select c from legacy.cx_retencion_casos c where c.folio = f);
end $$;

-- ---------------------------------------------------------------- autorizar
create or replace function legacy.cx_retencion_autorizar(p_folio text) returns legacy.cx_retencion_casos
  language plpgsql security definer set search_path = ''
as $$
declare c legacy.cx_retencion_casos; yo text := legacy.cx_ret_email();
begin
  if not legacy.cx_ret_permiso('autorizar') then
    raise exception 'Solo Gerencia CX (Diego Velázquez) autoriza.' using errcode = '42501';
  end if;
  perform set_config('cx.retencion_rpc', '1', true);
  update legacy.cx_retencion_casos set autorizo = 'Diego Velázquez', autorizo_email = yo, autorizo_at = now(),
         resumen_copiado_at = null
   where folio = p_folio and estado = 'abierto' returning * into c;
  perform set_config('cx.retencion_rpc', '', true);
  if c.folio is null then raise exception 'El caso % no está abierto.', p_folio; end if;
  insert into legacy.cx_retencion_eventos (folio, tipo, por) values (p_folio, 'autorizado', yo);
  return c;
end $$;

-- ------------------------------------------------------------------- cerrar
create or replace function legacy.cx_retencion_cerrar(p_folio text) returns legacy.cx_retencion_casos
  language plpgsql security definer set search_path = ''
as $$
declare
  c legacy.cx_retencion_casos; cfg legacy.cx_retencion_config; yo text := legacy.cx_ret_email();
  pr jsonb; sol jsonb; a record; suma numeric := 0; tope numeric; requiere boolean := false;
  ofrecidos int; aceptados int; minimo int := 2; st text; acept text;
begin
  select * into c from legacy.cx_retencion_casos where folio = p_folio for update;
  if c.folio is null or c.estado <> 'abierto' then raise exception 'El caso % no está abierto.', p_folio; end if;
  if not (c.atiende = yo or legacy.cx_rol() in ('superadmin','admin')) then
    raise exception 'Solo quien atiende el caso puede cerrarlo.' using errcode = '42501';
  end if;
  if not c.con_arbol then raise exception 'Esta marca todavía no tiene árbol: ciérrala desde la ficha de cancelación.'; end if;
  select * into cfg from legacy.cx_retencion_config where marca = c.marca;
  pr := cfg.arbol -> 'reglas' -> 'parametros';
  -- Datos mínimos
  if c.contacto is null or c.empresa is null or c.mensualidad is null or c.antiguedad_meses is null
     or c.vendedor_original is null or c.motivo_inicial is null or c.zona is null then
    raise exception 'Faltan datos del caso (paso 1).' using errcode = 'check_violation'; end if;
  if c.primer_contacto_at is null then raise exception 'Falta el primer contacto (paso 2).' using errcode = 'check_violation'; end if;
  if c.llamada_at is null and c.intentos < 3 then raise exception 'Falta la llamada o los 3 intentos (paso 3).' using errcode = 'check_violation'; end if;
  if c.causa_raiz is null then raise exception 'Falta la causa raíz (paso 3).' using errcode = 'check_violation'; end if;
  if c.causa_raiz = 'sincontacto' and (c.llamada_at is not null or c.intentos < 3) then
    raise exception '«Sin contacto» solo aplica con 3 intentos y sin llamada.' using errcode = 'check_violation'; end if;
  if c.propuesta_enviada_at is null then raise exception 'Falta enviar la propuesta por escrito (paso 5).' using errcode = 'check_violation'; end if;
  if c.resultado is null then raise exception 'Elige el resultado.' using errcode = 'check_violation'; end if;
  -- Mínimos de soluciones
  select count(*), count(*) filter (where estado = 'a') into ofrecidos, aceptados
    from legacy.cx_retencion_acciones where folio = p_folio;
  select coalesce((m ->> 'minimo_ofrecidos_para_baja')::int, 2) into minimo
    from jsonb_array_elements(cfg.arbol -> 'motivos') m where m ->> 'id' = c.causa_raiz;
  if c.resultado = 'baja' and ofrecidos < coalesce(minimo, 2) then
    raise exception 'Para baja se necesitan al menos % soluciones ofrecidas.', coalesce(minimo, 2) using errcode = 'check_violation'; end if;
  if c.resultado in ('aj','pausa') and aceptados < 1 then
    raise exception 'Se necesita al menos una solución aceptada.' using errcode = 'check_violation'; end if;
  if c.resultado = 'ret' and ofrecidos < 1 then
    raise exception 'Se necesita al menos una solución ofrecida.' using errcode = 'check_violation'; end if;
  -- Tope y autorización (misma regla que el árbol)
  tope := c.mensualidad * coalesce((pr -> 'topeMeses' ->> 'valor')::numeric, 1);
  for a in select x.accion, x.estado from legacy.cx_retencion_acciones x where x.folio = p_folio and x.estado in ('o','a') loop
    select s into sol from jsonb_array_elements(cfg.arbol -> 'soluciones') s where s ->> 'id' = a.accion;
    if a.estado = 'a' and coalesce(sol ->> 'nivel', 'ger') <> 'cx' then requiere := true; end if;
    if coalesce((sol -> 'valor' ->> 'cuenta_para_tope')::boolean, false) then
      suma := suma + case sol -> 'valor' ->> 'codigo'
        when 'tarifa' then c.mensualidad * (pr -> 'descPct' ->> 'valor')::numeric / 100 * (pr -> 'descMeses' ->> 'valor')::numeric
        when 'mes' then c.mensualidad
        when 'pestex' then coalesce(nullif(pr -> 'valorPestex' ->> 'valor', '')::numeric, 0)
        else 0 end;
    end if;
  end loop;
  if suma > tope then requiere := true; end if;
  if c.resultado = 'baja' and c.tarifa_compensatoria = 'condona' then requiere := true; end if;
  if requiere and c.autorizo is null then
    raise exception 'Falta la autorización de Gerencia CX.' using errcode = 'check_violation'; end if;
  if c.resultado = 'pausa' and c.fecha_reactivacion is null then raise exception 'Falta la fecha de reactivación.' using errcode = 'check_violation'; end if;
  if c.resultado <> 'baja' and c.fecha_seguimiento is null then raise exception 'Falta la fecha del próximo seguimiento.' using errcode = 'check_violation'; end if;
  if c.resultado = 'baja' and c.fecha_efectiva is null then raise exception 'Falta la fecha efectiva de la baja.' using errcode = 'check_violation'; end if;
  if c.resultado = 'baja' and c.antiguedad_meses < 12 and c.tarifa_compensatoria is null then
    raise exception 'Cuenta con menos de 12 meses: indica si la tarifa compensatoria se cobra o se condona.' using errcode = 'check_violation'; end if;
  if c.resultado = 'aj' and exists (select 1 from legacy.cx_retencion_acciones where folio = p_folio and accion = 'reconfig' and estado = 'a')
     and c.nueva_mensualidad is null then
    raise exception 'Reconfiguración aceptada: escribe la nueva mensualidad.' using errcode = 'check_violation'; end if;
  if c.resumen_copiado_at is null then raise exception 'Copia el resumen para Operandium antes de cerrar.' using errcode = 'check_violation'; end if;
  -- Sincroniza el ticket (lo valida cx_regla_cierre_cancelacion)
  perform set_config('cx.retencion_rpc', '1', true);
  st := case
    when c.resultado = 'baja' and c.causa_raiz = 'morosidad' then 'Cancelado por morosidad'
    when c.resultado = 'baja' then 'Cancelada'
    when c.resultado = 'pausa' then 'Pausa'
    when c.resultado = 'aj' and c.nueva_mensualidad is not null and c.nueva_mensualidad < c.mensualidad then 'Downgrade'
    else 'Retenida' end;
  select string_agg(s ->> 'nombre', '; ') into acept
    from legacy.cx_retencion_acciones x join jsonb_array_elements(cfg.arbol -> 'soluciones') s on s ->> 'id' = x.accion
   where x.folio = p_folio and x.estado = 'a';
  update legacy.tickets set
    estatus = 'Cerrado', status_cancelacion = st,
    fecha_efectiva_cancelacion = case when c.resultado = 'baja' then c.fecha_efectiva else fecha_efectiva_cancelacion end,
    monto_nuevo_downgrade = case when st = 'Downgrade' then c.nueva_mensualidad else monto_nuevo_downgrade end,
    facturacin_sin_iva = coalesce(facturacin_sin_iva, c.mensualidad),
    zona = c.zona,
    empresa = coalesce(nullif(btrim(empresa), ''), c.empresa),
    nombre = coalesce(nullif(btrim(nombre), ''), c.contacto),
    causa_raiz_cancelacion = (select m ->> 'nombre' from jsonb_array_elements(cfg.arbol -> 'motivos') m where m ->> 'id' = c.causa_raiz),
    oferta_retencion = coalesce(acept, oferta_retencion)
  where folio = p_folio;
  update legacy.cx_retencion_casos set estado = 'cerrado', cerrado_at = now() where folio = p_folio returning * into c;
  perform set_config('cx.retencion_rpc', '', true);
  insert into legacy.cx_retencion_eventos (folio, tipo, detalle, por)
    values (p_folio, 'cerrado', jsonb_build_object('status_cancelacion', st), yo);
  return c;
end $$;

create or replace function legacy.cx_retencion_reabrir(p_folio text) returns legacy.cx_retencion_casos
  language plpgsql security definer set search_path = ''
as $$
declare c legacy.cx_retencion_casos; yo text := legacy.cx_ret_email();
begin
  select * into c from legacy.cx_retencion_casos where folio = p_folio;
  if c.folio is null or c.estado <> 'cerrado' then raise exception 'El caso % no está cerrado.', p_folio; end if;
  if not (c.atiende = yo or legacy.cx_rol() in ('superadmin','admin')) then
    raise exception 'Solo quien atiende el caso puede reabrirlo.' using errcode = '42501'; end if;
  update legacy.tickets set estatus = 'En proceso' where folio = p_folio;
  perform set_config('cx.retencion_rpc', '1', true);
  update legacy.cx_retencion_casos set estado = 'abierto', cerrado_at = null, resumen_copiado_at = null
   where folio = p_folio returning * into c;
  perform set_config('cx.retencion_rpc', '', true);
  insert into legacy.cx_retencion_eventos (folio, tipo, por) values (p_folio, 'reabierto', yo);
  return c;
end $$;

-- ------------------------------------------------- campos por definir (editores)
create or replace function legacy.cx_retencion_editar_regla(p_marca text, p_campo text, p_valor jsonb)
  returns legacy.cx_retencion_config
  language plpgsql security definer set search_path = ''
as $$
declare cfg legacy.cx_retencion_config; antes jsonb; yo text := legacy.cx_ret_email();
begin
  if not legacy.cx_ret_permiso('editar') then
    raise exception 'Solo Diego Velázquez y Alejandro Gil editan estos campos.' using errcode = '42501'; end if;
  if p_campo not in ('bundlePestex','bundleOrigen','valorPestex','cashback','horario','visita48',
                     'descPct','descMeses','topeMeses','valorRoomSpray') then
    raise exception 'Ese campo no se edita desde aquí.' using errcode = 'check_violation'; end if;
  if p_campo in ('valorPestex','valorRoomSpray','descPct','descMeses','topeMeses')
     and (jsonb_typeof(p_valor) <> 'number' or (p_valor #>> '{}')::numeric < 0) then
    raise exception 'El valor debe ser un número mayor o igual a 0.' using errcode = 'check_violation'; end if;
  if p_campo = 'descPct' and (p_valor #>> '{}')::numeric > 100 then
    raise exception 'El descuento va de 0 a 100 %%.' using errcode = 'check_violation'; end if;
  if p_campo = 'descMeses' and ((p_valor #>> '{}')::numeric <> trunc((p_valor #>> '{}')::numeric)
                                or (p_valor #>> '{}')::numeric not between 1 and 24) then
    raise exception 'Los meses de tarifa de apoyo van de 1 a 24 (entero).' using errcode = 'check_violation'; end if;
  if p_campo = 'topeMeses' and ((p_valor #>> '{}')::numeric <= 0 or (p_valor #>> '{}')::numeric > 12) then
    raise exception 'El tope va de más de 0 hasta 12 mensualidades.' using errcode = 'check_violation'; end if;
  if p_campo = 'visita48' and (p_valor #>> '{}') not in ('', 'hábiles', 'naturales') then
    raise exception 'Elige horas hábiles o naturales.' using errcode = 'check_violation'; end if;
  select * into cfg from legacy.cx_retencion_config where marca = p_marca for update;
  if cfg.marca is null or cfg.arbol is null then raise exception 'La marca % no tiene árbol.', p_marca; end if;
  if p_campo in ('bundlePestex','bundleOrigen','valorPestex','descPct','descMeses','topeMeses','valorRoomSpray') then
    antes := cfg.arbol -> 'reglas' -> 'parametros' -> p_campo -> 'valor';
    update legacy.cx_retencion_config
       set arbol = jsonb_set(arbol, array['reglas','parametros',p_campo,'valor'], p_valor),
           version = version + 1, updated_by = yo, updated_at = now()
     where marca = p_marca returning * into cfg;
  else
    antes := cfg.por_definir -> p_campo;
    update legacy.cx_retencion_config
       set por_definir = por_definir || jsonb_build_object(p_campo, p_valor),
           version = version + 1, updated_by = yo, updated_at = now()
     where marca = p_marca returning * into cfg;
  end if;
  insert into legacy.cx_retencion_config_log (marca, campo, antes, despues, por) values (p_marca, p_campo, antes, p_valor, yo);
  return cfg;
end $$;

revoke execute on function legacy.cx_ret_permiso(text), legacy.cx_ret_puede_tomar(),
  legacy.cx_retencion_tomar(text), legacy.cx_retencion_registrar(text,text,text,text,text,text),
  legacy.cx_retencion_autorizar(text), legacy.cx_retencion_cerrar(text), legacy.cx_retencion_reabrir(text),
  legacy.cx_retencion_editar_regla(text,text,jsonb) from public, anon;
grant execute on function legacy.cx_ret_email(), legacy.cx_ret_permiso(text), legacy.cx_ret_puede_tomar(),
  legacy.cx_retencion_tomar(text), legacy.cx_retencion_registrar(text,text,text,text,text,text),
  legacy.cx_retencion_autorizar(text), legacy.cx_retencion_cerrar(text), legacy.cx_retencion_reabrir(text),
  legacy.cx_retencion_editar_regla(text,text,jsonb) to authenticated;

-- ------------------------------- una sola puerta de cierre para casos de retención
-- Un ticket con caso de retención abierto (marca con árbol) solo se cierra desde Retención.
create or replace function legacy.cx_retencion_bloquear_cierre_externo() returns trigger
  language plpgsql security definer set search_path = ''
as $$
begin
  if lower(coalesce(new.estatus, '')) in ('cerrado','resuelto','resuelta','cancelado')
     and lower(coalesce(old.estatus, '')) not in ('cerrado','resuelto','resuelta','cancelado')
     and coalesce(current_setting('cx.retencion_rpc', true), '') <> '1'
     and exists (select 1 from legacy.cx_retencion_casos c
                 where c.folio = new.folio and c.estado = 'abierto' and c.con_arbol) then
    raise exception 'Este ticket tiene un caso de retención abierto: ciérralo desde Retención en el dashboard CX.'
      using errcode = 'check_violation';
  end if;
  return new;
end $$;
drop trigger if exists cx_retencion_una_puerta on legacy.tickets;
create trigger cx_retencion_una_puerta before update on legacy.tickets
  for each row execute function legacy.cx_retencion_bloquear_cierre_externo();

-- ------------------------------------- regla de cierre: acepta el resultado «Pausa»
create or replace function legacy.cx_validar_cierre_cancelacion() returns trigger
  language plpgsql set search_path = ''
as $$
declare
  c_estatus text := tg_argv[0];
  c_tipo    text := tg_argv[1];
  n jsonb := to_jsonb(new);
  o jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) end;
  norm_estatus text := lower(coalesce(n ->> c_estatus, ''));
  resultado text := translate(lower(btrim(coalesce(n ->> 'status_cancelacion', ''))), 'áéíóú', 'aeiou');
  cerrado_antes boolean := o is not null and lower(coalesce(o ->> c_estatus, '')) in ('cerrado','resuelto','resuelta','cancelado');
begin
  if lower(coalesce(n ->> c_tipo, '')) not like '%cancelac%'
     or norm_estatus not in ('cerrado','resuelto','resuelta','cancelado') then
    return new;
  end if;
  if cerrado_antes
     and (o ->> 'status_cancelacion') is not distinct from (n ->> 'status_cancelacion')
     and (o ->> 'fecha_efectiva_cancelacion') is not distinct from (n ->> 'fecha_efectiva_cancelacion')
     and (o ->> c_tipo) is not distinct from (n ->> c_tipo) then
    return new;
  end if;
  if resultado not in ('retenida','cancelada','downgrade','migracion','cancelado por morosidad','pausa') then
    raise exception 'Para cerrar una cancelación selecciona un resultado definitivo.'
      using errcode = 'check_violation';
  end if;
  if resultado in ('cancelada','cancelado por morosidad') and new.fecha_efectiva_cancelacion is null then
    raise exception 'Indica la fecha efectiva de la cancelación (AAAA-MM-DD).'
      using errcode = 'check_violation';
  end if;
  return new;
end $$;

commit;
