import { createHash } from "node:crypto";
import {
  organizationPlanningDefaultsSchema,
  updateOrganizationPlanningDefaultsResponseSchema,
  type InternalActorClaims,
  type OrganizationPlanningDefaults,
  type UpdateOrganizationPlanningDefaultsCommand,
  type UpdateOrganizationPlanningDefaultsResponse,
} from "@tazkle/platform-contracts";
import type { Pool } from "pg";
import { resolveActor, safeRollback } from "./db-helpers.js";
import { ProjectOperationError } from "./errors.js";

export type OrganizationPlanningRepository = {
  get: (
    actor: InternalActorClaims,
    organizationId: string,
  ) => Promise<OrganizationPlanningDefaults>;
  update: (
    actor: InternalActorClaims,
    organizationId: string,
    command: UpdateOrganizationPlanningDefaultsCommand,
    idempotencyKey: string,
  ) => Promise<UpdateOrganizationPlanningDefaultsResponse>;
};

type OrganizationPlanningRow = {
  id: string;
  risk_reserve_percent: number;
  target_margin_percent: number;
  workday_hours: number;
  allow_finance_rate_edits: boolean;
  updated_at: Date | string;
};

export function createPostgresOrganizationPlanningRepository(
  pool: Pool,
): OrganizationPlanningRepository {
  return {
    get: async (actor, organizationId) => {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        await resolveActor(client, actor);

        const authorized = await client.query<{ can_view: boolean }>(
          "SELECT tazkle.can_view_organization_planning_defaults($1) AS can_view",
          [organizationId],
        );
        if (!authorized.rows[0]?.can_view) {
          throw new ProjectOperationError(
            403,
            "ORGANIZATION_PLANNING_FORBIDDEN",
            "No tienes permiso para ver estos valores de costeo interno.",
          );
        }

        const result = await client.query<OrganizationPlanningRow>(
          `SELECT id, risk_reserve_percent, target_margin_percent,
                  workday_hours, allow_finance_rate_edits, updated_at
             FROM tazkle.organizations
            WHERE id = $1`,
          [organizationId],
        );
        await client.query("COMMIT");
        const row = result.rows[0];
        if (!row) {
          throw new ProjectOperationError(
            403,
            "ORGANIZATION_NOT_FOUND",
            "La organización no existe o no tienes acceso a ella.",
          );
        }
        return organizationPlanningDefaultsSchema.parse(defaultsFromRow(row));
      } catch (error) {
        await safeRollback(client);
        throw normalizeDatabaseError(error);
      } finally {
        client.release();
      }
    },

    update: async (actor, organizationId, command, idempotencyKey) => {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        const userId = await resolveActor(client, actor);

        const authorized = await client.query<{ can_manage: boolean }>(
          "SELECT tazkle.can_manage_organization_settings($1) AS can_manage",
          [organizationId],
        );
        if (!authorized.rows[0]?.can_manage) {
          throw new ProjectOperationError(
            403,
            "ORGANIZATION_SETTINGS_FORBIDDEN",
            "Sólo un administrador de la organización puede capturar estos valores.",
          );
        }

        const requestHash = hashUpdateRequest(actor, organizationId, command);
        await client.query(
          "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
          [`${organizationId}:${userId}:${idempotencyKey}`],
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
          [organizationId, userId, idempotencyKey],
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
          const response = updateOrganizationPlanningDefaultsResponseSchema.parse(
            stored.response_body,
          );
          return { ...response, replayed: true };
        }

        const result = await client.query<OrganizationPlanningRow>(
          `UPDATE tazkle.organizations
              SET risk_reserve_percent = $2,
                  target_margin_percent = $3,
                  workday_hours = $4,
                  allow_finance_rate_edits = $5,
                  updated_at = now()
            WHERE id = $1
        RETURNING id, risk_reserve_percent, target_margin_percent,
                  workday_hours, allow_finance_rate_edits, updated_at`,
          [
            organizationId,
            command.riskReservePercent,
            command.targetMarginPercent,
            command.workdayHours,
            command.allowFinanceRateEdits,
          ],
        );

        const row = result.rows[0];
        if (!row) {
          throw new ProjectOperationError(
            403,
            "ORGANIZATION_NOT_FOUND",
            "La organización no existe o no tienes acceso a ella.",
          );
        }

        const response = updateOrganizationPlanningDefaultsResponseSchema.parse({
          defaults: defaultsFromRow(row),
          replayed: false,
        });

        await client.query(
          `INSERT INTO tazkle.idempotency_keys (
             organization_id, actor_user_id, idempotency_key,
             request_hash, response_body
           )
           VALUES ($1, $2, $3, $4, $5::jsonb)`,
          [
            organizationId,
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

function hashUpdateRequest(
  actor: InternalActorClaims,
  organizationId: string,
  command: UpdateOrganizationPlanningDefaultsCommand,
): string {
  return createHash("sha256")
    .update(
      JSON.stringify({
        issuer: actor.identityIssuer,
        subject: actor.subject,
        organizationId,
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
    "ORGANIZATION_STORE_UNAVAILABLE",
    "El almacenamiento de la organización no está disponible.",
  );
}

function defaultsFromRow(row: OrganizationPlanningRow): OrganizationPlanningDefaults {
  const updatedAt =
    row.updated_at instanceof Date
      ? row.updated_at.toISOString()
      : new Date(row.updated_at).toISOString();

  return {
    organizationId: row.id,
    riskReservePercent: row.risk_reserve_percent,
    targetMarginPercent: row.target_margin_percent,
    workdayHours: row.workday_hours,
    allowFinanceRateEdits: row.allow_finance_rate_edits,
    updatedAt,
  };
}
