# Descarga la imagen publicada por el pipeline.
resource "docker_image" "nginx" {
  name         = var.image
  keep_locally = true
}

# Contenedor con medidas de hardening adicionales a nivel de ejecución.
resource "docker_container" "nginx" {
  name    = var.container_name
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  # Sistema de ficheros de solo lectura; solo /tmp es escribible (PID, temporales y certificado).
  read_only = true

  tmpfs = {
    "/tmp" = "rw,noexec,nosuid,size=16m"
  }

  # Sin capacidades de Linux adicionales ni escalada de privilegios.
  capabilities {
    drop = ["ALL"]
  }
  security_opts = ["no-new-privileges"]

  # Límite de memoria (MB).
  memory = 128

  ports {
    internal = 8080
    external = var.http_port
  }

  ports {
    internal = 8443
    external = var.https_port
  }
}
