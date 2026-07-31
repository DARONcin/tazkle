# ADR-0008: convención de stack tecnológico por capa

- Estado: propuesto
- Fecha: 2026-07-31

## Contexto

Los servicios de `services/*` convergieron de forma orgánica en el mismo stack
(Node.js 22, TypeScript estricto, Hono, Zod vía `platform-contracts`, `pg`,
`tsx`), documentado como decisión puntual en ADR-0005. El cliente nativo usa
Swift/SwiftUI (ADR-0001). Pero nada impide hoy que un nuevo directorio bajo
`apps/` o `services/` llegue con un stack distinto sin pasar por una ADR.

Ese riesgo ya se materializó: `apps/landing` apareció sin seguimiento en git
(`??` en `git status`), con su propio repositorio `.git` anidado y un stack
generado por una herramienta externa —rastro en `apps/landing/.openai/hosting.json`—
que no comparte nada con el resto del monorepo: Next.js 16, React 19, Drizzle
ORM, Tailwind 4 y Cloudflare Workers (`wrangler`/`vinext`). No reutiliza
`platform-contracts` ni `design-system`, y no está respaldado por ninguna ADR.

## Decisión

Fijar el stack por defecto de cada capa. Un proyecto nuevo dentro del monorepo
lo hereda automáticamente; apartarse de él exige una ADR propia, no una
elección implícita del generador o plantilla que se haya usado para arrancar.

| Capa | Stack por defecto | Fuente |
|---|---|---|
| Servicios HTTP (`services/*`) | Node.js ≥22, TypeScript estricto (`tsconfig.base.json`), Hono, Zod, `pg`, `tsx` | ADR-0005 |
| Persistencia central | PostgreSQL (Neon en producción, Postgres 17 local) | ADR-0003 |
| Sincronización / offline | SQLite local + PowerSync | ADR-0003 |
| Identidad | Better Auth + OIDC, verificación JWKS en Gateway | ADR-0007 |
| Cliente nativo | Swift/SwiftUI, puentes AppKit sólo si el lienzo o accesibilidad lo exige | ADR-0001 |
| IA | Interfaz interna intercambiable; ningún proveedor como dependencia irreversible | ADR-0004 |
| Web (`apps/web`) | Reutiliza `platform-contracts` y tokens de `design-system`; el framework sigue abierto | Pendiente — requiere su propia ADR antes de scaffolding |

## Reglas

- Un servicio nuevo bajo `services/*` hereda Node + TypeScript + Hono + Zod +
  `pg` salvo que una ADR documente por qué se aparta.
- Ninguna plantilla o generador externo (starters, scaffolding de terceros,
  CLIs de proveedores) se integra al monorepo directamente. Se evalúa primero
  contra el stack aprobado; si se justifica una excepción, se documenta en su
  propia ADR antes de mezclar código.
- Toda tecnología nueva (framework, ORM, runtime, servicio gestionado) entra
  a `package.json` o `Package.swift` sólo después de tener ADR, no como
  experimento que luego se vuelve permanente.
- Dependencias fijadas a versión exacta, como ya aplica ADR-0005.
- `CONTRIBUTING.md` referencia esta ADR en su sección de convenciones.

## Caso abierto: apps/landing

Requiere una decisión explícita, no queda resuelto por esta ADR:

1. Adoptar el stack de `apps/landing` y documentarlo en una ADR propia
   (implicaría además normalizar su `.git` anidado dentro del monorepo), o
2. Reescribirlo sobre el stack aprobado para `apps/web`, o
3. Excluirlo del monorepo si es un experimento fuera de alcance.

## Pendiente

- Decidir el framework de `apps/web` (hoy abierto en `packages/contracts/README.md`).
- Resolver el caso `apps/landing`.
- Definir convención compartida de testing y lint entre servicios Node y
  futuras superficies web, si llegan a divergir.
