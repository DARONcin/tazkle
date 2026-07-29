CREATE TABLE tazkle.users (
    id uuid PRIMARY KEY,
    display_name text,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended', 'deleted')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (
        display_name IS NULL
        OR (
            char_length(display_name) BETWEEN 1 AND 120
            AND display_name !~ '[[:cntrl:]]'
        )
    )
);

CREATE TABLE tazkle.user_identities (
    issuer text NOT NULL,
    subject text NOT NULL,
    user_id uuid NOT NULL REFERENCES tazkle.users(id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT now(),
    last_seen_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (issuer, subject),
    UNIQUE (user_id, issuer),
    CHECK (
        char_length(issuer) BETWEEN 1 AND 512
        AND issuer LIKE 'https://%'
        AND issuer !~ '[[:cntrl:]]'
    ),
    CHECK (
        char_length(subject) BETWEEN 1 AND 255
        AND subject !~ '[[:cntrl:]]'
    )
);

CREATE TABLE tazkle.organizations (
    id uuid PRIMARY KEY,
    owner_user_id uuid NOT NULL REFERENCES tazkle.users(id) ON DELETE RESTRICT,
    name text NOT NULL,
    kind text NOT NULL DEFAULT 'team'
        CHECK (kind IN ('personal', 'team')),
    created_at timestamptz NOT NULL DEFAULT now(),
    row_version integer NOT NULL DEFAULT 1 CHECK (row_version > 0),
    CHECK (
        char_length(name) BETWEEN 1 AND 120
        AND name !~ '[[:cntrl:]]'
    )
);

CREATE UNIQUE INDEX organizations_one_personal_space_per_owner
    ON tazkle.organizations (owner_user_id)
    WHERE kind = 'personal';

CREATE TABLE tazkle.memberships (
    id uuid PRIMARY KEY,
    organization_id uuid NOT NULL
        REFERENCES tazkle.organizations(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES tazkle.users(id) ON DELETE RESTRICT,
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
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('invited', 'active', 'suspended', 'revoked')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (organization_id, user_id)
);

CREATE INDEX memberships_user_status
    ON tazkle.memberships (user_id, status, organization_id);

CREATE TABLE tazkle.projects (
    id uuid PRIMARY KEY,
    organization_id uuid NOT NULL
        REFERENCES tazkle.organizations(id) ON DELETE RESTRICT,
    responsible_user_id uuid NOT NULL
        REFERENCES tazkle.users(id) ON DELETE RESTRICT,
    name text NOT NULL,
    template_key text NOT NULL
        CHECK (template_key IN ('web-application', 'blank-canvas')),
    lifecycle_status text NOT NULL DEFAULT 'draft'
        CHECK (lifecycle_status IN ('draft', 'active', 'archived')),
    row_version integer NOT NULL DEFAULT 1 CHECK (row_version > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (
        char_length(name) BETWEEN 1 AND 120
        AND name !~ '[[:cntrl:]]'
    )
);

CREATE INDEX projects_organization_created
    ON tazkle.projects (organization_id, created_at DESC);

CREATE TABLE tazkle.idempotency_keys (
    organization_id uuid NOT NULL
        REFERENCES tazkle.organizations(id) ON DELETE CASCADE,
    actor_user_id uuid NOT NULL REFERENCES tazkle.users(id) ON DELETE RESTRICT,
    idempotency_key text NOT NULL,
    request_hash text NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
    response_body jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (organization_id, actor_user_id, idempotency_key),
    CHECK (
        char_length(idempotency_key) BETWEEN 16 AND 128
        AND idempotency_key ~ '^[A-Za-z0-9._~-]+$'
    )
);

CREATE TABLE tazkle_audit.events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id uuid REFERENCES tazkle.projects(id) ON DELETE RESTRICT,
    organization_id uuid NOT NULL
        REFERENCES tazkle.organizations(id) ON DELETE RESTRICT,
    actor_user_id uuid NOT NULL
        REFERENCES tazkle.users(id) ON DELETE RESTRICT,
    action text NOT NULL,
    resource_type text NOT NULL,
    resource_id uuid,
    outcome text NOT NULL CHECK (outcome IN ('success', 'denied', 'failed')),
    request_id uuid NOT NULL,
    reason_code text,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    CHECK (char_length(action) BETWEEN 1 AND 80),
    CHECK (char_length(resource_type) BETWEEN 1 AND 80),
    CHECK (reason_code IS NULL OR char_length(reason_code) <= 80)
);

CREATE INDEX audit_events_project_time
    ON tazkle_audit.events (project_id, occurred_at DESC);
CREATE INDEX audit_events_organization_time
    ON tazkle_audit.events (organization_id, occurred_at DESC);

CREATE FUNCTION tazkle.current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;

CREATE FUNCTION tazkle.resolve_actor(
    p_issuer text,
    p_subject text,
    p_display_name text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, tazkle
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    IF p_issuer IS NULL
       OR char_length(p_issuer) NOT BETWEEN 1 AND 512
       OR p_issuer NOT LIKE 'https://%'
       OR p_issuer ~ '[[:cntrl:]]'
       OR p_subject IS NULL
       OR char_length(p_subject) NOT BETWEEN 1 AND 255
       OR p_subject ~ '[[:cntrl:]]'
       OR (
           p_display_name IS NOT NULL
           AND (
               char_length(p_display_name) NOT BETWEEN 1 AND 120
               OR p_display_name ~ '[[:cntrl:]]'
           )
       )
    THEN
        RAISE EXCEPTION 'invalid verified identity';
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtextextended(p_issuer || chr(31) || p_subject, 0)
    );

    SELECT user_id
      INTO v_user_id
      FROM tazkle.user_identities
     WHERE issuer = p_issuer
       AND subject = p_subject;

    IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();
        INSERT INTO tazkle.users (id, display_name)
        VALUES (v_user_id, p_display_name);

        INSERT INTO tazkle.user_identities (issuer, subject, user_id)
        VALUES (p_issuer, p_subject, v_user_id);
    ELSE
        UPDATE tazkle.user_identities
           SET last_seen_at = now()
         WHERE issuer = p_issuer
           AND subject = p_subject;

        IF p_display_name IS NOT NULL THEN
            UPDATE tazkle.users
               SET display_name = p_display_name,
                   updated_at = now()
             WHERE id = v_user_id;
        END IF;
    END IF;

    PERFORM set_config('app.user_id', v_user_id::text, true);
    RETURN v_user_id;
END
$$;

CREATE FUNCTION tazkle.can_access_organization(p_organization_id uuid)
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
               )
           )
    )
$$;

CREATE FUNCTION tazkle.can_create_project(p_organization_id uuid)
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
           AND membership.role IN ('organization-admin', 'project-manager')
    )
$$;

CREATE FUNCTION tazkle_audit.prevent_event_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'audit events are immutable';
END
$$;

CREATE TRIGGER audit_events_are_immutable
BEFORE UPDATE OR DELETE ON tazkle_audit.events
FOR EACH ROW EXECUTE FUNCTION tazkle_audit.prevent_event_mutation();

ALTER TABLE tazkle.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tazkle.organizations FORCE ROW LEVEL SECURITY;
ALTER TABLE tazkle.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE tazkle.memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE tazkle.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE tazkle.projects FORCE ROW LEVEL SECURITY;
ALTER TABLE tazkle.idempotency_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE tazkle.idempotency_keys FORCE ROW LEVEL SECURITY;
ALTER TABLE tazkle_audit.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE tazkle_audit.events FORCE ROW LEVEL SECURITY;

CREATE POLICY organizations_select
    ON tazkle.organizations
    FOR SELECT
    TO tazkle_app
    USING (tazkle.can_access_organization(id));

CREATE POLICY organizations_insert_personal
    ON tazkle.organizations
    FOR INSERT
    TO tazkle_app
    WITH CHECK (
        owner_user_id = tazkle.current_user_id()
        AND kind = 'personal'
    );

CREATE POLICY memberships_select_own
    ON tazkle.memberships
    FOR SELECT
    TO tazkle_app
    USING (user_id = tazkle.current_user_id());

CREATE POLICY memberships_insert_personal_owner
    ON tazkle.memberships
    FOR INSERT
    TO tazkle_app
    WITH CHECK (
        user_id = tazkle.current_user_id()
        AND role = 'organization-admin'
        AND status = 'active'
        AND EXISTS (
            SELECT 1
              FROM tazkle.organizations AS organization
             WHERE organization.id = organization_id
               AND organization.owner_user_id = tazkle.current_user_id()
               AND organization.kind = 'personal'
        )
    );

CREATE POLICY projects_select
    ON tazkle.projects
    FOR SELECT
    TO tazkle_app
    USING (tazkle.can_access_organization(organization_id));

CREATE POLICY projects_insert
    ON tazkle.projects
    FOR INSERT
    TO tazkle_app
    WITH CHECK (
        responsible_user_id = tazkle.current_user_id()
        AND tazkle.can_create_project(organization_id)
    );

CREATE POLICY idempotency_select_own
    ON tazkle.idempotency_keys
    FOR SELECT
    TO tazkle_app
    USING (
        actor_user_id = tazkle.current_user_id()
        AND tazkle.can_access_organization(organization_id)
    );

CREATE POLICY idempotency_insert_own
    ON tazkle.idempotency_keys
    FOR INSERT
    TO tazkle_app
    WITH CHECK (
        actor_user_id = tazkle.current_user_id()
        AND tazkle.can_access_organization(organization_id)
    );

CREATE POLICY audit_insert_actor
    ON tazkle_audit.events
    FOR INSERT
    TO tazkle_app
    WITH CHECK (
        actor_user_id = tazkle.current_user_id()
        AND tazkle.can_access_organization(organization_id)
    );

REVOKE ALL ON SCHEMA tazkle FROM PUBLIC;
REVOKE ALL ON SCHEMA tazkle_audit FROM PUBLIC;
GRANT USAGE ON SCHEMA tazkle TO tazkle_app;
GRANT USAGE ON SCHEMA tazkle_audit TO tazkle_app;

REVOKE ALL ON FUNCTION tazkle.resolve_actor(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION tazkle.resolve_actor(text, text, text) TO tazkle_app;
GRANT EXECUTE ON FUNCTION tazkle.current_user_id() TO tazkle_app;
GRANT EXECUTE ON FUNCTION tazkle.can_access_organization(uuid) TO tazkle_app;
GRANT EXECUTE ON FUNCTION tazkle.can_create_project(uuid) TO tazkle_app;

GRANT SELECT, INSERT ON tazkle.organizations TO tazkle_app;
GRANT SELECT, INSERT ON tazkle.memberships TO tazkle_app;
GRANT SELECT, INSERT ON tazkle.projects TO tazkle_app;
GRANT SELECT, INSERT ON tazkle.idempotency_keys TO tazkle_app;
GRANT INSERT ON tazkle_audit.events TO tazkle_app;
GRANT USAGE, SELECT ON SEQUENCE tazkle_audit.events_id_seq TO tazkle_app;

INSERT INTO tazkle.platform_metadata (key, value)
VALUES ('schema_version', '2')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = now();

COMMENT ON FUNCTION tazkle.resolve_actor(text, text, text) IS
    'Resuelve una identidad OIDC verificada y establece el actor de la transacción.';
COMMENT ON TABLE tazkle.idempotency_keys IS
    'Evita duplicar mutaciones al reintentar una petición autenticada.';
COMMENT ON TABLE tazkle_audit.events IS
    'Eventos minimizados e inmutables; no almacena tokens ni payloads completos.';
