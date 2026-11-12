# Stack Nginx + Tomcat

Segunda parte del laboratorio: una aplicación Java (un panel de estado) ejecutada en **Tomcat 10.1**, con **Nginx** delante como proxy inverso y terminación de TLS, y **PostgreSQL** como base de datos. Todo orquestado con Docker Compose y validado por su propio pipeline.

```
Navegador ──HTTPS 8443──▶ Nginx ──HTTP (red interna)──▶ Tomcat ──JDBC (JNDI)──▶ PostgreSQL
              (TLS, cabeceras de        │                 (8080 no publicado)     (5432 no publicado)
               seguridad, proxy)        └─ HTTP 8080: redirige a HTTPS y /healthz
```

## La aplicación

Un panel de estado muy pequeño, pensado para diagnóstico:

| Ruta | Qué hace |
|---|---|
| `/` | Muestra el contenedor, la versión de Java, el usuario del proceso, el tiempo en marcha y cómo llegó la petición (esquema y IP del cliente vistos por Tomcat) |
| `/health` | Devuelve `{"status":"UP"}`; lo usan el `HEALTHCHECK` y el pipeline |
| `/db` | Consulta PostgreSQL a través del datasource JNDI y devuelve el estado, la base de datos, el usuario con el que se conecta y un dato guardado en la base. Si la base de datos falla, responde `503` sin detalles |

El código está en `app/` y se compila con Maven dentro del propio build de Docker. Los valores que se pintan en la página se escapan para evitar inyección de HTML.

## Medidas de seguridad

**Tomcat**
- Aplicaciones por defecto eliminadas (`manager`, `host-manager`, `examples`, `docs`).
- Puerto de apagado (`SHUTDOWN`) desactivado.
- Páginas de error sin versión del servidor ni trazas; sin cabecera `Server` ni `X-Powered-By`.
- Ejecución con un usuario sin privilegios (`tomcat`, UID 10001) y bits SUID/SGID eliminados.
- Configuración en solo lectura para ese usuario.
- `RemoteIpValve` para tomar la IP y el esquema reales de las cabeceras del proxy.

**Nginx**
- TLS 1.2 y 1.3, HTTP/2 y HSTS; cabeceras de seguridad; solo `GET` y `HEAD`; ficheros ocultos bloqueados.
- La cabecera `X-Forwarded-For` se sobrescribe en el borde para que un cliente no pueda falsificarla.

**Base de datos y secretos**
- Datasource JNDI/JDBC definido en Tomcat (`tomcat/context.xml`); el código de la aplicación no contiene credenciales.
- Las contraseñas son **secretos de Docker** generados en local (`scripts/init-secrets.sh`, ignorados por Git). Tomcat recibe la suya como variable de entorno solo para su proceso: no aparece en el repositorio, en los logs ni en la línea de comandos.
- La aplicación se conecta con un usuario de **mínimo privilegio** (`app`): solo puede conectarse y leer la tabla que se le concede. No puede crear ni borrar tablas, ni leer catálogos de contraseñas, ni conectarse a otras bases de datos.
- PostgreSQL corre sin root, con sistema de ficheros de solo lectura y sin capacidades de Linux; solo está en la red interna.

**Contenedores y red**
- Sistema de ficheros de solo lectura, con `tmpfs` solo donde hace falta escribir.
- Sin capacidades de Linux (`cap_drop: ALL`), `no-new-privileges` y límites de memoria.
- Tomcat solo está en una red interna, sin salida a Internet y sin puertos publicados.
- Ninguna clave privada en las imágenes: el certificado se genera al arrancar Nginx.

## Ejecutar en local

```bash
cd stack-tomcat
bash scripts/init-secrets.sh    # crea las contraseñas en ./secrets (solo la primera vez)
docker compose up -d --build
bash tests/smoke.sh             # pruebas de humo
```

Abre `https://localhost:8443` (el navegador avisará del certificado autofirmado). Para pararlo:

```bash
docker compose down        # conserva los datos de la base de datos
docker compose down -v     # además, borra el volumen de datos
```

Si cambias las contraseñas de `secrets/` después de haber arrancado una vez, borra el volumen (`docker compose down -v`): el usuario `app` solo se crea al inicializar la base de datos por primera vez.

## Pipeline

El workflow `stack-tomcat.yml` se ejecuta en cada cambio de esta carpeta: genera contraseñas aleatorias solo para esa ejecución, construye las imágenes (incluida la compilación con Maven), analiza las tres con Trivy, levanta el stack esperando a que los contenedores estén sanos y ejecuta `tests/smoke.sh`.

Por ahora **no publica** imágenes; eso se añadirá al desplegar en AWS.

## Próximos pasos

- [x] PostgreSQL y un datasource JNDI/JDBC con credenciales como secretos.
- [ ] TLS entre Tomcat y PostgreSQL (hoy la comunicación es en claro dentro de la red interna).
- [ ] Publicar y firmar las imágenes en GHCR.
- [ ] Desplegar el stack en AWS con Terraform.
