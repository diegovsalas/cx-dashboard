#!/bin/bash
# Pruebas de acceso H1 contra Supabase LOCAL. Uso: prueba_h1.sh  (lee /Users/diego/cx-local/.env.local)
set -a; . /Users/diego/cx-local/.env.local; set +a
case "$API_URL" in *127.0.0.1*|*localhost*) ;; *) echo "Solo local"; exit 1;; esac
PASS=$(cat /Users/diego/cx-local/USUARIOS_PRUEBA.txt)
pwd_de(){ echo "$PASS" | awk -v e="$1" '$1==e{print $2}'; }
jwt(){ curl -s -X POST "$API_URL/auth/v1/token?grant_type=password" -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d "{\"email\":\"$1\",\"password\":\"$(pwd_de $1)\"}" | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])"; }
ok=0; fallo=0
# req <bearer> <metodo> <ruta> [cuerpo] -> imprime "codigo filas"
req(){ local out code
  out=$(curl -s -w '\n%{http_code}' -X "$2" "$API_URL/rest/v1/$3" -H "apikey: $ANON_KEY" -H "Authorization: Bearer $1" \
    -H "Accept-Profile: legacy" -H "Content-Profile: legacy" -H "Content-Type: application/json" -H "Prefer: return=representation" ${4:+-d "$4"})
  code=$(echo "$out" | tail -1); body=$(echo "$out" | sed '$d')
  echo "$code $(echo "$body" | python3 -c "import sys,json
try:
  d=json.load(sys.stdin);print(len(d) if isinstance(d,list) else 'err')
except Exception: print('err')")"; }
esperar(){ local desc="$1" obtenido="$2" esperado="$3"
  if [[ "$obtenido" =~ ^($esperado)$ ]]; then ok=$((ok+1)); echo "OK    $desc -> $obtenido"; else fallo=$((fallo+1)); echo "FALLO $desc -> $obtenido (esperado $esperado)"; fi; }

F=$(curl -s "$API_URL/rest/v1/tickets?select=folio&order=folio.asc&limit=1" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Accept-Profile: legacy" | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['folio'])")
BG=$(curl -s "$API_URL/rest/v1/base_general?select=id&order=id.asc&limit=1" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Accept-Profile: legacy" | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['id'])")
RESP_TK=$(curl -s "$API_URL/rest/v1/tickets?folio=eq.$F" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Accept-Profile: legacy" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin)[0]))")
RESP_BG=$(curl -s "$API_URL/rest/v1/base_general?id=eq.$BG" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Accept-Profile: legacy" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin)[0]))")

echo "== Sin sesión (llave pública)"
for t in tickets base_general envios_plantillas mensajes agentes; do esperar "anon lee $t" "$(req "$ANON_KEY" GET "$t?select=id&limit=5")" "401 err|200 0"; done
esperar "anon edita ticket" "$(req "$ANON_KEY" PATCH "tickets?folio=eq.$F" '{"zona":"Centro"}')" "401 err|200 0"

echo "== Consulta (sin rol)"
C=$(jwt consulta.prueba@grupoavantex.com)
esperar "consulta lee tickets" "$(req "$C" GET 'tickets?select=id')" "200 763"
esperar "consulta lee base_general (1a página)" "$(req "$C" GET 'base_general?select=id')" "200 1000"
esperar "consulta lee base_general (2a página)" "$(req "$C" GET 'base_general?select=id&offset=1000')" "200 151"
esperar "consulta no ve campañas" "$(req "$C" GET 'envios_plantillas?select=id')" "200 0"
esperar "consulta no lee mensajes" "$(req "$C" GET 'mensajes?select=id&limit=1')" "401 err|403 err"
esperar "consulta no lee agentes" "$(req "$C" GET 'agentes?select=id&limit=1')" "401 err|403 err"
esperar "consulta cambia zona de ticket" "$(req "$C" PATCH "tickets?folio=eq.$F" '{"zona":"Centro"}')" "200 1"
esperar "consulta no cambia estatus" "$(req "$C" PATCH "tickets?folio=eq.$F" '{"estatus":"Nuevo"}')" "403 err"
esperar "consulta no edita histórico" "$(req "$C" PATCH "base_general?id=eq.$BG" '{"comentarios_de_seguimiento":"x"}')" "200 0"
esperar "consulta no borra ticket" "$(req "$C" DELETE "tickets?folio=eq.$F")" "200 0"

echo "== Editora (Itzel)"
E=$(jwt itzelramirez@grupoavantex.com)
esperar "editora cambia estatus" "$(req "$E" PATCH "tickets?folio=eq.$F" '{"estatus":"Seguimiento"}')" "200 1"
esperar "editora edita histórico" "$(req "$E" PATCH "base_general?id=eq.$BG" '{"comentarios_de_seguimiento":"prueba H1"}')" "200 1"
esperar "editora no ve campañas" "$(req "$E" GET 'envios_plantillas?select=id')" "200 0"
esperar "editora no borra ticket" "$(req "$E" DELETE "tickets?folio=eq.$F")" "200 0"

echo "== Superadmin (Diego)"
S=$(jwt diegovelazquez@grupoavantex.com)
esperar "superadmin ve campañas" "$(req "$S" GET 'envios_plantillas?select=id')" "200 114"
esperar "superadmin borra ticket" "$(req "$S" DELETE "tickets?folio=eq.$F")" "200 1"

echo "== Bot (llave de servicio)"
esperar "bot lee mensajes" "$(req "$SERVICE_ROLE_KEY" GET 'mensajes?select=id&limit=1')" "200 [01]"
esperar "bot reinserta ticket" "$(req "$SERVICE_ROLE_KEY" POST tickets "$RESP_TK")" "201 1"
CUERPO_EST=$(echo "$RESP_TK" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(json.dumps(dict(estatus=d["estatus"],zona=d["zona"])))')
esperar "bot cambia estatus" "$(req "$SERVICE_ROLE_KEY" PATCH "tickets?folio=eq.$F" "$CUERPO_EST")" "200 1"
esperar "bot restaura histórico" "$(req "$SERVICE_ROLE_KEY" PATCH "base_general?id=eq.$BG" "$RESP_BG")" "200 1"

echo "== Resultado: $ok OK, $fallo FALLO"
[ "$fallo" -eq 0 ]
