# Navegación y estructura de interfaz

## Navegación principal

- Resumen.
- Mapa del proyecto.
- Arquitectura.
- Equipo.
- Factibilidad.
- Costos.
- Plan de trabajo.
- Perfil y configuración.

El catálogo de bloques aparece únicamente en Mapa del proyecto y Arquitectura. Las demás áreas usan filtros, resúmenes e inspectores apropiados para reducir saturación.

## Patrón macOS

```text
Sidebar de navegación | Contenido principal | Inspector contextual
```

- La sidebar se puede ocultar.
- El inspector aparece solo cuando existe una selección o tarea que lo requiere.
- Factibilidad, costos y plan de trabajo priorizan resumen antes que detalle.
- Las acciones de toolbar también están disponibles en el menú de macOS.
- Las ventanas se pueden redimensionar sin ocultar acciones críticas.

## Estados obligatorios

- Vacío.
- Cargando.
- Guardado localmente.
- Sincronizando.
- Sin conexión.
- Conflicto.
- Sin permisos.
- Datos insuficientes.
- Error recuperable.
- Resultado pendiente de aprobación.

## Prevención de errores

- Deshacer y rehacer.
- Confirmación para acciones destructivas o difíciles de revertir.
- Advertencias que indiquen causa, impacto y corrección.
- Preservación del contexto al cambiar de perspectiva.
- Comparación antes de aplicar una propuesta de Tazki.
