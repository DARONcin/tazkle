CREATE TABLE tazkle.blocks (
    id uuid PRIMARY KEY,
    project_id uuid NOT NULL REFERENCES tazkle.projects(id) ON DELETE CASCADE,
    title text NOT NULL,
    summary text NOT NULL DEFAULT '',
    family text NOT NULL CHECK (
        family IN (
            'strategy',
            'product',
            'process',
            'technology',
            'people',
            'economy',
            'governance'
        )
    ),
    state text NOT NULL DEFAULT 'draft'
        CHECK (state IN ('draft', 'ready', 'warning', 'approved')),
    architecture_layer text
        CHECK (
            architecture_layer IS NULL
            OR architecture_layer IN ('experience', 'services', 'data', 'infrastructure')
        ),
    position_x double precision NOT NULL,
    position_y double precision NOT NULL,
    row_version integer NOT NULL DEFAULT 1 CHECK (row_version > 0),
    CHECK (
        char_length(title) BETWEEN 1 AND 80
        AND title !~ '[[:cntrl:]]'
    ),
    CHECK (
        char_length(summary) <= 500
        AND summary !~ '[[:cntrl:]]'
    ),
    CHECK (position_x BETWEEN -1e6 AND 1e6),
    CHECK (position_y BETWEEN -1e6 AND 1e6)
);

CREATE INDEX blocks_project ON tazkle.blocks (project_id);

CREATE TABLE tazkle.relations (
    id uuid PRIMARY KEY,
    project_id uuid NOT NULL REFERENCES tazkle.projects(id) ON DELETE CASCADE,
    source_block_id uuid NOT NULL REFERENCES tazkle.blocks(id) ON DELETE CASCADE,
    target_block_id uuid NOT NULL REFERENCES tazkle.blocks(id) ON DELETE CASCADE,
    source_port text NOT NULL DEFAULT 'right'
        CHECK (source_port IN ('top', 'right', 'bottom', 'left')),
    target_port text NOT NULL DEFAULT 'left'
        CHECK (target_port IN ('top', 'right', 'bottom', 'left')),
    type text NOT NULL CHECK (
        type IN (
            'contains',
            'dependsOn',
            'implements',
            'requires',
            'produces',
            'validates',
            'assigns',
            'finances',
            'blocks'
        )
    ),
    is_critical boolean NOT NULL DEFAULT false,
    row_version integer NOT NULL DEFAULT 1 CHECK (row_version > 0),
    CHECK (source_block_id <> target_block_id)
);

CREATE INDEX relations_project ON tazkle.relations (project_id);
CREATE INDEX relations_source ON tazkle.relations (source_block_id);
CREATE INDEX relations_target ON tazkle.relations (target_block_id);
CREATE UNIQUE INDEX relations_unique_semantic
    ON tazkle.relations (project_id, source_block_id, type, target_block_id);

ALTER TABLE tazkle.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tazkle.blocks FORCE ROW LEVEL SECURITY;
ALTER TABLE tazkle.relations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tazkle.relations FORCE ROW LEVEL SECURITY;

CREATE FUNCTION tazkle.can_access_project(p_project_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, tazkle
AS $$
    SELECT EXISTS (
        SELECT 1
          FROM tazkle.projects AS project
         WHERE project.id = p_project_id
           AND tazkle.can_access_organization(project.organization_id)
    )
$$;

CREATE POLICY blocks_select
    ON tazkle.blocks
    FOR SELECT
    TO tazkle_app
    USING (tazkle.can_access_project(project_id));

CREATE POLICY blocks_insert
    ON tazkle.blocks
    FOR INSERT
    TO tazkle_app
    WITH CHECK (tazkle.can_access_project(project_id));

CREATE POLICY blocks_delete
    ON tazkle.blocks
    FOR DELETE
    TO tazkle_app
    USING (tazkle.can_access_project(project_id));

CREATE POLICY relations_select
    ON tazkle.relations
    FOR SELECT
    TO tazkle_app
    USING (tazkle.can_access_project(project_id));

CREATE POLICY relations_insert
    ON tazkle.relations
    FOR INSERT
    TO tazkle_app
    WITH CHECK (tazkle.can_access_project(project_id));

CREATE POLICY relations_delete
    ON tazkle.relations
    FOR DELETE
    TO tazkle_app
    USING (tazkle.can_access_project(project_id));

CREATE POLICY projects_update_graph_replace
    ON tazkle.projects
    FOR UPDATE
    TO tazkle_app
    USING (tazkle.can_access_organization(organization_id))
    WITH CHECK (tazkle.can_access_organization(organization_id));

REVOKE ALL ON FUNCTION tazkle.can_access_project(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION tazkle.can_access_project(uuid) TO tazkle_app;

GRANT SELECT, INSERT, DELETE ON tazkle.blocks TO tazkle_app;
GRANT SELECT, INSERT, DELETE ON tazkle.relations TO tazkle_app;
GRANT UPDATE (row_version, updated_at) ON tazkle.projects TO tazkle_app;

INSERT INTO tazkle.platform_metadata (key, value)
VALUES ('schema_version', '3')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = now();

COMMENT ON TABLE tazkle.blocks IS
    'Bloques del grafo de proyecto. Se reemplazan como conjunto completo por guardado, igual que el SQLite local.';
COMMENT ON TABLE tazkle.relations IS
    'Relaciones tipadas entre bloques del mismo proyecto. Se reemplazan como conjunto completo por guardado.';
