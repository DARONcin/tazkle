# ADR-0003: Neon, PowerSync y API propia

- Estado: aceptado para prototipo técnico
- Fecha: 2026-07-22

## Decisión

Usar Neon PostgreSQL como base central, SQLite como almacenamiento local y PowerSync como capa de sincronización. Una API propia conserva la autoridad de escritura.

## Validaciones pendientes

- Costos y límites en escenarios de crecimiento.
- Compatibilidad del modelo de autorización con sincronización.
- Resolución de conflictos y migraciones locales.
- Funcionamiento con grandes mapas de bloques.
