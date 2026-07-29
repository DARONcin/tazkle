# ADR-0007: Better Auth como proveedor de identidad

- Estado: aceptado para prototipo funcional
- Fecha: 2026-07-29

## Decisión

Tazkle incorpora un quinto servicio acotado, `identity`, construido con Better
Auth 1.6.25 y su proveedor OAuth 2.1. La separación no modifica la autoridad del
dominio: Project Core sigue resolviendo membresías y permisos; Identity sólo
crea cuentas, sesiones y tokens.

Gateway es el único puerto público. Publica por proxy las rutas
`/api/auth/*`, `/sign-in`, `/sign-up` y `/consent`, y nunca permite elegir el
destino interno desde una petición.

## Cliente macOS

El cliente registrado es público y no tiene secreto:

- `client_id`: `tazkle-macos`;
- callback fijo: `app.tazkle.desktop:/oauth/callback`;
- tipo `native`;
- Authorization Code con PKCE S256 obligatorio;
- scopes `openid profile email offline_access`;
- audiencia local `tazkle-local`.

El flujo se abre con `ASWebAuthenticationSession`. `Crear cuenta` añade
`prompt=create`, mientras que `Iniciar sesión` usa la autorización normal.
Nombre, correo y contraseña se escriben una sola vez en la pantalla alojada.
Swift conserva el access token en memoria y el refresh token en Keychain.

## Tokens y claves

- Firma asimétrica ES256 para compatibilidad con el allowlist de Gateway.
- Access token e ID token: 15 minutos.
- Código de autorización: 5 minutos.
- Refresh token: 30 días y revocable.
- Claves JWKS almacenadas en el esquema de identidad, con rotación y gracia de
  30 días.
- El secreto de Better Auth y las contraseñas PostgreSQL se montan como archivos
  y no se incorporan a imágenes, bundles ni repositorio.

## Persistencia y privilegios

La migración `0003_better_auth.sql` fue generada con la CLI oficial de Better
Auth 1.6.25 y se ejecuta dentro del esquema `auth`.

- `tazkle_identity` puede leer y modificar únicamente tablas `auth`.
- `tazkle_app` no recibe privilegios sobre esas tablas.
- El cliente nativo se registra mediante una migración determinista.
- El runtime no puede crear roles, bases ni esquemas.

## Desarrollo local

El emisor local es `http://127.0.0.1:8787/api/auth`. HTTP sólo se admite con
`ALLOW_INSECURE_LOCAL_OIDC=true` y únicamente para hosts allowlisted de
loopback o para el endpoint JWKS interno `identity`. Los builds Release de
macOS siguen exigiendo HTTPS.

## Antes de producción

- Publicar un dominio HTTPS estable y eliminar el modo HTTP local.
- Configurar entrega de correo y exigir verificación antes de crear sesión.
- Decidir recuperación de contraseña, MFA y política de bloqueo.
- Ensayar rotación JWKS, revocación, respaldo y restauración.
- Resolver cualquier advisory de dependencias antes del release.
