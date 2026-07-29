# Tazkle para macOS

Primer corte ejecutable del núcleo visual y local de Tazkle.

## Dirección acordada

- SwiftUI como base y AppKit cuando el lienzo o la accesibilidad lo requieran.
- SQLite local.
- Keychain para credenciales.
- Ventanas, menús, comandos, sidebar e inspector nativos.
- Teclado, VoiceOver, Reduce Motion y temas del sistema desde el primer prototipo.

## Autenticación durante desarrollo

El cliente implementa Authorization Code con PKCE S256 mediante
`ASWebAuthenticationSession`. La contraseña y el segundo factor permanecen en
el proveedor OIDC; Tazkle conserva el refresh token únicamente en Keychain y
mantiene el access token corto en memoria.

La puerta de entrada solicita el correo como primer paso y lo envía únicamente
al proveedor como `login_hint`. No lo conserva en `UserDefaults`, SQLite ni
Keychain. El proveedor decide si continúa con contraseña, código temporal,
enlace o MFA.

La página alojada por Identity permite correo y contraseña y, cuando existen
credenciales de servidor, acceso con Google o Microsoft. El flujo social
continúa dentro de la misma autorización PKCE; sus client secrets nunca forman
parte de la aplicación macOS. Consulta
[`infrastructure/README.md`](../../infrastructure/README.md) para registrar los
callbacks.

Después del intercambio, el cliente consulta el endpoint OIDC `userinfo`
descubierto por el proveedor. Sólo presenta `sub`, nombre y correo después de
validar longitud, caracteres de control y formato. Si el perfil no está
disponible, la sesión puede continuar sin inventar una identidad visible.

Registra el callback público del cliente nativo como:

```text
app.tazkle.desktop:/oauth/callback
```

El build Debug utiliza de forma predeterminada el proveedor local:

```text
http://127.0.0.1:8787/api/auth
```

Inicia primero la infraestructura y luego la app:

```bash
npm run infra:init
npm run infra:up:detached
swift run Tazkle
```

Para apuntar Debug a otro emisor, configura el proceso antes de ejecutar:

```bash
export TAZKLE_OIDC_ISSUER="https://identity.example.com"
export TAZKLE_OIDC_CLIENT_ID="tazkle-macos"
export TAZKLE_OIDC_RESOURCE="tazkle-local"
swift run Tazkle
```

`TAZKLE_OIDC_RESOURCE` es opcional y debe corresponder con la audiencia que
Gateway valida cuando el proveedor utiliza OAuth Resource Indicators. El
cliente lo incluye tanto al solicitar autorización como al canjear y renovar
tokens. Para una
app distribuida, estos valores públicos se incorporarán al `Info.plist` en el
proceso de build; nunca se incluirá un client secret en el bundle. Los builds
Release continúan exigiendo HTTPS.

Si el proveedor no está disponible, la entrada ofrece un modo local explícito. Ese modo no
representa una identidad autenticada y no habilita colaboración ni
sincronización.

## Estado de los datos del prototipo

- Los proyectos, bloques, relaciones, posiciones del lienzo y el perfil de
  planeación se conservan en SQLite.
- Una instalación nueva crea un lienzo vacío llamado `Proyecto sin nombre`; no
  inserta módulos, tecnologías ni relaciones de demostración.
- La cuenta muestra únicamente identidad validada por OIDC o un estado local
  explícito.
- Organización, miembros, permisos, tarifas y capacidad muestran estados vacíos
  hasta que Project Core los proporcione.
- Los proyectos guardados por versiones anteriores se respetan y no se eliminan
  automáticamente, aunque se hayan creado a partir del escenario inicial.

## Ejecutar durante desarrollo

```bash
swift run Tazkle
```

Para construir un paquete de aplicación identificable por macOS y sus herramientas
de accesibilidad:

```bash
./scripts/build-macos-app.sh
open .build/Tazkle.app
```

El paquete generado es solamente para desarrollo local: todavía no incluye firma
ni notarización.
