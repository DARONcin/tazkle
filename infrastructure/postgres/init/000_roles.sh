#!/usr/bin/env sh
set -eu

if [ -n "${TAZKLE_APP_DATABASE_PASSWORD_FILE:-}" ]; then
  TAZKLE_APP_DATABASE_PASSWORD="$(tr -d '\r\n' < "$TAZKLE_APP_DATABASE_PASSWORD_FILE")"
fi
if [ -n "${TAZKLE_IDENTITY_DATABASE_PASSWORD_FILE:-}" ]; then
  TAZKLE_IDENTITY_DATABASE_PASSWORD="$(tr -d '\r\n' < "$TAZKLE_IDENTITY_DATABASE_PASSWORD_FILE")"
fi

if [ -z "${TAZKLE_APP_DATABASE_PASSWORD:-}" ]; then
  echo "TAZKLE_APP_DATABASE_PASSWORD or its file is required" >&2
  exit 1
fi
if [ -z "${TAZKLE_IDENTITY_DATABASE_PASSWORD:-}" ]; then
  echo "TAZKLE_IDENTITY_DATABASE_PASSWORD or its file is required" >&2
  exit 1
fi

psql \
  --set=ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=app_password="$TAZKLE_APP_DATABASE_PASSWORD" \
  --set=identity_password="$TAZKLE_IDENTITY_DATABASE_PASSWORD" <<'SQL'
SELECT format(
  'CREATE ROLE tazkle_app LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION',
  :'app_password'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'tazkle_app'
)
\gexec

ALTER ROLE tazkle_app PASSWORD :'app_password';

SELECT format(
  'CREATE ROLE tazkle_identity LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION',
  :'identity_password'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'tazkle_identity'
)
\gexec

ALTER ROLE tazkle_identity PASSWORD :'identity_password';
SQL
