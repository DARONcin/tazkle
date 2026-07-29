#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="${1:-debug}"

case "$configuration" in
  debug|release) ;;
  *)
    echo "Uso: $0 [debug|release]" >&2
    exit 2
    ;;
esac

cd "$root"
"$root/scripts/sync-brand-assets.sh"
swift build -c "$configuration" --product Tazkle

binary_path="$(swift build -c "$configuration" --show-bin-path)"
app_path="$root/.build/Tazkle.app"
contents="$app_path/Contents"
resource_bundle="$binary_path/Tazkle_TazkleApp.bundle"

rm -rf "$app_path"
mkdir -p "$contents/MacOS" "$contents/Resources"
cp "$root/apps/macos/Config/Info.plist" "$contents/Info.plist"
cp "$binary_path/Tazkle" "$contents/MacOS/Tazkle"
cp "$root/apps/macos/Config/Tazkle.icns" "$contents/Resources/Tazkle.icns"

if [[ -d "$resource_bundle" ]]; then
  cp -R "$resource_bundle" "$contents/Resources/Tazkle_TazkleApp.bundle"
  ln -s "Contents/Resources/Tazkle_TazkleApp.bundle" "$app_path/Tazkle_TazkleApp.bundle"
fi

echo "$app_path"
