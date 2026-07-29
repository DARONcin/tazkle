# Automation Service

Trabajos asíncronos, exportaciones, notificaciones y procesos programados. Las operaciones son idempotentes y pasan por Project Core.

- No recibe acceso a PostgreSQL.
- No escribe el dominio directamente.
- La cola permanece sin configurar y se declara como tal hasta implementar
  reintentos, idempotencia y observabilidad.
