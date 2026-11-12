#!/bin/bash
# Lee la contraseña de la base de datos desde el secreto de Docker y la expone solo al proceso
# de Tomcat como variable de entorno. No se escribe en disco ni en la línea de comandos.
set -euo pipefail

if [ -r /run/secrets/db_app_password ]; then
    DB_PASSWORD="$(< /run/secrets/db_app_password)"
    export DB_PASSWORD
fi

exec "$@"
