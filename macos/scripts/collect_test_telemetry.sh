#!/usr/bin/env bash
# collect_test_telemetry.sh <output_dir> [bundle1 bundle2 ...]
# Extracts pass/fail/skip counts from xcresult bundles and writes a JSON summary.
# Safe to run with zero bundles — produces an empty-run record.
#
# Used by: .github/workflows/qa-regression-telemetry.yml
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: collect_test_telemetry.sh <output_dir> [bundle...]" >&2
  exit 1
fi

OUTPUT_DIR="$1"
shift
BUNDLES=("$@")
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RUN_ID="${GITHUB_RUN_ID:-local_$(date +%s)}"
REPORT="$OUTPUT_DIR/telemetry_${RUN_ID}.json"

mkdir -p "$OUTPUT_DIR"

echo "▶ Collecting test telemetry (${#BUNDLES[@]} bundle(s) → $REPORT)"

# Extract summary from a single xcresult bundle using xcresulttool.
# Returns JSON fragment: {"passed":N,"failed":N,"skipped":N}
bundle_summary() {
  local bundle="$1"
  local raw
  raw=$(xcrun xcresulttool get --format json --path "$bundle" 2>/dev/null) || {
    echo '{"passed":0,"failed":0,"skipped":0,"error":"xcresulttool failed"}'
    return
  }
  python3 - "$raw" <<'PYEOF'
import json, sys

raw = sys.argv[1]
try:
    d = json.loads(raw)
    # Xcode 15 structure: actions._values[0].actionResult.metrics
    values = d.get("actions", {}).get("_values", [])
    passed = failed = skipped = 0
    for action in values:
        m = action.get("actionResult", {}).get("metrics", {})
        passed  += int(m.get("testsCount",       {}).get("_value", 0))
        failed  += int(m.get("testsFailedCount",  {}).get("_value", 0))
        skipped += int(m.get("testsSkippedCount", {}).get("_value", 0))
    print(json.dumps({"passed": passed, "failed": failed, "skipped": skipped}))
except Exception as e:
    print(json.dumps({"passed": 0, "failed": 0, "skipped": 0, "parse_error": str(e)}))
PYEOF
}

# Build bundle array JSON
BUNDLE_JSON="["
SEP=""
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

for bundle in "${BUNDLES[@]}"; do
  if [ ! -e "$bundle" ]; then
    echo "  ⚠️  bundle not found: $bundle" >&2
    continue
  fi
  echo "  processing: $bundle"
  SUMMARY=$(bundle_summary "$bundle")
  P=$(echo "$SUMMARY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('passed',0))")
  F=$(echo "$SUMMARY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('failed',0))")
  S=$(echo "$SUMMARY" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('skipped',0))")
  TOTAL_PASSED=$((TOTAL_PASSED + P))
  TOTAL_FAILED=$((TOTAL_FAILED + F))
  TOTAL_SKIPPED=$((TOTAL_SKIPPED + S))
  BUNDLE_JSON="${BUNDLE_JSON}${SEP}{\"path\":\"$(basename "$bundle")\",\"passed\":$P,\"failed\":$F,\"skipped\":$S}"
  SEP=","
done
BUNDLE_JSON="${BUNDLE_JSON}]"

STATUS="passed"
[ "$TOTAL_FAILED" -gt 0 ] && STATUS="failed"
[ "${#BUNDLES[@]}" -eq 0 ] && STATUS="no_bundles"

cat > "$REPORT" <<JSON
{
  "run_id": "$RUN_ID",
  "timestamp": "$TIMESTAMP",
  "status": "$STATUS",
  "totals": {
    "passed": $TOTAL_PASSED,
    "failed": $TOTAL_FAILED,
    "skipped": $TOTAL_SKIPPED
  },
  "bundles": $BUNDLE_JSON
}
JSON

echo "✅ Telemetry written → $REPORT"
echo "   passed=$TOTAL_PASSED  failed=$TOTAL_FAILED  skipped=$TOTAL_SKIPPED"
