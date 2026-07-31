import type { InternalActorClaims } from "@tazkle/platform-contracts";
import type { PoolClient } from "pg";
import { ProjectOperationError } from "./errors.js";

/**
 * Resolves a verified OIDC identity to an internal user id and sets it as
 * the transaction actor for row-level security. Shared by every repository
 * so identity resolution never drifts between domains.
 */
export async function resolveActor(
  client: PoolClient,
  actor: InternalActorClaims,
): Promise<string> {
  const result = await client.query<{ user_id: string }>(
    "SELECT tazkle.resolve_actor($1, $2, $3) AS user_id",
    [actor.identityIssuer, actor.subject, actor.displayName ?? null],
  );
  const userId = result.rows[0]?.user_id;
  if (!userId) {
    throw new ProjectOperationError(
      503,
      "IDENTITY_UNAVAILABLE",
      "No fue posible resolver la identidad.",
    );
  }
  return userId;
}

export async function safeRollback(client: PoolClient): Promise<void> {
  try {
    await client.query("ROLLBACK");
  } catch {
    // Preserve the original operation error.
  }
}
