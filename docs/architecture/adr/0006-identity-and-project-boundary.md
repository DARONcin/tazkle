# ADR-0006: identidad y primer límite de proyectos

- Estado: aceptado para prototipo técnico
- Fecha: 2026-07-28

## Decisión

Gateway verificará access tokens OIDC firmados mediante una URL JWKS fija. La
configuración exige emisor HTTPS, audiencia explícita, expiración y algoritmos
asimétricos permitidos (`RS256` o `ES256`).

Después de verificar el token, Gateway sustituye la credencial externa por una
aserción interna `HS256`:

- audiencia exclusiva `tazkle-project-core`;
- vida máxima de 30 segundos;
- identificador de petición firmado;
- emisor y sujeto de identidad, sin roles del cliente;
- secreto disponible únicamente para Gateway y Project Core.

Project Core resuelve `(issuer, subject)` a un usuario interno. Las membresías y
los roles efectivos siempre se consultan en PostgreSQL.

## Primer comando

`POST /v1/projects` acepta únicamente:

- `name`;
- `templateKey`;
- `organizationId` opcional.

Sin organización explícita, Project Core crea o reutiliza el espacio personal
del actor y lo establece como responsable final. Para una organización
existente, sólo `organization-admin` y `project-manager` pueden crear.

La mutación requiere `Idempotency-Key`. El resultado y su hash se guardan en la
misma transacción que el proyecto y el evento de auditoría.

## Persistencia y defensa en profundidad

- `tazkle_admin` aplica migraciones y no llega al runtime de Project Core.
- `tazkle_app` no es superusuario, no crea bases ni roles.
- Las contraseñas y el secreto de identidad se montan como archivos; no se
  conservan en la configuración de entorno de los contenedores.
- RLS restringe organizaciones, membresías, proyectos e idempotencia.
- Las tablas de identidad no se conceden al rol de aplicación; una función
  `SECURITY DEFINER` estrecha resuelve el actor verificado.
- Los eventos de auditoría no pueden actualizarse ni eliminarse.
- Las migraciones se aplican en orden, bajo advisory lock y con checksum
  inmutable.

## Pendiente

- Desplegar el proveedor OIDC seleccionado con HTTPS y rotación operativa.
- Definir rotación del secreto interno sin interrupción.
- Añadir revocación de sesiones y rate limiting por identidad.
- Registrar intentos denegados en un canal de seguridad que no permita
  escrituras arbitrarias ni filtraciones entre organizaciones.
- Diseñar migraciones de bloques y relaciones antes de sincronizar con
  PowerSync.

## Cliente macOS implementado

El cliente nativo ya aplica el contrato independiente de proveedor:

- Authorization Code mediante `ASWebAuthenticationSession`;
- PKCE S256, `state` aleatorio y callback fijo
  `app.tazkle.desktop:/oauth/callback`;
- correo validado y enviado sólo como `login_hint`, sin persistencia local;
- descubrimiento OIDC sobre HTTPS con coincidencia exacta de emisor;
- validación de endpoints, límites de respuesta y respuesta Bearer;
- access token únicamente en memoria;
- refresh token no sincronizable en Keychain y accesible sólo con la Mac
  desbloqueada;
- renovación antes de exponer un token a la capa de API;
- cierre local y revocación remota cuando el proveedor publica endpoint;
- estados separados para sesión remota, sin conexión y trabajo sólo local.

La app recopila únicamente el correo como paso inicial; la contraseña se
introduce en la pantalla alojada por Identity, nunca en una vista Swift. El modo local permite
trabajar con SQLite, pero no fabrica identidad, membresía ni autorización
remota. Better Auth implementa actualmente ese contrato; consulta ADR-0007.
