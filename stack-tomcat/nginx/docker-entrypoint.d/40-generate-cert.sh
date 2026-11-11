#!/bin/sh
# Genera un certificado autofirmado de laboratorio al arrancar el contenedor,
# solo si no hay ya uno montado en /tmp/certs (server.crt y server.key).
# Así no se guarda ninguna clave privada dentro de la imagen.
set -eu

CERT_DIR=/tmp/certs
mkdir -p "$CERT_DIR"

if [ ! -s "$CERT_DIR/server.crt" ] || [ ! -s "$CERT_DIR/server.key" ]; then
    echo "[40-generate-cert] Generando certificado autofirmado de laboratorio (CN=localhost)..."
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -days 365 -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
        -keyout "$CERT_DIR/server.key" -out "$CERT_DIR/server.crt" 2>/dev/null
    chmod 600 "$CERT_DIR/server.key"
else
    echo "[40-generate-cert] Usando el certificado montado en $CERT_DIR"
fi
