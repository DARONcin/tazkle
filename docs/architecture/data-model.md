# Modelo conceptual de datos

Este esquema fija relaciones y propiedad; no sustituye las migraciones SQL.

```mermaid
erDiagram
    USER ||--o{ MEMBERSHIP : participates
    ORGANIZATION ||--o{ MEMBERSHIP : grants
    ORGANIZATION ||--o{ PROJECT : owns
    USER ||--o{ PROJECT : finally_responsible
    PROJECT ||--o{ PROJECT_VERSION : versions
    PROJECT ||--o{ BLOCK : contains
    BLOCK_TYPE ||--o{ BLOCK : classifies
    BLOCK ||--o{ BLOCK_RELATION : source
    BLOCK ||--o{ BLOCK_RELATION : target
    RELATION_TYPE ||--o{ BLOCK_RELATION : classifies
    PROJECT ||--o{ ASSIGNMENT : allocates
    USER ||--o{ ASSIGNMENT : receives
    BLOCK ||--o{ ASSIGNMENT : scopes
    PROJECT ||--o{ COST_ITEM : estimates
    BLOCK ||--o{ COST_ITEM : attributes
    PROJECT ||--o{ RISK : identifies
    BLOCK ||--o{ RISK : affects
    PROJECT ||--o{ APPROVAL : requires
    USER ||--o{ APPROVAL : decides
    PROJECT_VERSION ||--o{ CHANGE_REQUEST : evolves
    PROJECT ||--o{ ARTIFACT : stores
    PROJECT ||--o{ AUDIT_EVENT : records

    USER {
      uuid id PK
      string display_name
      string status
    }
    ORGANIZATION {
      uuid id PK
      string name
      uuid owner_user_id FK
    }
    MEMBERSHIP {
      uuid id PK
      uuid organization_id FK
      uuid user_id FK
      string role
      string status
    }
    PROJECT {
      uuid id PK
      uuid organization_id FK
      uuid responsible_user_id FK
      string name
      string lifecycle_status
      int row_version
    }
    PROJECT_VERSION {
      uuid id PK
      uuid project_id FK
      int version_number
      string approval_status
      json snapshot
    }
    BLOCK_TYPE {
      uuid id PK
      string family
      string key
      json schema
    }
    BLOCK {
      uuid id PK
      uuid project_id FK
      uuid type_id FK
      uuid parent_block_id FK
      string title
      json properties
      int row_version
    }
    RELATION_TYPE {
      uuid id PK
      string key
      json rules
    }
    BLOCK_RELATION {
      uuid id PK
      uuid source_block_id FK
      uuid target_block_id FK
      uuid relation_type_id FK
      string exception_status
    }
    ASSIGNMENT {
      uuid id PK
      uuid project_id FK
      uuid block_id FK
      uuid user_id FK
      decimal planned_hours
      decimal actual_hours
    }
    COST_ITEM {
      uuid id PK
      uuid project_id FK
      uuid block_id FK
      string category
      decimal internal_cost
      decimal client_price
    }
    RISK {
      uuid id PK
      uuid project_id FK
      uuid block_id FK
      string severity
      string treatment_status
    }
    APPROVAL {
      uuid id PK
      uuid project_id FK
      uuid approver_user_id FK
      string scope
      string decision
    }
    CHANGE_REQUEST {
      uuid id PK
      uuid project_version_id FK
      string status
      json impact
    }
    ARTIFACT {
      uuid id PK
      uuid project_id FK
      string storage_key
      string security_status
    }
    AUDIT_EVENT {
      uuid id PK
      uuid project_id FK
      uuid actor_user_id FK
      string action
      string outcome
    }
```

## Reglas invariantes

- Cada proyecto tiene un solo propietario organizacional.
- Cada proyecto tiene un responsable final.
- Un bloque compartido existe una vez y puede relacionarse con múltiples módulos.
- Las relaciones siempre poseen un tipo explícito.
- Las versiones aprobadas son inmutables; un cambio crea una nueva propuesta.
- Horas planeadas y reales se almacenan por separado.
- Costo interno y precio al cliente se almacenan por separado y tienen permisos distintos.
- Los eventos de auditoría no se editan desde los clientes.
