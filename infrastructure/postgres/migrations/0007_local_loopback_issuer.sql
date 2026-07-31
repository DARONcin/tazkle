-- resolve_actor() and the tazkle.user_identities CHECK constraint both
-- required `issuer LIKE 'https://%'`, unconditionally. Local development
-- intentionally issues OIDC tokens from a plain-HTTP loopback origin
-- (`http://127.0.0.1:8787/api/auth`), gated at the Gateway layer by
-- ALLOW_INSECURE_LOCAL_OIDC and an explicit host allowlist (see
-- services/gateway/src/authentication.ts, oidcConfigurationFromEnvironment).
-- Nothing macOS-side had exercised an actor-resolving Project Core endpoint
-- with the *real* local issuer until now (every prior smoke test used a
-- synthetic https:// issuer), so this table/function-level mismatch was
-- latent: every real local sign-in failed resolve_actor with "invalid
-- verified identity".
--
-- Mirror Gateway's own loopback allowlist here rather than dropping the
-- scheme check outright. Gateway is the only writer of the internal actor
-- assertion Project Core trusts, and it only accepts a loopback issuer when
-- ALLOW_INSECURE_LOCAL_OIDC=true (never in a real deployment), so this stays
-- a defense-in-depth format check, not the actual trust boundary.

DO $$
DECLARE
    v_constraint_name text;
BEGIN
    SELECT conname INTO v_constraint_name
      FROM pg_constraint
     WHERE conrelid = 'tazkle.user_identities'::regclass
       AND contype = 'c'
       AND pg_get_constraintdef(oid) LIKE '%https://%';

    IF v_constraint_name IS NOT NULL THEN
        EXECUTE format(
            'ALTER TABLE tazkle.user_identities DROP CONSTRAINT %I',
            v_constraint_name
        );
    END IF;
END
$$;

ALTER TABLE tazkle.user_identities
    ADD CONSTRAINT user_identities_issuer_format CHECK (
        char_length(issuer) BETWEEN 1 AND 512
        AND issuer !~ '[[:cntrl:]]'
        AND (
            issuer LIKE 'https://%'
            OR issuer LIKE 'http://127.0.0.1%'
            OR issuer LIKE 'http://localhost%'
            OR issuer LIKE 'http://[::1]%'
        )
    );

CREATE OR REPLACE FUNCTION tazkle.resolve_actor(
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
       OR NOT (
           p_issuer LIKE 'https://%'
           OR p_issuer LIKE 'http://127.0.0.1%'
           OR p_issuer LIKE 'http://localhost%'
           OR p_issuer LIKE 'http://[::1]%'
       )
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

COMMENT ON FUNCTION tazkle.resolve_actor(text, text, text) IS
    'Resuelve una identidad OIDC verificada y establece el actor de la transacción. Acepta issuers https:// o el loopback HTTP explícito que usa el desarrollo local.';
