# Seguridad de peticiones

## Recorrido

```mermaid
sequenceDiagram
    autonumber
    participant App as Tazkle
    participant Edge as Cloudflare
    participant Gateway as API Gateway
    participant Core as Project Core
    participant DB as Neon
    participant Audit as Auditoria

    App->>Edge: HTTPS + token + JSON + Idempotency-Key
    Edge->>Edge: Rate limit, tamaño y reglas WAF
    Edge->>Gateway: Petición admitida
    Gateway->>Gateway: Request ID, token y esquema
    Gateway->>Core: Comando tipado + identidad
    Core->>Core: Autorizar objeto, acción y propiedades
    Core->>Core: Regla de negocio y row_version
    Core->>DB: Consulta parametrizada
    DB-->>Core: Resultado
    Core->>Audit: Actor, acción, recurso y resultado
    Core-->>App: JSON mínimo + Request ID
```

## Headers aceptados

| Header | Política |
|---|---|
| `Authorization` | Token de corta duración. Nunca se coloca en URL. |
| `Content-Type` | `application/json` para comandos JSON. |
| `Accept` | `application/json` en la API. |
| `Idempotency-Key` | Requerida para mutaciones críticas y reintentos. |
| `X-Client-Version` | Compatibilidad; no concede permisos. |
| `Origin` | Verificado en la versión web. |

El servidor genera o normaliza el Request ID. Encabezados de rol, organización o permiso enviados por un cliente no constituyen autoridad.

## Respuestas sensibles

```http
Content-Type: application/json; charset=utf-8
Cache-Control: no-store
X-Content-Type-Options: nosniff
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

La versión web añadirá CSP, Referrer-Policy, CORS específico y protección CSRF si la autenticación usa cookies.

## Validación

- Métodos y rutas permitidos.
- Tipo y tamaño de contenido.
- JSON válido y esquema por operación.
- Longitud, formato, rango y enumeraciones.
- Rechazo de propiedades desconocidas.
- Autorización sobre organización, proyecto, bloque y campo.
- Control optimista de versiones.
- Consultas parametrizadas y allowlist para identificadores dinámicos.
- Errores sin stack traces, SQL ni secretos.

## Códigos relevantes

- `400`: petición mal formada.
- `401`: identidad ausente o inválida.
- `403`: acción no autorizada.
- `409`: conflicto o versión desactualizada.
- `413`: contenido excesivo.
- `415`: tipo no soportado.
- `422`: regla de negocio no satisfecha.
- `429`: límite excedido.
