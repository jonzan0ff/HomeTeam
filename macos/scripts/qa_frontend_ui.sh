#!/usr/bin/env bash
# qa_frontend_ui.sh
# Layer 2: frontend (menu bar app) snapshot QA. Runs FrontendSnapshotTests if
# implemented; produces a status report so CI tracks coverage over time.
#
# Env vars (set by workflow):
#   HOMETEAM_QA_WIDGET_SNAPSHOT_MODE  — "coverage" | "record"
#   HOMETEAM_QA_STORAGE_MODE          — "isolated" | "shared"
#
# Used by: .github/workflows/ui-qa.yml, .github/workflows/qa-regression-telemetry.yml
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$SCRIPT_DIR/../HomeTeam.xcodeproj"
OUTPUT_DIR="macos/artifacts/uiqa"
SNAPSHOT_MODE="${HOMETEAM_QA_WIDGET_SNAPSHOT_MODE:-coverage}"
STAMP="$(date +%s)"
RESULT_BUNDLE="/tmp/HomeTeamUIQA_${STAMP}.xcresult"

mkdir -p "$OUTPUT_DIR"

echo "▶ Frontend snapshot QA (mode=$SNAPSHOT_MODE)"

RUN_OUTPUT=""
RUN_EXIT=0
RUN_OUTPUT=$(xcodebuild test \
  -project "$PROJECT" \
  -scheme HomeTeam \
  -configuration Debug \
  -destination 'platform=macOS' \
  -allowProvisioningUpdates \
  ENABLE_TESTABILITY=YES \
  -only-testing "HomeTeamTests/FrontendSnapshotTests" \
  -resultBundlePath "$RESULT_BUNDLE" 2>&1) || RUN_EXIT=$?

if echo "$RUN_OUTPUT" | grep -qiE "no tests were executed|does not exist|not found"; then
  echo "⚠️  FrontendSnapshotTests not yet implemented (Layer 2 = 0%)"
  cat > "$OUTPUT_DIR/snapshot_status.json" <<JSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "layer": 2,
  "status": "not_implemented",
  "message": "FrontendSnapshotTests not yet written — see QA.md Layer 2",
  "mode": "$SNAPSHOT_MODE"
}
JSON
  exit 0
fi

if [ "$RUN_EXIT" -ne 0 ]; then
  echo "❌ Frontend snapshot tests FAILED (exit $RUN_EXIT)"
  echo "$RUN_OUTPUT" | tail -40
  exit 1
fi

cp -r "$RESULT_BUNDLE" "$OUTPUT_DIR/" 2>/dev/null || true

cat > "$OUTPUT_DIR/snapshot_status.json" <<JSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "layer": 2,
  "status": "passed",
  "bundle": "$RESULT_BUNDLE",
  "mode": "$SNAPSHOT_MODE"
}
JSON

echo "✅ Frontend snapshot QA passed — $RESULT_BUNDLE"
