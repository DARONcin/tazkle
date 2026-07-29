# Quality gates

## Universal gates

- `git diff --check` has no whitespace errors.
- No conflict markers, secrets, prohibited binaries, or oversized files.
- Project-specific skills validate successfully.
- Documentation and ADRs match material behavior changes.
- Changed behavior has tests or an explicit reason why a test is not applicable.
- Accessibility and security evidence is included when the surface requires it.

## Change matrix

| Change | Required evidence |
|---|---|
| Documentation | Markdown structure, relative links, Mermaid review, terminology consistency |
| Approved visual asset | Correct source, readable preview, light/dark context, file-size check |
| Swift/macOS | Format/lint when configured, compile, unit tests, relevant UI/accessibility checks |
| Service | Typecheck, lint, unit tests, authorization tests, build |
| Contract | Schema validation, backward-compatibility review, producer and consumer tests |
| Database | Migration lint, forward migration, rollback or recovery plan, authorization/RLS tests |
| Sync/offline | Local mutation, reconnect, conflict, rejection, idempotency and version tests |
| Tazki/AI | Schema evals, adversarial inputs, provider failure, budget limit, human approval boundary |
| Infrastructure | Validate/plan, least privilege, secret handling, environment separation |
| Dependency | License, maintenance, lockfile, vulnerability scan, bundle or runtime impact |
| Release | Clean build, signed artifact plan, migrations, rollback, release notes, approval |

## Evidence labels

- **Design documented:** intended behavior exists in product or architecture documentation.
- **Implementation observed:** code or configuration exists and was inspected.
- **QA confirmed:** the relevant check ran successfully in the stated environment.
- **Pending revalidation:** a required check could not run; include the blocker.

Never convert a design claim into QA confirmation without execution evidence.

## Pull-request sequence

1. Repository policy and changed-file classification.
2. Secret and dependency safety checks.
3. Formatting, lint, typecheck, and schema validation.
4. Unit tests.
5. Integration and persistence tests.
6. macOS build and targeted accessibility/UI tests.
7. Packaging or deploy preview when applicable.

## Release sequence

1. Freeze the candidate commit.
2. Build in a clean environment.
3. Verify migrations and backward compatibility.
4. Run security, accessibility, offline, and critical-flow regressions.
5. Produce a signed/notarized macOS artifact when distribution begins.
6. Promote the verified artifact with manual production approval.
7. Verify telemetry and rollback readiness after release.
