variable "image" {
  description = "Imagen a desplegar (la que publica el pipeline en GHCR)."
  type        = string
  default     = "ghcr.io/luissotro/laboratorio-devsecops:latest"
}

variable "container_name" {
  description = "Nombre del contenedor."
  type        = string
  default     = "nginx-devsecops"
}

variable "http_port" {
  description = "Puerto del host para HTTP (redirige a HTTPS y expone /healthz)."
  type        = number
  default     = 8080
}

variable "https_port" {
  description = "Puerto del host para HTTPS."
  type        = number
  default     = 8443
}
