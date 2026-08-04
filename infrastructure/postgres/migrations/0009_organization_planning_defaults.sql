ALTER TABLE tazkle.organizations
    ADD COLUMN risk_reserve_percent integer NOT NULL DEFAULT 10
        CHECK (risk_reserve_percent BETWEEN 0 AND 100),
    ADD COLUMN target_margin_percent integer NOT NULL DEFAULT 20
        CHECK (target_margin_percent BETWEEN 0 AND 100),
    ADD COLUMN workday_hours integer NOT NULL DEFAULT 8
        CHECK (workday_hours BETWEEN 1 AND 24),
    ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();

CREATE FUNCTION tazkle.can_manage_organization_settings(p_organization_id uuid)
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

CREATE POLICY organizations_update_settings
    ON tazkle.organizations
    FOR UPDATE
    TO tazkle_app
    USING (tazkle.can_manage_organization_settings(id))
    WITH CHECK (tazkle.can_manage_organization_settings(id));

REVOKE ALL ON FUNCTION tazkle.can_manage_organization_settings(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION tazkle.can_manage_organization_settings(uuid) TO tazkle_app;

GRANT UPDATE (
    risk_reserve_percent, target_margin_percent, workday_hours, updated_at
) ON tazkle.organizations TO tazkle_app;

INSERT INTO tazkle.platform_metadata (key, value)
VALUES ('schema_version', '5')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = now();

COMMENT ON COLUMN tazkle.organizations.risk_reserve_percent IS
    'Porcentaje de reserva de riesgo aplicado por defecto a nuevas cotizaciones; capturado a mano por un administrador.';
COMMENT ON COLUMN tazkle.organizations.target_margin_percent IS
    'Margen objetivo por defecto sobre el costo interno; capturado a mano por un administrador.';
COMMENT ON COLUMN tazkle.organizations.workday_hours IS
    'Horas de jornada laboral por defecto usadas para convertir capacidad semanal en horas.';
COMMENT ON FUNCTION tazkle.can_manage_organization_settings(uuid) IS
    'Sólo organization-admin captura los valores predeterminados de costeo; mirroring can_manage_role_rates.';
