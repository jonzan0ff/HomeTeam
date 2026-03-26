#!/usr/bin/env bash
# capture_widget_screenshot.sh <output_dir>
# Layer 2: widget snapshot QA. Runs WidgetSnapshotTests if implemented; produces
# a status report regardless so CI can track coverage over time.
#
# Env vars (set by workflow):
#   HOMETEAM_QA_WIDGET_SNAPSHOT_MODE  — "coverage" | "record"  (default: coverage)
#   HOMETEAM_QA_STORAGE_MODE          — "isolated" | "shared"  (default: isolated)
#
# Used by: .github/workflows/ui-qa.yml, .github/workflows/qa-regression-telemetry.yml
set -euo pipefail

OUTPUT_DIR="${1:-macos/artifacts/widgetqa}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$SCRIPT_DIR/../HomeTeam.xcodeproj"
SNAPSHOT_MODE="${HOMETEAM_QA_WIDGET_SNAPSHOT_MODE:-coverage}"
STAMP="$(date +%s)"
RESULT_BUNDLE="/tmp/HomeTeamWidgetSnapshot_${STAMP}.xcresult"

mkdir -p "$OUTPUT_DIR"

echo "▶ Widget snapshot QA (mode=$SNAPSHOT_MODE)"

# Attempt to run WidgetSnapshotTests. If the class doesn't exist yet, xcodebuild
# exits non-zero with "no tests were executed" — we treat that as "not yet
# implemented" (warning, not failure) rather than a CI red.
RUN_OUTPUT=""
RUN_EXIT=0
RUN_OUTPUT=$(xcodebuild test \
  -project "$PROJECT" \
  -scheme HomeTeam \
  -configuration Debug \
  -destination 'platform=macOS' \
  -allowProvisioningUpdates \
  ENABLE_TESTABILITY=YES \
  -only-testing "HomeTeamTests/WidgetSnapshotTests" \
  -resultBundlePath "$RESULT_BUNDLE" 2>&1) || RUN_EXIT=$?

if echo "$RUN_OUTPUT" | grep -qiE "no tests were executed|does not exist|not found"; then
  echo "⚠️  WidgetSnapshotTests not yet implemented (Layer 2 = 0%)"
  cat > "$OUTPUT_DIR/snapshot_status.json" <<JSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "layer": 2,
  "status": "not_implemented",
  "message": "WidgetSnapshotTests not yet written — see QA.md Layer 2",
  "mode": "$SNAPSHOT_MODE"
}
JSON
  echo "  Status written to $OUTPUT_DIR/snapshot_status.json"
  exit 0
fi

if [ "$RUN_EXIT" -ne 0 ]; then
  echo "❌ Widget snapshot tests FAILED (exit $RUN_EXIT)"
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

echo "✅ Widget snapshot QA passed — $RESULT_BUNDLE"
