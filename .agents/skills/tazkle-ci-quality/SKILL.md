---
name: tazkle-ci-quality
description: Define, run, and evolve Tazkle quality gates for documentation, Swift/macOS code, service code, contracts, database migrations, security controls, design assets, and release readiness. Use when scaffolding projects, adding dependencies, changing build or test commands, creating CI workflows, reviewing pull requests, preparing releases, diagnosing failed checks, or deciding what evidence a change needs before merge.
---

# Tazkle CI and Quality

Make quality evidence proportional to the changed risk while keeping local and CI commands aligned.

## Workflow

1. Read `references/quality-gates.md` completely.
2. Inspect real manifests, tool versions, and changed files. Do not invent commands from planned architecture.
3. Classify the change as documentation, design, macOS, service, contract, database, infrastructure, dependency, or mixed.
4. Select every applicable gate from the matrix; security and accessibility gates are additive.
5. Run the narrowest fast checks first, then builds, tests, integration checks, and release checks.
6. Run `scripts/run-quality-gates.sh` for repository-wide baseline checks.
7. Record exact commands, pass/fail status, skipped checks, and blockers.
8. Keep CI deterministic, least-privileged, secret-free, cancellable, and cache-safe.

## Merge rule

Do not call a change ready when a required check did not run. Mark it pending revalidation with the exact missing environment, dependency, credential, simulator, or external service.

## CI design

- Pin runtime versions and major action versions deliberately.
- Give workflow tokens the minimum permissions required.
- Never expose production secrets to pull requests from forks.
- Separate untrusted build/test jobs from privileged deployment jobs.
- Use concurrency cancellation for superseded pull-request runs.
- Build once and promote verified artifacts between release stages when feasible.
- Require manual approval for production deployment and destructive migrations.

## Output

Summarize the changed surface, applicable gates, commands executed, evidence produced, and remaining risks. Distinguish local verification from CI confirmation.
