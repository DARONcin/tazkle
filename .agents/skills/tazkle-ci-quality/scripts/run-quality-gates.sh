#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
skill_root="$root/.agents/skills"
creator="${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-creator/scripts/quick_validate.py"

cd "$root"

git diff --check
python3 "$skill_root/tazkle-ci-quality/scripts/check-markdown-links.py"

if [[ -x "$skill_root/tazkle-security-audit/scripts/security-baseline.sh" ]]; then
  "$skill_root/tazkle-security-audit/scripts/security-baseline.sh"
fi

if [[ -x "$skill_root/tazkle-visual-consistency/scripts/check-visual-tokens.sh" ]]; then
  "$skill_root/tazkle-visual-consistency/scripts/check-visual-tokens.sh"
fi

if [[ -x "$skill_root/tazkle-ux-accessibility/scripts/check-accessibility-contract.sh" ]]; then
  "$skill_root/tazkle-ux-accessibility/scripts/check-accessibility-contract.sh"
fi

if [[ -f "$creator" ]]; then
  for skill in "$skill_root"/*; do
    [[ -d "$skill" ]] || continue
    python3 "$creator" "$skill"
  done
else
  echo "quality-gates: skill validator not found at $creator" >&2
  exit 1
fi

if [[ -f Package.swift ]]; then
  swift test
fi

echo "quality-gates: repository baseline passed"
