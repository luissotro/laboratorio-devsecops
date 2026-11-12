# =========================================================================
# Etapa 1: validar la configuración de Nginx
# =========================================================================
FROM nginx:1.30-alpine AS builder

# openssl solo se usa aquí para crear un certificado temporal con el que validar la sintaxis
RUN apk add --no-cache openssl

# Certificado temporal (esta etapa NO se publica; el real se genera al arrancar el contenedor)
RUN mkdir -p /tmp/certs && \
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
      -days 1 -subj "/CN=localhost" \
      -keyout /tmp/certs/server.key -out /tmp/certs/server.crt

COPY nginx.conf /etc/nginx/nginx.conf
RUN nginx -t

# =========================================================================
# Etapa 2: imagen final endurecida
# =========================================================================
FROM nginx:1.30-alpine

LABEL org.opencontainers.image.source="https://github.com/luissotro/laboratorio-devsecops"

# Parches de seguridad; openssl se necesita para generar el certificado al arrancar
RUN apk update && apk upgrade --no-cache && apk add --no-cache openssl

# Eliminar los bits SUID/SGID
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

# Directorios de trabajo accesibles para el usuario sin privilegios
RUN chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx /var/run/ && \
    chmod -R 755 /var/cache/nginx /var/log/nginx /etc/nginx

USER nginx

COPY --from=builder --chown=nginx:nginx /etc/nginx/nginx.conf /etc/nginx/nginx.conf

# Genera el certificado autofirmado al arrancar (si no hay uno montado en /tmp/certs)
COPY --chown=nginx:nginx --chmod=0755 docker-entrypoint.d/40-generate-cert.sh /docker-entrypoint.d/40-generate-cert.sh

# 8080: redirección a HTTPS y /healthz · 8443: HTTPS (proxy inverso hacia Tomcat)
EXPOSE 8080 8443

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
