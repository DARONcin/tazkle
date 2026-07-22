# Auditoría y evidencia

## Eventos mínimos

- Inicio y cierre de sesión relevantes.
- Cambios de rol o permiso.
- Creación y transferencia de organizaciones y proyectos.
- Cambios de alcance, arquitectura, costo o responsables.
- Creación, aprobación y rechazo de versiones.
- Excepciones documentadas.
- Exportaciones y acceso a archivos sensibles.
- Solicitudes a Tazki y aplicación de propuestas.
- Fallos repetidos de validación, autenticación o autorización.

## Contenido de un evento

- Identificador y fecha del evento.
- Actor y contexto de identidad.
- Organización y proyecto.
- Acción y recurso.
- Resultado: permitido, rechazado, conflicto o error.
- Request ID y versión afectada.
- Motivo normalizado, sin contenido sensible innecesario.

## Exclusiones

Nunca registrar tokens, contraseñas, claves, cookies, prompts completos sensibles, documentos completos o respuestas que contengan datos privados. Los valores de costos se auditan por referencia y diferencia autorizada, no mediante copias indiscriminadas.

## Retención

La política exacta de retención se definirá por tipo de organización, sensibilidad y requisitos legales. Debe permitir exportación, investigación y eliminación compatible con las obligaciones de privacidad.
