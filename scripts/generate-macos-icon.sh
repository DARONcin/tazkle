#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_svg="$root/design/approved/brand/production/tazkle-app-icon.svg"
destination="$root/apps/macos/Config/Tazkle.icns"
source_hash="$root/apps/macos/Config/Tazkle.icns.source-sha256"
work="$(mktemp -d "${TMPDIR:-/tmp}/tazkle-icon.XXXXXX")"
trap 'rm -rf "$work"' EXIT

qlmanage -t -s 1024 -o "$work" "$source_svg" >/dev/null
master="$work/$(basename "$source_svg").png"
iconset="$work/Tazkle.iconset"
mkdir -p "$iconset"

render() {
  local pixels="$1"
  local name="$2"
  sips -z "$pixels" "$pixels" "$master" --out "$iconset/$name" >/dev/null
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
cp "$master" "$iconset/icon_512x512@2x.png"

iconutil -c icns "$iconset" -o "$destination"
shasum -a 256 "$source_svg" | awk '{print $1}' > "$source_hash"
echo "macos-icon: generated $destination"
