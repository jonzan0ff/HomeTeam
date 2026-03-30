#!/usr/bin/env bash
# qa_unit_gate.sh — run all unit tests (no network, no signing required)
# Used by: .github/workflows/unit-gate.yml
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
  -only-testing HomeTeamTests \
  -resultBundlePath "$RESULT_BUNDLE"

echo "✅ Unit gate passed — $RESULT_BUNDLE"
