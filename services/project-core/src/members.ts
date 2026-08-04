import {
  membersListResponseSchema,
  type InternalActorClaims,
  type MembersListResponse,
} from "@tazkle/platform-contracts";
import type { Pool } from "pg";
import { resolveActor, safeRollback } from "./db-helpers.js";
import { ProjectOperationError } from "./errors.js";

export type MemberRepository = {
  list: (actor: InternalActorClaims) => Promise<MembersListResponse>;
};

type MembershipRow = {
  organization_id: string;
  user_id: string;
  display_name: string | null;
  role: MembersListResponse["members"][number]["role"];
  status: MembersListResponse["members"][number]["status"];
  created_at: Date | string;
};

export function createPostgresMemberRepository(pool: Pool): MemberRepository {
  return {
    list: async (actor) => {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        await resolveActor(client, actor);
        const result = await client.query<MembershipRow>(
          "SELECT * FROM tazkle.list_organization_memberships()",
        );
        await client.query("COMMIT");
        return membersListResponseSchema.parse({
          members: result.rows.map(memberFromRow),
        });
      } catch (error) {
        await safeRollback(client);
        throw normalizeDatabaseError(error);
      } finally {
        client.release();
      }
    },
  };
}

function normalizeDatabaseError(error: unknown): Error {
  if (error instanceof ProjectOperationError) {
    return error;
  }
  return new ProjectOperationError(
    503,
    "MEMBER_STORE_UNAVAILABLE",
    "El almacenamiento de miembros no está disponible.",
  );
}

function memberFromRow(
  row: MembershipRow,
): MembersListResponse["members"][number] {
  const createdAt =
    row.created_at instanceof Date
      ? row.created_at.toISOString()
      : new Date(row.created_at).toISOString();

  return {
    organizationId: row.organization_id,
    userId: row.user_id,
    displayName: row.display_name,
    role: row.role,
    status: row.status,
    createdAt,
  };
}
