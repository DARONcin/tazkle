# ADR-0005: runtime inicial de servicios

- Estado: aceptado para prototipo técnico
- Fecha: 2026-07-28

## Decisión

Usar Node.js 22, TypeScript, Hono y contratos Zod para el primer corte de API
Gateway, Project Core, Tazki y Automation.

Los cuatro servicios permanecen como workspaces y procesos desplegables
independientes. Comparten contratos y controles HTTP mínimos, pero no comparten
autoridad de dominio.

## Motivo

- Hono conserva una superficie ligera y portable entre Node.js y un futuro
  perímetro compatible con Workers.
- TypeScript y Zod permiten mantener contratos estáticos y validación en runtime.
- Node.js tiene soporte directo y maduro para PostgreSQL, trabajos asíncronos y
  proveedores HTTP.
- Un PostgreSQL 17 local reduce diferencias con Neon sin exigir una cuenta
  remota durante el desarrollo.

## Reglas

- Gateway es la única entrada HTTP publicada.
- Sólo Project Core recibe credenciales de PostgreSQL.
- Tazki y Automation llaman a Project Core para cualquier cambio.
- Las URLs internas proceden de configuración confiable y usan una allowlist
  fija; nunca se toman de parámetros de usuario.
- Dependencias remotas, imágenes y runtimes se fijan a versiones explícitas.

## Pendiente

- Elegir identidad y validar JWKS, revocación y sesiones.
- Diseñar contratos de comandos y eventos versionados.
- Probar Neon con conexión agrupada y migraciones directas separadas.
- Evaluar PowerSync Cloud frente a Open Edition y definir Sync Streams.
- Elegir cola y almacenamiento de objetos.
