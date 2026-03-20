#!/usr/bin/env bash
# Prompt-free deterministic test gate: no network, no live ESPN/API, no widget desktop automation.
# Fails the build if StreamingFilterTests or other offline-safe tests regress.
# Live snapshot + network smoke tests are opt-in via HOMETEAM_RUN_NETWORK_TESTS=1 (see capture_widget_screenshot.sh / qa_frontend_ui.sh).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/HomeTeamDerivedUnitGate}"
ALLOW_LOCAL_XCODEBUILD="${HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD:-0}"

if [[ "${CI:-}" != "true" && "${CI:-}" != "1" && "$ALLOW_LOCAL_XCODEBUILD" != "1" ]]; then
  echo "FAIL: Local xcodebuild is disabled (avoid privacy prompts). Run in CI, or:"
  echo "  HOMETEAM_QA_ALLOW_LOCAL_XCODEBUILD=1 macos/scripts/qa_unit_gate.sh"
  exit 2
fi

echo "[qa_unit_gate] Live tests require HOMETEAM_RUN_NETWORK_TESTS=1 (unset => skip; see macos/scripts/qa_frontend_ui.sh)."

if ! xcodebuild \
  -project macos/HomeTeam.xcodeproj \
  -scheme HomeTeam \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  test; then
  echo "FAIL: Unit gate tests failed. Fix regressions before relying on live QA."
  exit 1
fi

echo "OK: Unit gate passed (HomeTeamTests bundle, network-dependent tests skipped)."
