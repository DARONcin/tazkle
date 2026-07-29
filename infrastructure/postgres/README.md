# PostgreSQL y migraciones

## Roles

- `tazkle_admin`: propietario local y ejecutor de migraciones.
- `tazkle_app`: rol de runtime con privilegios mínimos y RLS obligatorio.

Project Core recibe únicamente las variables `PG*` no sensibles de
`tazkle_app`; la contraseña llega como archivo montado. El servicio efímero
`migrate` monta la credencial administrativa, aplica archivos de `migrations/`
y termina antes de iniciar Project Core. Ninguna contraseña se conserva como
variable del contenedor.

## Contrato de migraciones

- Nombres: `NNNN_descripcion.sql`.
- Orden lexicográfico.
- Una transacción por archivo.
- Exclusión mediante advisory lock.
- Registro en `tazkle_migrations.applied`.
- Un archivo aplicado no se modifica: cambiar su checksum detiene el despliegue.

Para corregir un esquema aplicado se agrega otra migración; no se reescribe la
anterior.

## Recuperación

Las migraciones destructivas no se ejecutarán automáticamente. Antes de una
migración productiva se requiere:

1. respaldo verificado;
2. consulta de impacto y bloqueo;
3. estrategia forward-fix;
4. procedimiento de restauración probado;
5. aprobación manual del ambiente productivo.

En el entorno local, `docker compose down -v` elimina completamente la base. No
debe utilizarse en ambientes que contengan datos que deban conservarse.

## Prueba de aislamiento

Con el entorno levantado:

```bash
npm run test:domain:docker
```

La prueba confirma creación, replay idempotente, listado del propietario,
aislamiento de otro actor y rechazo de una escritura cruzada.
