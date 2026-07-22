# ADR-0002: cuatro servicios iniciales

- Estado: aceptado
- Fecha: 2026-07-22

## Decisión

Separar API Gateway, Project Core, Tazki y Automation como límites desplegables. Se mantienen en un monorepo durante la etapa inicial.

## Motivo

La separación protege el núcleo de dominio, limita el alcance de la IA y permite escalar trabajos asíncronos sin convertir el sistema en un monolito. El monorepo reduce fricción para cambiar contratos durante la validación.

## Regla

Tazki y Automation no escriben directamente en las tablas de dominio; solicitan operaciones a Project Core.
