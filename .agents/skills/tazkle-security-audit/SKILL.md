---
name: tazkle-security-audit
description: Threat-model, review, and audit Tazkle changes across the macOS client, Gateway, Project Core, Tazki, Automation, Neon, PowerSync, SQLite, R2, and external APIs. Use for authentication, authorization, roles, data models, migrations, headers, requests, file handling, offline sync, secrets, logging, AI tools, dependencies, infrastructure, security reviews, or any change that handles project, client, cost, identity, or architecture data.
---

# Tazkle Security Audit

Apply defense in depth while preserving the architectural rule that clients and auxiliary services never bypass Project Core authority.

## Workflow

1. Read `references/security-contract.md` completely.
2. Read `docs/security/threat-model.md` plus the domain or architecture document affected by the change.
3. Identify assets, actors, trust boundaries, entry points, data classifications, and failure modes.
4. Trace authentication, authorization, validation, persistence, synchronization, logging, and external egress separately.
5. Test object-level and property-level authorization, not only endpoint access.
6. Check injection, replay, concurrency, file, SSRF, secret, privacy, and prompt-injection risks as applicable.
7. Require a deterministic validator and human approval for AI-generated changes with material impact.
8. Run `scripts/security-baseline.sh`; add targeted tests for changed controls.
9. Record residual risks and explicit exceptions. Never describe an unverified control as implemented.

## Severity

- **Critical:** cross-tenant access, secret exposure, arbitrary execution, authorization bypass, destructive unaudited action.
- **High:** material data modification, prompt-to-tool privilege escalation, exploitable injection, insecure file or URL handling.
- **Medium:** incomplete validation, excessive data exposure, missing rate limit, weak recovery or audit evidence.
- **Low:** hardening, diagnostic quality, or defense-in-depth gap without a direct exploit path.

## Output

For each finding provide severity, evidence, attack path, affected asset, current control, required correction, and verification method. Separate design intent, observed implementation, confirmed test evidence, and pending revalidation.
