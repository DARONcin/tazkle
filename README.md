# Tazkle

Tazkle es una aplicación de planeación de proyectos de software, macOS first, que convierte una idea en un sistema estructurado de bloques, relaciones, responsables, arquitectura, factibilidad y costos.

La primera entrega busca que un equipo pueda transformar una idea de aplicación web en un proyecto coherente, evaluado y cotizado en menos de dos horas, sin construir manualmente documentos separados.

## Estado

**Preproducción conceptual.** Este repositorio contiene decisiones de producto, arquitectura, seguridad, accesibilidad y el lenguaje visual aprobado. Todavía no contiene una implementación productiva.

## Primer resultado útil

1. Capturar una idea libremente, mediante entrevista o plantilla.
2. Convertirla en bloques estructurados y relaciones explícitas.
3. Evaluar factibilidad técnica, económica, operativa y de mercado.
4. Generar rangos de costo con supuestos y nivel de confianza.
5. Comparar una alternativa generada por Tazki.
6. Obtener aprobación responsable y producir el expediente del proyecto.

## Arquitectura acordada

- Cliente nativo de macOS como primera superficie.
- Versión web posterior para Windows y Linux.
- SQLite local para trabajo offline; Neon PostgreSQL como fuente central.
- PowerSync para sincronización; las escrituras de dominio se autorizan en la API.
- Cuatro servicios iniciales: API Gateway, Project Core, Tazki y Automation.
- R2 para archivos y entregables.
- IA mediante una capa de proveedores; OmniRoute se evaluará como opción, no como dependencia irreversible.

Un monorepo no implica un monolito: cada servicio tendrá límites, contratos y despliegue independiente.

## Documentación

- [Visión del producto](docs/product/vision.md)
- [Alcance de la primera versión](docs/product/scope-v1.md)
- [Arquitectura del sistema](docs/architecture/system-overview.md)
- [Modelo conceptual de datos](docs/architecture/data-model.md)
- [Seguridad](docs/security/threat-model.md)
- [Accesibilidad](docs/ux/accessibility.md)
- [Atajos de teclado](docs/ux/keyboard-shortcuts.md)
- [Índice visual](design/index.md)

## Skills de proyecto

- `tazkle-visual-consistency`: coherencia visual, temas, densidad, marca y movimiento.
- `tazkle-ux-accessibility`: flujos, teclado, VoiceOver, estados y alternativas al arrastre.
- `tazkle-security-audit`: amenazas, autorización, inyecciones, APIs, IA y auditoría.
- `tazkle-ci-quality`: puertas de calidad, evidencia, CI y preparación de releases.

Las skills viven en `.agents/skills` y forman parte de las reglas versionadas del proyecto. Su puerta local conjunta es:

```bash
.agents/skills/tazkle-ci-quality/scripts/run-quality-gates.sh
```

## Estructura futura

```text
apps/           Superficies macOS y web
services/       Gateway, núcleo de proyecto, IA y automatización
packages/       Contratos, design system y controles compartidos
infrastructure/ Infraestructura como código y configuración de ambientes
docs/           Fuente de verdad de producto y arquitectura
design/         Recursos visuales aprobados
```

## Principios

- Un único modelo de proyecto y varias vistas por rol.
- Ningún cambio aprobado se modifica silenciosamente.
- La IA propone; las reglas y las personas autorizan.
- Offline first con estado de sincronización comprensible.
- Accesibilidad, seguridad y auditoría desde el diseño.
- Incertidumbre explícita: rangos, supuestos y confianza, no falsa precisión.
