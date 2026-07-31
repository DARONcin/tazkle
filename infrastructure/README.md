# Infraestructura

El primer corte ejecutable reproduce localmente los cuatro servicios de dominio,
el servicio Identity y un PostgreSQL compatible con Neon.

## Inicio local

```bash
npm install
npm run infra:init
npm run infra:up
```

El único puerto HTTP publicado es `127.0.0.1:8787`, correspondiente al Gateway.
Identity, PostgreSQL, Project Core, Tazki y Automation permanecen en redes
internas. Gateway publica las rutas OIDC de Identity sin exponer su puerto.

```bash
curl --fail http://127.0.0.1:8787/health/ready
curl --fail http://127.0.0.1:8787/v1/platform/capabilities
curl --fail http://127.0.0.1:8787/api/auth/.well-known/openid-configuration
```

Los scripts de `npm` crean un enlace temporal con ruta ASCII cuando el
repositorio está en una carpeta con acentos. Esto evita un fallo conocido de la
ruta de compilación de Docker Desktop sin mover el proyecto.

El servicio efímero `migrate` aplica primero las migraciones versionadas y
termina; Project Core sólo inicia si éstas concluyen correctamente.

```bash
npm run test:domain:docker
```

Esta prueba crea datos desechables y comprueba idempotencia y aislamiento entre
organizaciones. Better Auth emite localmente los tokens que Gateway valida.

## Correo y segundo factor

Identity usa Resend para verificar el correo y enviar el segundo factor. Agrega
una clave con permiso exclusivo de envío y un remitente seguro:

```dotenv
TAZKLE_RESEND_API_KEY=re_...
TAZKLE_AUTH_EMAIL_FROM=Tazkle <onboarding@resend.dev>
```

El remitente de desarrollo sólo permite entregar al correo propietario de la
cuenta de Resend. Para otras personas se requiere un dominio verificado y un
remitente de ese dominio.

La clave se convierte en un archivo `0600` y sólo se monta en Identity.
Identity conserva salida HTTPS para Resend, pero no publica su puerto. Gateway
sigue siendo la única entrada HTTP.

El registro exige un OTP de seis dígitos antes de activar la cuenta. Después
presenta ocho códigos de recuperación. Los accesos con contraseña posteriores
exigen otro OTP; la interfaz no marca esta Mac como confiable automáticamente.

La comprobación interactiva requiere un destinatario autorizado y solicita el
OTP directamente en la terminal:

```bash
TAZKLE_SMOKE_EMAIL=tu-correo@example.com npm run test:identity:local
```

No uses una cuenta real compartida en CI. Las pruebas automatizadas sustituyen
el transporte de correo y nunca requieren una clave de Resend.

## Google y Microsoft

Los providers sociales son opcionales y se activan únicamente con un par de
credenciales completo. Agrega los valores a `infrastructure/.env.local`:

```dotenv
TAZKLE_GOOGLE_CLIENT_ID=...
TAZKLE_GOOGLE_CLIENT_SECRET=...
TAZKLE_MICROSOFT_CLIENT_ID=...
TAZKLE_MICROSOFT_CLIENT_SECRET=...
TAZKLE_MICROSOFT_TENANT_ID=common
```

Registra estas URI de redirección en Google Cloud y Microsoft Entra:

```text
http://127.0.0.1:8787/api/auth/callback/google
http://127.0.0.1:8787/api/auth/callback/microsoft
```

Después ejecuta nuevamente `npm run infra:up:detached`. Identity oculta el
botón de cualquier provider incompleto y falla al arrancar si sólo se configuró
una mitad del par. Los client secrets se convierten en archivos `0600` y sólo
se montan en Identity; no llegan al Gateway ni al cliente macOS.

## Límites actuales

- Project Core e Identity reciben credenciales PostgreSQL diferentes. Sus roles
  sólo acceden al esquema de dominio y a `auth`, respectivamente.
- El migrador recibe la cuenta administrativa sólo mientras aplica cambios y
  termina antes de iniciar Project Core.
- Tazki declara autoridad `proposal-only`.
- Automation no escribe el dominio directamente.
- Los contenedores de aplicación se ejecutan sin privilegios, con filesystem de
  sólo lectura y sin publicar puertos internos.
- El PostgreSQL local activa replicación lógica para preparar la evaluación de
  PowerSync, pero PowerSync todavía no se conecta.
- Neon administrado, R2, cola y proveedor de IA requieren configuración externa
  y no se simulan como operativos.
- El envío transaccional está conectado a Resend. La migración y el servicio se
  validan localmente, pero la entrega a una bandeja real requiere una prueba
  manual con un destinatario autorizado.
- Google y Microsoft conservan la verificación que entregue su identidad; ese
  indicador nunca se inventa localmente.

No se almacenan secretos. `infrastructure/.env.local` permanece ignorado.
El script de infraestructura convierte temporalmente las credenciales locales
en archivos `0600` fuera del repositorio. Los contenedores reciben rutas
en `/run/secrets`; sus variables de entorno no contienen las contraseñas ni el
secreto de identidad. Los archivos temporales se retiran con `npm run
infra:down`.

Consulta el [contrato de migraciones](postgres/README.md).
