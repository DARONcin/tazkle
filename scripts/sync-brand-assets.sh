#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
approved="$root/design/approved/brand"
production="$approved/production"
resources="$root/apps/macos/Sources/TazkleApp/Resources"
mode="${1:-sync}"

assets=(
  "tazkle-mark.svg:$production/tazkle-mark.svg"
  "tazkle-mark-mono-dark.svg:$production/tazkle-mark-mono-dark.svg"
  "tazkle-wordmark-light.svg:$production/tazkle-wordmark-light.svg"
  "tazkle-wordmark-dark.svg:$production/tazkle-wordmark-dark.svg"
  "tazki-mascot.svg:$approved/tazki-mascot.svg"
)

mkdir -p "$resources"

for mapping in "${assets[@]}"; do
  destination_name="${mapping%%:*}"
  source_path="${mapping#*:}"
  destination_path="$resources/$destination_name"

  if [[ "$mode" == "--check" ]]; then
    if [[ ! -f "$destination_path" ]] || ! cmp -s "$source_path" "$destination_path"; then
      echo "brand-assets: $destination_name no coincide con el activo aprobado" >&2
      exit 1
    fi
  else
    cp "$source_path" "$destination_path"
  fi
done

if [[ "$mode" == "--check" ]]; then
  echo "brand-assets: synchronized"
else
  echo "brand-assets: updated"
fi
