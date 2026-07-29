# Alcance de la primera versión

## Objetivo

Validar el recorrido completo de una aplicación web ficticia desde la captura de la idea hasta una evaluación de factibilidad y una cotización aprobable.

## Incluido

- Espacio personal transferible posteriormente a una organización.
- Proyecto con un único propietario y un responsable final.
- Captura combinada: texto libre, entrevista, plantilla o lienzo.
- Plantilla base para aplicaciones web.
- Selector inicial de frontend, lenguaje backend, API, autenticación, base de
  datos e infraestructura.
- Generación de servicios conectados y advertencias de compatibilidad a partir
  de la selección tecnológica.
- Catálogo inicial de bloques sin tipos personalizados.
- Bloques anidados y relaciones tipadas.
- Advertencias para relaciones discutibles y bloqueo solo de contradicciones graves.
- Vistas y permisos por rol.
- Factibilidad asistida por IA en diez dimensiones.
- Rangos, supuestos y nivel de confianza.
- Estimación por horas y tarifas, costos fijos, licencias, infraestructura y reserva.
- Diferenciación entre costo interno y precio al cliente.
- Variante alternativa generada por Tazki.
- Aprobaciones configurables con decisión final del responsable autorizado.
- Historial de cambios y versiones del plan.
- Trabajo local offline con sincronización posterior.
- Expediente, PDF, propuesta comercial, ficha técnica, presupuesto y JSON/Markdown.
- Temas automático, claro, oscuro y mayor contraste.
- Navegación por teclado, VoiceOver y alternativas al arrastre.

## Dimensiones de factibilidad

1. Claridad del problema y objetivos.
2. Alcance y complejidad funcional.
3. Viabilidad técnica.
4. Compatibilidad de tecnologías.
5. Capacidad y experiencia del equipo.
6. Tiempo disponible.
7. Presupuesto.
8. Riesgos y dependencias.
9. Evidencia de necesidad o mercado.
10. Seguridad, privacidad y cumplimiento.

El resultado combina semáforo, evaluación por dimensión y conclusión explicada. No usa un porcentaje que aparente una precisión inexistente.

## Condiciones mínimas para aprobación

- Factibilidad económica aceptable o excepción documentada.
- Roles cubiertos sin sobrecarga no autorizada.
- Arquitectura coherente y riesgos críticos tratados.
- Entregables, criterios de aceptación y responsables definidos.
- Supuestos e incertidumbre visibles.

## Fuera del primer resultado útil

- Integración automática con GitHub.
- Portal completo para clientes.
- Plantillas diferentes de aplicación web.
- Tipos de bloque personalizados.
- IA completamente local.
- Comparación avanzada de versiones.
- Generación de contratos o documentos legales.

La gestión completa de tareas y sprints pertenece al producto futuro; en la primera versión solo se modela lo necesario para estimar capacidad, tiempo y costo.

## Criterio de éxito

Un equipo puede convertir una idea de aplicación web en un proyecto coherente, evaluado y cotizado en menos de dos horas, sin construir manualmente varios documentos separados.

## Corte funcional nativo actual

- El expediente local ya captura problema, objetivo, evidencia de mercado,
  plazo, capacidad, presupuesto, horas, tarifas, servicios, reserva y margen.
- Un motor determinista calcula costo interno, precio propuesto, incertidumbre,
  confianza y las diez dimensiones de factibilidad desde el grafo vigente.
- Los resultados insuficientes generan condiciones o una recomendación de
  replanteamiento; no bloquean la búsqueda de una variante y no aprueban el
  proyecto.
- El perfil se persiste en SQLite por proyecto y continúa disponible sin
  conexión.
- El cliente OIDC de macOS implementa acceso con correo, PKCE, Keychain y lectura
  segura de `userinfo`; falta configurar un proveedor real y confirmar el flujo
  de extremo a extremo.
- Una base local nueva parte de un proyecto vacío. Cuenta, organización y equipo
  no fabrican personas, roles, costos ni capacidad mientras Project Core no
  entregue esos datos.
- Sincronización remota, aprobación y proveedor de IA permanecen fuera de este
  corte.
