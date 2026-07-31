import { createHash, randomUUID } from "node:crypto";
import {
  createProjectResponseSchema,
  projectListResponseSchema,
  type CreateProjectCommand,
  type CreateProjectResponse,
  type InternalActorClaims,
  type ProjectSummary,
} from "@tazkle/platform-contracts";
import type { Pool, PoolClient } from "pg";
import { resolveActor, safeRollback } from "./db-helpers.js";
import { ProjectOperationError } from "./errors.js";

export type ProjectRepository = {
  create: (
    actor: InternalActorClaims,
    command: CreateProjectCommand,
    idempotencyKey: string,
  ) => Promise<CreateProjectResponse>;
  list: (actor: InternalActorClaims) => Promise<ProjectSummary[]>;
};

export { ProjectOperationError };

type ProjectRow = {
  id: string;
  organization_id: string;
  responsible_user_id: string;
  name: string;
  template_key: "web-application" | "blank-canvas";
  lifecycle_status: "draft" | "active" | "archived";
  row_version: number;
  created_at: Date | string;
};

export function createPostgresProjectRepository(
  pool: Pool,
): ProjectRepository {
  return {
    create: async (actor, command, idempotencyKey) => {
      const client = await pool.connect();
      try {
        await client.query("BEGIN ISOLATION LEVEL SERIALIZABLE");
        const userId = await resolveActor(client, actor);
        const organizationId = command.organizationId
          ? await requireProjectCreationAccess(
              client,
              command.organizationId,
              userId,
            )
          : await ensurePersonalOrganization(client, userId);
        const requestHash = hashCreateProjectRequest(actor, command);

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
          const response = createProjectResponseSchema.parse(
            stored.response_body,
          );
          return { ...response, replayed: true };
        }

        const projectId = randomUUID();
        const inserted = await client.query<ProjectRow>(
          `INSERT INTO tazkle.projects (
             id,
             organization_id,
             responsible_user_id,
             name,
             template_key
           )
           VALUES ($1, $2, $3, $4, $5)
           RETURNING
             id,
             organization_id,
             responsible_user_id,
             name,
             template_key,
             lifecycle_status,
             row_version,
             created_at`,
          [
            projectId,
            organizationId,
            userId,
            command.name,
            command.templateKey,
          ],
        );

        const project = projectSummaryFromRow(inserted.rows[0]);
        const response = createProjectResponseSchema.parse({
          project,
          replayed: false,
        });

        await client.query(
          `INSERT INTO tazkle_audit.events (
             project_id,
             organization_id,
             actor_user_id,
             action,
             resource_type,
             resource_id,
             outcome,
             request_id
           )
           VALUES ($1, $2, $3, 'project.created', 'project', $1, 'success', $4)`,
          [projectId, organizationId, userId, actor.requestId],
        );

        await client.query(
          `INSERT INTO tazkle.idempotency_keys (
             organization_id,
             actor_user_id,
             idempotency_key,
             request_hash,
             response_body
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

    list: async (actor) => {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        await resolveActor(client, actor);
        const result = await client.query<ProjectRow>(
          `SELECT
             id,
             organization_id,
             responsible_user_id,
             name,
             template_key,
             lifecycle_status,
             row_version,
             created_at
           FROM tazkle.projects
           ORDER BY created_at DESC, id
           LIMIT 500`,
        );
        await client.query("COMMIT");
        return projectListResponseSchema.parse({
          projects: result.rows.map(projectSummaryFromRow),
        }).projects;
      } catch (error) {
        await safeRollback(client);
        throw normalizeDatabaseError(error);
      } finally {
        client.release();
      }
    },
  };
}

async function ensurePersonalOrganization(
  client: PoolClient,
  userId: string,
): Promise<string> {
  const existing = await client.query<{ id: string }>(
    `SELECT id
       FROM tazkle.organizations
      WHERE owner_user_id = $1
        AND kind = 'personal'
      LIMIT 1`,
    [userId],
  );
  if (existing.rows[0]) {
    return existing.rows[0].id;
  }

  const organizationId = randomUUID();
  await client.query(
    `INSERT INTO tazkle.organizations (id, owner_user_id, name, kind)
     VALUES ($1, $2, 'Espacio personal', 'personal')`,
    [organizationId, userId],
  );
  await client.query(
    `INSERT INTO tazkle.memberships (
       id,
       organization_id,
       user_id,
       role,
       status
     )
     VALUES ($1, $2, $3, 'organization-admin', 'active')`,
    [randomUUID(), organizationId, userId],
  );
  return organizationId;
}

async function requireProjectCreationAccess(
  client: PoolClient,
  organizationId: string,
  userId: string,
): Promise<string> {
  const membership = await client.query<{ organization_id: string }>(
    `SELECT organization_id
       FROM tazkle.memberships
      WHERE organization_id = $1
        AND user_id = $2
        AND status = 'active'
        AND role IN ('organization-admin', 'project-manager')
      LIMIT 1`,
    [organizationId, userId],
  );
  if (!membership.rows[0]) {
    throw new ProjectOperationError(
      403,
      "PROJECT_CREATE_FORBIDDEN",
      "No tienes permiso para crear proyectos en esta organización.",
    );
  }
  return membership.rows[0].organization_id;
}

function projectSummaryFromRow(row: ProjectRow | undefined): ProjectSummary {
  if (!row) {
    throw new ProjectOperationError(
      503,
      "DATABASE_RESULT_INVALID",
      "La base central devolvió un resultado inválido.",
    );
  }
  const createdAt =
    row.created_at instanceof Date
      ? row.created_at.toISOString()
      : new Date(row.created_at).toISOString();

  return {
    id: row.id,
    organizationId: row.organization_id,
    responsibleUserId: row.responsible_user_id,
    name: row.name,
    templateKey: row.template_key,
    lifecycleStatus: row.lifecycle_status,
    rowVersion: row.row_version,
    createdAt,
  };
}

function hashCreateProjectRequest(
  actor: InternalActorClaims,
  command: CreateProjectCommand,
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
  if (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    error.code === "40001"
  ) {
    return new ProjectOperationError(
      409,
      "WRITE_CONFLICT",
      "El proyecto cambió durante la operación. Inténtalo nuevamente.",
    );
  }
  return new ProjectOperationError(
    503,
    "PROJECT_STORE_UNAVAILABLE",
    "El almacenamiento de proyectos no está disponible.",
  );
}
