# Security contract

## Architecture invariants

- All external traffic enters through the Gateway.
- Project Core authorizes and owns domain writes.
- Tazki and Automation request operations through Project Core; they do not write domain tables directly.
- PowerSync download rules do not replace write authorization.
- The client never contains provider, database, or service credentials.
- Approved versions are immutable; material changes create a new proposal and approval path.

## Request pipeline

1. Enforce TLS at the edge.
2. Apply route-specific size and rate limits.
3. Validate method, path, content type, and accepted response type.
4. Validate token signature, issuer, audience, expiry, and revocation state.
5. Generate or normalize a trusted request ID.
6. Parse into an operation-specific schema and reject unknown properties.
7. Authorize organization, project, object, action, and sensitive properties.
8. Enforce business invariants, idempotency, and optimistic version checks.
9. Execute parameterized data access with a least-privilege role and RLS as defense in depth.
10. Emit a minimized audit event and generic external error.

## Injection defenses

- Parameterize SQL values; allowlist dynamic identifiers; never concatenate user input into SQL.
- Avoid shell execution. If unavoidable, fix the executable, validate each argument, isolate the process, and apply time and resource limits.
- Treat arbitrary URLs as SSRF risk. Allowlist scheme, host, port, resolved IP ranges, redirects, size, and timeout.
- Render external content as text by default. Sanitize Markdown or HTML and use contextual encoding plus CSP on web.
- Reject CRLF and control characters in headers and log fields.
- Generate storage keys server-side and ignore path segments in original filenames.
- Use per-command DTOs to prevent mass assignment.

## Authentication and authorization

- Store macOS refresh credentials in Keychain.
- Prefer short-lived access tokens and revocable sessions.
- Treat organization and role claims from the client as hints only; resolve effective authorization on the server.
- Test users with multiple roles, multiple projects, revoked membership, and stale offline state.
- Separate internal costs, client price, and project content permissions.

## Files

- Authorize before issuing a short-lived upload URL.
- Enforce expected size, extension, signature, checksum, and ownership.
- Quarantine until malware and content checks complete.
- Serve private files through authorized short-lived downloads.
- Keep original filename as sanitized metadata, not as the storage path.

## External APIs and Tazki

- Keep keys in service secret stores and separate them by environment.
- Minimize and redact context before egress.
- Allowlist provider, model, host, and operation.
- Bound tokens, cost, response size, timeout, redirects, and retries.
- Treat provider output as untrusted; parse a strict schema and validate semantics.
- Put no secrets or authorization rules in prompts.
- Give models no direct database authority.
- Require user review for scope, architecture, cost, approval, and external action changes.

## Logging and audit

Log actor, organization, project, action, resource, result, request ID, version, and normalized reason. Do not log tokens, cookies, secrets, complete sensitive prompts, customer documents, or unnecessary cost data.

## References for live verification

Use current primary documentation when a control or library may have changed:

- OWASP REST Security Cheat Sheet.
- OWASP SQL Injection Prevention Cheat Sheet.
- OWASP SSRF Prevention Cheat Sheet.
- OWASP File Upload Cheat Sheet.
- OWASP GenAI Prompt Injection guidance.
- PostgreSQL row security documentation.
- PowerSync authorization and Sync Streams documentation.
- Cloudflare secrets, WAF, and rate-limiting documentation.
