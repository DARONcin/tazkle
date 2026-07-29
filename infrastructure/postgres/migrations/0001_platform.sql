CREATE SCHEMA IF NOT EXISTS tazkle;
CREATE SCHEMA IF NOT EXISTS tazkle_audit;

CREATE TABLE IF NOT EXISTS tazkle.platform_metadata (
    key text PRIMARY KEY,
    value text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO tazkle.platform_metadata (key, value)
VALUES ('schema_version', '1')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = now();

COMMENT ON SCHEMA tazkle IS
    'Estado autorizado por Project Core. No concede acceso directo a clientes o servicios auxiliares.';
COMMENT ON SCHEMA tazkle_audit IS
    'Eventos de auditoría minimizados e inmutables en futuras migraciones.';
