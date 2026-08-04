import { createHash } from "node:crypto";
import {
  roleRatesListResponseSchema,
  upsertRoleRateResponseSchema,
  type InternalActorClaims,
  type RoleRatesListResponse,
  type UpsertRoleRateCommand,
  type UpsertRoleRateResponse,
} from "@tazkle/platform-contracts";
import type { Pool } from "pg";
import { resolveActor, safeRollback } from "./db-helpers.js";
import { ProjectOperationError } from "./errors.js";

export type RoleRateRepository = {
  list: (actor: InternalActorClaims) => Promise<RoleRatesListResponse>;
  upsert: (
    actor: InternalActorClaims,
    command: UpsertRoleRateCommand,
    idempotencyKey: string,
  ) => Promise<UpsertRoleRateResponse>;
};

type RoleRateRow = {
  organization_id: string;
  role: RoleRatesListResponse["rates"][number]["role"];
  hourly_rate_mxn: number;
  updated_at: Date | string;
};

export function createPostgresRoleRateRepository(pool: Pool): RoleRateRepository {
  return {
    list: async (actor) => {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        await resolveActor(client, actor);
        const result = await client.query<RoleRateRow>(
          `SELECT organization_id, role, hourly_rate_mxn, updated_at
             FROM tazkle.role_rates
            ORDER BY organization_id, role`,
        );
        await client.query("COMMIT");
        return roleRatesListResponseSchema.parse({
          rates: result.rows.map(rateFromRow),
        });
      } catch (error) {
        await safeRollback(client);
        throw normalizeDatabaseError(error);
      } finally {
        client.release();
      }
    },

    upsert: async (actor, command, idempotencyKey) => {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        const userId = await resolveActor(client, actor);

        const authorized = await client.query<{ can_manage: boolean }>(
          "SELECT tazkle.can_manage_role_rates($1) AS can_manage",
          [command.organizationId],
        );
        if (!authorized.rows[0]?.can_manage) {
          throw new ProjectOperationError(
            403,
            "RATE_MANAGEMENT_FORBIDDEN",
            "Sólo un administrador de la organización puede capturar tarifas internas.",
          );
        }

        const requestHash = hashUpsertRequest(actor, command);
        await client.query(
          "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
          [`${command.organizationId}:${userId}:${idempotencyKey}`],
        );
        const replay = await client.query<{
          request_hash: string;
          response_body: unknown;
        }>(
          `SELECT request_hash, response_body
             FROM tazkle.idempotency_keys
            WHERE organization_id = $1
              AND actor_user_id = $2
              AND idempotency_key = $3`,
          [command.organizationId, userId, idempotencyKey],
        );

        const stored = replay.rows[0];
        if (stored) {
          if (stored.request_hash !== requestHash) {
            throw new ProjectOperationError(
              409,
              "IDEMPOTENCY_CONFLICT",
              "La clave de idempotencia ya se utilizó para otra operación.",
            );
          }
          await client.query("COMMIT");
          const response = upsertRoleRateResponseSchema.parse(stored.response_body);
          return { ...response, replayed: true };
        }

        const result = await client.query<RoleRateRow>(
          `INSERT INTO tazkle.role_rates (
             organization_id, role, hourly_rate_mxn, updated_by
           )
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (organization_id, role)
           DO UPDATE SET
             hourly_rate_mxn = EXCLUDED.hourly_rate_mxn,
             updated_by = EXCLUDED.updated_by,
             updated_at = now()
           RETURNING organization_id, role, hourly_rate_mxn, updated_at`,
          [command.organizationId, command.role, command.hourlyRateMXN, userId],
        );

        const row = result.rows[0];
        if (!row) {
          throw new ProjectOperationError(
            503,
            "RATE_STORE_UNAVAILABLE",
            "El almacenamiento de tarifas no está disponible.",
          );
        }

        const response = upsertRoleRateResponseSchema.parse({
          rate: rateFromRow(row),
          replayed: false,
        });

        await client.query(
          `INSERT INTO tazkle.idempotency_keys (
             organization_id, actor_user_id, idempotency_key,
             request_hash, response_body
           )
           VALUES ($1, $2, $3, $4, $5::jsonb)`,
          [
            command.organizationId,
            userId,
            idempotencyKey,
            requestHash,
            JSON.stringify(response),
          ],
        );

        await client.query("COMMIT");
        return response;
      } catch (error) {
        await safeRollback(client);
        throw normalizeDatabaseError(error);
      } finally {
        client.release();
      }
    },
  };
}

function hashUpsertRequest(
  actor: InternalActorClaims,
  command: UpsertRoleRateCommand,
): string {
  return createHash("sha256")
    .update(
      JSON.stringify({
        issuer: actor.identityIssuer,
        subject: actor.subject,
        command,
      }),
    )
    .digest("hex");
}

function normalizeDatabaseError(error: unknown): Error {
  if (error instanceof ProjectOperationError) {
    return error;
  }
  return new ProjectOperationError(
    503,
    "RATE_STORE_UNAVAILABLE",
    "El almacenamiento de tarifas no está disponible.",
  );
}

function rateFromRow(row: RoleRateRow): RoleRatesListResponse["rates"][number] {
  const updatedAt =
    row.updated_at instanceof Date
      ? row.updated_at.toISOString()
      : new Date(row.updated_at).toISOString();

  return {
    organizationId: row.organization_id,
    role: row.role,
    hourlyRateMXN: row.hourly_rate_mxn,
    updatedAt,
  };
}
