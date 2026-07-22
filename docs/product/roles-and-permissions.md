# Roles y permisos

## Roles iniciales

- Administrador de la organización.
- Responsable del proyecto.
- Producto.
- Responsable técnico.
- Diseño.
- Desarrollo.
- QA.
- Finanzas.
- Colaborador.
- Cliente u observador.

Una persona puede tener varios roles. Las vistas no duplican datos: filtran el mismo modelo según responsabilidad y permiso.

## Principios de autorización

- Un proyecto tiene un propietario y un responsable final.
- Los responsables específicos pueden cubrir producto, tecnología y finanzas.
- La aprobación depende de la estructura del proyecto, el tipo de cambio y la responsabilidad asignada.
- El responsable final puede resolver la aprobación cuando la política del proyecto lo permita.
- Las excepciones siempre se documentan.
- Un rol visible en el cliente nunca concede permisos por sí solo; el servidor autoriza cada acción.

## Vistas

| Rol | Perspectiva principal |
|---|---|
| Dirección | Factibilidad, presupuesto, capacidad, riesgos y aprobaciones |
| Producto | Objetivos, módulos, funcionalidades y alcance |
| Tecnología | Arquitectura, integraciones y dependencias |
| Diseño | Flujos, entregables y criterios de aceptación |
| Equipo | Tareas, capacidad, sprints, bloqueos y entregables |
| Finanzas | Tarifas, costos internos, reservas, precio y margen |
| Cliente | Alcance, calendario, precio, cambios y aprobaciones permitidas |

Las vistas iniciales son definidas por rol y no personalizables. Se pueden solicitar perspectivas adicionales sin alterar el modelo fuente.
