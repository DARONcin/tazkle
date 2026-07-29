# Tazki Service

Capa de IA para entrevistas, estructuración, análisis y variantes. Las salidas son propuestas validadas; este servicio no autoriza ni escribe directamente el dominio.

- Declara autoridad `proposal-only`.
- No recibe acceso a PostgreSQL.
- Mientras no exista un proveedor configurado, responde con un estado explícito
  de indisponibilidad en vez de simular resultados de IA.
