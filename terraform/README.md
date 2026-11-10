# Terraform: despliegue local de la imagen

Despliega en local, con Terraform y el proveedor de Docker, la imagen que publica el pipeline en GHCR. Es la primera fase de infraestructura como código del laboratorio; la siguiente es llevar el mismo despliegue a AWS.

## Requisitos

- Docker en ejecución
- Terraform >= 1.6

## Uso

```bash
cd terraform
terraform init
terraform plan
terraform apply

# Comprobar (-k porque el certificado es autofirmado)
curl -skI https://localhost:8443
curl -s http://localhost:8080/healthz

# Limpiar
terraform destroy
```

Si ya tienes otro contenedor usando los puertos 8080 u 8443, cámbialos con `-var http_port=9080 -var https_port=9443`.

## Qué crea

| Recurso | Descripción |
|---|---|
| `docker_image.nginx` | Descarga la imagen indicada en `var.image` |
| `docker_container.nginx` | Contenedor con sistema de ficheros de solo lectura, `/tmp` en memoria, todas las capacidades de Linux retiradas, `no-new-privileges` y límite de memoria |

## Pipeline

El workflow `terraform.yml` comprueba en cada cambio de esta carpeta: formato (`fmt`), validación (`validate`), análisis de la configuración con Trivy y `plan`.
