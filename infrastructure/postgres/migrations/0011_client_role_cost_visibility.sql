-- role_rates_select (0008) and the planning-defaults read path only ever
-- checked can_access_organization, which does not filter by role. Any
-- active member of an organization — including someone with role = 'client'
-- — could read every role's internal hourly rate and the org's risk
-- reserve / target margin. That contradicts the documented invariant that
-- internal cost and client price carry separate permissions, and the
-- macOS "Costos y tarifas" screen already (incorrectly) claimed rates were
-- not visible to the client. This migration makes that true.

CREATE FUNCTION tazkle.can_view_role_rates(p_organization_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, tazkle
AS $$
    SELECT EXISTS (
        SELECT 1
          FROM tazkle.organizations AS organization
         WHERE organization.id = p_organization_id
           AND (
               organization.owner_user_id = tazkle.current_user_id()
               OR EXISTS (
                   SELECT 1
                     FROM tazkle.memberships AS membership
                    WHERE membership.organization_id = organization.id
                      AND membership.user_id = tazkle.current_user_id()
                      AND membership.status = 'active'
                      AND membership.role <> 'client'
               )
           )
    )
$$;

DROP POLICY role_rates_select ON tazkle.role_rates;

CREATE POLICY role_rates_select
    ON tazkle.role_rates
    FOR SELECT
    TO tazkle_app
    USING (tazkle.can_view_role_rates(organization_id));

CREATE FUNCTION tazkle.can_view_organization_planning_defaults(p_organization_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, tazkle
AS $$
    SELECT EXISTS (
        SELECT 1
          FROM tazkle.organizations AS organization
         WHERE organization.id = p_organization_id
           AND (
               organization.owner_user_id = tazkle.current_user_id()
               OR EXISTS (
                   SELECT 1
                     FROM tazkle.memberships AS membership
                    WHERE membership.organization_id = organization.id
                      AND membership.user_id = tazkle.current_user_id()
                      AND membership.status = 'active'
                      AND membership.role <> 'client'
               )
           )
    )
$$;

REVOKE ALL ON FUNCTION tazkle.can_view_role_rates(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION tazkle.can_view_role_rates(uuid) TO tazkle_app;

REVOKE ALL ON FUNCTION tazkle.can_view_organization_planning_defaults(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION tazkle.can_view_organization_planning_defaults(uuid) TO tazkle_app;

INSERT INTO tazkle.platform_metadata (key, value)
VALUES ('schema_version', '7')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = now();

COMMENT ON FUNCTION tazkle.can_view_role_rates(uuid) IS
    'Cualquier miembro activo salvo role = client puede leer tarifas internas; el dueño de la organización siempre puede. Costo interno, no precio al cliente.';
COMMENT ON FUNCTION tazkle.can_view_organization_planning_defaults(uuid) IS
    'Misma restricción que can_view_role_rates, aplicada por Project Core (no por RLS de fila completa) antes de devolver reserva de riesgo y margen objetivo, porque organizations_select cubre toda la fila, no sólo las columnas de costeo.';
