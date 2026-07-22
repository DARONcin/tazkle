#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

required=(
  docs/ux/accessibility.md
  docs/ux/keyboard-shortcuts.md
  docs/ux/themes-and-motion.md
)

missing=0
for file in "${required[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "accessibility-contract: missing $file"
    missing=1
  fi
done

if [[ -d apps/macos ]]; then
  drag_files="$(rg -l --glob '*.swift' '\.(draggable|onDrag)\b' apps/macos 2>/dev/null || true)"
  if [[ -n "$drag_files" ]]; then
    echo "accessibility-contract: manually verify non-drag alternatives in:"
    printf '%s\n' "$drag_files"
  fi

  motion_files="$(rg -l --glob '*.swift' '\.(animation|transition)\b' apps/macos 2>/dev/null || true)"
  if [[ -n "$motion_files" ]]; then
    echo "accessibility-contract: manually verify Reduce Motion behavior in:"
    printf '%s\n' "$motion_files"
  fi
fi

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

echo "accessibility-contract: required documentation present; manual checks remain mandatory"
