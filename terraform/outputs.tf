output "https_url" {
  description = "URL HTTPS del servidor (certificado autofirmado)."
  value       = "https://localhost:${var.https_port}"
}

output "health_url" {
  description = "Endpoint de salud (HTTP)."
  value       = "http://localhost:${var.http_port}/healthz"
}
