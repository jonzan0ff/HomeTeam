#!/usr/bin/env bash
# build_verification_unit_gate.sh — deterministic unit tests on GitHub Actions
# Used by: .github/workflows/unit-gate.yml
#
# Scope: StreamingFilterTests (deterministic, no UI, no network, no signing).
# WidgetSnapshotTests and MenuBarPopoverSnapshotTests use NSHostingView, which
# requires a real window server session. CI runners crash with
# `CGSConnectionByID` assertion when AppKit/SwiftUI tries to connect. Per
# qa-standards.md §8, snapshot tests run on claudesandbox, not in GitHub CI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$SCRIPT_DIR/../HomeTeam.xcodeproj"
RESULT_BUNDLE="/tmp/HomeTeamUnitGate_$(date +%s).xcresult"

echo "▶ HomeTeam unit gate"
echo "  project : $PROJECT"
echo "  bundle  : $RESULT_BUNDLE"

xcodebuild test \
  -project "$PROJECT" \
  -scheme HomeTeam \
  -configuration Debug \
  -destination 'platform=macOS' \
  -allowProvisioningUpdates \
  ENABLE_TESTABILITY=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing HomeTeamTests/StreamingFilterTests \
  -resultBundlePath "$RESULT_BUNDLE"

echo "✅ Unit gate passed — $RESULT_BUNDLE"
