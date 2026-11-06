# Laboratorio DevSecOps: Nginx securizado con Docker y GitHub Actions

![Pipeline](https://github.com/luissotro/laboratorio-devsecops/actions/workflows/devsecops-final.yml/badge.svg)

Proyecto personal para practicar un flujo DevSecOps completo sobre una imagen Docker de Nginx con HTTPS: construcción con hardening, análisis de seguridad en cada cambio, prueba de arranque y de TLS, publicación en GitHub Container Registry (GHCR) y firma digital de la imagen.

> **Alcance:** es un laboratorio de aprendizaje. El certificado TLS es autofirmado y se genera al arrancar el contenedor; en un entorno real se montaría un certificado emitido por una CA (ver más abajo).

## Qué hace el pipeline

Se ejecuta en cada `push` a `main`/`master` y en cada pull request (workflow en `.github/workflows/`).

| Fase | Herramienta | Qué hace |
|---|---|---|
| 1. Análisis de código | TruffleHog | Busca secretos expuestos (credenciales, tokens) en los cambios del repositorio |
| 2. Construcción | Docker | Build multi-etapa; valida la sintaxis de Nginx (`nginx -t`) antes de empaquetar |
| 3. Análisis de vulnerabilidades | Trivy | Escanea la imagen (sistema operativo y librerías). Es informativo: no bloquea el pipeline |
| 4. Prueba de arranque | curl | Levanta el contenedor y comprueba el endpoint de salud, la redirección HTTP→HTTPS, la respuesta `200` por HTTPS y las cabeceras de seguridad (incluida HSTS) |
| 5. Publicación | GHCR | Sube la imagen con dos etiquetas: `latest` y el hash del commit |
| 6. Firma | Cosign | Firma la imagen por digest, sin claves (keyless), con la identidad de GitHub Actions |

La publicación y la firma solo se ejecutan en `push`, nunca en pull requests. Las acciones de terceros críticas (TruffleHog, Trivy) están fijadas por hash de commit.

## Medidas de hardening

**Imagen (`Dockerfile`)**
- Build multi-etapa: la configuración se valida en una etapa previa, con un certificado temporal que no llega a la imagen final.
- Imagen base oficial `nginx:1.30-alpine` y actualización de paquetes (`apk upgrade`) en cada build.
- Eliminación de los bits SUID/SGID del sistema de ficheros.
- Ejecución como usuario no root (`nginx`) y puertos sin privilegios (8080 y 8443).
- Ninguna clave privada dentro de la imagen: el certificado se genera al arrancar.
- `HEALTHCHECK` que comprueba cada 30 s que Nginx responde.
- `.dockerignore` para no incluir ficheros innecesarios en el contexto de build.

**Servidor (`nginx.conf`)**
- TLS 1.2 y 1.3 únicamente, con suites de cifrado modernas y sin tickets de sesión.
- HTTP/2 y cabecera `Strict-Transport-Security` (HSTS).
- El puerto 8080 solo redirige a HTTPS y expone `/healthz`.
- `server_tokens off` para no exponer la versión de Nginx.
- PID y directorios temporales en `/tmp`, para poder funcionar sin root.
- Cabeceras de seguridad (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Content-Security-Policy`, `Permissions-Policy`).
- Solo se permiten los métodos `GET` y `HEAD`; se bloquea el acceso a ficheros ocultos.

## Estructura del repositorio

```
.
├── .github/workflows/        # Pipeline de CI/CD
├── docker-entrypoint.d/
│   └── 40-generate-cert.sh   # Genera el certificado autofirmado al arrancar
├── html/                     # Contenido estático (index.html y style.css)
├── .dockerignore
├── Dockerfile
├── nginx.conf
└── README.md
```

## Ejecutar en local

```bash
# Construir
docker build -t nginx-hardened .

# Ejecutar (HTTP en 8080, HTTPS en 8443)
docker run --rm -p 8080:8080 -p 8443:8443 nginx-hardened

# Comprobar (-k porque el certificado es autofirmado)
curl -skI https://localhost:8443
curl -sI http://localhost:8080        # 301 hacia https
```

Debería devolver `200` por HTTPS con las cabeceras de seguridad y sin la versión de Nginx.

## Usar un certificado propio

Si en `/tmp/certs` hay un `server.crt` y un `server.key`, el contenedor los usa en lugar de generar uno:

```bash
docker run --rm -p 8443:8443 \
  -v "$PWD/certs:/tmp/certs:ro" \
  nginx-hardened
```

## Usar la imagen publicada

```bash
docker pull ghcr.io/luissotro/laboratorio-devsecops:latest
```

## Verificar la firma

La imagen se firma con Cosign usando la identidad del workflow, sin claves manuales:

```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/luissotro/laboratorio-devsecops/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/luissotro/laboratorio-devsecops:latest
```

## Decisiones y limitaciones

- **Certificado autofirmado.** Sirve para el laboratorio; los navegadores avisarán de que no es de confianza. En producción se montaría un certificado de una CA (por ejemplo, Let's Encrypt o el de un balanceador).
- **El certificado se genera al arrancar,** no durante el build, para no guardar una clave privada dentro de la imagen.
- **Trivy informativo.** El escaneo muestra los resultados pero no detiene el pipeline; el siguiente paso sería activar el fallo con severidad `CRITICAL`.
- **Escaneo de secretos.** Analiza los cambios de cada push, no el historial completo en cada ejecución.

## Próximos pasos

- [ ] Infraestructura como código: desplegar el contenedor en una instancia EC2 de AWS con Terraform.
- [ ] Hacer que el pipeline falle ante vulnerabilidades críticas.
- [ ] Monitorización básica del contenedor.
