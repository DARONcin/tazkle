import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { readSecretValue } from "@tazkle/service-kit";
import { Pool, type PoolClient } from "pg";

const migrationFilePattern = /^\d{4}_[a-z0-9_]+\.sql$/;
const connectionString = process.env.MIGRATION_DATABASE_URL;
const migrationsDirectory = path.resolve(
  process.env.MIGRATIONS_DIRECTORY ??
    "infrastructure/postgres/migrations",
);

if (
  !connectionString &&
  (!process.env.PGHOST ||
    !process.env.PGUSER ||
    !process.env.PGDATABASE)
) {
  throw new Error(
    "MIGRATION_DATABASE_URL or complete PostgreSQL environment is required",
  );
}

const pool = new Pool({
  ...(connectionString ? { connectionString } : {}),
  ...(!connectionString
    ? {
        password: readSecretValue(
          process.env.PGPASSWORD,
          process.env.PGPASSWORD_FILE,
          "Migration database password",
        ),
      }
    : {}),
  max: 1,
  connectionTimeoutMillis: 5_000,
  idleTimeoutMillis: 5_000,
  allowExitOnIdle: true,
});

const client = await pool.connect();
try {
  await client.query("SELECT pg_advisory_lock(781_091, 2)");
  await ensureMigrationTable(client);

  const files = (await readdir(migrationsDirectory))
    .filter((file) => migrationFilePattern.test(file))
    .sort();
  if (files.length === 0) {
    throw new Error("No migration files were found");
  }

  for (const file of files) {
    await applyMigration(client, file);
  }

  console.info(
    JSON.stringify({
      level: "info",
      service: "project-core-migrations",
      event: "migrations_complete",
      count: files.length,
    }),
  );
} catch (error) {
  console.error(
    JSON.stringify({
      level: "error",
      service: "project-core-migrations",
      event: "migration_failed",
      errorType: error instanceof Error ? error.name : "UnknownError",
    }),
  );
  process.exitCode = 1;
} finally {
  try {
    await client.query("SELECT pg_advisory_unlock(781_091, 2)");
  } catch {
    process.exitCode = 1;
  }
  client.release();
  await pool.end();
}

async function ensureMigrationTable(client: PoolClient): Promise<void> {
  await client.query(`
    CREATE SCHEMA IF NOT EXISTS tazkle_migrations;
    CREATE TABLE IF NOT EXISTS tazkle_migrations.applied (
      filename text PRIMARY KEY,
      checksum text NOT NULL CHECK (checksum ~ '^[0-9a-f]{64}$'),
      applied_at timestamptz NOT NULL DEFAULT now()
    )
  `);
}

async function applyMigration(
  client: PoolClient,
  filename: string,
): Promise<void> {
  const sql = await readFile(path.join(migrationsDirectory, filename), "utf8");
  const checksum = createHash("sha256").update(sql).digest("hex");
  const existing = await client.query<{ checksum: string }>(
    `SELECT checksum
       FROM tazkle_migrations.applied
      WHERE filename = $1`,
    [filename],
  );

  if (existing.rows[0]) {
    if (existing.rows[0].checksum !== checksum) {
      throw new Error(`Applied migration checksum changed: ${filename}`);
    }
    return;
  }

  await client.query("BEGIN");
  try {
    await client.query(sql);
    await client.query(
      `INSERT INTO tazkle_migrations.applied (filename, checksum)
       VALUES ($1, $2)`,
      [filename, checksum],
    );
    await client.query("COMMIT");
    console.info(
      JSON.stringify({
        level: "info",
        service: "project-core-migrations",
        event: "migration_applied",
        filename,
        checksum: checksum.slice(0, 12),
      }),
    );
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  }
}
