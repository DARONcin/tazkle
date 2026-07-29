# Gateway

Límite de entrada para autenticación, validación superficial, rate limiting, correlación y enrutamiento. No contiene las reglas centrales del proyecto.

- Único servicio HTTP publicado al host.
- Expone `/health/live`, `/health/ready`, `/v1/platform/status` y
  `/v1/platform/capabilities`.
- No recibe credenciales de base de datos ni autoriza escrituras del dominio.
- Verifica access tokens OIDC y sustituye la credencial externa por una aserción
  interna de corta duración.
- Expone `GET /v1/projects` y `POST /v1/projects`.
