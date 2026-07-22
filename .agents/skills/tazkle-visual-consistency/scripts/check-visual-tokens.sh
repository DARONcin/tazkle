#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

paths=()
for path in apps services packages; do
  [[ -d "$path" ]] && paths+=("$path")
done

if [[ ${#paths[@]} -eq 0 ]]; then
  echo "visual-token-check: no product source directories found"
  exit 0
fi

mapfile_name="${TMPDIR:-/tmp}/tazkle-raw-colors.$$"
trap 'rm -f "$mapfile_name"' EXIT

if rg -n --glob '*.swift' --glob '*.ts' --glob '*.tsx' --glob '*.css' \
  --glob '!packages/design-system/**' '#[0-9A-Fa-f]{6}\b' "${paths[@]}" >"$mapfile_name"; then
  echo "visual-token-check: raw hex colors found outside the design-system package"
  sed -n '1,120p' "$mapfile_name"
  exit 1
fi

echo "visual-token-check: passed"
