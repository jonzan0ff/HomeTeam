#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET_DIR="$ROOT_DIR/CapsWidgetApp/Assets.xcassets/AppIcon.appiconset"
SOURCE_IMAGE="${1:-$ROOT_DIR/assets/caps_logo_dark.png}"

if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "Source image not found: $SOURCE_IMAGE"
  echo "Place a square high-res Capitals logo at macos/assets/caps_logo_dark.png"
  echo "Tip: a dark-background-compatible source works best for dock rendering."
  exit 1
fi

mkdir -p "$ICONSET_DIR"

generate_icon() {
  local size="$1"
  local output="$2"
  sips -z "$size" "$size" "$SOURCE_IMAGE" --out "$ICONSET_DIR/$output" >/dev/null
}

generate_icon 16 icon_16x16.png
generate_icon 32 icon_16x16@2x.png
generate_icon 32 icon_32x32.png
generate_icon 64 icon_32x32@2x.png
generate_icon 128 icon_128x128.png
generate_icon 256 icon_128x128@2x.png
generate_icon 256 icon_256x256.png
generate_icon 512 icon_256x256@2x.png
generate_icon 512 icon_512x512.png
generate_icon 1024 icon_512x512@2x.png

echo "Generated AppIcon.appiconset from $SOURCE_IMAGE"
