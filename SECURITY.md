# Política de seguridad

Tazkle se encuentra en preproducción y todavía no acepta reportes sobre una versión desplegada.

Cuando exista código ejecutable, los problemas de seguridad no deberán publicarse como issues. Se habilitarán los avisos privados de seguridad de GitHub y se documentará un canal de contacto antes del primer release.

## Reglas del repositorio

- No agregar secretos, tokens, cookies, llaves privadas ni archivos `.env`.
- Usar datos ficticios en fixtures, capturas y pruebas.
- Toda entrada externa se considera no confiable.
- Los cambios de autenticación, autorización, cifrado, auditoría o IA requieren revisión específica.
- Una dependencia nueva requiere comprobar licencia, mantenimiento y superficie de riesgo.

Consulta [el modelo de amenazas](docs/security/threat-model.md) y [la seguridad de peticiones](docs/security/request-security.md).
