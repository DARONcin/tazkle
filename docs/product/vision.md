# Visión del producto

## Problema

Los equipos suelen repartir la concepción, arquitectura, costos, tareas y decisiones de un proyecto entre pizarras, documentos y gestores de trabajo. Esa fragmentación dificulta entender cómo una decisión afecta al resto del proyecto y favorece pérdidas de contexto cuando cambia el alcance.

## Propuesta

Tazkle representa el proyecto como registros estructurados que también pueden observarse y manipularse como bloques conectados. Un mismo bloque participa en el mapa, arquitectura, costos, responsables, riesgos y calendario sin duplicarse.

## Propuesta de valor

**Haz que el proyecto encaje.** Tazkle ayuda a convertir ideas vagas en planes viables, trazables, cotizables y comprensibles para distintos roles.

## Usuarios iniciales

- Equipos pequeños que construyen su propio producto.
- Posteriormente, agencias que preparan proyectos para clientes.
- Producto, dirección, arquitectura, diseño, desarrollo, QA y finanzas.
- Personas no técnicas mediante explicaciones y vistas adaptadas al rol.

## Corazón del producto

El lienzo no es un dibujo libre. Es una representación del modelo real del proyecto. Los bloques contienen datos y las conexiones expresan relaciones como `contiene`, `depende de`, `implementa`, `requiere`, `produce`, `valida`, `asigna`, `financia` y `bloquea`.

## Familias iniciales de bloques

1. Estrategia: problema, objetivo, mercado y restricción.
2. Producto: módulo, funcionalidad y criterio de aceptación.
3. Proceso: fase, actividad, tarea, sprint y entregable.
4. Tecnología: sistema, servicio, base de datos, integración e infraestructura.
5. Personas: rol, responsable, capacidad y aprobación.
6. Economía: horas, tarifa, licencia, infraestructura, reserva y precio.
7. Gobierno: riesgo, decisión, dependencia, cambio y evidencia.

Los bloques pueden contener otros bloques y compartir referencias. Una tecnología reutilizada existe una sola vez y muestra todos los módulos afectados.

## Resultado de preproducción

Un expediente aprobado que incluya alcance, arquitectura, módulos, funcionalidades, responsables, costos, calendario, riesgos, resultado del estudio de mercado, tareas y una representación legible por IA en JSON o Markdown.
