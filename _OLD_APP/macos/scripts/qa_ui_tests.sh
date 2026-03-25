#!/usr/bin/env bash
# Runs XCTest UI bundle (HomeTeamUITests): launches the app, Accessibility, screenshots.
# Requires full Xcode; local runs need HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1 (or CI=true).
# Uses project signing (no CODE_SIGNING_ALLOWED=NO) so the test runner can launch the app.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/HomeTeamDerivedUITests}"
ALLOW_LOCAL_XCODEBUILD="${HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD:-0}"

if [[ "${CI:-}" != "true" && "${CI:-}" != "1" && "$ALLOW_LOCAL_XCODEBUILD" != "1" ]]; then
  echo "FAIL: Local UI test runs are disabled (avoid unexpected Accessibility prompts)."
  echo "  HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1 macos/scripts/qa_ui_tests.sh"
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export HOMETEAM_DESKTOP_AUTOMATION_QA=1

ONLY_TESTING="${HOMETEAM_UI_TESTS_ONLY:-HomeTeamUITests}"

exec "$SCRIPT_DIR/desktop_automation_gate.sh" xcodebuild \
  -project macos/HomeTeam.xcodeproj \
  -scheme HomeTeam \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  test \
  -only-testing:"$ONLY_TESTING"
