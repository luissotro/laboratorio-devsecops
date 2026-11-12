#!/usr/bin/env bash
# Crea contraseñas aleatorias para la base de datos en ./secrets (ignorado por Git).
# No sobrescribe las que ya existan. Uso: bash scripts/init-secrets.sh
set -eu

cd "$(dirname "$0")/.."
mkdir -p secrets

for name in db_admin_password db_app_password; do
    file="secrets/${name}.txt"
    if [ -s "$file" ]; then
        echo "Ya existe: $file"
    else
        head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32 > "$file"
        # Legible por los usuarios sin privilegios de los contenedores
        chmod 644 "$file"
        echo "Creado:    $file"
    fi
done
