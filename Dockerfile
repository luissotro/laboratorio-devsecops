# =========================================================================
# Etapa 1: Build y validación de archivos de configuración
# =========================================================================
FROM nginx:1.30-alpine AS builder

# Copiar nuestra configuración personalizada de Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Verificar que la sintaxis de Nginx sea correcta antes de empaquetar
RUN nginx -t

# =========================================================================
# Etapa 2: Imagen final optimizada y securizada (Hardening)
# =========================================================================
FROM nginx:1.30-alpine

# Buenas prácticas: Actualizar el gestor de paquetes y aplicar parches de seguridad (CVEs)
RUN apk update && apk upgrade --no-cache

# Hardening 1: Eliminar permisos SUID/SGID innecesarios para evitar escalada de privilegios
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

# Hardening 2: Modificar los directorios de trabajo de Nginx para que no requieran ser Root
RUN chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx /var/run/ && \
    chmod -R 755 /var/cache/nginx /var/log/nginx /etc/nginx

# Hardening 3: Cambiar a un usuario no raíz (Non-root user) por seguridad
USER nginx

# Copiar la configuración validada desde la etapa anterior
COPY --from=builder --chown=nginx:nginx /etc/nginx/nginx.conf /etc/nginx/nginx.conf

# Copiar el código estático de tu web 
COPY --chown=nginx:nginx ./html /usr/share/nginx/html

# Exponer un puerto superior al 1024 (el usuario no-root 'nginx' no puede usar el puerto 80)
EXPOSE 8080

# HEALTHCHECK
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
  
# Comando de arranque por defecto
CMD ["nginx", "-g", "daemon off;"]
