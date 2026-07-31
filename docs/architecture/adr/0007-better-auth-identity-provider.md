# ADR-0007: Better Auth como proveedor de identidad

- Estado: aceptado para prototipo funcional
- Fecha: 2026-07-29

## Decisión

Tazkle incorpora un quinto servicio acotado, `identity`, construido con Better
Auth 1.6.25 y su proveedor OAuth 2.1. La separación no modifica la autoridad del
dominio: Project Core sigue resolviendo membresías y permisos; Identity sólo
crea cuentas, sesiones y tokens.

Gateway es el único puerto público. Publica por proxy las rutas
`/api/auth/*`, `/sign-in`, `/sign-up`, `/consent` y los dos scripts de cliente
allowlisted bajo `/identity/client/`; nunca permite elegir el destino interno
desde una petición. Las páginas no incorporan manejadores JavaScript inline:
los cargan desde el mismo origen con `script-src 'self'`, mientras los estilos
conservan un nonce por respuesta.

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
Swift conserva el access token en memoria y el refresh token en Keychain. Junto
con la credencial guarda una copia validada y acotada de `sub`, nombre y correo
para reconocer la misma cuenta cuando el proveedor no está disponible.

No existe acceso anónimo al espacio de trabajo. El modo sin conexión requiere
una sesión previamente validada en esa Mac y abre únicamente el SQLite derivado
de la pareja emisor + `sub` OIDC. El nombre de la carpeta usa SHA-256 del
identificador y no expone correo, emisor ni `sub`. Un refresh token antiguo sin identidad validada no
habilita acceso offline; debe renovarse en línea una vez.

## Ciclo de vida de la cuenta

Cerrar sesión y eliminar la cuenta son operaciones separadas. El cierre revoca
el refresh token cuando Identity está disponible y siempre limpia Keychain. La
eliminación sólo se ofrece con una sesión online: macOS presenta una
confirmación y fuerza una autorización OIDC con `prompt=login`. El cliente
compara la pareja emisor + `sub` reautenticada con el espacio activo antes de
abrir `/account/delete` en `ASWebAuthenticationSession`; la persona debe
escribir `ELIMINAR`. Better Auth exige la cookie de esa sesión reciente,
elimina la identidad y revoca sus sesiones. Una ruta acotada de Identity
comprueba con una consulta parametrizada que el `user.id` autenticado ya no
exista y sólo entonces permite devolver un callback con `state` validado. El
cliente elimina después el SQLite asociado a emisor + `sub`; si la comprobación
falla, preserva los datos locales. Esta limpieza ocurre directamente dentro
del flujo confirmado, antes de abandonar el espacio activo, para que un cambio
de vista no pueda cancelar el borrado. Si la identidad remota ya desapareció
pero el sistema de archivos falla, la puerta de acceso mantiene una acción de
reintento para eliminar la copia local pendiente.

Project Core todavía no sincroniza los proyectos de este corte. Antes de
producción deberá decidir transferencia, exportación, retención y borrado de
proyectos remotos sin eliminar eventos de auditoría obligatorios.

Las cuentas con contraseña siguen un recorrido obligatorio:

1. verificar la propiedad del correo con un OTP de seis dígitos;
2. activar el segundo factor y guardar ocho códigos de recuperación;
3. exigir contraseña y un OTP por correo en los accesos posteriores.

La pantalla solicita explícitamente el OTP después del alta o de detectar un
correo aún no verificado; no depende del envío implícito del alta. Esto evita
afirmar que se envió un código cuando la respuesta opaca de creación corresponde
a una cuenta ya existente. Si la persona demuestra posesión del correo pero la
contraseña no coincide con esa cuenta, la sesión provisional se cierra y el
flujo ofrece volver a iniciar sesión con la contraseña vigente.

Los códigos caducan en cinco minutos, se almacenan con hash, admiten cinco
intentos y no habilitan una sesión hasta completar el desafío. La interfaz
actual no confía dispositivos: solicita el segundo factor en cada acceso con
contraseña. Google y Microsoft conservan el MFA y la verificación que aplique
su propio proveedor.

## Tokens y claves

- Firma asimétrica ES256 para compatibilidad con el allowlist de Gateway.
- Access token e ID token: 15 minutos.
- Solicitud firmada y código de autorización: 10 minutos; continúa siendo
  de un solo uso y queda dentro del máximo recomendado para OAuth.
- Refresh token: 30 días y revocable.
- Claves JWKS almacenadas en el esquema de identidad, con rotación y gracia de
  30 días.
- El secreto de Better Auth y las contraseñas PostgreSQL se montan como archivos
  y no se incorporan a imágenes, bundles ni repositorio.
- La clave de Resend se monta como archivo exclusivamente en Identity. Identity
  es el único servicio con acceso a ella y sólo envía correo, OTP y propósito al
  endpoint HTTPS fijo de Resend.
- Los OTP de verificación y segundo factor tienen seis dígitos, vida de cinco
  minutos y almacenamiento con hash. Los códigos de recuperación permanecen
  cifrados y sólo se muestran al habilitar el segundo factor.

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
- Verificar un dominio de envío propio y dejar `onboarding@resend.dev`.
- Completar recuperación de contraseña y rotación de códigos de recuperación.
- Evaluar passkeys o TOTP como factor resistente a la pérdida del correo.
- Ensayar rotación JWKS, revocación, respaldo y restauración.
- Resolver cualquier advisory de dependencias antes del release.
