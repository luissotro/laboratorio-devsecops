FROM postgres:17-alpine

LABEL org.opencontainers.image.source="https://github.com/luissotro/laboratorio-devsecops"

# gosu solo lo usa el entrypoint cuando el contenedor arranca como root, para cambiar al usuario
# "postgres". Aquí el contenedor se ejecuta siempre como "postgres" (ver docker-compose.yml), así
# que gosu no se utiliza nunca. Se elimina para quitar su superficie de ataque: Trivy detecta
# vulnerabilidades en la versión de Go con la que está compilado.
RUN rm -f /usr/local/bin/gosu
