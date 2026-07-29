# Project Core

Propietario del dominio: proyectos, bloques, relaciones, versiones, factibilidad, costos, capacidad, cambios y aprobaciones.

- Único runtime que recibe las credenciales PostgreSQL de aplicación.
- Declara autoridad `domain` y es el único capaz de escribir el estado central.
- Verifica la identidad interna, resuelve membresías y aplica RLS.
- Implementa creación y listado de proyectos con espacio personal,
  idempotencia y auditoría.
