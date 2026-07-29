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
named_color_file="${TMPDIR:-/tmp}/tazkle-named-colors.$$"
trap 'rm -f "$mapfile_name" "$named_color_file"' EXIT

if rg -n --glob '*.swift' --glob '*.ts' --glob '*.tsx' --glob '*.css' \
  --glob '!packages/design-system/**' '#[0-9A-Fa-f]{6}\b' "${paths[@]}" >"$mapfile_name"; then
  echo "visual-token-check: raw hex colors found outside the design-system package"
  sed -n '1,120p' "$mapfile_name"
  exit 1
fi

if rg -n --glob '*.swift' --glob '!packages/design-system/**' \
  'Color\.(red|orange|yellow|green|blue|purple|pink|cyan|mint|teal|indigo|brown)\b|foregroundStyle\(\.(red|orange|yellow|green|blue|purple|pink|cyan|mint|teal|indigo|brown)\)|\.tint\(\.(red|orange|yellow|green|blue|purple|pink|cyan|mint|teal|indigo|brown)\)' \
  "${paths[@]}" >"$named_color_file"; then
  echo "visual-token-check: named system colors found outside the design-system package"
  sed -n '1,120p' "$named_color_file"
  exit 1
fi

"$root/scripts/sync-brand-assets.sh" --check
python3 "$root/scripts/check-brand-consistency.py"

echo "visual-token-check: passed"
