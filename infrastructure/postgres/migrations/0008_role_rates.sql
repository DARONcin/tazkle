CREATE TABLE tazkle.role_rates (
    organization_id uuid NOT NULL
        REFERENCES tazkle.organizations(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (
        role IN (
            'organization-admin',
            'project-manager',
            'product',
            'technical-lead',
            'design',
            'development',
            'qa',
            'finance',
            'collaborator',
            'client',
            'observer'
        )
    ),
    hourly_rate_mxn integer NOT NULL CHECK (hourly_rate_mxn BETWEEN 0 AND 100000),
    updated_by uuid NOT NULL REFERENCES tazkle.users(id) ON DELETE RESTRICT,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (organization_id, role)
);

CREATE FUNCTION tazkle.can_manage_role_rates(p_organization_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, tazkle
AS $$
    SELECT EXISTS (
        SELECT 1
          FROM tazkle.memberships AS membership
         WHERE membership.organization_id = p_organization_id
           AND membership.user_id = tazkle.current_user_id()
           AND membership.status = 'active'
           AND membership.role = 'organization-admin'
    )
$$;

ALTER TABLE tazkle.role_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE tazkle.role_rates FORCE ROW LEVEL SECURITY;

CREATE POLICY role_rates_select
    ON tazkle.role_rates
    FOR SELECT
    TO tazkle_app
    USING (tazkle.can_access_organization(organization_id));

CREATE POLICY role_rates_insert
    ON tazkle.role_rates
    FOR INSERT
    TO tazkle_app
    WITH CHECK (
        updated_by = tazkle.current_user_id()
        AND tazkle.can_manage_role_rates(organization_id)
    );

CREATE POLICY role_rates_update
    ON tazkle.role_rates
    FOR UPDATE
    TO tazkle_app
    USING (tazkle.can_manage_role_rates(organization_id))
    WITH CHECK (
        updated_by = tazkle.current_user_id()
        AND tazkle.can_manage_role_rates(organization_id)
    );

REVOKE ALL ON FUNCTION tazkle.can_manage_role_rates(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION tazkle.can_manage_role_rates(uuid) TO tazkle_app;

GRANT SELECT, INSERT, UPDATE ON tazkle.role_rates TO tazkle_app;

INSERT INTO tazkle.platform_metadata (key, value)
VALUES ('schema_version', '4')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = now();

COMMENT ON TABLE tazkle.role_rates IS
    'Tarifa interna MXN/hora por rol y organización, capturada a mano por un administrador. Costo interno, no precio al cliente.';
COMMENT ON FUNCTION tazkle.can_manage_role_rates(uuid) IS
    'Sólo organization-admin captura o modifica tarifas internas; mirroring can_create_project.';
