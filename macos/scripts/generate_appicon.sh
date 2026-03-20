#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET_DIR="$ROOT_DIR/HomeTeamApp/Assets.xcassets/AppIcon.appiconset"
DEFAULT_SOURCE="$ROOT_DIR/assets/Logo.png"
if [[ -f "$ROOT_DIR/../Assets/Logo.png" ]]; then
  DEFAULT_SOURCE="$ROOT_DIR/../Assets/Logo.png"
fi
SOURCE_IMAGE="${1:-$DEFAULT_SOURCE}"

if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "Source image not found: $SOURCE_IMAGE"
  echo "Place a square high-res logo at:"
  echo "  - Assets/Logo.png (preferred)"
  echo "  - macos/assets/Logo.png (fallback)"
  echo "Tip: a dark-background-compatible source works best for dock rendering."
  exit 1
fi

mkdir -p "$ICONSET_DIR"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

prepare_source() {
  local input="$1"
  local output="$TMP_DIR/prepared_source.png"
  local width height square trim_percent trim_size

  width="$(sips -g pixelWidth "$input" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$input" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
  if [[ -z "$width" || -z "$height" ]]; then
    cp "$input" "$output"
    echo "$output"
    return
  fi

  if (( width < height )); then
    square="$width"
  else
    square="$height"
  fi

  cp "$input" "$output"
  sips -c "$square" "$square" "$output" --out "$output" >/dev/null

  trim_percent="${BORDER_TRIM_PERCENT:-100}"
  trim_size=$(( square * trim_percent / 100 ))
  if (( trim_size > 0 && trim_size < square )); then
    sips -c "$trim_size" "$trim_size" "$output" --out "$output" >/dev/null
  fi

  echo "$output"
}

PREPARED_SOURCE="$(prepare_source "$SOURCE_IMAGE")"

generate_icon() {
  local size="$1"
  local output="$2"
  sips -z "$size" "$size" "$PREPARED_SOURCE" --out "$ICONSET_DIR/$output" >/dev/null
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
