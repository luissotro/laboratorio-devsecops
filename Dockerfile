# =========================================================================
# Etapa 1: Build y validación de archivos de configuración
# =========================================================================
FROM nginx:1.30-alpine AS builder

# openssl solo se usa aquí para crear un certificado temporal con el que validar la sintaxis
RUN apk add --no-cache openssl

# Certificado temporal (esta etapa NO se publica; el real se genera al arrancar el contenedor)
RUN mkdir -p /tmp/certs && \
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
      -days 1 -subj "/CN=localhost" \
      -keyout /tmp/certs/server.key -out /tmp/certs/server.crt

# Copiar nuestra configuración personalizada de Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Verificar que la sintaxis de Nginx sea correcta antes de empaquetar
RUN nginx -t

# =========================================================================
# Etapa 2: Imagen final optimizada y securizada (Hardening)
# =========================================================================
FROM nginx:1.30-alpine

# Buenas prácticas: Actualizar el gestor de paquetes y aplicar parches de seguridad (CVEs)
# openssl se necesita para generar el certificado de laboratorio al arrancar
RUN apk update && apk upgrade --no-cache && apk add --no-cache openssl

# Hardening 1: Eliminar permisos SUID/SGID innecesarios para evitar escalada de privilegios
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

# Hardening 2: Modificar los directorios de trabajo de Nginx para que no requieran ser Root
RUN chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx /var/run/ && \
    chmod -R 755 /var/cache/nginx /var/log/nginx /etc/nginx

# Hardening 3: Cambiar a un usuario no raíz (Non-root user) por seguridad
USER nginx

# Copiar la configuración validada desde la etapa anterior
COPY --from=builder --chown=nginx:nginx /etc/nginx/nginx.conf /etc/nginx/nginx.conf

# Script que genera el certificado autofirmado al arrancar (si no hay uno montado en /tmp/certs)
COPY --chown=nginx:nginx --chmod=0755 docker-entrypoint.d/40-generate-cert.sh /docker-entrypoint.d/40-generate-cert.sh

# Copiar el código estático de tu web
COPY --chown=nginx:nginx ./html /usr/share/nginx/html

# Puertos superiores a 1024 (el usuario no-root 'nginx' no puede usar el 80/443)
# 8080: redirección a HTTPS y /healthz · 8443: HTTPS
EXPOSE 8080 8443

# HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

# Comando de arranque por defecto
CMD ["nginx", "-g", "daemon off;"]
