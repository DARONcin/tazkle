import type { DependencyStatus } from "@tazkle/platform-contracts";
import { Pool } from "pg";
import type { IdentityConfiguration } from "./config.js";

export type IdentityDatabase = {
  pool: Pool;
  probe: () => Promise<DependencyStatus[]>;
  userExists: (userID: string) => Promise<boolean>;
  close: () => Promise<void>;
};

export function createIdentityDatabase(
  configuration: IdentityConfiguration,
): IdentityDatabase {
  const pool = new Pool({
    ...configuration.database,
    max: 5,
    connectionTimeoutMillis: 2_000,
    idleTimeoutMillis: 10_000,
    allowExitOnIdle: true,
  });

  return {
    pool,
    probe: async () => {
      try {
        await pool.query("SELECT 1 AS healthy");
        return [{ name: "postgres-auth", status: "available" }];
      } catch {
        return [
          {
            name: "postgres-auth",
            status: "unavailable",
            detail: "La base de identidad no respondió.",
          },
        ];
      }
    },
    userExists: async (userID: string) => {
      const result = await pool.query(
        'SELECT 1 FROM auth."user" WHERE "id" = $1 LIMIT 1',
        [userID],
      );
      return result.rowCount === 1;
    },
    close: async () => {
      await pool.end();
    },
  };
}
