# PowerSync

PowerSync no se inicia todavía dentro de `compose.yaml`.

Antes de conectarlo se requieren:

1. Tablas centrales y políticas de autorización estables.
2. Proveedor de identidad y JWKS del Gateway.
3. Usuario de replicación separado y publicación lógica.
4. Sync Streams revisados para organización y proyecto.
5. Endpoint de carga que envíe mutaciones a Project Core.

La aplicación macOS no enviará escrituras directamente a PostgreSQL. El
conector de PowerSync deberá subir su cola al Gateway y Project Core volverá a
autorizar cada objeto, propiedad y versión.

Para la futura instalación se usará una imagen fijada por digest o PowerSync
Cloud. No se añadirá `latest` ni una configuración con secretos al repositorio.
