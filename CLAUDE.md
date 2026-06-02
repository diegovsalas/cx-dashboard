# cx-dashboard — Contexto para Claude

App de **Customer Experience de Grupo Avantex**. SPA de un solo archivo (`index.html` en la **raíz**) servida por un Express mínimo (`server.js`), desplegada en **Render**. Backend en **Supabase** (proyecto ref `cyntwgxryfbrboehcdex`).

## Cómo correr local
```bash
npm install
PORT=3099 npm start     # OJO: el puerto 3000 lo suele ocupar la app "katia.work"
# abrir http://localhost:3099
```
- `server.js` sirve el `index.html` de la **raíz** en `/` (NO `public/index.html`, que es una versión vieja/obsoleta). `express.static('public',{index:false})` + rutas explícitas para `favicon.png` y `guia.html`. Los `.py`/`.sql` no se exponen.
- La app requiere **login de Supabase** (auth). Admins: `diegovelazquez@grupoavantex.com`, `servicioalcliente@grupoavantex.com` (constante `ADMIN_EMAILS` en `index.html`).

## Arquitectura de la SPA (index.html raíz)
- Cliente Supabase global `sb` (createClient con `SUPABASE_URL` + `SUPABASE_ANON_KEY` hardcodeados arriba del `<script>`).
- Navegación por páginas: links con `data-page` + `onclick="goPage('x')"`, divs `id="page-x"` dentro de `#pg-app`. La función `goPage(p)` muestra/oculta páginas e inicializa cada una.
- Páginas: home, dashboard, registros, cancelaciones, tickets, campanias, **permisos**.
- Datos principales desde tabla `base_general`.

## Módulo de Permisos (página "permisos", admin-only)
Réplica de un Google Apps Script de Sodexo, generalizada a todos los clientes. Envía solicitudes de acceso por zona a clientes, con el INE (PDF) de cada técnico adjunto.

- **Página** `#page-permisos` + funciones JS con prefijo `perm*` (antes del `checkSession()` final). Reusa `sb` para leer y llama a la Edge Function con el access_token de la sesión.
- **Edge Function** `enviar-permisos` (Supabase): agrupa sucursales por zona, arma el HTML, descarga los INE de Google Drive (links "cualquiera con el enlace") y envía por **Resend**.
  - Remitente: `Grupo Avantex <servicioalcliente@grupoavantex.com>` (dominio grupoavantex.com verificado en Resend).
  - La API key de Resend está incrustada como respaldo en la función (restringida solo-envío). `Deno.env.get('RESEND_API_KEY')`/`RESEND_FROM` tienen prioridad si se registran como secrets → **TODO pendiente: moverla a secret**.
  - Payload: `{ account_id, fecha_texto, horario?, asunto?, test_to?, dry_run?, sucursales:[{suc_id,nombre,solicitante,zona,horario?,tipo?,tecnicos:[]}] }`. `dry_run:true` devuelve preview sin enviar; `test_to` manda todo a un correo (prueba).

### Tablas (todas con prefijo del sistema de permisos)
- `cs_accounts` — clientes (ya existía). SODEXO id `149ee656-9eb5-4e93-af1a-edab5d60283d`.
- `cs_permisos_config` — por cliente: asunto, intro_html (con `{fecha}`/`{horario}`), cierre_html, horario_default, from_email.
- `cs_permisos_zonas` — por cliente+zona: para, cc, cco, asunto_override (= hoja "Dashboard" del script).
- `cs_permisos_sucursales` — catálogo de sucursales por cliente (= hoja "Base"): suc_id, nombre, solicitante, zona, horario, tipo, tecnicos_default.
- `cs_tecnicos` — técnicos (account_id NULL = global): nombre, ine_url (link Drive).
- `cs_permisos_envios` — log de envíos.

### Seguridad (RLS)
Las 5 tablas de permisos tienen **RLS activado** con política `for all to authenticated` (anon bloqueado; service role / Edge Function hace bypass). El cx-dashboard funciona logueado.
⚠️ Quedan ~43 tablas más con RLS deshabilitado (cs_accounts, base_general, customer_master, savio_*, api_keys, zoho_tokens…) — pendiente endurecer con cuidado (riesgo de romper otras apps que comparten el Supabase).

## Pendientes
1. Mover la API key de Resend a un secret de Supabase (`RESEND_API_KEY`, `RESEND_FROM`).
2. Plan de RLS por tabla para las ~43 restantes.
3. Borrar `public/index.html` (obsoleto). El nav tiene 8 ítems y "Permisos"/"Chat agentes" se salen en pantallas angostas (overflow horizontal).
