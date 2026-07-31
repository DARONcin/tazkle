#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

failure=0

tracked_secrets="$(
  git ls-files \
    | rg '(^|/)(\.env($|\.)|.*\.(pem|p12|key|mobileprovision)$)' \
    | rg -v '(^|/)\.env\.(example|sample|template)$' \
    || true
)"
if [[ -n "$tracked_secrets" ]]; then
  echo "security-baseline: secret-like files are tracked:"
  printf '%s\n' "$tracked_secrets"
  failure=1
fi

secret_files="$(rg -l --hidden \
  --glob '!.git/**' \
  --glob '!.agents/skills/tazkle-security-audit/**' \
  --glob '!design/**' \
  --glob '!*.md' \
  '(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY)' . 2>/dev/null || true)"
if [[ -n "$secret_files" ]]; then
  echo "security-baseline: possible credential patterns found; inspect without printing values:"
  printf '%s\n' "$secret_files"
  failure=1
fi

large_files="$(find . \
  \( -path './.git' -o -path './.build' -o -path './DerivedData' -o -path '*/node_modules' \) -prune \
  -o -type f -size +10M -print)"
if [[ -n "$large_files" ]]; then
  echo "security-baseline: files larger than 10 MB found:"
  printf '%s\n' "$large_files"
  failure=1
fi

dangerous="$(rg -n --hidden \
  --glob '!.git/**' \
  --glob '!.agents/skills/**' \
  --glob '!design/**' \
  --glob '*.{swift,ts,tsx,js,mjs,sql}' \
  '(dangerouslySetInnerHTML|shell[[:space:]]*:[[:space:]]*true|\$queryRawUnsafe|\$executeRawUnsafe|Process\([[:space:]]*\)|/bin/(sh|bash))' . 2>/dev/null || true)"
if [[ -n "$dangerous" ]]; then
  echo "security-baseline: high-risk API usage requires manual review:"
  printf '%s\n' "$dangerous"
fi

if [[ "$failure" -ne 0 ]]; then
  exit 1
fi

echo "security-baseline: passed; targeted threat tests are still required"
