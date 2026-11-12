#!/usr/bin/env bash
# Pruebas de humo del stack Nginx + Tomcat.
# Uso: ./tests/smoke.sh   (con el stack levantado)
set -euo pipefail

BASE_HTTP="${BASE_HTTP:-http://localhost:8080}"
BASE_HTTPS="${BASE_HTTPS:-https://localhost:8443}"

fail() { echo "FALLO: $1"; exit 1; }

echo "1) Endpoint de salud de Nginx (HTTP)"
curl -sf "$BASE_HTTP/healthz" > /dev/null || fail "/healthz no responde"
echo "   OK"

echo "2) Redirección de HTTP a HTTPS"
curl -sI "$BASE_HTTP/" | grep -q " 301" || fail "no hay redirección 301"
echo "   OK"

echo "3) Página de la aplicación por HTTPS (certificado autofirmado, por eso -k)"
HEADERS="$(curl -skI "$BASE_HTTPS/")"
echo "$HEADERS" | sed 's/^/   /'
echo "$HEADERS" | grep -Eq "^HTTP/(1.1|2) 200" || fail "la página no devuelve 200"
echo "   OK"

echo "4) Cabeceras de seguridad"
for h in strict-transport-security x-content-type-options x-frame-options content-security-policy; do
  echo "$HEADERS" | grep -qi "^$h:" || fail "falta la cabecera $h"
done
echo "   OK"

echo "5) Salud de la aplicación a través del proxy"
curl -sk "$BASE_HTTPS/health" | grep -q '"status":"UP"' || fail "/health no devuelve UP"
echo "   OK"

echo "6) La aplicación confirma el proxy y el usuario sin privilegios"
BODY="$(curl -sk "$BASE_HTTPS/")"
echo "$BODY" | grep -q "<td>https</td>"  || fail "Tomcat no ve el esquema https (¿falla el proxy?)"
echo "$BODY" | grep -q "<td>tomcat</td>" || fail "Tomcat no se ejecuta como el usuario 'tomcat'"
echo "   OK"

echo "7) Solo lectura: POST rechazado"
CODE="$(curl -sk -o /dev/null -w '%{http_code}' -X POST "$BASE_HTTPS/")"
[ "$CODE" = "403" ] || fail "POST devolvió $CODE y debería ser 403"
echo "   OK"

echo "8) Los ficheros ocultos están bloqueados"
CODE="$(curl -sk -o /dev/null -w '%{http_code}' "$BASE_HTTPS/.env")"
[ "$CODE" = "403" ] || fail "/.env devolvió $CODE y debería ser 403"
echo "   OK"

echo "9) La aplicación consulta PostgreSQL (datasource JNDI) a través del proxy"
DB="$(curl -sk "$BASE_HTTPS/db")"
echo "$DB" | grep -q '"status":"UP"' || fail "/db no devuelve UP: $DB"
echo "$DB" | grep -q '"message":"Hola desde PostgreSQL"' || fail "/db no devuelve el dato de la base de datos"
echo "   OK"

echo "10) La aplicación usa el usuario de mínimo privilegio ('app'), no el administrador"
echo "$DB" | grep -q '"user":"app"' || fail "/db no se conecta como el usuario 'app'"
echo "   OK"

echo "11) PostgreSQL no está expuesto en el equipo (puerto ${PG_PORT:-5432})"
if ( exec 3<>"/dev/tcp/127.0.0.1/${PG_PORT:-5432}" ) 2>/dev/null; then
  fail "hay algo escuchando en el puerto ${PG_PORT:-5432} (¿otro PostgreSQL local o un puerto publicado?)"
fi
echo "   OK"

echo
echo "Todas las pruebas han pasado."
