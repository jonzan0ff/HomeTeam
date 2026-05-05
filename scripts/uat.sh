#!/usr/bin/env bash
set -euo pipefail

# Launch the freshly-built Debug build on this Mac for interactive user testing.
# The pre-push hook requires UAT approval for Mac-side code changes; this is
# the build+launch step that precedes that approval.

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# Detect layout: What to Watch uses app/, other Mac apps use macos/.
if [ -f "$PROJECT_DIR/app/project.yml" ]; then
    SPEC_DIR="app"
elif [ -f "$PROJECT_DIR/macos/project.yml" ]; then
    SPEC_DIR="macos"
else
    echo "UAT launch failed: no project.yml found under app/ or macos/."
    exit 1
fi

APP_NAME=$(grep '^name:' "$PROJECT_DIR/$SPEC_DIR/project.yml" | head -1 | awk '{print $2}')
if [ -z "$APP_NAME" ]; then
    echo "UAT launch failed: could not read app name from $SPEC_DIR/project.yml."
    exit 1
fi

XCODEPROJ="$PROJECT_DIR/$SPEC_DIR/${APP_NAME}.xcodeproj"
if [ ! -d "$XCODEPROJ" ]; then
    echo "Regenerating Xcode project via xcodegen..."
    (cd "$PROJECT_DIR/$SPEC_DIR" && PATH="$HOME/bin:$PATH" xcodegen generate >/dev/null)
fi

echo "Building $APP_NAME on this Mac..."
(cd "$PROJECT_DIR/$SPEC_DIR" && xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "$APP_NAME" -destination 'platform=macOS' -configuration Debug build >/dev/null)

echo "Closing any running copy of $APP_NAME..."
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
sleep 1

APP_PATH=$(ls -d "$HOME/Library/Developer/Xcode/DerivedData/${APP_NAME}-"*/Build/Products/Debug/"${APP_NAME}.app" 2>/dev/null | head -n 1)
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "UAT launch failed: no DerivedData build found for $APP_NAME."
    exit 1
fi

open "$APP_PATH"

echo ""
echo "UAT build is running: $APP_PATH"
echo "HEAD: $(git rev-parse HEAD)"
echo ""
echo "Try the change. When it works the way you expect, the agent will record approval with:"
echo "  ./scripts/uat_approve.sh"
