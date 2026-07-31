import { createHash } from "node:crypto";
import {
  projectGraphResponseSchema,
  type InternalActorClaims,
  type ProjectGraph,
  type ProjectGraphResponse,
  type ReplaceProjectGraphCommand,
} from "@tazkle/platform-contracts";
import type { Pool, PoolClient } from "pg";
import { resolveActor, safeRollback } from "./db-helpers.js";
import { ProjectOperationError } from "./errors.js";

export type GraphRepository = {
  get: (
    actor: InternalActorClaims,
    projectId: string,
  ) => Promise<ProjectGraphResponse>;
  replace: (
    actor: InternalActorClaims,
    projectId: string,
    command: ReplaceProjectGraphCommand,
    idempotencyKey: string,
  ) => Promise<ProjectGraphResponse>;
};

type BlockRow = {
  id: string;
  title: string;
  summary: string;
  family: ProjectGraph["blocks"][number]["family"];
  state: ProjectGraph["blocks"][number]["state"];
  architecture_layer: ProjectGraph["blocks"][number]["architectureLayer"];
  position_x: number;
  position_y: number;
  row_version: number;
};

type RelationRow = {
  id: string;
  source_block_id: string;
  target_block_id: string;
  source_port: ProjectGraph["relations"][number]["sourcePort"];
  target_port: ProjectGraph["relations"][number]["targetPort"];
  type: ProjectGraph["relations"][number]["type"];
  is_critical: boolean;
  row_version: number;
};

export function createPostgresGraphRepository(pool: Pool): GraphRepository {
  return {
    get: async (actor, projectId) => {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        await resolveActor(client, actor);
        const rowVersion = await requireProjectRowVersion(client, projectId);
        const graph = await readGraph(client, projectId);
        await client.query("COMMIT");
        return projectGraphResponseSchema.parse({
          graph,
          rowVersion,
          replayed: false,
        });
      } catch (error) {
        await safeRollback(client);
        throw normalizeDatabaseError(error);
      } finally {
        client.release();
      }
    },

    replace: async (actor, projectId, command, idempotencyKey) => {
      const client = await pool.connect();
      try {
        await client.query("BEGIN ISOLATION LEVEL SERIALIZABLE");
        const userId = await resolveActor(client, actor);
        const organizationId = await requireProjectAccess(
          client,
          projectId,
        );
        const requestHash = hashReplaceGraphRequest(actor, projectId, command);

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
          const response = projectGraphResponseSchema.parse(stored.response_body);
          return { ...response, replayed: true };
        }

        const currentRowVersion = await requireProjectRowVersion(client, projectId);
        if (currentRowVersion !== command.expectedRowVersion) {
          throw new ProjectOperationError(
            409,
            "WRITE_CONFLICT",
            "El proyecto cambió desde la última lectura. Actualiza antes de guardar.",
          );
        }

        await client.query(
          "DELETE FROM tazkle.relations WHERE project_id = $1",
          [projectId],
        );
        await client.query(
          "DELETE FROM tazkle.blocks WHERE project_id = $1",
          [projectId],
        );

        for (const block of command.graph.blocks) {
          await client.query(
            `INSERT INTO tazkle.blocks (
               id, project_id, title, summary, family, state,
               architecture_layer, position_x, position_y, row_version
             )
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
            [
              block.id,
              projectId,
              block.title,
              block.summary,
              block.family,
              block.state,
              block.architectureLayer,
              block.position.x,
              block.position.y,
              block.rowVersion,
            ],
          );
        }

        for (const relation of command.graph.relations) {
          await client.query(
            `INSERT INTO tazkle.relations (
               id, project_id, source_block_id, target_block_id,
               source_port, target_port, type, is_critical, row_version
             )
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
            [
              relation.id,
              projectId,
              relation.sourceId,
              relation.targetId,
              relation.sourcePort,
              relation.targetPort,
              relation.type,
              relation.isCritical,
              relation.rowVersion,
            ],
          );
        }

        const nextRowVersion = currentRowVersion + 1;
        await client.query(
          `UPDATE tazkle.projects
              SET row_version = $2, updated_at = now()
            WHERE id = $1`,
          [projectId, nextRowVersion],
        );

        await client.query(
          `INSERT INTO tazkle_audit.events (
             project_id, organization_id, actor_user_id, action,
             resource_type, resource_id, outcome, request_id
           )
           VALUES ($1, $2, $3, 'project.graph_replaced', 'project', $1, 'success', $4)`,
          [projectId, organizationId, userId, actor.requestId],
        );

        const response = projectGraphResponseSchema.parse({
          graph: command.graph,
          rowVersion: nextRowVersion,
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

async function requireProjectAccess(
  client: PoolClient,
  projectId: string,
): Promise<string> {
  const project = await client.query<{ organization_id: string }>(
    "SELECT organization_id FROM tazkle.projects WHERE id = $1",
    [projectId],
  );
  const organizationId = project.rows[0]?.organization_id;
  if (!organizationId) {
    throw new ProjectOperationError(
      403,
      "PROJECT_NOT_FOUND",
      "El proyecto no existe o no tienes acceso a él.",
    );
  }
  return organizationId;
}

async function requireProjectRowVersion(
  client: PoolClient,
  projectId: string,
): Promise<number> {
  const project = await client.query<{ row_version: number }>(
    "SELECT row_version FROM tazkle.projects WHERE id = $1",
    [projectId],
  );
  const rowVersion = project.rows[0]?.row_version;
  if (rowVersion === undefined) {
    throw new ProjectOperationError(
      403,
      "PROJECT_NOT_FOUND",
      "El proyecto no existe o no tienes acceso a él.",
    );
  }
  return rowVersion;
}

async function readGraph(
  client: PoolClient,
  projectId: string,
): Promise<ProjectGraph> {
  const blocks = await client.query<BlockRow>(
    `SELECT id, title, summary, family, state, architecture_layer,
            position_x, position_y, row_version
       FROM tazkle.blocks
      WHERE project_id = $1
      ORDER BY id`,
    [projectId],
  );
  const relations = await client.query<RelationRow>(
    `SELECT id, source_block_id, target_block_id, source_port,
            target_port, type, is_critical, row_version
       FROM tazkle.relations
      WHERE project_id = $1
      ORDER BY id`,
    [projectId],
  );

  return {
    blocks: blocks.rows.map((row) => ({
      id: row.id,
      title: row.title,
      summary: row.summary,
      family: row.family,
      state: row.state,
      architectureLayer: row.architecture_layer,
      position: { x: row.position_x, y: row.position_y },
      rowVersion: row.row_version,
    })),
    relations: relations.rows.map((row) => ({
      id: row.id,
      sourceId: row.source_block_id,
      targetId: row.target_block_id,
      sourcePort: row.source_port,
      targetPort: row.target_port,
      type: row.type,
      isCritical: row.is_critical,
      rowVersion: row.row_version,
    })),
  };
}

function hashReplaceGraphRequest(
  actor: InternalActorClaims,
  projectId: string,
  command: ReplaceProjectGraphCommand,
): string {
  return createHash("sha256")
    .update(
      JSON.stringify({
        issuer: actor.identityIssuer,
        subject: actor.subject,
        projectId,
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
    "El almacenamiento del grafo no está disponible.",
  );
}
