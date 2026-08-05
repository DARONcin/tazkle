ALTER TABLE tazkle.organizations
    ADD COLUMN allow_finance_rate_edits boolean NOT NULL DEFAULT false;

-- Extends the organization-admin-only gates from 0008/0009 with an
-- explicit, admin-controlled carve-out for the `finance` role. An admin
-- must first flip allow_finance_rate_edits to true (only organization-admin
-- can do that, via the same gate) before finance actually gains anything;
-- finance can subsequently turn it back off (self-limiting only, never
-- self-escalating).
CREATE OR REPLACE FUNCTION tazkle.can_manage_role_rates(p_organization_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, tazkle
AS $$
    SELECT EXISTS (
        SELECT 1
          FROM tazkle.memberships AS membership
          JOIN tazkle.organizations AS organization
            ON organization.id = membership.organization_id
         WHERE membership.organization_id = p_organization_id
           AND membership.user_id = tazkle.current_user_id()
           AND membership.status = 'active'
           AND (
               membership.role = 'organization-admin'
               OR (
                   membership.role = 'finance'
                   AND organization.allow_finance_rate_edits
               )
           )
    )
$$;

CREATE OR REPLACE FUNCTION tazkle.can_manage_organization_settings(p_organization_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, tazkle
AS $$
    SELECT EXISTS (
        SELECT 1
          FROM tazkle.memberships AS membership
          JOIN tazkle.organizations AS organization
            ON organization.id = membership.organization_id
         WHERE membership.organization_id = p_organization_id
           AND membership.user_id = tazkle.current_user_id()
           AND membership.status = 'active'
           AND (
               membership.role = 'organization-admin'
               OR (
                   membership.role = 'finance'
                   AND organization.allow_finance_rate_edits
               )
           )
    )
$$;

GRANT UPDATE (allow_finance_rate_edits) ON tazkle.organizations TO tazkle_app;

INSERT INTO tazkle.platform_metadata (key, value)
VALUES ('schema_version', '6')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = now();

COMMENT ON COLUMN tazkle.organizations.allow_finance_rate_edits IS
    'Cuando es true, miembros con rol finance también pueden capturar tarifas y valores predeterminados de costeo, no sólo organization-admin. Sólo organization-admin puede cambiar este valor.';
