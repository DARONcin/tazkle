-- `memberships_select_own` (0002) only lets an actor see their own
-- membership row, which is enough to resolve "am I a member" but not to
-- list an organization's team. `tazkle.users` has neither RLS nor a grant
-- for `tazkle_app` at all, by design (ADR-0006: identity-adjacent tables
-- stay ungranted; a narrow SECURITY DEFINER function resolves what's
-- needed). Follow that same pattern here instead of granting the table or
-- widening its RLS, which would also have to reason about resolve_actor's
-- own writes to tazkle.users.
CREATE FUNCTION tazkle.list_organization_memberships()
RETURNS TABLE (
    organization_id uuid,
    user_id uuid,
    display_name text,
    role text,
    status text,
    created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, tazkle
AS $$
    SELECT
        membership.organization_id,
        membership.user_id,
        user_account.display_name,
        membership.role,
        membership.status,
        membership.created_at
      FROM tazkle.memberships AS membership
      JOIN tazkle.users AS user_account ON user_account.id = membership.user_id
     WHERE tazkle.can_access_organization(membership.organization_id)
     ORDER BY membership.organization_id, membership.created_at
$$;

REVOKE ALL ON FUNCTION tazkle.list_organization_memberships() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION tazkle.list_organization_memberships() TO tazkle_app;

COMMENT ON FUNCTION tazkle.list_organization_memberships() IS
    'Lists teammates across every organization the current actor can access. Narrow SECURITY DEFINER reader, mirroring resolve_actor, so tazkle.users stays ungranted to tazkle_app.';
