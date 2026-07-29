import type { DependencyStatus } from "@tazkle/platform-contracts";
import { readSecretValue } from "@tazkle/service-kit";
import { Pool, type PoolConfig } from "pg";
import {
  createPostgresProjectRepository,
  type ProjectRepository,
} from "./projects.js";

export type DatabaseConnection = {
  probe: () => Promise<DependencyStatus[]>;
  close: () => Promise<void>;
  projects: ProjectRepository;
};

export function createDatabaseConnection(
  environment: NodeJS.ProcessEnv = process.env,
): DatabaseConnection {
  const poolConfiguration = databasePoolConfiguration(environment);
  if (!poolConfiguration) {
    const unavailable = async (): Promise<never> => {
      throw new Error("DATABASE_URL is not configured");
    };
    return {
      probe: async () => [
        {
          name: "postgres",
          status: "unavailable",
          detail: "DATABASE_URL no está configurada.",
        },
      ],
      close: async () => {},
      projects: {
        create: unavailable,
        list: unavailable,
      },
    };
  }

  const pool = new Pool({
    ...poolConfiguration,
    max: 5,
    connectionTimeoutMillis: 2_000,
    idleTimeoutMillis: 10_000,
    allowExitOnIdle: true,
  });

  return {
    probe: async () => {
      try {
        await pool.query("SELECT 1 AS healthy");
        return [{ name: "postgres", status: "available" }];
      } catch {
        return [
          {
            name: "postgres",
            status: "unavailable",
            detail: "La base central no respondió.",
          },
        ];
      }
    },
    close: async () => {
      await pool.end();
    },
    projects: createPostgresProjectRepository(pool),
  };
}

function databasePoolConfiguration(
  environment: NodeJS.ProcessEnv,
): PoolConfig | undefined {
  if (environment.DATABASE_URL) {
    return { connectionString: environment.DATABASE_URL };
  }
  if (
    !environment.PGHOST ||
    !environment.PGUSER ||
    !environment.PGDATABASE
  ) {
    return undefined;
  }

  const port = Number(environment.PGPORT ?? "5432");
  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error("PGPORT must be an integer between 1 and 65535");
  }

  return {
    host: environment.PGHOST,
    user: environment.PGUSER,
    password: readSecretValue(
      environment.PGPASSWORD,
      environment.PGPASSWORD_FILE,
      "PostgreSQL password",
    ),
    database: environment.PGDATABASE,
    port,
  };
}
